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
                             find_image_rects)
from proto_cv import cv_snap_box, render_page_bgr

# Snap tolerances (PDF points)
DY_MAX = 10.0                 # blank baseline below answer bottom
DY_MIN_FACTOR = 0.65          # ... or overlapping up to this fraction of height
X_GAP_MAX = 12.0              # max horizontal gap between answer and blank
BOX_HEIGHT_PAD = 3.0          # clickable height = font height + 2*pad
TICK_BOX_MIN, TICK_BOX_MAX = 6.0, 22.0
TICK_DIST_MAX = 18.0


def x_overlap_or_gap(a0, a1, b0, b1):
    """>0 overlap amount, <0 gap size (negative)."""
    return min(a1, b1) - max(a0, b0)


def find_tick_boxes(page):
    """Small square-ish vector rects: the boxes students tick."""
    boxes = []
    for d in page.get_drawings():
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
    r"students.{0,3}own answers|öğrencinin kendi cevabı", re.IGNORECASE)


def build_clickables(answers, blanks, tick_boxes):
    """Produce one clickable rect per answer."""
    answers = [s for s in answers if not NON_ANSWER_RE.search(s["text"])]
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
            h = (s["bbox"][3] - s["bbox"][1]) + 2 * BOX_HEIGHT_PAD
            bottom = max(by1, s["bbox"][3])
            x0 = min(cuts[i], s["bbox"][0])      # answer may stick out of the line
            x1 = max(cuts[i + 1], s["bbox"][2])
            results.append({
                "answer": s,
                "rect": [x0, bottom - h, x1, bottom],
                "snap": "blank" if len(spans) == 1 else "blank_shared",
            })

    results.sort(key=lambda r: (r["rect"][1], r["rect"][0]))
    return results


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
        clickables = build_clickables(answers, blanks, ticks)

        # CV fallback: write-on areas drawn inside raster artwork.
        unmatched = [c for c in clickables if c["snap"] == "none"]
        if unmatched:
            page_bgr = render_page_bgr(po)
            for c in unmatched:
                rect = cv_snap_box(page_bgr, c["answer"]["bbox"])
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
