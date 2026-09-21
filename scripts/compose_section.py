"""Stack extra page regions (a table, a passage) above/below an activity image.

Some questions are answered from a table or passage that sits elsewhere on the
page ("Look at the table and answer the questions 3 and 4"). The activity image
then has to carry that region too. This cuts each attachment from the original
PDF and stacks it with the question's own crop into one PNG.

The question image itself is taken as is (not re-rendered), so its pixels — and
the answer boxes placed on them — stay exactly what they were. The attachments
are rendered at the same pixels-per-page-pixel as the question, so their text
comes out the same size. Pieces are centered on a white canvas.

Usage:
  compose_section.py <raw_dir> <page_index> <png_w> <png_h> <base_img>
                     <base_rect_json> <attachments_json> <output_path>

base_rect_json   {"x","y","w","h"}: page-PNG region the question image covers
attachments_json [{"x","y","w","h","position": "top"|"bottom"}, ...] in page-PNG
                 px; drawn in list order, top ones above the question.

Prints one JSON line: {"offset": {"x","y"}, "w", "h"} — where the question image
landed in the output, so the caller can move its answers the same amount.
"""
import sys
import os
import json

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from _bootstrap import ensure_runtime_deps
ensure_runtime_deps()

import fitz
from PIL import Image

from book_files import find_original_pdf

GAP_PT = 10.0   # space between stacked pieces, in PDF points


def main(argv):
    if len(argv) != 9:
        print("ERROR: Usage: compose_section.py <raw_dir> <page_index> <png_w> <png_h> "
              "<base_img> <base_rect_json> <attachments_json> <output_path>", flush=True)
        return 1
    raw_dir = argv[1]
    page_idx = int(argv[2])
    png_w, png_h = float(argv[3]), float(argv[4])
    base_img_path = argv[5]
    base_rect = json.loads(argv[6])
    attachments = json.loads(argv[7])
    output_path = argv[8]

    if float(base_rect.get("w", 0)) <= 0:
        print("ERROR: the activity has no crop region yet — crop it first", flush=True)
        return 1
    if not os.path.isfile(base_img_path):
        print(f"ERROR: activity image not found: {base_img_path}", flush=True)
        return 1

    pdf_path = find_original_pdf(raw_dir)
    if not pdf_path:
        print(f"ERROR: No PDF found in: {raw_dir}", flush=True)
        return 1
    doc = fitz.open(pdf_path)
    if page_idx < 0 or page_idx >= len(doc):
        print(f"ERROR: Page index {page_idx} out of range (0-{len(doc)-1})", flush=True)
        doc.close()
        return 1
    page = doc.load_page(page_idx)

    base = Image.open(base_img_path).convert("RGB")
    # Output px per page-PNG px, from the question crop; the same density is
    # used for every attachment so the text sizes match.
    px_per_png = base.width / float(base_rect["w"])
    pt_to_png_x = png_w / page.rect.width
    pt_to_png_y = png_h / page.rect.height
    render_scale = px_per_png * pt_to_png_x
    gap = max(8, int(round(GAP_PT * render_scale)))

    def render(a):
        clip = fitz.Rect(a["x"] / pt_to_png_x, a["y"] / pt_to_png_y,
                         (a["x"] + a["w"]) / pt_to_png_x,
                         (a["y"] + a["h"]) / pt_to_png_y) & page.rect
        if clip.is_empty:
            return None
        pix = page.get_pixmap(matrix=fitz.Matrix(render_scale, render_scale),
                              clip=clip, alpha=False)
        return Image.frombytes("RGB", (pix.width, pix.height), pix.samples)

    top, bottom = [], []
    for a in attachments:
        img = render(a)
        if img is None:
            continue
        (bottom if a.get("position") == "bottom" else top).append(img)
    doc.close()

    pieces = top + [base] + bottom
    width = max(p.width for p in pieces)
    height = sum(p.height for p in pieces) + gap * (len(pieces) - 1)
    canvas = Image.new("RGB", (width, height), "white")
    y = 0
    offset = {"x": 0, "y": 0}
    for p in pieces:
        x = (width - p.width) // 2
        canvas.paste(p, (x, y))
        if p is base:
            offset = {"x": x, "y": y}
        y += p.height + gap

    os.makedirs(os.path.dirname(output_path) or ".", exist_ok=True)
    canvas.save(output_path)
    print(f"Compose: {len(top)} top + {len(bottom)} bottom, {width}x{height}px", flush=True)
    print(json.dumps({"offset": offset, "w": width, "h": height}), flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
