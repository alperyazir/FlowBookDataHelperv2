"""Prototype step 4: emit editor config.json from the snap pipeline.

Runs diff -> snap -> CV fallback on an answered/original PDF pair and
writes the results into the book's config.json in the exact format the
editor (ConfigParser) and ai_analyzer.py use:

  - text answers   -> one "fill" section per page, coords in PNG pixels
  - checkmarks     -> one "markwithx" activity section per page
  - unmatched      -> included with "needs_review": true so the human
                      pass can find them quickly

If the book has no config.json yet, a skeleton matching
smartdatahelper.py's output is created from the images/ folder.
A timestamped backup is written before an existing config is touched.

Usage:
  python3 proto_emit.py <book_dir> [<page> ...]      # default: all pages
"""

import datetime
import json
import os
import shutil
import sys

import fitz

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from proto_inventory import diff_answer_spans, find_blank_lines, get_spans
from proto_snap import build_clickables, find_tick_boxes, merge_same_region
from proto_cv import cv_snap_box, render_page_bgr
from proto_circle import build_circle_sections


def find_pdf_pair(raw_dir):
    pdfs = [f for f in os.listdir(raw_dir) if f.lower().endswith(".pdf")]
    answered = original = None
    for f in pdfs:
        low = f.lower()
        if any(k in low for k in ("cevap", "answer", "key")):
            answered = os.path.join(raw_dir, f)
        else:
            original = os.path.join(raw_dir, f)
    if not (answered and original):
        sys.exit(f"Error: need both answered and original PDFs in {raw_dir}")
    return original, answered


def make_skeleton(book_dir):
    """Mirror smartdatahelper.py's config.json layout from images/."""
    book_name = os.path.basename(os.path.abspath(book_dir))
    images_dir = os.path.join(book_dir, "images")
    modules = []
    for mod in sorted(os.listdir(images_dir)):
        mod_dir = os.path.join(images_dir, mod)
        if not os.path.isdir(mod_dir):
            continue
        nums = sorted(int(os.path.splitext(f)[0]) for f in os.listdir(mod_dir)
                      if f.lower().endswith(".png") and os.path.splitext(f)[0].isdigit())
        pages = [{
            "page_number": n,
            "image_path": f"./books/{book_name}/images/{mod}/{n}.png",
            "sections": [],
        } for n in nums]
        modules.append({"name": mod.replace("_", " "), "pages": pages})
    if not modules:
        sys.exit(f"Error: no module image folders under {images_dir}")
    return {
        "publisher_name": "",
        "publisher_logo_path": "./publisher_logo/publisher_logo.png",
        "publisher_full_logo_path": "./rsc/images/publisher_full_logo.png",
        "book_title": book_name,
        "book_cover": f"./books/{book_name}/images/book_cover.png",
        "language": "English",
        "fullscreen": False,
        "books": [{"type": "not selected", "modules": modules}],
    }


def px(rect_pt, sx, sy):
    x0, y0, x1, y1 = rect_pt
    return {"x": int(round(x0 * sx)), "y": int(round(y0 * sy)),
            "w": int(round((x1 - x0) * sx)), "h": int(round((y1 - y0) * sy))}


def sections_from_clickables(clickables, sx, sy):
    """Convert snapped clickables to config.json sections."""
    fills = []
    for c in clickables:
        # Ticks are fill answers too: the student puts a "✓" in the box.
        ans = {
            "coords": px(c["rect"], sx, sy),
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


def process_page(orig_doc, ans_doc, page_number, png_path, crop_dir, crop_prefix):
    po, pa = orig_doc[page_number - 1], ans_doc[page_number - 1]
    answers = diff_answer_spans(po, pa)
    if not answers:
        return None, {}
    blanks = find_blank_lines(po)
    obstacles = [s["bbox"] for s in get_spans(po)] + blanks
    clickables = build_clickables(answers, blanks, find_tick_boxes(po), obstacles)
    unmatched = [c for c in clickables if c["snap"] == "none"]
    if unmatched:
        page_bgr = render_page_bgr(po)
        for c in unmatched:
            rect = cv_snap_box(page_bgr, c["answer"]["bbox"])
            if rect:
                c["rect"] = rect
                c["snap"] = "cvbox"
        clickables = merge_same_region(clickables)

    pix = fitz.Pixmap(png_path)
    sx, sy = pix.width / po.rect.width, pix.height / po.rect.height
    pix = None

    stats = {}
    for c in clickables:
        stats[c["snap"]] = stats.get(c["snap"], 0) + 1

    sections = sections_from_clickables(clickables, sx, sy)
    circles = build_circle_sections(po, pa, page_number, crop_dir, crop_prefix,
                                    sx, sy, start_idx=len(sections) + 1)
    if circles:
        stats["circle"] = len(circles)
    return sections + circles, stats


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)
    book_dir = sys.argv[1]
    only_pages = {int(p) for p in sys.argv[2:]} or None

    original_path, answered_path = find_pdf_pair(os.path.join(book_dir, "raw"))
    print(f"original: {original_path}\nanswered: {answered_path}", flush=True)

    config_path = os.path.join(book_dir, "config.json")
    if os.path.exists(config_path):
        stamp = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
        shutil.copy2(config_path, config_path + f".bak_{stamp}")
        with open(config_path, encoding="utf-8") as f:
            config = json.load(f)
        print(f"config.json loaded (backup: .bak_{stamp})", flush=True)
    else:
        config = make_skeleton(book_dir)
        print("config.json not found, skeleton created from images/", flush=True)

    orig_doc = fitz.open(original_path)
    ans_doc = fitz.open(answered_path)

    pages = [(m, p) for b in config["books"] for m in b.get("modules", [])
             for p in m.get("pages", [])]
    total = len(pages)
    done = skipped = review = 0
    for i, (module, page) in enumerate(pages):
        pno = page["page_number"]
        if only_pages and pno not in only_pages:
            continue
        if pno < 1 or pno > len(orig_doc):
            continue
        print(f"PROGRESS:{int(i / total * 100)}%", flush=True)
        png_path = os.path.join(book_dir, "images",
                                *page["image_path"].replace("\\", "/").split("/images/")[-1].split("/"))
        if not os.path.exists(png_path):
            print(f"  page {pno}: image missing, skipped", flush=True)
            skipped += 1
            continue
        crop_dir = os.path.dirname(png_path)
        crop_prefix = page["image_path"].replace("\\", "/").rsplit("/", 1)[0] + "/"
        sections, stats = process_page(orig_doc, ans_doc, pno, png_path,
                                       crop_dir, crop_prefix)
        if sections is None:
            print(f"  page {pno}: no answer overlay", flush=True)
            continue
        page["sections"] = sections
        done += 1
        review += stats.get("none", 0)
        print(f"  page {pno} ({module['name']}): {stats}", flush=True)

    orig_doc.close(); ans_doc.close()

    with open(config_path, "w", encoding="utf-8") as f:
        json.dump(config, f, indent=4, ensure_ascii=False)
    print("PROGRESS:100%", flush=True)
    print(f"Saved {config_path}: {done} pages with sections, "
          f"{skipped} skipped, {review} answers need review", flush=True)


if __name__ == "__main__":
    main()
