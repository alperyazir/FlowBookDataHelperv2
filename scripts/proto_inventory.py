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


def diff_answer_spans(orig_page, ans_page, tol=3.0):
    return _cached(orig_page, ("diff_spans", id(ans_page), tol),
                   lambda: _build_diff_spans(orig_page, ans_page, tol))


def _build_diff_spans(orig_page, ans_page, tol):
    """Spans present in answered but not in original = answer overlay.

    Position matching is tolerant: some publishers re-typeset the
    whole answered page with ~1pt drift, so "same text within tol"
    counts as the same printed span, not as an answer."""
    by_text = {}
    for o in get_spans(orig_page):
        by_text.setdefault(o["text"], []).append(o["bbox"])

    def is_new(s):
        for b in by_text.get(s["text"], ()):
            if abs(b[0] - s["bbox"][0]) <= tol and \
               abs(b[1] - s["bbox"][1]) <= tol:
                return False
        return True

    new = [s for s in get_spans(ans_page) if is_new(s)]

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


def diff_answer_drawings(orig_page, ans_page, tol=3.0):
    return _cached(orig_page, ("diff_draw", id(ans_page), tol),
                   lambda: _build_diff_drawings(orig_page, ans_page, tol))


def _build_diff_drawings(orig_page, ans_page, tol):
    """Vector drawings present only in answered pdf (circles, strokes...).

    Same drift tolerance as diff_answer_spans: a drawing with the same
    shape signature within tol points is the same printed artwork."""
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
        if any(abs(x - r.x0) <= tol and abs(y - r.y0) <= tol
               for x, y in by_sig.get(sig, ())):
            continue
        # Off-page clip-art bleed is not an answer mark.
        if not r.intersects(ans_page.rect):
            continue
        out.append({
            "bbox": [r.x0, r.y0, r.x1, r.y1],
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


def _build_image_rects(page):
    out = []
    for img in page.get_images(full=True):
        xref = img[0]
        for r in page.get_image_rects(xref):
            # Skip page-sized background images.
            if r.width > page.rect.width * 0.9 and r.height > page.rect.height * 0.9:
                continue
            out.append({"xref": xref, "bbox": [r.x0, r.y0, r.x1, r.y1]})
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
