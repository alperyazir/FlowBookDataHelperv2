"""Prototype: deterministic page inventory from an answered/original PDF pair.

For each requested page, extracts:
  - answer overlay spans (text diff between answered and original)
  - answer overlay drawings (vector diff: circles, lines drawn on answers)
  - blank lines (horizontal rules / dashed sequences the student writes on)
  - embedded image rects (photo cards etc.)
  - exercise number anchors ("1.", "2." ... at block starts)

Outputs per page:
  - <out>/page_NNN.png          annotated render (2x zoom)
  - <out>/page_NNN.json         raw inventory in PDF point coords

Usage:
  python3 proto_inventory.py <original.pdf> <answered.pdf> <out_dir> <page> [<page> ...]
"""

import json
import os
import re
import sys

import fitz
from PIL import Image, ImageDraw

ZOOM = 2.0

WHITE = 0xFFFFFF


# ---------------------------------------------------------------------------
# Page-level extraction cache: every detector re-parses the same page
# (get_text("dict") alone costs ~1.5s on vector-heavy pages and used
# to run 15-25x per page). The cache lives ON the fitz Page object, so
# it is freed with the page.
# ---------------------------------------------------------------------------

def _cached(page, key, builder):
    try:
        store = page._fb_cache
    except AttributeError:
        store = {}
        try:
            page._fb_cache = store
        except AttributeError:
            return builder()        # exotic page object: just compute
    if key not in store:
        store[key] = builder()
    return store[key]


def page_dict(page, ws=False):
    if ws:
        return _cached(page, "dict_ws", lambda: page.get_text(
            "dict", flags=fitz.TEXT_PRESERVE_WHITESPACE))
    return _cached(page, "dict", lambda: page.get_text("dict"))


def page_words(page):
    return _cached(page, "words", lambda: page.get_text("words"))


def page_plain_text(page):
    return _cached(page, "plain", lambda: page.get_text())


def page_drawings(page):
    return _cached(page, "drawings", lambda: _build_drawings(page))


def _build_drawings(page):
    """get_cdrawings() returns the same data as get_drawings() but ~5x
    faster: it leaves rect/points as plain tuples instead of building a
    fitz.Rect/Point per vector (the dominant cost on illustrated pages —
    Rise Up p13: 16.8s -> 3.2s for 380k drawings). Detectors read
    d["rect"] as a Rect, so wrap just the rect back (cheap, ~0.3s); the
    item operands are only ever read as op letters (item[0]), so leaving
    them as tuples is fine."""
    try:
        draws = page.get_cdrawings()
    except AttributeError:
        return page.get_drawings()   # very old PyMuPDF: fall back
    for d in draws:
        d["rect"] = fitz.Rect(d["rect"])
    return draws


def page_rawdict_ws(page):
    return _cached(page, "rawdict_ws", lambda: page.get_text(
        "rawdict", flags=fitz.TEXT_PRESERVE_WHITESPACE))


# ---------------------------------------------------------------------------
# Extraction helpers
# ---------------------------------------------------------------------------

def get_spans(page):
    return _cached(page, "spans", lambda: _build_spans(page))


def _build_spans(page):
    spans = []
    for b in page_dict(page, ws=True)["blocks"]:
        if b["type"] != 0:
            continue
        for l in b["lines"]:
            for s in l["spans"]:
                t = s["text"].strip()
                if t:
                    spans.append({
                        "text": t,
                        "bbox": list(s["bbox"]),
                        "color": s["color"],
                        "font": s["font"],
                        "size": s["size"],
                    })
    return spans


def span_key(s):
    return (s["text"], round(s["bbox"][0]), round(s["bbox"][1]))


# ---------------------------------------------------------------------------
# Page registration. Some publishers export the answered PDF with the whole
# page translated (Rise Up: EVERY page sits at a constant (-8.5, -8.5)pt vs
# the original). The ±3pt diff tolerance cannot absorb that, so the naive
# diff floods phantom "answers" (Rise Up: 3074 naive vs 358 after offset
# correction). Estimate the per-page (dx, dy) FIRST and diff around it.
#
# Estimator 1 — text anchors: spans whose text is unique on both pages are
# the same printed object; the median of their displacement is the page
# offset. Coherence = fraction of anchors within 1pt of the median (1.0 =
# rigid translation, low = per-block reflow -> fall through).
# Estimator 2 — phase correlation on the prep render cache (proto_prep):
# pages with no/short text layers (Trace pages, art spreads). Deterministic,
# subpixel, ~0.1s; `response` gates confidence.
# Fallback — (0, 0): the pre-registration behaviour.
#
# All diff results are mapped back into ORIGINAL page space (bbox - offset):
# blanks, tick boxes, obstacles and the editor's page PNGs all live there.
# ---------------------------------------------------------------------------

REG_MIN_PAIRS = 5      # text anchors needed for a trustworthy median
REG_COHERENCE = 0.6    # anchors agreeing with the median (else reflow)
REG_PAIR_TOL = 1.0     # "agreeing" = within this many pt of the median
REG_RESP_MIN = 0.4     # min phase-correlation response


def page_offset(orig_page, ans_page):
    """(dx, dy, method, conf): answered-page displacement vs original."""
    return _cached(orig_page, ("reg_offset", id(ans_page)),
                   lambda: _build_offset(orig_page, ans_page))


def _build_offset(po, pa):
    from collections import Counter
    import statistics
    so, sa = get_spans(po), get_spans(pa)
    co = Counter(s["text"] for s in so)
    ca = Counter(s["text"] for s in sa)
    bo = {s["text"]: s["bbox"] for s in so if co[s["text"]] == 1}
    ba = {s["text"]: s["bbox"] for s in sa if ca.get(s["text"]) == 1}
    pairs = [(ba[t][0] - b[0], ba[t][1] - b[1])
             for t, b in bo.items() if t in ba]
    if len(pairs) >= REG_MIN_PAIRS:
        dx = statistics.median(p[0] for p in pairs)
        dy = statistics.median(p[1] for p in pairs)
        coh = sum(1 for x, y in pairs
                  if abs(x - dx) <= REG_PAIR_TOL and
                  abs(y - dy) <= REG_PAIR_TOL) / len(pairs)
        if coh >= REG_COHERENCE:
            return {"dx": dx, "dy": dy, "method": "text", "conf": coh}
    off = _raster_offset(po, pa)
    if off:
        return off
    return {"dx": 0.0, "dy": 0.0, "method": "none", "conf": 0.0}


def _book_dir(page):
    """books/<name>/ derived from the PDF path (raw/ lives inside it)."""
    pdf = getattr(page.parent, "name", "") or ""
    d = os.path.dirname(os.path.abspath(pdf))
    return os.path.dirname(d) if os.path.basename(d) == "raw" else None


def _raster_offset(po, pa):
    """Phase-correlate the prep-cache renders (proto_prep). None when the
    cache/deps are missing or the correlation peak is ambiguous."""
    try:
        import cv2
        import numpy as np
        from PIL import Image
        from proto_prep import DPI, render_path
    except ImportError:
        return None
    bd_o, bd_a = _book_dir(po), _book_dir(pa)
    if not (bd_o and bd_a):
        return None
    pno = po.number + 1
    p_o = render_path(bd_o, "orig", pno, expect_pdf=getattr(po.parent, "name", None))
    p_a = render_path(bd_a, "ans", pno, expect_pdf=getattr(pa.parent, "name", None))
    if not (p_o and p_a):
        return None
    with Image.open(p_o) as im:
        go = np.asarray(im.convert("L"), dtype=np.float32)
    with Image.open(p_a) as im:
        ga = np.asarray(im.convert("L"), dtype=np.float32)
    h, w = min(go.shape[0], ga.shape[0]), min(go.shape[1], ga.shape[1])
    (dx, dy), resp = cv2.phaseCorrelate(go[:h, :w], ga[:h, :w])
    if resp < REG_RESP_MIN:
        # The cache is present but the pages do not correlate: the
        # answered page is re-LAID-OUT (front matter re-set, art
        # re-arranged), not translated. No offset can align it — the
        # whole diff is untrustworthy. Distinct from "no cache" (None):
        # callers use this to defer the page instead of flooding.
        return {"dx": 0.0, "dy": 0.0, "method": "raster_low", "conf": resp}
    scale = DPI / 72.0                 # render px per PDF pt (fixed by DPI)
    return {"dx": dx / scale, "dy": dy / scale,
            "method": "raster", "conf": resp}


def _shift_bbox(b, dx, dy):
    return [b[0] - dx, b[1] - dy, b[2] - dx, b[3] - dy]


REG_UNRELIABLE_MIN_ANSWERS = 10


def registration_unreliable(po, pa, min_answers=REG_UNRELIABLE_MIN_ANSWERS):
    """True when the page can't be aligned (re-laid-out: no shared text
    anchors AND no image correlation -> method 'raster_low') yet carries
    enough diff to matter. On such a page EVERY diff — spans and drawings
    alike — is phantom, so all deterministic detectors (fill, dragdrop,
    circle, markwithx, puzzle) should defer to the AI layer, not just fill.
    Shared by snap_page and the main Analyze so one page-level verdict
    governs every consumer."""
    if page_offset(po, pa)["method"] != "raster_low":
        return False
    return len(diff_answer_spans(po, pa)) >= min_answers


def diff_answer_spans(orig_page, ans_page, tol=3.0, offset=None):
    """offset: None = auto (page_offset); pass (0, 0) to force the old
    unregistered diff (eval/debug only)."""
    key = ("diff_spans", id(ans_page), tol,
           offset if offset is not None else "auto")
    return _cached(orig_page, key,
                   lambda: _build_diff_spans(orig_page, ans_page, tol, offset))


def _build_diff_spans(orig_page, ans_page, tol, offset=None):
    """Spans present in answered but not in original = answer overlay.

    Position matching is tolerant: some publishers re-typeset the
    whole answered page with ~1pt drift, so "same text within tol"
    counts as the same printed span, not as an answer. The measured
    page offset (registration above) is applied on top, and surviving
    answer bboxes are mapped back into original-page space."""
    if offset is None:
        off = page_offset(orig_page, ans_page)
        dx, dy = off["dx"], off["dy"]
    else:
        dx, dy = offset
    by_text = {}
    for o in get_spans(orig_page):
        by_text.setdefault(o["text"], []).append(o["bbox"])

    def is_new(s):
        for b in by_text.get(s["text"], ()):
            if abs(b[0] + dx - s["bbox"][0]) <= tol and \
               abs(b[1] + dy - s["bbox"][1]) <= tol:
                return False
        return True

    new = []
    for s in get_spans(ans_page):
        if is_new(s):
            s = dict(s)
            s["bbox"] = _shift_bbox(s["bbox"], dx, dy)
            new.append(s)

    # Drop white halo twins: keep the non-white copy of duplicated spans.
    by_key = {}
    for s in new:
        k = span_key(s)
        if k not in by_key or (by_key[k]["color"] == WHITE and s["color"] != WHITE):
            by_key[k] = s
    deduped = [s for s in by_key.values() if s["color"] != WHITE or True]
    # If a span only exists in white it is still an answer (rare); keep it.
    deduped.sort(key=lambda s: (s["bbox"][1], s["bbox"][0]))

    for s in deduped:
        s["is_checkmark"] = "ZapfDingbats" in s["font"]
    return deduped


def drawing_key(d):
    r = d["rect"]
    ops = "".join(item[0] for item in d["items"])
    return (round(r.x0, 1), round(r.y0, 1), round(r.x1, 1), round(r.y1, 1),
            ops, str(d.get("color")), str(d.get("fill")))


# When the answered page's vectors barely cancel against the original,
# the survivors are re-rendered artwork, not answer marks. Heavily
# illustrated books (Rise Up p13: 339k drawings survive a 380k-drawing
# diff) re-rasterize/re-typeset their art on the answered side so almost
# nothing matches. No real answer key draws this many marks — Goals_2's
# busiest legit page leaves 5,514 — so above this we treat the page's
# vector diff as unusable and defer it to the AI vision layer. This also
# stops the circle/mark detectors from grinding through artwork noise.
DIFF_DRAW_CAP = 10000


def diff_answer_drawings(orig_page, ans_page, tol=3.0, offset=None):
    key = ("diff_draw", id(ans_page), tol,
           offset if offset is not None else "auto")
    return _cached(orig_page, key,
                   lambda: _build_diff_drawings(orig_page, ans_page, tol, offset))


def _build_diff_drawings(orig_page, ans_page, tol, offset=None):
    """Vector drawings present only in answered pdf (circles, strokes...).

    Same drift tolerance as diff_answer_spans: a drawing with the same
    shape signature within tol points is the same printed artwork. The
    measured page offset is applied the same way, and surviving marks
    are mapped back into original-page space."""
    if offset is None:
        off = page_offset(orig_page, ans_page)
        dx, dy = off["dx"], off["dy"]
    else:
        dx, dy = offset
    by_sig = {}
    for d in page_drawings(orig_page):
        r = d["rect"]
        sig = ("".join(item[0] for item in d["items"]),
               str(d.get("color")), str(d.get("fill")),
               round(r.width), round(r.height))
        by_sig.setdefault(sig, []).append((r.x0, r.y0))
    out = []
    for d in page_drawings(ans_page):
        r = d["rect"]
        sig = ("".join(item[0] for item in d["items"]),
               str(d.get("color")), str(d.get("fill")),
               round(r.width), round(r.height))
        if any(abs(x + dx - r.x0) <= tol and abs(y + dy - r.y0) <= tol
               for x, y in by_sig.get(sig, ())):
            continue
        # Off-page clip-art bleed is not an answer mark.
        if not r.intersects(ans_page.rect):
            continue
        out.append({
            "bbox": _shift_bbox([r.x0, r.y0, r.x1, r.y1], dx, dy),
            "ops": "".join(item[0] for item in d["items"]),
            "color": list(d["color"]) if d.get("color") else None,
        })
    if len(out) > DIFF_DRAW_CAP:
        return []        # vector layers don't align — defer to AI
    return out


BLANK_CHARS = set("._…")


def find_underscore_runs(page, min_chars=4):
    """Blanks typed as underscore/dot runs, possibly inside mixed spans
    ("Hello, I am ______ . I like ____"). Uses per-char bboxes."""
    runs = []
    raw = page_rawdict_ws(page)
    for b in raw["blocks"]:
        if b["type"] != 0:
            continue
        for l in b["lines"]:
            for s in l["spans"]:
                run = []
                for ch in s["chars"] + [{"c": "\0", "bbox": None}]:  # sentinel
                    if ch["c"] in BLANK_CHARS:
                        run.append(ch["bbox"])
                    else:
                        if len(run) >= min_chars:
                            x0 = min(r[0] for r in run)
                            y0 = min(r[1] for r in run)
                            x1 = max(r[2] for r in run)
                            y1 = max(r[3] for r in run)
                            runs.append([x0, y0, x1, y1])
                        run = []
    return runs


def find_blank_lines(page, min_w=15.0, max_h=3.0, merge_gap=6.0):
    return _cached(page, ("blanks", min_w, max_h, merge_gap),
                   lambda: _build_blank_lines(page, min_w, max_h, merge_gap))


def _build_blank_lines(page, min_w=15.0, max_h=3.0, merge_gap=6.0):
    """Horizontal rules / dash sequences students write on.

    Collects thin, wide vector segments and merges collinear pieces
    (dashed lines arrive as many short segments on one baseline).
    """
    page_rect = page.rect
    segs = []
    seen = set()
    for d in page_drawings(page):       # cached: was a 2nd full get_drawings()
        r = d["rect"]
        # Off-page clip-art and duplicated objects produce garbage.
        if not r.intersects(page_rect):
            continue
        key = (round(r.x0, 1), round(r.y0, 1), round(r.x1, 1), round(r.y1, 1))
        if key in seen:
            continue
        seen.add(key)
        if r.height <= max_h and r.width >= 2.0:
            segs.append(r)

    # Group by baseline y (rounded), merge segments with small x gaps.
    segs.sort(key=lambda r: (round((r.y0 + r.y1) / 2, 0), r.x0))
    merged = []
    for r in segs:
        y = (r.y0 + r.y1) / 2
        if merged:
            m = merged[-1]
            my = (m[1] + m[3]) / 2
            if abs(my - y) <= 1.5 and r.x0 - m[2] <= merge_gap:
                m[2] = max(m[2], r.x1)
                m[1], m[3] = min(m[1], r.y0), max(m[3], r.y1)
                continue
        merged.append([r.x0, r.y0, r.x1, r.y1])

    # Also: blanks typed as underscore/dot character runs.
    merged.extend(find_underscore_runs(page))

    return [m for m in merged if (m[2] - m[0]) >= min_w]


def find_image_rects(page):
    return _cached(page, "imgrects", lambda: _build_image_rects(page))


# Pages whose artwork is TILED from thousands of small images (Rise Up
# p101: 3,754 images -> 15.8M placement rects) are decorative art, not
# photo layouts; enumerating them costs minutes and every consumer of
# image rects (photo cards, match pictures, blob features) wants none
# of them. Real photo pages carry a few dozen images at most.
IMG_LIST_CAP = 600


def _build_image_rects(page):
    imgs = page.get_images(full=True)
    if len(imgs) > IMG_LIST_CAP:
        return []
    out = []
    for img in imgs:
        xref = img[0]
        for r in page.get_image_rects(xref):
            # Skip page-sized background images.
            if r.width > page.rect.width * 0.9 and r.height > page.rect.height * 0.9:
                continue
            out.append({"xref": xref, "bbox": [r.x0, r.y0, r.x1, r.y1]})
        if len(out) > IMG_LIST_CAP * 20:
            return []          # placement-rect flood: same tiled-art case
    return out


def find_exercise_anchors(page):
    """Text spans like '1.' '2.' that start an exercise block."""
    anchors = []
    for s in get_spans(page):
        if re.fullmatch(r"\d{1,2}\.?", s["text"]) and s["size"] >= 9:
            anchors.append(s)
    return anchors


# ---------------------------------------------------------------------------
# Rendering
# ---------------------------------------------------------------------------

COLORS = {
    "answer": (255, 0, 0),
    "answer_drawing": (255, 140, 0),
    "blank": (0, 120, 255),
    "image": (0, 180, 0),
    "anchor": (160, 0, 200),
}


def render_annotated(orig_page, inventory, out_png):
    pix = orig_page.get_pixmap(matrix=fitz.Matrix(ZOOM, ZOOM))
    img = Image.frombytes("RGB", (pix.width, pix.height), pix.samples)
    drw = ImageDraw.Draw(img)

    def box(bbox, color, width=3, label=None):
        x0, y0, x1, y1 = (v * ZOOM for v in bbox)
        if x1 - x0 < 2: x1 = x0 + 2
        if y1 - y0 < 2: y1 = y0 + 2
        drw.rectangle([x0, y0, x1, y1], outline=color, width=width)
        if label:
            drw.text((x0 + 2, max(0, y0 - 14)), label, fill=color)

    for r in inventory["image_rects"]:
        box(r["bbox"], COLORS["image"], 2)
    for b in inventory["blank_lines"]:
        box(b, COLORS["blank"], 2)
    for a in inventory["exercise_anchors"]:
        box(a["bbox"], COLORS["anchor"], 3, a["text"])
    for d in inventory["answer_drawings"]:
        box(d["bbox"], COLORS["answer_drawing"], 2)
    for s in inventory["answer_spans"]:
        label = "✓" if s["is_checkmark"] else s["text"][:18]
        box(s["bbox"], COLORS["answer"], 3, label)

    img.save(out_png)


# ---------------------------------------------------------------------------

def main():
    if len(sys.argv) < 5:
        print(__doc__)
        sys.exit(1)
    orig_path, ans_path, out_dir = sys.argv[1:4]
    pages = [int(p) for p in sys.argv[4:]]
    os.makedirs(out_dir, exist_ok=True)

    orig = fitz.open(orig_path)
    ans = fitz.open(ans_path)
    if len(orig) != len(ans):
        print(f"WARNING: page counts differ ({len(orig)} vs {len(ans)})")

    for pno in pages:
        po, pa = orig[pno - 1], ans[pno - 1]
        inv = {
            "page": pno,
            "page_size": [po.rect.width, po.rect.height],
            "answer_spans": diff_answer_spans(po, pa),
            "answer_drawings": diff_answer_drawings(po, pa),
            "blank_lines": find_blank_lines(po),
            "image_rects": find_image_rects(po),
            "exercise_anchors": find_exercise_anchors(po),
        }
        base = os.path.join(out_dir, f"page_{pno:03d}")
        with open(base + ".json", "w", encoding="utf-8") as f:
            json.dump(inv, f, ensure_ascii=False, indent=1)
        render_annotated(po, inv, base + ".png")
        print(f"page {pno}: answers={len(inv['answer_spans'])} "
              f"ans_drawings={len(inv['answer_drawings'])} "
              f"blanks={len(inv['blank_lines'])} images={len(inv['image_rects'])} "
              f"anchors={len(inv['exercise_anchors'])}")

    orig.close(); ans.close()


if __name__ == "__main__":
    main()
