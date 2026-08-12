import sys
import os

# Self-bootstrap the runtime packages on a fresh machine before use.
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from _bootstrap import ensure_runtime_deps
ensure_runtime_deps()

import fitz

if len(sys.argv) != 10:
    print("ERROR: Usage: crop_section.py <raw_dir> <page_index> <x> <y> <w> <h> <png_width> <png_height> <output_path>", flush=True)
    sys.exit(1)


from book_files import find_original_pdf   # one rule, shared (see book_files)


raw_dir = sys.argv[1]
page_idx = int(sys.argv[2])
px, py, pw, ph = float(sys.argv[3]), float(sys.argv[4]), float(sys.argv[5]), float(sys.argv[6])
png_w, png_h = float(sys.argv[7]), float(sys.argv[8])
output_path = sys.argv[9]

pdf_path = find_original_pdf(raw_dir)
if not pdf_path:
    print(f"ERROR: No PDF found in: {raw_dir}", flush=True)
    sys.exit(1)
print(f"Using PDF: {pdf_path}", flush=True)

doc = fitz.open(pdf_path)

if page_idx < 0 or page_idx >= len(doc):
    print(f"ERROR: Page index {page_idx} out of range (0-{len(doc)-1})", flush=True)
    doc.close()
    sys.exit(1)

page = doc.load_page(page_idx)

# PNG pixel -> PDF point conversion
scale_x = page.rect.width / png_w
scale_y = page.rect.height / png_h
clip = fitz.Rect(px * scale_x, py * scale_y, (px + pw) * scale_x, (py + ph) * scale_y)

# Calculate scale so the longer side is ~1000px
TARGET_SIZE = 1000.0
clip_w = clip.width
clip_h = clip.height
if clip_w <= 0 or clip_h <= 0:
    print("ERROR: Invalid clip dimensions", flush=True)
    doc.close()
    sys.exit(1)
longer_side = max(clip_w, clip_h)
render_scale = TARGET_SIZE / longer_side
# Minimum scale 2x to avoid downscaling small regions
render_scale = max(render_scale, 2.0)

mat = fitz.Matrix(render_scale, render_scale)
pix = page.get_pixmap(matrix=mat, clip=clip)
print(f"Crop: clip={clip_w:.1f}x{clip_h:.1f}pt, scale={render_scale:.2f}x, output={pix.width}x{pix.height}px", flush=True)

# Ensure output directory exists
os.makedirs(os.path.dirname(output_path), exist_ok=True)

pix.save(output_path)
pix = None
doc.close()

print("OK", flush=True)
