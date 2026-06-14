"""Prototype step 10: matchTheWords (match the words / pictures).

GT structure: match_words[] = the numbered word list ("1. beautiful"),
sentences[] = the lettered items ("a. long" — text, or a picture crop)
each carrying its correct word. Two variants, decided automatically:
items WITH images inside the area -> picture matching, else text.

Pairing evidence, in order of trust:
  1. written tokens the key adds (a digit next to item "a" pairs it
     with word #digit; a letter next to a word pairs that word)
  2. lines the key draws between the columns (elongated drawings —
     each endpoint snaps to the nearest word row / item)

Detection runs inside a rect (the editor's smart-crop) or inside the
page's exercise bands (Analyze).

CLI (editor crop flow):
  proto_match.py --redetect <raw_dir> <page> <x> <y> <w> <h>
                 <png_w> <png_h> <out_base.png>
prints {"match_words": [...], "sentences": [{"sentence", "word",
"image_path"?}, ...]} — image crops saved next to out_base.
"""

import os
import re
import sys

import fitz

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from proto_inventory import (diff_answer_drawings, diff_answer_spans,
                             find_image_rects, get_spans, page_dict,
                             page_words)
from proto_circle import find_exercise_bands, find_pdf_pair, place_button

WORD_RE = re.compile(r"^(\d{1,2})[.)]?\s+\S")
ITEM_RE = re.compile(r"^([a-h])[.)](\s|$)")
BARE_LETTER_RE = re.compile(r"^[a-h]\.?$")
MIN_WORDS = 3
MIN_PAIRS = 2
IMG_MIN_PT = 24.0          # smaller pictures are bullets/decor
CROP_SCALE = 3.0


def _rows(page, rect):
    """Printed rows inside rect: [{text, bbox}], halo echoes removed."""
    x0, y0, x1, y1 = rect
    rows = {}
    for b in page_dict(page)["blocks"]:
        if b["type"] != 0:
            continue
        for l in b["lines"]:
            spans = [s for s in l["spans"] if s["text"].strip()]
            if not spans:
                continue
            cx = sum((s["bbox"][0] + s["bbox"][2]) / 2 for s in spans) / len(spans)
            cy = sum((s["bbox"][1] + s["bbox"][3]) / 2 for s in spans) / len(spans)
            if not (x0 <= cx <= x1 and y0 <= cy <= y1):
                continue
            ly0 = min(s["bbox"][1] for s in spans)
            key = next((k for k in rows
                        if abs(k[0] - ly0) < 4 and k[1] == round(cx / 250)),
                       (ly0, round(cx / 250)))
            rows.setdefault(key, []).extend(spans)
    out = []
    for key in sorted(rows):
        seen, parts, bb = set(), [], None
        for s in sorted(rows[key], key=lambda s: s["bbox"][0]):
            k = (s["text"].strip(), int(s["bbox"][0] / 3))
            if k in seen:
                continue
            seen.add(k)
            parts.append(s["text"].strip())
            b = s["bbox"]
            bb = b if bb is None else (min(bb[0], b[0]), min(bb[1], b[1]),
                                       max(bb[2], b[2]), max(bb[3], b[3]))
        text = re.sub(r"\s+", " ", " ".join(parts)).strip()
        text = re.sub(r"\b(\S+)( \1)+\b", r"\1", text)
        out.append({"text": text, "bbox": list(bb)})
    return out


def detect_match(po, pa, rect):
    """Returns {"match_words": [{word, bbox}], "items": [{letter,
    sentence, bbox, image (bbox|None), word}]} or None."""
    rows = _rows(po, rect)
    words, items = [], []
    for r in rows:
        m = WORD_RE.match(r["text"])
        if m:
            body = r["text"][m.end(1):].strip(" .)")
            # A list WORD is short — numbered instructions ("1. Listen
            # and repeat...") and dotted blanks ("4. ......") are not.
            if 0 < len(body) <= 32 and len(body.split()) <= 3 \
                    and ".." not in r["text"]:
                words.append({"no": m.group(1), "word": r["text"],
                              "bbox": r["bbox"]})
            continue
        m = ITEM_RE.match(r["text"])
        if m and ".." not in r["text"]:
            # An answer-slot column may merge into the row: "a. long 1."
            sent = re.sub(r"\s+\d{1,2}[.)]?$", "", r["text"]).strip()
            items.append({"letter": m.group(1), "sentence": sent,
                          "bbox": r["bbox"], "image": None, "word": ""})

    # Picture-label variant: items are LONE letters ("a", "b") next to
    # the pictures — row merging loses them, so fall back to tokens.
    if len(items) < 2:
        x0_, y0_, x1_, y1_ = rect
        seen = set()
        tok_items = []
        for w in page_words(po):
            t = w[4].strip()
            cx, cy = (w[0] + w[2]) / 2, (w[1] + w[3]) / 2
            if BARE_LETTER_RE.match(t) and x0_ <= cx <= x1_ \
                    and y0_ <= cy <= y1_:
                letter = t[0].lower()
                if letter not in seen:
                    seen.add(letter)
                    tok_items.append({"letter": letter,
                                      "sentence": f"{letter}.",
                                      "bbox": list(w[:4]),
                                      "image": None, "word": ""})
        if len(tok_items) >= 3:
            items = tok_items
    if len(words) < MIN_WORDS or not items:
        return None

    # Pictures inside the rect attach to the nearest lettered label —
    # their presence flips the variant to picture-matching.
    x0, y0, x1, y1 = rect
    for img in find_image_rects(po):
        b = img["bbox"]
        if b[2] - b[0] < IMG_MIN_PT or b[3] - b[1] < IMG_MIN_PT:
            continue
        cx, cy = (b[0] + b[2]) / 2, (b[1] + b[3]) / 2
        if not (x0 <= cx <= x1 and y0 <= cy <= y1):
            continue
        best, bd = None, 1e9
        for it in items:
            ib = it["bbox"]
            d = ((cx - (ib[0] + ib[2]) / 2) ** 2 +
                 (cy - (ib[1] + ib[3]) / 2) ** 2) ** 0.5
            if d < bd:
                best, bd = it, d
        if best is not None and bd < 160:
            if best["image"] is None or bd < best.get("_imgd", 1e9):
                best["image"] = list(b)
                best["_imgd"] = bd

    by_no = {w["no"]: w for w in words}
    by_letter = {it["letter"]: it for it in items}

    # Printed slot tokens ("1." / "a.") — the key writes its answer
    # right AFTER one of these, and that token is the true context
    # (answer-slot columns sit far away from the word/item rows).
    slot_nums, slot_letters = [], []
    for w in page_words(po):
        t = w[4].strip().rstrip(".")
        if re.fullmatch(r"\d{1,2}", t):
            slot_nums.append((t, list(w[:4])))
        elif re.fullmatch(r"[a-h]", t):
            slot_letters.append((t, list(w[:4])))

    def left_slot(b, slots):
        """The printed slot token sitting just left on the same row."""
        cy = (b[1] + b[3]) / 2
        best, bd = None, 30.0
        for t, sb in slots:
            if sb[1] - 4 <= cy <= sb[3] + 4:
                gap = b[0] - sb[2]
                if -4 <= gap < bd:
                    best, bd = t, gap
        return best

    # Evidence 1: written tokens from the key.
    for s in diff_answer_spans(po, pa):
        t = s["text"].strip().strip(".,)")
        b = s["bbox"]
        cx, cy = (b[0] + b[2]) / 2, (b[1] + b[3]) / 2
        if not (x0 <= cx <= x1 and y0 <= cy <= y1):
            continue
        if re.fullmatch(r"\d{1,2}", t) and t in by_no:
            # written NUMBER: pairs the word with the slot's letter,
            # else with the nearest item row.
            sl = left_slot(b, slot_letters)
            it = by_letter.get(sl) if sl else None
            if it is None:
                best, bd = None, 1e9
                for cand in items:
                    ref = cand["image"] or cand["bbox"]
                    d = ((cx - (ref[0] + ref[2]) / 2) ** 2 +
                         (cy - (ref[1] + ref[3]) / 2) ** 2) ** 0.5
                    if d < bd:
                        best, bd = cand, d
                it = best if bd < 200 else None
            if it is not None and not it["word"]:
                it["word"] = by_no[t]["word"]
        elif re.fullmatch(r"[a-h]", t.lower()):
            # written LETTER: pairs the slot's word number with that
            # item ("3. (a)" -> word 3 matches item a).
            sl = left_slot(b, slot_nums)
            wd = by_no.get(sl) if sl else None
            if wd is None:
                best, bd = None, 1e9
                for cand in words:
                    wb = cand["bbox"]
                    d = ((cx - (wb[0] + wb[2]) / 2) ** 2 +
                         (cy - (wb[1] + wb[3]) / 2) ** 2) ** 0.5
                    if d < bd:
                        best, bd = cand, d
                wd = best if bd < 200 else None
            it = by_letter.get(t.lower())
            if wd is not None and it is not None and not it["word"]:
                it["word"] = wd["word"]

    # Evidence 2: drawn connector lines. A connector's endpoints are
    # two opposite corners of its bbox, but WHICH diagonal — and which
    # end touches the word vs the item — is unknown: score all four
    # combinations with point-to-rect distance, then assign the
    # best-scoring lines first.
    def rect_dist(p, b):
        dx = max(0.0, b[0] - p[0], p[0] - b[2])
        dy = max(0.0, b[1] - p[1], p[1] - b[3])
        return (dx * dx + dy * dy) ** 0.5

    def nearest(p, cands, key):
        best, bd = None, 1e9
        for c in cands:
            d = rect_dist(p, key(c))
            if d < bd:
                best, bd = c, d
        return best, bd

    line_pairs = []
    for d in diff_answer_drawings(po, pa):
        b = d["bbox"]
        if max(b[2] - b[0], b[3] - b[1]) < 40:
            continue
        cx, cy = (b[0] + b[2]) / 2, (b[1] + b[3]) / 2
        if not (x0 <= cx <= x1 and y0 <= cy <= y1):
            continue
        diagonals = [((b[0], b[1]), (b[2], b[3])),
                     ((b[0], b[3]), (b[2], b[1]))]
        best = None
        for pA, pB in diagonals:
            for pw, pi in ((pA, pB), (pB, pA)):
                wd, dw = nearest(pw, words, lambda w: w["bbox"])
                it, di = nearest(pi, items,
                                 lambda i: i["image"] or i["bbox"])
                sc = dw + di
                if best is None or sc < best[0]:
                    best = (sc, wd, it)
        if best and best[0] < 90 and best[1] is not None and best[2] is not None:
            line_pairs.append(best)
    used_words = set()
    for sc, wd, it in sorted(line_pairs, key=lambda t: t[0]):
        if not it["word"] and id(wd) not in used_words:
            it["word"] = wd["word"]
            used_words.add(id(wd))

    if sum(1 for it in items if it["word"]) < MIN_PAIRS:
        return None
    return {"match_words": words, "items": items}


def save_item_crops(po, items, out_dir, base, ext=".jpg"):
    """Render each item's picture; returns abs paths aligned to items."""
    paths = []
    for k, it in enumerate(items):
        if it["image"] is None:
            paths.append(None)
            continue
        b = it["image"]
        rect = fitz.Rect(b[0] - 2, b[1] - 2, b[2] + 2, b[3] + 2)
        pix = po.get_pixmap(matrix=fitz.Matrix(CROP_SCALE, CROP_SCALE),
                            clip=rect)
        p = os.path.join(out_dir, f"{base}_m{k + 1}{ext}")
        pix.save(p)
        paths.append(p)
    return paths


def result_json(po, res, out_dir, base):
    paths = save_item_crops(po, res["items"], out_dir, base)
    sentences = []
    for it, p in zip(res["items"], paths):
        entry = {"sentence": it["sentence"] if p is None
                 else f"{it['letter']}.",
                 "word": it["word"]}
        if p is not None:
            entry["image_path"] = p
        sentences.append(entry)
    return {"match_words": [w["word"] for w in res["match_words"]],
            "sentences": sentences}


def build_match_sections(po, pa, page_num, images_dir, prefix, sx, sy):
    """Analyze path: one matchTheWords section per exercise band that
    holds a word list + lettered items + written/drawn pair evidence."""
    sections = []
    occupied = [s["bbox"] for s in get_spans(po)]
    k = 0
    for band in find_exercise_bands(po):
        res = detect_match(po, pa, band["rect"])
        if not res:
            continue
        k += 1
        data = result_json(po, res, images_dir, f"p{page_num}match{k}")
        sentences = []
        for s in data["sentences"]:
            entry = {"sentence": s["sentence"], "word": s["word"]}
            if "image_path" in s:
                entry["image_path"] = f"{prefix}{os.path.basename(s['image_path'])}"
            sentences.append(entry)
        sections.append({
            "activity": {
                "type": "matchTheWords",
                "match_words": [{"word": w} for w in data["match_words"]],
                "sentences": sentences,
                "circleCount": 0,
                "markCount": 0,
                "coords": place_button(band["header"], occupied,
                                       po.rect.width, sx, sy),
                "headerText": "",
            },
            "audio_extra": {},
        })
    return sections


def redetect_match(raw_dir, page_no, rect_px, png_size, out_base):
    import json
    original_path, answered_path = find_pdf_pair(raw_dir)
    if not original_path or not answered_path:
        print(json.dumps({"error": "pdf pair not found in raw dir"}))
        return 1
    orig, ans = fitz.open(original_path), fitz.open(answered_path)
    po, pa = orig[page_no - 1], ans[page_no - 1]
    sx = po.rect.width / png_size[0]
    sy = po.rect.height / png_size[1]
    x, y, w, h = rect_px
    rect = (x * sx, y * sy, (x + w) * sx, (y + h) * sy)
    res = detect_match(po, pa, rect)
    if not res:
        print(json.dumps({"match_words": [], "sentences": []}))
        return 0
    out_dir = os.path.dirname(out_base) or "."
    base = os.path.splitext(os.path.basename(out_base))[0]
    print(json.dumps(result_json(po, res, out_dir, base), ensure_ascii=False))
    orig.close(); ans.close()
    return 0


def main():
    if len(sys.argv) >= 2 and sys.argv[1] == "--redetect":
        a = sys.argv[2:]
        if len(a) != 9:
            print("usage: --redetect <raw_dir> <page> <x> <y> <w> <h> "
                  "<png_w> <png_h> <out_base>")
            sys.exit(1)
        sys.exit(redetect_match(a[0], int(a[1]),
                                tuple(float(v) for v in a[2:6]),
                                (float(a[6]), float(a[7])), a[8]))
    print(__doc__)


if __name__ == "__main__":
    main()
