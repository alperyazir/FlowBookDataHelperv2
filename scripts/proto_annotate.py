"""Prototype step 7: labeled review renders for the AI verification pass.

Draws everything the Analyze run wrote into config.json onto the page
image, the way the editor's page view shows it — so a vision model (or
a human) can verify the whole page at a glance:

  - fill answers      red boxes, answer text above (magenta + "?" when
                      needs_review)
  - audio icons       blue boxes
  - activity buttons  purple squares, labeled "A1 dragdroppicture"
  - activities        side panels: the section crop with its drop
                      zones / options drawn and labeled, plus the
                      headerText and the words pool underneath

Output: <out_dir>/page_NNN_review.png (page left, activity panels right)

Usage:
  python3 proto_annotate.py <book_dir> <out_dir> [<page> ...]
  (book_dir holds config.json; default: every page that has sections)
"""

import json
import os
import sys

from PIL import Image, ImageDraw, ImageFont

PANEL_W = 760            # activity panel column width
PAD = 14
FILL_C = (220, 30, 30)
REVIEW_C = (220, 0, 200)
AUDIO_C = (30, 90, 220)
BTN_C = (140, 40, 200)
ZONE_C = (0, 150, 60)
WRONG_C = (30, 90, 220)  # circle options that are not correct


def font(size):
    for path in ("/System/Library/Fonts/Helvetica.ttc",
                 "/Library/Fonts/Arial.ttf",
                 "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"):
        try:
            return ImageFont.truetype(path, size)
        except (OSError, IOError):
            continue
    return ImageFont.load_default()


F_BOX = font(20)
F_TITLE = font(26)
F_SMALL = font(17)


def label(drw, x, y, text, color, fnt=F_BOX):
    """Text with a white backing so it stays readable on artwork."""
    bb = drw.textbbox((x, y), text, font=fnt)
    drw.rectangle([bb[0] - 2, bb[1] - 1, bb[2] + 2, bb[3] + 1],
                  fill=(255, 255, 255, 230))
    drw.text((x, y), text, fill=color, font=fnt)


def inset_label(drw, c, text, color):
    """The answer text INSIDE its box, like the editor renders fills:
    font shrinks until it fits the box (floor 9px, then truncation)."""
    size = max(9, min(22, int(c["h"] * 0.72)))
    while size > 9:
        f = font(size)
        if drw.textlength(text, font=f) <= c["w"] - 4:
            break
        size -= 1
    f = font(size)
    while text and drw.textlength(text, font=f) > c["w"] - 4:
        text = text[:-1]
    bb = drw.textbbox((0, 0), text, font=f)
    y = c["y"] + (c["h"] - (bb[3] - bb[1])) / 2 - bb[1]
    drw.text((c["x"] + 3, y), text, fill=color, font=f)


def resolve(release_root, path):
    """config paths look like ./books/<name>/images/..."""
    return os.path.normpath(os.path.join(release_root, path.lstrip("./")))


def section_type(s):
    return s.get("type") or s.get("activity", {}).get("type") or "?"


def draw_rect(drw, c, color, width=3):
    drw.rectangle([c["x"], c["y"], c["x"] + c["w"], c["y"] + c["h"]],
                  outline=color, width=width)


def annotate_page_image(page, release_root):
    img = Image.open(resolve(release_root, page["image_path"])).convert("RGB")
    drw = ImageDraw.Draw(img)
    act_no = 0
    for s in page.get("sections", []):
        st = section_type(s)
        if st == "fill":
            for a in s.get("answer", s.get("answers", [])):
                c = a["coords"]
                bad = a.get("needs_review")
                color = REVIEW_C if bad else FILL_C
                draw_rect(drw, c, color)
                txt = ("? " if bad else "") + a.get("text", "")
                inset_label(drw, c, txt, color)
        elif st == "audio":
            c = s["coords"]
            draw_rect(drw, c, AUDIO_C)
            label(drw, c["x"], c["y"] + c["h"] + 2, "audio", AUDIO_C)
        elif "activity" in s:
            act_no += 1
            a = s["activity"]
            c = a.get("coords")
            if c:
                draw_rect(drw, c, BTN_C, 4)
                label(drw, c["x"], max(0, c["y"] - 24),
                      f"A{act_no} {a.get('type', '?')}", BTN_C)
    return img


def wrap_text(drw, text, fnt, width):
    words, lines, cur = text.split(), [], ""
    for w in words:
        t = (cur + " " + w).strip()
        if drw.textlength(t, font=fnt) > width and cur:
            lines.append(cur)
            cur = w
        else:
            cur = t
    if cur:
        lines.append(cur)
    return lines


def activity_panel(s, idx, release_root):
    """One labeled panel: crop + zones + header/words text block."""
    a = s["activity"]
    crop_path = a.get("section_path")
    crop = None
    if crop_path:
        try:
            crop = Image.open(resolve(release_root, crop_path)).convert("RGB")
        except (OSError, IOError):
            pass
    if crop is None:
        crop = Image.new("RGB", (PANEL_W, 60), (245, 245, 245))
    scale = PANEL_W / crop.width
    crop = crop.resize((PANEL_W, int(crop.height * scale)))
    drw = ImageDraw.Draw(crop)
    for ans in a.get("answer", []):
        c = ans["coords"]
        box = [c["x"] * scale, c["y"] * scale,
               (c["x"] + c["w"]) * scale, (c["y"] + c["h"]) * scale]
        if a.get("type") == "circle":
            color = ZONE_C if ans.get("isCorrect") else WRONG_C
        else:
            color = REVIEW_C if ans.get("needs_review") else ZONE_C
        drw.rectangle(box, outline=color, width=3)
        txt = ans.get("text") or "|".join(ans.get("group", []))
        if txt:
            label(drw, box[0] + 2, max(0, box[1] - 20), txt, color, F_SMALL)

    # Text block under the crop: title, header, words.
    meas = ImageDraw.Draw(Image.new("RGB", (1, 1)))
    n = len(a.get("answer") or a.get("sentences") or a.get("words") or [])
    lines = [(f"A{idx} {a.get('type', '?')}  ({n} answers)", F_TITLE, BTN_C)]
    if a.get("headerText"):
        for t in wrap_text(meas, a["headerText"], F_SMALL, PANEL_W - 12):
            lines.append((t, F_SMALL, (60, 60, 60)))
    if a.get("words"):
        for t in wrap_text(meas, "words: " + " | ".join(a["words"]),
                           F_SMALL, PANEL_W - 12):
            lines.append((t, F_SMALL, ZONE_C))
    if a.get("match_words"):
        mw = [w.get("word", "") for w in a["match_words"]]
        for t in wrap_text(meas, "words: " + " | ".join(mw),
                           F_SMALL, PANEL_W - 12):
            lines.append((t, F_SMALL, ZONE_C))
        for sn in a.get("sentences", []):
            pair = f"{sn.get('sentence', '')}  ->  {sn.get('word', '')}" + (
                "  [img]" if sn.get("image_path") else "")
            for t in wrap_text(meas, pair, F_SMALL, PANEL_W - 12):
                lines.append((t, F_SMALL, (60, 60, 60)))
    th = sum(int(f.size * 1.35) for _, f, _ in lines) + 10
    panel = Image.new("RGB", (PANEL_W, crop.height + th), (255, 255, 255))
    pd = ImageDraw.Draw(panel)
    y = 2
    for t, f, col in lines:
        pd.text((4, y), t, fill=col, font=f)
        y += int(f.size * 1.35)
    panel.paste(crop, (0, th))
    pd.rectangle([0, 0, PANEL_W - 1, panel.height - 1],
                 outline=(180, 180, 180), width=1)
    return panel


def render_answered(page, ans_doc, out_path):
    """Clean ANSWERED-page render: the blind segmentation input for
    the audit agents — the exercises plus the key's marks, none of
    our overlays."""
    import fitz
    pn = page["page_number"]
    if ans_doc is None or pn - 1 >= len(ans_doc):
        return False
    pix = ans_doc[pn - 1].get_pixmap(matrix=fitz.Matrix(2, 2))
    pix.save(out_path)
    return True


def review_page(page, release_root, out_path):
    img = annotate_page_image(page, release_root)
    panels = [activity_panel(s, i + 1, release_root)
              for i, s in enumerate([s for s in page.get("sections", [])
                                     if "activity" in s
                                     and (s["activity"].get("answer")
                                          or s["activity"].get("words")
                                          or s["activity"].get("match_words"))])]
    ph = sum(p.height + PAD for p in panels)
    H = max(img.height, ph) + 2 * PAD
    W = img.width + (PANEL_W + 3 * PAD if panels else 2 * PAD)
    canvas = Image.new("RGB", (W, H), (235, 235, 235))
    canvas.paste(img, (PAD, PAD))
    y = PAD
    for p in panels:
        canvas.paste(p, (img.width + 2 * PAD, y))
        y += p.height + PAD
    canvas.save(out_path)


def iter_pages(cfg):
    if isinstance(cfg, dict):
        if "page_number" in cfg and "sections" in cfg:
            yield cfg
        else:
            for v in cfg.values():
                yield from iter_pages(v)
    elif isinstance(cfg, list):
        for v in cfg:
            yield from iter_pages(v)


def main():
    if len(sys.argv) < 3:
        print(__doc__)
        sys.exit(1)
    book_dir, out_dir = sys.argv[1], sys.argv[2]
    only = {int(p) for p in sys.argv[3:]}
    release_root = os.path.normpath(os.path.join(book_dir, "..", ".."))
    with open(os.path.join(book_dir, "config.json"), encoding="utf-8") as f:
        cfg = json.load(f)
    os.makedirs(out_dir, exist_ok=True)
    ans_doc = None
    try:
        import fitz
        from proto_circle import find_pdf_pair
        _, ans_path = find_pdf_pair(os.path.join(book_dir, "raw"))
        if ans_path:
            ans_doc = fitz.open(ans_path)
    except Exception:
        pass
    n = 0
    for page in iter_pages(cfg):
        pn = page["page_number"]
        if only and pn not in only:
            continue
        if not page.get("sections"):
            continue
        out = os.path.join(out_dir, f"page_{pn:03d}_review.png")
        try:
            review_page(page, release_root, out)
            render_answered(page, ans_doc,
                            os.path.join(out_dir, f"page_{pn:03d}_answered.png"))
            n += 1
            print(f"page {pn}: {len(page['sections'])} sections -> {out}")
        except Exception as e:
            print(f"page {pn}: FAILED {e}")
    print(f"{n} review image(s) written to {out_dir}")


if __name__ == "__main__":
    main()
