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
# Extraction helpers
# ---------------------------------------------------------------------------

def get_spans(page):
    spans = []
    for b in page.get_text("dict", flags=fitz.TEXT_PRESERVE_WHITESPACE)["blocks"]:
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


def diff_answer_spans(orig_page, ans_page):
    """Spans present in answered but not in original = answer overlay."""
    okeys = {span_key(s) for s in get_spans(orig_page)}
    new = [s for s in get_spans(ans_page) if span_key(s) not in okeys]

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


def diff_answer_drawings(orig_page, ans_page):
    """Vector drawings present only in answered pdf (circles, strokes...)."""
    okeys = {drawing_key(d) for d in orig_page.get_drawings()}
    out = []
    for d in ans_page.get_drawings():
        if drawing_key(d) in okeys:
            continue
        r = d["rect"]
        out.append({
            "bbox": [r.x0, r.y0, r.x1, r.y1],
            "ops": "".join(item[0] for item in d["items"]),
            "color": list(d["color"]) if d.get("color") else None,
        })
    return out


def find_blank_lines(page, min_w=15.0, max_h=3.0, merge_gap=6.0):
    """Horizontal rules / dash sequences students write on.

    Collects thin, wide vector segments and merges collinear pieces
    (dashed lines arrive as many short segments on one baseline).
    """
    segs = []
    for d in page.get_drawings():
        r = d["rect"]
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

    # Also: dotted blanks made of text dots ("......") or underscores.
    for s in get_spans(page):
        if re.fullmatch(r"[._…]{4,}", s["text"]):
            merged.append(list(s["bbox"]))

    return [m for m in merged if (m[2] - m[0]) >= min_w]


def find_image_rects(page):
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
