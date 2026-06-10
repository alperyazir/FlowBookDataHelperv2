"""Prototype step 5: circle (multiple-choice) activities from the diff.

The answered/original drawing diff yields the circles the publisher drew
around correct options — color independent. This module turns them into
the editor's circle activity format, following the completed-book style
(one section per exercise, answer coords in the crop's pixel space):

  1. circles   = circle-like drawings present only in the answered PDF
  2. options   = printed tokens like "a." / "B)" near each circle
  3. exercises = page bands between numbered instruction headers
  4. per exercise: crop the band from the original PDF (longer side
     ~1000px, same rule as crop_section.py / ai_analyzer) and emit
     options as answers, isCorrect where a circle sits on the option

Debug mode renders an overlay png instead of writing into the book:
  python3 proto_circle.py <original.pdf> <answered.pdf> <out_dir> <page> [...]
"""

import os
import re
import sys

import fitz

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from proto_inventory import diff_answer_drawings, get_spans

OPTION_RE = re.compile(r"^([a-hA-H])[.)]$|^([a-hA-H])[.)]\s+\S")
TF_RE = re.compile(r"^(T|F|TRUE|FALSE|YES|NO)$", re.IGNORECASE)
HEADER_RE = re.compile(r"^\d{1,2}\.(\s+\S|$)")
HEADER_X_MAX = 60.0        # exercise headers start at the page margin
CROP_TARGET = 1000.0       # longer side of the crop render
CROP_MIN_SCALE = 2.0
BUTTON_SIZE = 44           # entry button size in page-image pixels


def is_circle_drawing(d):
    x0, y0, x1, y1 = d["bbox"]
    w, h = x1 - x0, y1 - y0
    return "c" in d["ops"] and 8 <= w <= 30 and 8 <= h <= 30 and abs(w - h) <= 6


def option_letter(text):
    t = text.strip()
    m = OPTION_RE.match(t)
    if m:
        return (m.group(1) or m.group(2)).lower()
    if TF_RE.match(t):
        return t[0].lower()
    return None


def find_exercise_bands(page):
    """Vertical bands [(y0, y1, header_span), ...] between numbered
    instruction headers sitting at the left page margin."""
    headers = []
    for s in get_spans(page):
        if s["bbox"][0] > HEADER_X_MAX:
            continue
        if HEADER_RE.match(s["text"].strip()):
            headers.append(s)
    headers.sort(key=lambda s: s["bbox"][1])
    bands = []
    for i, h in enumerate(headers):
        y0 = h["bbox"][1] - 4
        y1 = headers[i + 1]["bbox"][1] - 4 if i + 1 < len(headers) else page.rect.height
        bands.append((y0, y1, h))
    return bands


def detect_circle_exercises(po, pa):
    """Returns a list of exercises:
    {band, header, options: [{letter, bbox, isCorrect}], counts}"""
    circles = [d for d in diff_answer_drawings(po, pa) if is_circle_drawing(d)]
    if not circles:
        return []
    spans = get_spans(po)
    options = [s for s in spans if option_letter(s["text"])]

    # A bare "a." token is half an option: extend over the words that
    # follow on the same line (human books box the whole phrase).
    others = [s for s in spans if not option_letter(s["text"])]
    for opt in options:
        if not re.fullmatch(r"[a-hA-H][.)]", opt["text"].strip()):
            continue
        ob = list(opt["bbox"])
        grown = True
        while grown:
            grown = False
            for s in others:
                sb = s["bbox"]
                same_row = sb[1] < (ob[1] + ob[3]) / 2 < sb[3]
                if same_row and 0 <= sb[0] - ob[2] <= 6:
                    ob[2] = sb[2]
                    ob[1], ob[3] = min(ob[1], sb[1]), max(ob[3], sb[3])
                    grown = True
        opt["bbox"] = tuple(ob)
    bands = find_exercise_bands(po)
    if not bands:
        bands = [(0.0, po.rect.height, None)]

    def band_of(y):
        for i, (y0, y1, _) in enumerate(bands):
            if y0 <= y < y1:
                return i
        return None

    # Assign options to bands; mark options whose center a circle covers.
    exercises = {}
    for opt in options:
        ob = opt["bbox"]
        bi = band_of((ob[1] + ob[3]) / 2)
        if bi is None:
            continue
        exercises.setdefault(bi, []).append({
            "letter": option_letter(opt["text"]),
            "bbox": ob,
            "isCorrect": False,
        })

    # A circle marks the option it overlaps (the drawn ellipse may wrap
    # the whole phrase, so test intersection, then nearest center).
    for c in circles:
        cb = c["bbox"]
        cx, cy = (cb[0] + cb[2]) / 2, (cb[1] + cb[3]) / 2
        best, best_score = None, 1e9
        for bi, opts in exercises.items():
            for o in opts:
                ob = o["bbox"]
                ix = min(cb[2], ob[2]) - max(cb[0], ob[0])
                iy = min(cb[3], ob[3]) - max(cb[1], ob[1])
                ox, oy = (ob[0] + ob[2]) / 2, (ob[1] + ob[3]) / 2
                dist = ((cx - ox) ** 2 + (cy - oy) ** 2) ** 0.5
                if ix > 0 and iy > 0:
                    score = dist * 0.1          # overlapping: strongly preferred
                elif dist < 25.0:
                    score = dist
                else:
                    continue
                if score < best_score:
                    best, best_score = o, score
        if best:
            best["isCorrect"] = True
            best["circle_bbox"] = cb

    out = []
    for bi, opts in sorted(exercises.items()):
        correct = [o for o in opts if o["isCorrect"]]
        if not correct:
            continue   # exercise has circles elsewhere / not a circle exercise

        # The tap target is the area the student circles, not the glyph.
        # Hand-drawn circles wobble, so they only set the SIZE (median
        # per exercise); the position always comes from the typeset
        # token center — keeping every row perfectly aligned.
        ws = sorted(c["circle_bbox"][2] - c["circle_bbox"][0] for c in correct)
        hs = sorted(c["circle_bbox"][3] - c["circle_bbox"][1] for c in correct)
        med_w, med_h = ws[len(ws) // 2], hs[len(hs) // 2]
        for o in opts:
            ob = o["bbox"]
            w = max(med_w, ob[2] - ob[0])
            h = max(med_h, ob[3] - ob[1])
            cx, cy = (ob[0] + ob[2]) / 2, (ob[1] + ob[3]) / 2
            o["bbox"] = (cx - w / 2, cy - h / 2, cx + w / 2, cy + h / 2)
        # Question rows: options sharing a baseline belong to one question —
        # but two-column layouts put two questions on one baseline, so
        # split rows on large horizontal gaps.
        rows = {}
        for o in opts:
            rows.setdefault(round((o["bbox"][1] + o["bbox"][3]) / 2 / 6), []).append(o)
        mid_x = po.rect.width / 2

        per_q = []
        for row in rows.values():
            row.sort(key=lambda o: o["bbox"][0])
            seg = 1
            for a, b in zip(row, row[1:]):
                # Two-column page: a big gap across the page midline
                # separates two questions sharing a baseline.
                gap = b["bbox"][0] - a["bbox"][2]
                if gap > 60 and a["bbox"][2] < mid_x <= b["bbox"][0]:
                    per_q.append(seg)
                    seg = 0
                seg += 1
            per_q.append(seg)
        per_q = [n for n in per_q if n >= 2]
        circle_count = max(set(per_q), key=per_q.count) if per_q else len(opts)
        out.append({
            "band": bands[bi][:2],
            "header": bands[bi][2],
            "options": sorted(opts, key=lambda o: (o["bbox"][1], o["bbox"][0])),
            "circleCount": circle_count,
            "matched": len(correct),
        })
    return out


def crop_band(po, band, options, out_path):
    """Crop the exercise area from the original PDF; returns (rect, scale)."""
    y0, y1 = band
    xs0 = min(o["bbox"][0] for o in options)
    xs1 = max(o["bbox"][2] for o in options)
    # Content width: extend to printed spans inside the band.
    for s in get_spans(po):
        if s["bbox"][1] >= y0 and s["bbox"][3] <= y1:
            xs0 = min(xs0, s["bbox"][0])
            xs1 = max(xs1, s["bbox"][2])
    rect = fitz.Rect(max(0, xs0 - 6), max(0, y0), min(po.rect.width, xs1 + 6), y1)
    longer = max(rect.width, rect.height)
    scale = max(CROP_TARGET / longer, CROP_MIN_SCALE) if longer > 0 else CROP_MIN_SCALE
    pix = po.get_pixmap(matrix=fitz.Matrix(scale, scale), clip=rect)
    pix.save(out_path)
    return rect, scale


def place_button(header, occupied, page_w, sx, sy):
    """Entry button: under the exercise number, shifted into free space.
    Returns page-image pixel coords."""
    if header is None:
        return {"x": 0, "y": 0, "w": BUTTON_SIZE, "h": BUTTON_SIZE}
    hb = header["bbox"]
    size_pt = BUTTON_SIZE / sx
    candidates = [
        (hb[0], hb[3] + 2),                       # under the number
        (max(0, hb[0] - size_pt - 2), hb[1]),     # left of the number
        (hb[2] + 2, hb[1]),                       # right of the number
    ]
    def free(x, y):
        r = (x, y, x + size_pt, y + size_pt)
        return all(min(r[2], ob[2]) <= max(r[0], ob[0]) or
                   min(r[3], ob[3]) <= max(r[1], ob[1]) for ob in occupied)
    x, y = next(((x, y) for x, y in candidates if free(x, y)), candidates[0])
    return {"x": int(x * sx), "y": int(y * sy),
            "w": BUTTON_SIZE, "h": BUTTON_SIZE}


def build_circle_sections(po, pa, page_num, images_dir, prefix, sx, sy,
                          start_idx=1):
    """Emit editor-format circle sections (and write crop images)."""
    sections = []
    occupied = [s["bbox"] for s in get_spans(po)]
    for k, ex in enumerate(detect_circle_exercises(po, pa)):
        fname = f"p{page_num}s{start_idx + k}.png"
        rect, scale = crop_band(po, ex["band"], ex["options"],
                                os.path.join(images_dir, fname))
        answers = []
        for o in ex["options"]:
            ob = o["bbox"]
            entry = {
                "coords": {
                    "x": int((ob[0] - rect.x0 - 3) * scale),
                    "y": int((ob[1] - rect.y0 - 2) * scale),
                    "w": int((ob[2] - ob[0] + 6) * scale),
                    "h": int((ob[3] - ob[1] + 4) * scale),
                },
                "opacity": 1,
            }
            if o["isCorrect"]:
                entry["isCorrect"] = True
            answers.append(entry)
        sections.append({
            "activity": {
                "type": "circle",
                "answer": answers,
                "circleCount": ex["circleCount"],
                "markCount": 0,
                "coords": place_button(ex["header"], occupied, po.rect.width, sx, sy),
                "headerText": "",
                "section_path": f"{prefix}{fname}",
            },
            "audio_extra": {},
        })
    return sections


# ---------------------------------------------------------------------------

def main():
    from PIL import Image, ImageDraw
    if len(sys.argv) < 5:
        print(__doc__)
        sys.exit(1)
    orig_path, ans_path, out_dir = sys.argv[1:4]
    pages = [int(p) for p in sys.argv[4:]]
    os.makedirs(out_dir, exist_ok=True)
    orig, ans = fitz.open(orig_path), fitz.open(ans_path)

    for pno in pages:
        po, pa = orig[pno - 1], ans[pno - 1]
        exercises = detect_circle_exercises(po, pa)
        print(f"page {pno}: {len(exercises)} circle exercise(s)")

        zoom = 2.0
        pix = po.get_pixmap(matrix=fitz.Matrix(zoom, zoom))
        img = Image.frombytes("RGB", (pix.width, pix.height), pix.samples)
        drw = ImageDraw.Draw(img)
        for ex in exercises:
            y0, y1 = ex["band"]
            n_corr = sum(o["isCorrect"] for o in ex["options"])
            print(f"  band y={y0:.0f}..{y1:.0f}: {len(ex['options'])} options, "
                  f"{n_corr} correct, circleCount={ex['circleCount']}")
            drw.rectangle([10, y0 * zoom, pix.width - 10, y1 * zoom - 4],
                          outline=(160, 0, 200), width=3)
            for o in ex["options"]:
                color = (255, 0, 0) if o["isCorrect"] else (0, 120, 255)
                drw.rectangle([v * zoom for v in o["bbox"]], outline=color, width=3)
        img.save(os.path.join(out_dir, f"page_{pno:03d}_circle.png"))
    orig.close(); ans.close()


if __name__ == "__main__":
    main()
