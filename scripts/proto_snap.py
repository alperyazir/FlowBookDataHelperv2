"""Prototype step 2: snap answer overlays to the blanks they belong to.

Builds on proto_inventory. For every answer span found by the
answered/original diff, finds the blank line (or tick box) underneath
and produces the clickable rect the editor needs:

  - text answers  -> snapped to the full width of their blank line;
                     blanks shared by several answers are split between them
  - checkmarks    -> snapped to the nearest small square (tick box) drawing
  - no match      -> inflated answer bbox, flagged needs_review

Outputs per page:
  - <out>/page_NNN_snap.png   render: red = answer, blue = blank,
                              yellow = produced clickable rect (dashed if review)
  - <out>/page_NNN_snap.json  clickable rects in PDF points + PNG pixels

Usage:
  python3 proto_snap.py <original.pdf> <answered.pdf> <out_dir> <page> [<page> ...]
"""

import json
import re
import os
import sys

import fitz
from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from proto_inventory import (ZOOM, diff_answer_spans, find_blank_lines,
                             find_image_rects, get_spans,
                             page_drawings, page_plain_text)
try:
    # Optional: needs OpenCV. Without it, raster-artwork answers are
    # flagged needs_review instead of being snapped.
    from proto_cv import cv_snap_box, render_page_bgr
    HAVE_CV = True
except ImportError:
    HAVE_CV = False
try:
    # Optional raster-diff channel (needs OpenCV + the proto_prep render
    # cache). Provides the strongest phantom test we have: a text-diff
    # "answer" whose bbox contains no changed pixels on the aligned
    # render pair is invisible ink — a re-typeset/span-splitting echo,
    # never a real answer. Real typed answers measure >=10% changed
    # pixels; echoes measure ~0 (calibrated on Amazing + Rise Up).
    from proto_raster import support_fraction
    HAVE_RASTER_DIFF = True
except ImportError:
    HAVE_RASTER_DIFF = False

RASTER_SUPPORT_MIN = 0.02

# Snap tolerances (PDF points)
DY_MAX = 10.0                 # blank baseline below answer bottom
DY_MIN_FACTOR = 0.65          # ... or overlapping up to this fraction of height
X_GAP_MAX = 12.0              # max horizontal gap between answer and blank
INLINE_PAD = 2.0              # symmetric padding around the answer line
MAX_H_FACTOR = 1.6            # hard cap in answer-text heights
TICK_BOX_MIN, TICK_BOX_MAX = 6.0, 22.0
TICK_DIST_MAX = 18.0


def x_overlap_or_gap(a0, a1, b0, b1):
    """>0 overlap amount, <0 gap size (negative)."""
    return min(a1, b1) - max(a0, b0)


def find_tick_boxes(page):
    """Small square-ish vector rects: the boxes students tick."""
    boxes = []
    for d in page_drawings(page):
        r = d["rect"]
        w, h = r.width, r.height
        if TICK_BOX_MIN <= w <= TICK_BOX_MAX and TICK_BOX_MIN <= h <= TICK_BOX_MAX \
                and abs(w - h) <= 6:
            boxes.append([r.x0, r.y0, r.x1, r.y1])
    return boxes


def snap_text_answer(span, blanks):
    """Return (blank, score) of the best blank under the span, or None."""
    sx0, sy0, sx1, sy1 = span["bbox"]
    dy_min = -(sy1 - sy0) * DY_MIN_FACTOR  # answer may sit ON the line
    best, best_score = None, 1e9
    for b in blanks:
        bx0, by0, bx1, by1 = b
        by = (by0 + by1) / 2
        dy = by - sy1
        if not (dy_min <= dy <= DY_MAX):
            continue
        ov = x_overlap_or_gap(sx0, sx1, bx0, bx1)
        if ov < -X_GAP_MAX:
            continue
        score = abs(dy) + (0.0 if ov > 0 else -ov * 0.5)
        if score < best_score:
            best, best_score = b, score
    return best


def snap_checkmark(span, tick_boxes):
    sx0, sy0, sx1, sy1 = span["bbox"]
    cx, cy = (sx0 + sx1) / 2, (sy0 + sy1) / 2
    best, best_d = None, TICK_DIST_MAX
    for b in tick_boxes:
        bx, by = (b[0] + b[2]) / 2, (b[1] + b[3]) / 2
        d = ((cx - bx) ** 2 + (cy - by) ** 2) ** 0.5
        if d < best_d:
            best, best_d = b, d
    return best


# Publisher notes that mark free-text exercises, not real answers.
NON_ANSWER_RE = re.compile(
    r"student.{0,4}own answers|öğrencinin kendi cevabı", re.IGNORECASE)

# Label-like tokens that are phantoms when re-typeset by the key:
# speaker labels ("Cora:"), option letters ("a."), bare item numbers.
SHORT_PHANTOM_RE = re.compile(r"^\w+[.!?:]$|^[a-hA-H][.)]$|^\d{1,2}[.)]?$")


def build_clickables(answers, blanks, tick_boxes, obstacles=None):
    """Produce one clickable rect per answer.

    obstacles: bboxes of pre-printed page content (text spans etc.);
    blank-snapped boxes grow upward into free space until they hit one.
    """
    answers = [s for s in answers if not NON_ANSWER_RE.search(s["text"])]
    # Decorative glyphs that differ between the PDF revisions ('>',
    # arrows, bullets) are not answers — an answer has a word in it.
    answers = [s for s in answers
               if s["is_checkmark"] or re.search(r"\w", s["text"])]
    obstacles = obstacles or []
    # First pass: group text answers by the blank they snap to.
    by_blank = {}
    results = []
    for s in answers:
        if s["is_checkmark"]:
            box = snap_checkmark(s, tick_boxes)
            if box:
                pad = 2.0
                rect = [box[0] - pad, box[1] - pad, box[2] + pad, box[3] + pad]
                results.append({"answer": s, "rect": rect, "snap": "tickbox"})
            else:
                results.append({"answer": s, "rect": _inflated(s), "snap": "none"})
            continue
        b = snap_text_answer(s, blanks)
        if b is not None:
            by_blank.setdefault(tuple(b), []).append(s)
            continue
        # Short answers (T/F, single letters) are written into small boxes.
        box = snap_checkmark(s, tick_boxes) if len(s["text"]) <= 2 else None
        if box:
            pad = 2.0
            rect = [box[0] - pad, box[1] - pad, box[2] + pad, box[3] + pad]
            results.append({"answer": s, "rect": rect, "snap": "tickbox"})
        else:
            results.append({"answer": s, "rect": _inflated(s), "snap": "none"})

    # Second pass: blanks shared by N answers get split at midpoints.
    for bkey, spans in by_blank.items():
        bx0, by0, bx1, by1 = bkey
        spans.sort(key=lambda s: s["bbox"][0])
        cuts = [bx0]
        for a, b in zip(spans, spans[1:]):
            cuts.append((a["bbox"][2] + b["bbox"][0]) / 2)
        cuts.append(bx1)
        for i, s in enumerate(spans):
            text_h = s["bbox"][3] - s["bbox"][1]
            bottom = max(by1, s["bbox"][3])
            x0 = min(cuts[i], s["bbox"][0])      # answer may stick out of the line
            x1 = max(cuts[i + 1], s["bbox"][2])

            # The box is a one-line writing slot: answer line height + pad.
            top = bottom - (text_h + 2 * INLINE_PAD)
            # Inline gap: match the line of printed neighbors on this row.
            for ob in obstacles:
                v_ov = min(ob[3], s["bbox"][3]) - max(ob[1], s["bbox"][1])
                h_gap = max(ob[0] - x1, x0 - ob[2])
                if v_ov >= text_h * 0.5 and h_gap < 30:
                    top = min(top, ob[1] - 1)
            top = max(top, bottom - MAX_H_FACTOR * text_h)
            # Never overlap content strictly above this row.
            above = [ob[3] for ob in obstacles
                     if ob[2] > x0 and ob[0] < x1 and ob[3] <= s["bbox"][1] + 1]
            if above:
                top = max(top, max(above) + 1.5)
            top = min(top, s["bbox"][1] - 1)     # always cover the answer text
            results.append({
                "answer": s,
                "rect": [x0, top, x1, bottom],
                "snap": "blank" if len(spans) == 1 else "blank_shared",
            })

    results.sort(key=lambda r: (r["rect"][1], r["rect"][0]))
    return results


def separate_clickables(clickables):
    """Click targets must never overlap (dense tables write answers
    taller than the row pitch): shave overlapping pairs apart at the
    middle of the penetration, along the shallower axis."""
    for i in range(len(clickables)):
        for j in range(i + 1, len(clickables)):
            a, b = list(clickables[i]["rect"]), list(clickables[j]["rect"])
            ix = min(a[2], b[2]) - max(a[0], b[0])
            iy = min(a[3], b[3]) - max(a[1], b[1])
            if ix <= 1 or iy <= 1:
                continue
            if ix <= iy:       # separate horizontally
                cut = (max(a[0], b[0]) + min(a[2], b[2])) / 2
                if a[0] < b[0]:
                    a[2], b[0] = cut - 0.5, cut + 0.5
                else:
                    b[2], a[0] = cut - 0.5, cut + 0.5
            else:              # separate vertically
                cut = (max(a[1], b[1]) + min(a[3], b[3])) / 2
                if a[1] < b[1]:
                    a[3], b[1] = cut - 0.5, cut + 0.5
                else:
                    b[3], a[1] = cut - 0.5, cut + 0.5
            clickables[i]["rect"], clickables[j]["rect"] = a, b
    return clickables


_WS_NORM = re.compile(r"\s+")


def _norm_text(t):
    return _WS_NORM.sub("", t).lower()


# Re-typeset echo detection. Some publishers re-export the answered PDF with
# the whole page re-typeset at a constant horizontal offset (Rise Up: dx is
# constant, dy reflows per block). The position diff then flags every printed
# span as a "new" answer — flooding content pages with phantom fills, even
# ones that snap to a box (e.g. re-typeset slot numbers "1".."12"). A real
# answer sits at its own position and does NOT match the page's dominant
# offset. So: find the dominant horizontal displacement (dx) among diff spans
# whose text also exists in the original, and drop the spans that match it.
RETYPE_MIN_VOTES = 4       # dominant dx must have at least this many spans
RETYPE_DX_TOL = 3.0        # ... within this many points to count as the echo
RETYPE_RESCUE_SUPPORT = 0.03   # raster support above this = real answer


def _retypeset_echo_ids(po, pa, answers):
    orig = get_spans(po)
    by_text = {}
    for s in orig:
        by_text.setdefault(_norm_text(s["text"]), []).append(s["bbox"])
    cands = []                              # (answer, dx, dy) vs nearest twin
    for a in answers:
        if a.get("is_checkmark"):
            continue                        # a tick is never printed text
        k = _norm_text(a["text"])
        if not k:
            continue
        twins = by_text.get(k)
        if not twins:
            continue
        ax, ay = a["bbox"][0], a["bbox"][1]
        b = min(twins, key=lambda c: (ax - c[0]) ** 2 + (ay - c[1]) ** 2)
        cands.append((a, ax - b[0], ay - b[1]))
    if len(cands) < RETYPE_MIN_VOTES:
        return set()
    from collections import Counter
    dom_dx, votes = Counter(round(dx) for _, dx, _ in cands).most_common(1)[0]
    if votes < RETYPE_MIN_VOTES:
        return set()
    echo = {id(a): a for a, dx, _ in cands if abs(dx - dom_dx) <= RETYPE_DX_TOL}
    # The dominant-dx vote also captures REAL answers written in a fixed
    # column whose texts are printed on the page (option letters copied
    # into boxes: every 'a'..'k' sits at a constant dx from its label —
    # Amazing p14/p25). Only the raster channel can tell them apart: on a
    # coherently registered page a true echo renders identically (no ink at
    # its position), a real answer leaves ink.
    #
    # Fail-safe: DROP an echo only when the raster channel POSITIVELY
    # confirms it as a phantom (coherent registration + support below the
    # ink threshold). Without that proof — no render cache on this host, or
    # a page we can't register confidently — rescue the span. Deleting a
    # real fixed-column answer is unrecoverable; keeping a phantom is not.
    if not echo:
        return set()
    from proto_inventory import page_offset
    off = page_offset(po, pa)
    coherent = (off["method"] == "text" and off["conf"] >= 0.9) or \
               (off["method"] == "raster" and off["conf"] >= 0.7)
    for aid, a in list(echo.items()):
        confirmed_phantom = False
        if HAVE_RASTER_DIFF and coherent:
            sup = support_fraction(po, pa, a["bbox"])
            if sup is not None and sup < RETYPE_RESCUE_SUPPORT:
                confirmed_phantom = True
        if not confirmed_phantom:
            del echo[aid]
    return set(echo)


def snap_page(po, pa, sx, sy, skip_rects=None, use_cv=True,
              drop_offset_echoes=False):
    """Full fill pipeline for one page: diff -> snap -> optional CV
    fallback -> editor-format fill sections (PNG-pixel coords).

    skip_rects: clickable rects (PDF points) another activity already
    owns (e.g. dragdrop drop zones) — dropped from the fill section.
    use_cv: run the OpenCV banner-snap fallback for answers that match
    no blank/tick box. On free-label artwork (label-the-picture pages)
    the flood-fill grabs big illustration regions and merges neighbours
    into one block — the re-check path passes use_cv=False so unmatched
    answers keep their tight text bbox instead.
    drop_offset_echoes: remove re-typeset echoes (spans matching the page's
    dominant offset) before snapping — kills phantom fills on re-exported
    content pages regardless of whether they snap to a box."""
    answers = diff_answer_spans(po, pa)
    if not answers:
        return [], {}
    # Registration-reliability guard: the render cache exists but the
    # pages neither share text anchors nor correlate as images — the
    # answered page is re-laid-out (front matter, re-arranged art).
    # Every "diff" on such a page is noise; defer to the AI layer.
    from proto_inventory import registration_unreliable
    if registration_unreliable(po, pa):
        return [], {"registration_unreliable": len(answers)}
    if drop_offset_echoes:
        echo_ids = _retypeset_echo_ids(po, pa, answers)
        if echo_ids:
            answers = [a for a in answers if id(a) not in echo_ids]
            if not answers:
                return [], {"retypeset_echoes": len(echo_ids)}
    # Diff-reliability guard. On pages where the student book stores its
    # printed text as outlines/raster (Trace pages, fully illustrated
    # pages) the original has NO text layer, so the answered page's
    # entire printed text — labels, instructions, dialogue — surfaces as
    # "answers" (Rise Up p16: 35 phantom fills from the page's own
    # words). With no text baseline to subtract, fills are unrecoverable
    # here; defer the page to the AI vision layer rather than flood it.
    if not get_spans(po):
        return [], {"diff_unreliable": "original page has no text layer"}
    # A flood of single-letter answers is a solved letter grid. Two
    # kinds: CROSSWORD cells are small vector squares the student
    # types into (keep those letters — they become per-cell fills,
    # same as the human editors do) vs WORD-SEARCH grids with no cell
    # boxes (drop — that's a puzzle activity, not fills).
    letters = [a for a in answers
               if len(a["text"].strip()) == 1 and a["text"].strip().isalpha()]
    if len(letters) >= 20:
        cells = find_tick_boxes(po)
        def on_cell(a):
            cx = (a["bbox"][0] + a["bbox"][2]) / 2
            cy = (a["bbox"][1] + a["bbox"][3]) / 2
            return any(b[0] - 2 <= cx <= b[2] + 2 and
                       b[1] - 2 <= cy <= b[3] + 2 for b in cells)
        drop = {id(a) for a in letters if not on_cell(a)}
        answers = [a for a in answers if id(a) not in drop]
    if not answers:
        return [], {"puzzle_letters": len(letters)}
    blanks = find_blank_lines(po)
    obstacles = [s["bbox"] for s in get_spans(po)] + blanks
    clickables = build_clickables(answers, blanks, find_tick_boxes(po), obstacles)
    if skip_rects:
        def owned(c):
            return any(all(abs(a - b) < 0.5 for a, b in zip(c["rect"], r))
                       for r in skip_rects)
        clickables = [c for c in clickables if not owned(c)]
    unmatched = [c for c in clickables if c["snap"] == "none"]
    if unmatched and HAVE_CV and use_cv:
        for c in unmatched:
            rect = cv_snap_box(po, c["answer"]["bbox"])
            if rect:
                c["rect"] = rect
                c["snap"] = "cvbox"
        clickables = merge_same_region(clickables)
    # Phantom answers: answer-key PDFs re-typeset printed content in
    # color (correct option texts, instructions, speaker labels, item
    # numbers, table values). An "answer" that never snapped AND
    # already exists verbatim in the original page text is such an
    # echo when it is long, or when it looks like a label/number.
    page_text = re.sub(r"\s+", " ", page_plain_text(po)).lower()
    # Printed CONTENT only: underscore/dot runs are the blanks answers
    # get written onto — they must not count as "printed text", even
    # with a stray "?" at the end ("________ ?").
    def is_content(t):
        body = re.sub(r"[\s._…]", "", t)
        return len(body) > 0.3 * len(t.strip())
    orig_spans = [s["bbox"] for s in get_spans(po) if is_content(s["text"])]
    def over_print(c):
        """Share of the answer span lying ON original printed text —
        echoes are re-typeset in place, real answers sit on blanks."""
        ab = c["answer"]["bbox"]
        area = max(1e-6, (ab[2] - ab[0]) * (ab[3] - ab[1]))
        cov = 0.0
        for ob in orig_spans:
            ix = min(ab[2], ob[2]) - max(ab[0], ob[0])
            iy = min(ab[3], ob[3]) - max(ab[1], ob[1])
            if ix > 0 and iy > 0:
                cov += ix * iy
        return cov / area
    def phantom(c):
        t = re.sub(r"\s+", " ", c["answer"]["text"]).strip().lower()
        # Answer keys re-typeset printed content in color (instruction
        # lines, correct option texts): a long "answer" drawn ON TOP of
        # original text is such an echo. The text itself can't decide —
        # ligature-broken layers defeat matching, and real reading
        # answers quote the passage — but the LOCATION can.
        if len(t) >= 15 and over_print(c) >= 0.5:
            return True
        return (c["snap"] == "none" and t in page_text
                and bool(SHORT_PHANTOM_RE.match(t)))
    clickables = [c for c in clickables if not phantom(c)]
    # Raster fusion guard: no ink on the aligned render pair = phantom,
    # snapped or not. Skipped silently when the render cache is absent.
    dropped_raster = 0
    if HAVE_RASTER_DIFF:
        kept = []
        for c in clickables:
            sup = support_fraction(po, pa, c["answer"]["bbox"])
            if sup is not None and sup < RASTER_SUPPORT_MIN:
                dropped_raster += 1
            else:
                kept.append(c)
        clickables = kept
    separate_clickables(clickables)
    stats = {}
    for c in clickables:
        stats[c["snap"]] = stats.get(c["snap"], 0) + 1
    if dropped_raster:
        stats["raster_phantom"] = dropped_raster
    return sections_from_clickables(clickables, sx, sy), stats


def px_coords(rect_pt, sx, sy):
    x0, y0, x1, y1 = rect_pt
    return {"x": int(round(x0 * sx)), "y": int(round(y0 * sy)),
            "w": int(round((x1 - x0) * sx)), "h": int(round((y1 - y0) * sy))}


def sections_from_clickables(clickables, sx, sy):
    """Convert snapped clickables to config.json fill sections."""
    fills = []
    for c in clickables:
        # Ticks are fill answers too: the student puts a "✓" in the box.
        ans = {
            "coords": px_coords(c["rect"], sx, sy),
            "text": "✓" if c["answer"]["is_checkmark"] else c["answer"]["text"],
            "is_text_bold": True,
            "opacity": 1,
        }
        if c["snap"] == "none":
            ans["needs_review"] = True
        fills.append(ans)

    if not fills:
        return []
    return [{
        "type": "fill",
        "activity": {"circleCount": 0, "markCount": 0},
        "answer": fills,
        "audio_extra": {},
    }]


def order_answers(answers, page_width_px=0):
    """Order a fill activity's answer[] the way a reader fills them in.

    Default: top-to-bottom, left-to-right. Two-column exercises: left
    column top-to-bottom, THEN right column. A clean center gutter is
    required to switch to column mode (some answers entirely left, some
    entirely right, none straddling the middle) — anything ambiguous
    falls back to plain (y, x), so we never reorder a layout we misread.
    Mirror of ai_analyzer.order_page_sections, keyed on each answer's own
    `coords` (page-space image-pixel space)."""
    if len(answers) < 2:
        return list(answers)
    def box(a):
        c = a.get("coords") or {}
        x, y = c.get("x", 0), c.get("y", 0)
        return (x, y, x + c.get("w", 0), y + c.get("h", 0))
    boxes = [box(a) for a in answers]
    if page_width_px:
        mid = page_width_px / 2.0
        margin = page_width_px * 0.06
        def center(b):
            return (b[0] + b[2]) / 2.0
        straddles = any(b[0] < mid - margin and b[2] > mid + margin
                        for b in boxes)
        has_left = any(center(b) < mid and b[2] <= mid + margin for b in boxes)
        has_right = any(center(b) > mid and b[0] >= mid - margin for b in boxes)
        if has_left and has_right and not straddles:
            order = sorted(range(len(answers)),
                           key=lambda i: (0 if center(boxes[i]) < mid else 1,
                                          boxes[i][1], boxes[i][0]))
            return [answers[i] for i in order]
    order = sorted(range(len(answers)),
                   key=lambda i: (boxes[i][1], boxes[i][0]))
    return [answers[i] for i in order]


def merge_same_region(clickables):
    """Multi-line labels on one banner snap to the same CV region;
    they are one clickable, not several."""
    def iou(a, b):
        ix = max(0, min(a[2], b[2]) - max(a[0], b[0]))
        iy = max(0, min(a[3], b[3]) - max(a[1], b[1]))
        inter = ix * iy
        if inter == 0:
            return 0.0
        area = lambda r: (r[2] - r[0]) * (r[3] - r[1])
        return inter / (area(a) + area(b) - inter)

    def absorb(host, c):
        host["answer"] = dict(host["answer"])
        host["answer"]["text"] += " " + c["answer"]["text"]
        r1, r2 = host["rect"], c["rect"]
        host["rect"] = [min(r1[0], r2[0]), min(r1[1], r2[1]),
                        max(r1[2], r2[2]), max(r1[3], r2[3])]

    out = []
    leftovers = []
    for c in clickables:
        if c["snap"] == "cvbox":
            host = next((o for o in out if o["snap"] == "cvbox"
                         and iou(o["rect"], c["rect"]) > 0.5), None)
            if host:
                absorb(host, c)
                continue
        out.append(c)

    # Lines whose own seeds found nothing still belong to the banner
    # they touch (second line of a label overflowing the artwork).
    def intersects(a, b):
        return min(a[2], b[2]) > max(a[0], b[0]) and min(a[3], b[3]) > max(a[1], b[1])

    for c in [c for c in out if c["snap"] == "none"]:
        host = next((o for o in out if o["snap"] == "cvbox"
                     and intersects(o["rect"], c["answer"]["bbox"])), None)
        if host:
            absorb(host, c)
            out.remove(c)
    return out


def _inflated(span, pad=4.0):
    x0, y0, x1, y1 = span["bbox"]
    return [x0 - pad, y0 - pad, x1 + pad, y1 + pad]


# ---------------------------------------------------------------------------

def render(orig_page, blanks, clickables, out_png):
    pix = orig_page.get_pixmap(matrix=fitz.Matrix(ZOOM, ZOOM))
    img = Image.frombytes("RGB", (pix.width, pix.height), pix.samples)
    drw = ImageDraw.Draw(img)

    def box(bbox, color, width=2, dashed=False):
        x0, y0, x1, y1 = (v * ZOOM for v in bbox)
        if dashed:
            step = 8
            x = x0
            while x < x1:
                drw.line([x, y0, min(x + step / 2, x1), y0], fill=color, width=width)
                drw.line([x, y1, min(x + step / 2, x1), y1], fill=color, width=width)
                x += step
            y = y0
            while y < y1:
                drw.line([x0, y, x0, min(y + step / 2, y1)], fill=color, width=width)
                drw.line([x1, y, x1, min(y + step / 2, y1)], fill=color, width=width)
                y += step
        else:
            drw.rectangle([x0, y0, x1, y1], outline=color, width=width)

    for b in blanks:
        box(b, (0, 120, 255), 2)
    for c in clickables:
        box(c["answer"]["bbox"], (255, 0, 0), 2)
        needs_review = c["snap"] == "none"
        box(c["rect"], (240, 180, 0), 3, dashed=needs_review)

    img.save(out_png)


def main():
    if len(sys.argv) < 5:
        print(__doc__)
        sys.exit(1)
    orig_path, ans_path, out_dir = sys.argv[1:4]
    pages = [int(p) for p in sys.argv[4:]]
    os.makedirs(out_dir, exist_ok=True)

    orig = fitz.open(orig_path)
    ans = fitz.open(ans_path)

    for pno in pages:
        po, pa = orig[pno - 1], ans[pno - 1]
        answers = diff_answer_spans(po, pa)
        blanks = find_blank_lines(po)
        ticks = find_tick_boxes(po)
        obstacles = [s["bbox"] for s in get_spans(po)] + blanks
        clickables = build_clickables(answers, blanks, ticks, obstacles)

        # CV fallback: write-on areas drawn inside raster artwork.
        unmatched = [c for c in clickables if c["snap"] == "none"]
        if unmatched:
            for c in unmatched:
                rect = cv_snap_box(po, c["answer"]["bbox"])
                if rect:
                    c["rect"] = rect
                    c["snap"] = "cvbox"
            clickables = merge_same_region(clickables)

        stats = {}
        for c in clickables:
            stats[c["snap"]] = stats.get(c["snap"], 0) + 1
        print(f"page {pno}: {len(clickables)} clickables -> {stats}")

        base = os.path.join(out_dir, f"page_{pno:03d}_snap")
        out = {
            "page": pno,
            "page_size": [po.rect.width, po.rect.height],
            "clickables": [{
                "text": c["answer"]["text"],
                "is_checkmark": c["answer"]["is_checkmark"],
                "rect_pt": [round(v, 2) for v in c["rect"]],
                "answer_bbox_pt": [round(v, 2) for v in c["answer"]["bbox"]],
                "snap": c["snap"],
                "needs_review": c["snap"] == "none",
            } for c in clickables],
        }
        with open(base + ".json", "w", encoding="utf-8") as f:
            json.dump(out, f, ensure_ascii=False, indent=1)
        render(po, blanks, clickables, base + ".png")

    orig.close(); ans.close()


if __name__ == "__main__":
    main()
