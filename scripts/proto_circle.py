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

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from _bootstrap import ensure_runtime_deps
ensure_runtime_deps()

import fitz

from proto_inventory import (diff_answer_drawings, find_image_rects,
                             get_spans, page_dict, page_drawings,
                             page_words, _cached)

OPTION_RE = re.compile(r"^([a-hA-H])[.)]$|^([a-hA-H])[.)]\s+\S")
TF_RE = re.compile(r"^(T|F|TRUE|FALSE|YES|NO)$", re.IGNORECASE)
HEADER_RE = re.compile(r"^\d{1,2}\.(\s+\S|$)")
HEADER_X_MAX = 60.0        # exercise headers start at the page margin
CROP_TARGET = 1000.0       # longer side of the crop render
CROP_MIN_SCALE = 2.0
BUTTON_SIZE = 44           # entry button size in page-image pixels
MIN_TAP_PT = 16            # minimum tap-target side (PDF points)


def is_circle_drawing(d):
    """Circle/ellipse strokes: small rings around letters or wide
    ellipses around whole phrases."""
    x0, y0, x1, y1 = d["bbox"]
    w, h = x1 - x0, y1 - y0
    return "c" in d["ops"] and 8 <= h <= 30 and 0.75 * h <= w <= 130


def merge_circle_parts(circles, overlap=0.45):
    """Publishers often draw one ring as several path objects (and PDFs
    duplicate them); cluster heavily-overlapping parts into one circle.

    Parts of one ring overlap on most of their area; two DISTINCT
    rings stacked in a T/F column only touch at the tangent — so
    membership needs real overlap on both axes, not mere adjacency."""
    merged = []
    for c in sorted(circles, key=lambda c: (c["bbox"][1], c["bbox"][0])):
        cb = c["bbox"]
        host = None
        for m in merged:
            mb = m["bbox"]
            ix = min(cb[2], mb[2]) - max(cb[0], mb[0])
            iy = min(cb[3], mb[3]) - max(cb[1], mb[1])
            min_w = min(cb[2] - cb[0], mb[2] - mb[0])
            min_h = min(cb[3] - cb[1], mb[3] - mb[1])
            if ix > overlap * min_w and iy > overlap * min_h:
                host = m
                break
        if host:
            mb = host["bbox"]
            host["bbox"] = (min(mb[0], cb[0]), min(mb[1], cb[1]),
                            max(mb[2], cb[2]), max(mb[3], cb[3]))
        else:
            merged.append({"bbox": cb})
    return merged


def option_letter(text):
    t = text.strip()
    m = OPTION_RE.match(t)
    if m:
        return (m.group(1) or m.group(2)).lower()
    if TF_RE.match(t):
        return t[0].lower()
    return None


def slash_word_options(page):
    """Word alternatives around '/' tokens — "True / False",
    "ten / eleven", "do / does". The student circles a WORD, so each
    part needs its own word-level bbox (PyMuPDF "words" extraction).
    Returns [{line, parts: [{text, bbox}]}], one entry per slash chain."""
    by_line = {}
    for w in page_words(page):
        by_line.setdefault((w[5], w[6]), []).append(w)
    out = []
    for key, ws in by_line.items():
        ws.sort(key=lambda w: w[0])
        groups, cur = [], None
        for i, w in enumerate(ws):
            if w[4] == "/" and 0 < i < len(ws) - 1:
                if cur and cur[-1] == i - 1:
                    cur.append(i + 1)        # chain: a / b / c
                else:
                    cur = [i - 1, i + 1]
                    groups.append(cur)
        for grp in groups:
            parts = [{"text": ws[i][4].strip().strip(".,;:!?"),
                      "bbox": list(ws[i][:4])}
                     for i in grp if ws[i][4].strip() not in ("", "/")]
            parts = [p for p in parts if p["text"]]
            if len(parts) >= 2:
                out.append({"line": key, "parts": parts})
    # White halo twins duplicate whole lines: same texts at (nearly)
    # the same spot must yield ONE group.
    uniq, seen = [], set()
    for g in out:
        k = tuple((p["text"], int(p["bbox"][0] / 3), int(p["bbox"][1] / 3))
                  for p in g["parts"])
        if k not in seen:
            seen.add(k)
            uniq.append(g)
    return uniq


def find_exercise_bands(page):
    return _cached(page, "bands", lambda: _build_exercise_bands(page))


def _build_exercise_bands(page):
    """Rect bands [{rect, header}], one per numbered unit.

    Numbered headers at the left margin slice the page vertically.
    Test books put two questions side by side: a second number anchor
    on the same baseline near the page middle splits that slice into
    left/right column bands."""
    spans = get_spans(page)
    W, H = page.rect.width, page.rect.height
    mid = W / 2
    # Unit anchors: "7." style numbers, or a lone margin capital
    # ("A", "B" chips — Goals-style books letter their exercises).
    numbered = [s for s in spans
                if HEADER_RE.match(s["text"].strip())
                or re.fullmatch(r"[A-H]", s["text"].strip())]

    def row_count(s):
        return sum(1 for n in numbered
                   if abs(n["bbox"][1] - s["bbox"][1]) < 6)

    def keep(s, side):
        """Unit headers only: item numbers come in rows of 3+ or sit
        right under their own exercise header."""
        if row_count(s) >= 3:
            return False
        above = [a for a in side if a["bbox"][1] < s["bbox"][1] - 2]
        return not above or s["bbox"][1] - max(a["bbox"][1] for a in above) > 35

    left = sorted([s for s in numbered if s["bbox"][0] <= HEADER_X_MAX],
                  key=lambda s: s["bbox"][1])
    right = sorted([s for s in numbered
                    if mid - 20 <= s["bbox"][0] <= mid + 80],
                   key=lambda s: s["bbox"][1])
    left = [s for s in left if keep(s, left)]
    right = [s for s in right if keep(s, right)]

    # Two-column mode: a left/right anchor pair shares a baseline.
    # Columns then flow independently (questions stagger); a left
    # anchor with no right-column anchor beside it spans full width
    # and closes both columns.
    twin = any(abs(l["bbox"][1] - r["bbox"][1]) < 6
               for l in left for r in right)

    bands = []
    if not twin:
        if not left or left[0]["bbox"][1] > 30:
            y1 = left[0]["bbox"][1] - 4 if left else H
            bands.append({"rect": (0.0, 0.0, W, y1), "header": None})
        for i, h in enumerate(left):
            y0 = h["bbox"][1] - 4
            y1 = left[i + 1]["bbox"][1] - 4 if i + 1 < len(left) else H
            bands.append({"rect": (0.0, y0, W, y1), "header": h})
        return bands

    split_x = min(r["bbox"][0] for r in right) - 6

    def right_flow_at(y):
        """Is the right column mid-question at this latitude? True when
        right-column text or artwork sits beside/below the anchor row."""
        for s in spans:
            if s["bbox"][0] > split_x - 8 and y - 4 <= s["bbox"][1] <= y + 40:
                return True
        for img in find_image_rects(page):
            ib = img["bbox"]
            if ib[0] > split_x - 8 and ib[1] <= y + 40 and ib[3] >= y - 4:
                return True
        return False

    full = [h for h in left if not right_flow_at(h["bbox"][1])]
    col_left = [h for h in left if h not in full]
    full_ys = [h["bbox"][1] - 4 for h in full]

    def column_bands(anchors, x0, x1):
        for i, h in enumerate(anchors):
            y0 = h["bbox"][1] - 4
            nxt = [a["bbox"][1] - 4 for a in anchors[i + 1:]]
            nxt += [fy for fy in full_ys if fy > y0 + 4]
            y1 = min(nxt) if nxt else H
            bands.append({"rect": (x0, y0, x1, y1), "header": h})

    column_bands(col_left, 0.0, split_x)
    column_bands(right, split_x, W)
    for h in full:
        y0 = h["bbox"][1] - 4
        below = [a["bbox"][1] - 4 for a in left + right
                 if a["bbox"][1] - 4 > y0 + 4]
        y1 = min(below) if below else H
        bands.append({"rect": (0.0, y0, W, y1), "header": h})
    return bands


def _separate(opts):
    """Tap targets must never overlap: shave overlapping pairs apart
    at the middle of the penetration, along the shallower axis."""
    for i in range(len(opts)):
        for j in range(i + 1, len(opts)):
            a, b = list(opts[i]["bbox"]), list(opts[j]["bbox"])
            ix = min(a[2], b[2]) - max(a[0], b[0])
            iy = min(a[3], b[3]) - max(a[1], b[1])
            if ix <= 0 or iy <= 0:
                continue
            if ix <= iy:   # separate horizontally
                cut = (max(a[0], b[0]) + min(a[2], b[2])) / 2
                if a[0] < b[0]:
                    a[2], b[0] = cut - 1, cut + 1
                else:
                    b[2], a[0] = cut - 1, cut + 1
            else:          # separate vertically
                cut = (max(a[1], b[1]) + min(a[3], b[3])) / 2
                if a[1] < b[1]:
                    a[3], b[1] = cut - 1, cut + 1
                else:
                    b[3], a[1] = cut - 1, cut + 1
            opts[i]["bbox"], opts[j]["bbox"] = tuple(a), tuple(b)


def detect_circle_exercises(po, pa, bands_override=None):
    """Returns a list of exercises:
    {band, header, options: [{letter, bbox, isCorrect}], counts}

    bands_override: skip band detection and use the given rect bands —
    e.g. a crop area the user adjusted by hand in the editor."""
    circles = merge_circle_parts(
        [d for d in diff_answer_drawings(po, pa) if is_circle_drawing(d)])
    if not circles:
        return []
    spans = get_spans(po)
    options = [s for s in spans if option_letter(s["text"])]
    # White halo twins duplicate every token (slightly shifted): one
    # option letter must yield ONE tap target, not two stacked boxes.
    seen, uniq = set(), []
    for s in options:
        k = (s["text"], int(s["bbox"][0] / 3), int(s["bbox"][1] / 3))
        if k not in seen:
            seen.add(k)
            uniq.append(s)
    options = uniq
    bands = bands_override if bands_override else find_exercise_bands(po)
    if not bands:
        bands = [{"rect": (0.0, 0.0, po.rect.width, po.rect.height),
                  "header": None}]

    def band_of(x, y):
        for i, b in enumerate(bands):
            x0, y0, x1, y1 = b["rect"]
            if y0 <= y < y1 and x0 <= x < x1:
                return i
        return None

    # Assign options to bands; the tap target is the option's WHOLE
    # content, so extend each token over its phrase / adjacent artwork.
    exercises = {}
    for opt in options:
        ob = opt["bbox"]
        bi = band_of((ob[0] + ob[2]) / 2, (ob[1] + ob[3]) / 2)
        if bi is None:
            continue
        # Combined spans ("a. some text...") anchor on the letter glyph
        # only — otherwise one long option stretches every box.
        t = opt["text"].strip()
        if not re.fullmatch(r"[a-hA-H][.)]", t) and not TF_RE.fullmatch(t):
            ob = (ob[0], ob[1],
                  min(ob[2], ob[0] + opt["size"] * 1.2), ob[3])
        exercises.setdefault(bi, []).append({
            "letter": option_letter(opt["text"]),
            "bbox": ob,
            "anchor": ob,          # typeset token position, pre-extension
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
            c["used"] = True

    # Fallback: circles around bare number tokens ("circle the numbers
    # you hear") — siblings are the band's same-styled number tokens,
    # several circles in one band mean free selection (circleCount -1).
    for c in [c for c in circles if not c.get("used")]:
        cb = c["bbox"]
        best, best_area = None, 0.0
        for s in spans:
            sb = s["bbox"]
            ix = min(cb[2], sb[2]) - max(cb[0], sb[0])
            iy = min(cb[3], sb[3]) - max(cb[1], sb[1])
            if ix > 0 and iy > 0 and ix * iy > best_area:
                best, best_area = s, ix * iy
        if not best or not re.fullmatch(r"\d+", best["text"].strip()):
            continue
        bb = best["bbox"]
        bi = band_of((bb[0] + bb[2]) / 2, (bb[1] + bb[3]) / 2)
        if bi is None or bi in exercises:
            continue
        group = [s for s in spans
                 if re.fullmatch(r"\d+", s["text"].strip())
                 and s["font"] == best["font"] and abs(s["size"] - best["size"]) < 1
                 and band_of((s["bbox"][0] + s["bbox"][2]) / 2,
                             (s["bbox"][1] + s["bbox"][3]) / 2) == bi]
        gseen, guniq = set(), []
        for s in group:
            k = (s["text"], int(s["bbox"][0] / 3), int(s["bbox"][1] / 3))
            if k not in gseen:
                gseen.add(k)
                guniq.append(s)
        group = guniq
        if len(group) < 2:
            continue
        opts = exercises.setdefault(bi, [])
        existing = {id(o.get("span")) for o in opts}
        for s in group:
            if id(s) in existing:
                continue
            opts.append({"letter": s["text"], "bbox": s["bbox"],
                         "anchor": s["bbox"], "isCorrect": False,
                         "span": s, "numeric": True})
        for cc in [c2 for c2 in circles if not c2.get("used")]:
            ccb = cc["bbox"]
            for o in opts:
                ob = o["bbox"]
                if min(ccb[2], ob[2]) > max(ccb[0], ob[0]) and \
                   min(ccb[3], ob[3]) > max(ccb[1], ob[1]):
                    o["isCorrect"] = True
                    o["circle_bbox"] = ccb
                    cc["used"] = True
                    break

    # Fallback: circles around slash-separated WORD alternatives
    # ("True / False", "ten / eleven") — every line is one question,
    # its parts are the options; the ring marks the correct word.
    slash_groups = None
    for c in [c for c in circles if not c.get("used")]:
        cb = c["bbox"]
        if slash_groups is None:
            slash_groups = slash_word_options(po)
        # The ring may graze the neighbouring word too: the marked
        # part is the one with the LARGEST overlap, not the first.
        hit, best = None, 0.0
        for g in slash_groups:
            for p in g["parts"]:
                pb = p["bbox"]
                ix = min(cb[2], pb[2]) - max(cb[0], pb[0])
                iy = min(cb[3], pb[3]) - max(cb[1], pb[1])
                if ix > 0 and iy > 0 and ix * iy > best:
                    hit, best = (g, p), ix * iy
        if not hit:
            continue
        g, p = hit
        gx = sum((q["bbox"][0] + q["bbox"][2]) / 2 for q in g["parts"]) / len(g["parts"])
        gy = sum((q["bbox"][1] + q["bbox"][3]) / 2 for q in g["parts"]) / len(g["parts"])
        bi = band_of(gx, gy)
        if bi is None:
            continue
        opts = exercises.setdefault(bi, [])
        existing = {(o.get("slash_line"), o["letter"]) for o in opts}
        for part in g["parts"]:
            k = (g["line"], part["text"])
            if k in existing:
                continue
            opts.append({"letter": part["text"], "bbox": list(part["bbox"]),
                         "anchor": list(part["bbox"]),
                         "isCorrect": part is p,
                         "circle_bbox": cb if part is p else None,
                         "slash_line": g["line"]})
        c["used"] = True

    TF_LETTERS = {"t", "f", "y", "n"}
    out = []
    for bi, opts in sorted(exercises.items()):
        correct = [o for o in opts if o["isCorrect"]]
        if not correct or len(opts) < 2:
            continue   # not a real choice exercise

        # Pure T/F exercises: drop stray letter tokens (sub-exercise
        # headers like "b. Look at the table..." are not options).
        if all(o["letter"] in TF_LETTERS for o in correct):
            tf_only = [o for o in opts if o["letter"] in TF_LETTERS]
            if len(tf_only) >= 4:
                opts = tf_only
                correct = [o for o in opts if o["isCorrect"]]

        # Slash-word options already carry exact word boxes — they
        # must NOT go through the ring-based resize below (it is built
        # for letter tokens and would smear word boxes around).
        slash = [o for o in opts if o.get("slash_line")]
        plain = [o for o in opts if not o.get("slash_line")]
        for o in slash:
            ob = o["bbox"]
            o["bbox"] = (ob[0] - 2, ob[1] - 2, ob[2] + 2, ob[3] + 2)

        correct_plain = [o for o in plain if o["isCorrect"]]
        if plain and correct_plain:
            # The tap target is the area the student circles, not the
            # glyph. Hand-drawn circles wobble, so they only set the
            # SIZE (median per exercise); the position always comes
            # from the typeset token center — keeping rows aligned.
            ws = sorted(c["circle_bbox"][2] - c["circle_bbox"][0]
                        for c in correct_plain)
            hs = sorted(c["circle_bbox"][3] - c["circle_bbox"][1]
                        for c in correct_plain)
            med_w, med_h = ws[len(ws) // 2], hs[len(hs) // 2]
            # Token bboxes carry trailing-space/descender bias; the
            # drawn circles are centered on the visible glyph. Use
            # their median offset (small rings, capped) to re-center.
            offs = []
            for o in correct_plain:
                cb = o.get("circle_bbox")
                if cb and cb[2] - cb[0] <= 40:
                    ab = o["anchor"]
                    offs.append(((cb[0] + cb[2]) / 2 - (ab[0] + ab[2]) / 2,
                                 (cb[1] + cb[3]) / 2 - (ab[1] + ab[3]) / 2))
            offs.sort()
            dx, dy = offs[len(offs) // 2] if offs else (0.0, 0.0)
            dx = max(-6.0, min(6.0, dx))
            dy = max(-6.0, min(6.0, dy))

            # One uniform box size per exercise (consistent look),
            # shrunk to the option grid pitch to avoid collisions.
            w = max([med_w, MIN_TAP_PT] + [o["anchor"][2] - o["anchor"][0] + 3
                                           for o in plain])
            h = max([med_h, MIN_TAP_PT] + [o["anchor"][3] - o["anchor"][1] + 2
                                           for o in plain])
            centers = [((o["anchor"][0] + o["anchor"][2]) / 2,
                        (o["anchor"][1] + o["anchor"][3]) / 2) for o in plain]
            for (ax, ay), (bx, by) in zip(sorted(centers), sorted(centers)[1:]):
                if abs(bx - ax) > 2 and abs(by - ay) < 4:
                    w = min(w, abs(bx - ax) - 2)
            for (ay, ax), (by, bx) in zip(sorted((cy, cx) for cx, cy in centers),
                                          sorted((cy, cx) for cx, cy in centers)[1:]):
                if abs(by - ay) > 2 and abs(bx - ax) < w:
                    h = min(h, abs(by - ay) - 2)

            for o in plain:
                ob = o["bbox"]
                cx = (ob[0] + ob[2]) / 2 + dx
                cy = (ob[1] + ob[3]) / 2 + dy
                o["bbox"] = (cx - w / 2, cy - h / 2, cx + w / 2, cy + h / 2)
        _separate(opts)
        # Options per question: letter sequences reset at each new
        # question (a,b,c,d -> a...; T -> F), independent of layout.
        # Sort column-aware so two-column pages don't interleave.
        mid_x = po.rect.width / 2

        def is_successor(prev, cur):
            if prev == "t" and cur == "f":
                return True
            return len(prev) == 1 and len(cur) == 1 and ord(cur) == ord(prev) + 1

        letters = [o["letter"] for o in opts]
        slash_opts = [o for o in opts if o.get("slash_line")]
        if slash_opts:
            # word-alternative lines: one question per line, options
            # per question = that line's slash parts (usually 2).
            lines = {o["slash_line"] for o in slash_opts}
            circle_count = max(2, round(len(slash_opts) / len(lines)))
        elif any(o.get("numeric") for o in opts):
            circle_count = -1 if len(correct) > 1 else len(opts)
        elif len(set(letters)) == len(letters):
            circle_count = len(opts)     # unique letters: one question
        else:
            ordered = sorted(opts, key=lambda o: (
                (o["anchor"][0] + o["anchor"][2]) / 2 >= mid_x,
                round((o["anchor"][1] + o["anchor"][3]) / 2), o["anchor"][0]))
            groups, size = [], 0
            prev = None
            for o in ordered:
                if prev is not None and not is_successor(prev, o["letter"]):
                    groups.append(size)
                    size = 0
                size += 1
                prev = o["letter"]
            groups.append(size)
            groups = [g for g in groups if g >= 2]
            circle_count = max(set(groups), key=groups.count) if groups else len(opts)
        out.append({
            "band": bands[bi]["rect"],
            "header": bands[bi]["header"],
            "options": sorted(opts, key=lambda o: (o["bbox"][1], o["bbox"][0])),
            "circleCount": circle_count,
            "matched": len(correct),
        })
    return out


def header_text_in_rect(page, rect_pt):
    """COMMON header extractor: reading-order text of the printed
    lines whose center falls inside the user-drawn rect. White-halo
    echoes are collapsed ("7. 7." / doubled words)."""
    x0, y0, x1, y1 = rect_pt
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
            key = next((k for k in rows if abs(k - ly0) < 4), ly0)
            rows.setdefault(key, []).extend(spans)
    parts = []
    for key in sorted(rows):
        seen, row = set(), []
        for s in sorted(rows[key], key=lambda s: s["bbox"][0]):
            k = (s["text"].strip(), int(s["bbox"][0] / 3))
            if k not in seen:
                seen.add(k)
                row.append(s["text"].strip())
        parts.append(" ".join(row))
    text = re.sub(r"\s+", " ", " ".join(parts)).strip()
    text = re.sub(r"^(\d{1,2}\.)( \1)+", r"\1", text)
    text = re.sub(r"\b(\S+)( \1)+\b", r"\1", text).strip()
    # Drop the leading exercise number the rect inevitably catches
    # ("1 Complete the table..." -> "Complete the table...").
    text = re.sub(r"^\d{1,2}\s*[.)]?\s+", "", text).strip()
    return text


def headertext(raw_dir, page_no, rect_px, png_size):
    """CLI back-end for the editor's header-pick mode: convert the
    page-PNG rect to points and print {"headerText": ...}."""
    import json
    original_path, _ = find_pdf_pair(raw_dir)
    if not original_path:
        print(json.dumps({"error": "pdf not found in raw dir"}))
        return 1
    doc = fitz.open(original_path)
    po = doc[page_no - 1]
    sx = po.rect.width / png_size[0]
    sy = po.rect.height / png_size[1]
    x, y, w, h = rect_px
    text = header_text_in_rect(po, (x * sx, y * sy,
                                    (x + w) * sx, (y + h) * sy))
    print(json.dumps({"headerText": text}, ensure_ascii=False))
    doc.close()
    return 0


def _span_rgb(span):
    """(r,g,b) 0-255 of a fitz span's sRGB int colour."""
    c = int(span.get("color", 0))
    return ((c >> 16) & 255, (c >> 8) & 255, c & 255)


def _is_answer_colour(rgb):
    """True for a saturated non-black colour (the red/blue/green answer key),
    False for black/gray body text (the shuffled prompts + the header)."""
    r, g, b = rgb
    return max(r, g, b) > 90 and (max(r, g, b) - min(r, g, b)) > 40


def ordering_answer_lines(page, rect_pt):
    """The correct-order answer sentences printed inside the rect: reading-order
    text of each line, grouped per row. The shuffled prompt lines (they carry
    "/" separators, body colour) and the exercise header are dropped; only the
    coloured answer-key lines survive. Returns a list of strings, top-to-bottom."""
    x0, y0, x1, y1 = rect_pt
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
            key = next((k for k in rows if abs(k - ly0) < 4), ly0)
            rows.setdefault(key, []).extend(spans)

    lines = []
    for key in sorted(rows):
        seen, row = set(), []
        coloured = 0
        for s in sorted(rows[key], key=lambda s: s["bbox"][0]):
            txt = s["text"].strip()
            k = (txt, int(s["bbox"][0] / 3))
            if k in seen:
                continue
            seen.add(k)
            row.append(txt)
            if _is_answer_colour(_span_rgb(s)):
                coloured += 1
        text = re.sub(r"\s+", " ", " ".join(row)).strip()
        text = re.sub(r"\b(\S+)( \1)+\b", r"\1", text).strip()
        if text:
            lines.append((text, coloured, len(row)))

    def _clean(t):
        # The answer is written over the printed blank line, so the row text
        # picks up its underscores (and the trailing "." of the blank). Drop
        # every run of underscores and the leading punctuation left behind.
        t = re.sub(r"_+", " ", t)
        t = re.sub(r"^[\s._-]+", "", t)
        # Drop a leading item number ("1 The atmosphere..." -> "The atmosphere...").
        t = re.sub(r"^\d{1,2}\s*[.)]?\s+", "", t)
        return re.sub(r"\s+", " ", t).strip()

    # Primary: keep the coloured answer lines (most spans coloured, no "/").
    answers = [_clean(t) for (t, col, n) in lines
               if col >= max(1, n // 2) and "/" not in t]
    if answers:
        return answers

    # Fallback (no colour info, e.g. flattened PDF): the lines without a "/"
    # that read like a sentence, minus the instruction header.
    for (t, col, n) in lines:
        c = _clean(t)
        if "/" in c or len(c.split()) < 2:
            continue
        if re.search(r"correct order|put the words", c, re.I):
            continue
        answers.append(c)
    return answers


def ordering(raw_dir, page_no, rect_px, png_size):
    """CLI back-end for the editor's ordering crop: read the correct-order
    answer sentences from the ANSWERED PDF inside the page-PNG rect and print
    {"sentences": [...]}."""
    import json
    _, answered_path = find_pdf_pair(raw_dir)
    if not answered_path:
        print(json.dumps({"error": "answered pdf not found in raw dir",
                          "sentences": []}))
        return 1
    doc = fitz.open(answered_path)
    pa = doc[page_no - 1]
    sx = pa.rect.width / png_size[0]
    sy = pa.rect.height / png_size[1]
    x, y, w, h = rect_px
    sents = ordering_answer_lines(pa, (x * sx, y * sy,
                                       (x + w) * sx, (y + h) * sy))
    print(json.dumps({"sentences": sents}, ensure_ascii=False))
    doc.close()
    return 0


def crop_band(po, band, options, out_path):
    """Crop the exercise area from the original PDF; returns (rect, scale).

    The band rect is only the search region — the crop hugs the actual
    content inside it: text spans, embedded images and the options."""
    bx0, by0, bx1, by1 = band

    def inside(b):
        cx, cy = (b[0] + b[2]) / 2, (b[1] + b[3]) / 2
        return bx0 <= cx < bx1 and by0 <= cy < by1

    content = [o["bbox"] for o in options]
    content += [s["bbox"] for s in get_spans(po) if inside(s["bbox"])]
    content += [i["bbox"] for i in find_image_rects(po) if inside(i["bbox"])]

    xs0 = min(b[0] for b in content)
    ys0 = min(b[1] for b in content)
    xs1 = max(b[2] for b in content)
    ys1 = max(b[3] for b in content)
    # Artwork whose center is in the band may stick out over the band
    # top (decorative headers): let the crop follow it a little.
    img_top = min((i["bbox"][1] for i in find_image_rects(po)
                   if inside(i["bbox"])), default=by0)
    top_limit = max(0.0, min(by0, img_top), by0 - 14)
    pad = 6
    rect = fitz.Rect(max(bx0, xs0 - pad), max(top_limit, ys0 - pad),
                     min(bx1, xs1 + pad), min(by1, ys1 + pad))
    longer = max(rect.width, rect.height)
    scale = max(CROP_TARGET / longer, CROP_MIN_SCALE) if longer > 0 else CROP_MIN_SCALE
    pix = po.get_pixmap(matrix=fitz.Matrix(scale, scale), clip=rect)
    _save_pixmap(pix, out_path)
    return rect, scale


def _save_pixmap(pix, out_path, retries=2):
    """fitz save with the directory ensured and a short retry —
    freshly-copied book folders can hiccup on the first write."""
    os.makedirs(os.path.dirname(out_path) or ".", exist_ok=True)
    for attempt in range(retries + 1):
        try:
            pix.save(out_path)
            return
        except RuntimeError:
            if attempt == retries:
                raise
            import time
            time.sleep(0.2)


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
                    "x": int((ob[0] - rect.x0) * scale),
                    "y": int((ob[1] - rect.y0) * scale),
                    "w": int((ob[2] - ob[0]) * scale),
                    "h": int((ob[3] - ob[1]) * scale),
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
# markwithx: same machinery, but the student puts a MARK (✓ glyph or
# X strokes) into small printed boxes instead of circling an option.
# ---------------------------------------------------------------------------

def is_x_drawing(d):
    """X/check strokes: small line-only drawings, roughly square."""
    x0, y0, x1, y1 = d["bbox"]
    w, h = x1 - x0, y1 - y0
    return ("l" in d["ops"] and "c" not in d["ops"]
            and 4 <= w <= 26 and 4 <= h <= 26
            and 0.4 <= w / max(h, 0.1) <= 2.5)


def _mark_boxes(page, lo=6.0, hi=28.0):
    """Small printed squares (incl. rounded 24pt checkboxes that the
    fill pipeline's tick finder ignores). White-fill + colored-stroke
    twins draw the same box twice — dedupe on a coarse grid."""
    boxes, seen = [], set()
    for d in page_drawings(page):
        r = d["rect"]
        if lo <= r.width <= hi and lo <= r.height <= hi \
                and abs(r.width - r.height) <= 6:
            k = (int(r.x0 / 4), int(r.y0 / 4))
            if k not in seen:
                seen.add(k)
                boxes.append([r.x0, r.y0, r.x1, r.y1])
    return boxes


def detect_markwithx_exercises(po, pa, bands_override=None):
    """Returns [{band, header, boxes: [{bbox, isCorrect}], markCount}].

    Options are the page's small printed squares; correct = the boxes
    the key marked with a ✓ glyph or X strokes in the answered PDF."""
    from proto_inventory import diff_answer_spans

    boxes = _mark_boxes(po)
    # Audio icon glyphs are icon-sized squares too — never mark zones.
    try:
        from proto_audio import detect_audio_icons
        icons = detect_audio_icons(po)
        boxes = [b for b in boxes
                 if not any(min(b[2], i[2]) > max(b[0], i[0]) and
                            min(b[3], i[3]) > max(b[1], i[1]) for i in icons)]
    except ImportError:
        pass
    if not boxes:
        return []
    marks = [s["bbox"] for s in diff_answer_spans(po, pa) if s["is_checkmark"]]
    marks += [d["bbox"] for d in diff_answer_drawings(po, pa)
              if is_x_drawing(d)]
    if not marks:
        return []

    marked = set()
    for m in marks:
        mx, my = (m[0] + m[2]) / 2, (m[1] + m[3]) / 2
        best, bd = None, 18.0
        for i, b in enumerate(boxes):
            bx, by = (b[0] + b[2]) / 2, (b[1] + b[3]) / 2
            d = ((mx - bx) ** 2 + (my - by) ** 2) ** 0.5
            if d < bd:
                best, bd = i, d
        if best is not None:
            marked.add(best)
    if not marked:
        return []

    bands = bands_override if bands_override else find_exercise_bands(po)
    if not bands:
        bands = [{"rect": (0.0, 0.0, po.rect.width, po.rect.height),
                  "header": None}]

    def band_of(x, y):
        for i, b in enumerate(bands):
            x0, y0, x1, y1 = b["rect"]
            if y0 <= y < y1 and x0 <= x < x1:
                return i
        return None

    groups = {}
    for i, b in enumerate(boxes):
        bi = band_of((b[0] + b[2]) / 2, (b[1] + b[3]) / 2)
        if bi is not None:
            groups.setdefault(bi, []).append(i)

    out = []
    for bi, idxs in sorted(groups.items()):
        corr = [i for i in idxs if i in marked]
        if not corr or len(idxs) < 2:
            continue
        # The marked boxes define the exercise's checkbox size —
        # decorative squares (film strips, frames) differ and drop out.
        sizes = sorted(boxes[i][2] - boxes[i][0] for i in corr)
        ref = sizes[len(sizes) // 2]
        idxs = [i for i in idxs
                if abs((boxes[i][2] - boxes[i][0]) - ref) <= 0.3 * ref]
        corr = [i for i in idxs if i in marked]
        if not corr or len(idxs) < 2:
            continue
        # Rows of equal box counts with exactly one mark each = "mark
        # one per question" (markCount = boxes per row); anything else
        # is free multi-select (markCount -1, Alper 2026-06-12).
        rows = {}
        for i in idxs:
            cy = (boxes[i][1] + boxes[i][3]) / 2
            key = next((k for k in rows if abs(k - cy) < 6), cy)
            rows.setdefault(key, []).append(i)
        counts = {len(r) for r in rows.values()}
        marks_per_row = [sum(1 for i in r if i in marked)
                         for r in rows.values()]
        if len(counts) == 1 and max(counts) >= 2 and \
                all(m == 1 for m in marks_per_row):
            mark_count = max(len(r) for r in rows.values())
        else:
            mark_count = -1
        # Phantom guard: an irregular "free multi-select" band whose
        # marked boxes are a tiny minority of the candidate squares is
        # not a real mark-with-X exercise — it is a few stray ticks
        # landing on artwork squares (illustrations, comic panels,
        # mazes, board-game paths). A genuine free-select marks a
        # meaningful share of its boxes; regular row grids (mark_count
        # > 0) are exempt because they legitimately mark 1-of-N per row.
        # (Alper 2026-06-13: rise_upsb1 emitted 25 phantom markwithx,
        # all mark_count=-1 with marked fraction <= 0.143.)
        if mark_count == -1 and len(corr) < 0.15 * len(idxs):
            continue
        out.append({
            "band": bands[bi]["rect"],
            "header": bands[bi]["header"],
            "boxes": [{"bbox": list(boxes[i]), "isCorrect": i in marked}
                      for i in sorted(idxs, key=lambda i: (boxes[i][1],
                                                           boxes[i][0]))],
            "markCount": mark_count,
        })
    return out


def build_markwithx_sections(po, pa, page_num, images_dir, prefix, sx, sy,
                             start_idx=1):
    """Emit editor-format markwithx sections (and write crop images)."""
    sections = []
    occupied = [s["bbox"] for s in get_spans(po)]
    for k, ex in enumerate(detect_markwithx_exercises(po, pa)):
        fname = f"p{page_num}s{start_idx + k}.png"
        opts = [{"bbox": b["bbox"]} for b in ex["boxes"]]
        rect, scale = crop_band(po, ex["band"], opts,
                                os.path.join(images_dir, fname))
        answers = []
        for b in ex["boxes"]:
            bb = b["bbox"]
            entry = {
                "coords": {
                    "x": int((bb[0] - 2 - rect.x0) * scale),
                    "y": int((bb[1] - 2 - rect.y0) * scale),
                    "w": int((bb[2] - bb[0] + 4) * scale),
                    "h": int((bb[3] - bb[1] + 4) * scale),
                },
                "opacity": 1,
            }
            if b["isCorrect"]:
                entry["isCorrect"] = True
            answers.append(entry)
        sections.append({
            "activity": {
                "type": "markwithx",
                "answer": answers,
                "circleCount": 0,
                "markCount": ex["markCount"],
                "coords": place_button(ex["header"], occupied,
                                       po.rect.width, sx, sy),
                "headerText": "",
                "section_path": f"{prefix}{fname}",
            },
            "audio_extra": {},
        })
    return sections


# ---------------------------------------------------------------------------

def _pdf_page_count(path):
    try:
        d = fitz.open(path)
        n = len(d)
        d.close()
        return n
    except Exception:
        return 0


def find_pdf_pair(raw_dir):
    """Original + answered PDFs. Answered = name has cevap/answer/key.
    Original = the remaining book PDF. When several non-answered PDFs
    exist (e.g. a separate cover / 'kapak' file alongside the book) pick
    the one whose page count matches the answered PDF, so we never grab
    the few-page cover (that crashed header-pick on amazing: the cover
    has 3 pages, page 4 'not in document')."""
    pdfs = [f for f in os.listdir(raw_dir) if f.lower().endswith(".pdf")]
    answered = None
    rest = []
    for f in pdfs:
        if any(k in f.lower() for k in ("cevap", "answer", "key")):
            answered = os.path.join(raw_dir, f)
        else:
            rest.append(os.path.join(raw_dir, f))
    if not rest:
        return None, answered
    if len(rest) == 1:
        return rest[0], answered
    # Several candidates: prefer an explicit name, else drop obvious
    # covers, else match the answered page count, else the longest PDF.
    named = [p for p in rest if any(k in os.path.basename(p).lower()
                                    for k in ("original", "soru"))]
    if named:
        return named[0], answered
    cands = [p for p in rest if not any(k in os.path.basename(p).lower()
                                        for k in ("kapak", "cover", "kapag"))] or rest
    if len(cands) > 1 and answered:
        npages = _pdf_page_count(answered)
        match = [p for p in cands if _pdf_page_count(p) == npages]
        if match:
            cands = match
    if len(cands) == 1:
        return cands[0], answered
    return max(cands, key=_pdf_page_count), answered


def redetect(raw_dir, page_no, rect_px, png_size, out_path, kind="circle"):
    """Re-run option detection inside a user-adjusted crop rect.

    rect_px / png_size are in page-image pixel space (same convention
    as crop_section.py). Crops the exact rect, prints the section JSON
    (answers in crop pixels + circleCount/markCount) to stdout.
    kind: "circle" or "markwithx" — the activity the user is editing."""
    import json
    original_path, answered_path = find_pdf_pair(raw_dir)
    # The crop image is cut from the original, so that PDF (and this page in
    # it) is the only hard requirement. The answered PDF only drives option/
    # mark detection: when it's missing — or simply has no such page — fall
    # back to cropping the region from the original and leaving the answers
    # for the user to place by hand, rather than erroring out.
    if not original_path:
        print(json.dumps({"error": "original pdf not found in raw dir"}))
        return 1
    orig = fitz.open(original_path)
    if not (1 <= page_no <= len(orig)):
        print(json.dumps({"error": "page %d out of range in original pdf" % page_no}))
        orig.close()
        return 1
    po = orig[page_no - 1]
    ans, pa = None, None
    if answered_path:
        ans = fitz.open(answered_path)
        if 1 <= page_no <= len(ans):
            pa = ans[page_no - 1]
    sx = po.rect.width / png_size[0]
    sy = po.rect.height / png_size[1]
    x, y, w, h = rect_px
    band = (x * sx, y * sy, (x + w) * sx, (y + h) * sy)

    # Fill re-check: re-run the full fill snap pipeline for the page, then
    # keep only the fills whose center falls inside the user's rect. Unlike
    # circle/markwithx this produces no crop image and the coords stay in
    # page-PNG pixels (fills overlay the page directly). The editor deletes
    # the existing fills in the band and inserts these.
    if kind == "fill":
        # Fill re-check reads the answers from the answered/original diff, so
        # without an answered page there is nothing to re-detect (and fill
        # produces no crop image anyway) — return an empty band cleanly.
        out = []
        if pa is not None:
            # Use the SAME pipeline as Analyze (detect_fills): registration +
            # echo/phantom guards + prose/echo rescue + graphic-checkmark
            # recovery. The bare snap_page here used to re-insert exactly the
            # phantoms Analyze had filtered (and lose recovered ✓ marks) when
            # the user adjusted a band and hit re-check.
            from stage_fill import detect_fills
            snap_sx = png_size[0] / po.rect.width
            snap_sy = png_size[1] / po.rect.height
            secs = detect_fills(po, pa, snap_sx, snap_sy)
            for sec in secs:
                for a in sec.get("answer", []):
                    c = a["coords"]
                    cx = c["x"] + c["w"] / 2.0
                    cy = c["y"] + c["h"] / 2.0
                    if x <= cx <= x + w and y <= cy <= y + h:
                        out.append({"coords": c, "text": a.get("text", ""),
                                    "isTextBold": bool(a.get("is_text_bold", True)),
                                    "needs_review": bool(a.get("needs_review", False))})
        # detect_fills already emits the blanks in the page's reading order;
        # keep that (walking it here filtered by band preserves it) so the
        # re-checked band matches the page exactly.
        print(json.dumps({"fill": True, "answer": out}, ensure_ascii=False))
        orig.close()
        if ans is not None:
            ans.close()
        return 0

    # The user's rect is authoritative: crop exactly it, even when no
    # options are detected inside (the crop is still wanted).
    rect = fitz.Rect(*band)
    longer = max(rect.width, rect.height)
    scale = max(CROP_TARGET / longer, CROP_MIN_SCALE) if longer > 0 else CROP_MIN_SCALE
    pix = po.get_pixmap(matrix=fitz.Matrix(scale, scale), clip=rect)
    _save_pixmap(pix, out_path)

    def px(bb, pad=0.0):
        return {"x": int((bb[0] - pad - rect.x0) * scale),
                "y": int((bb[1] - pad - rect.y0) * scale),
                "w": int((bb[2] - bb[0] + 2 * pad) * scale),
                "h": int((bb[3] - bb[1] + 2 * pad) * scale)}

    answers = []
    circle_count = 0
    mark_count = 0
    # Options/marks come from the answered page. With no answered page the crop
    # is still saved above; we just emit no answers for the user to fill in.
    if pa is not None:
        override = [{"rect": band, "header": None}]
        if kind == "markwithx":
            exs = detect_markwithx_exercises(po, pa, bands_override=override)
            if exs:
                mark_count = exs[0]["markCount"]
                for b in exs[0]["boxes"]:
                    entry = {"coords": px(b["bbox"], pad=2.0), "opacity": 1}
                    if b["isCorrect"]:
                        entry["isCorrect"] = True
                    answers.append(entry)
        else:
            exs = detect_circle_exercises(po, pa, bands_override=override)
            if exs:
                circle_count = exs[0]["circleCount"]
                for o in exs[0]["options"]:
                    entry = {"coords": px(o["bbox"]), "opacity": 1}
                    if o["isCorrect"]:
                        entry["isCorrect"] = True
                    answers.append(entry)
    # Options come out of detect_*_exercises already in the same order the
    # main page uses (the (y,x) sort at build time), so leave them as-is to
    # match what the page shows.
    print(json.dumps({"answer": answers, "circleCount": circle_count,
                      "markCount": mark_count,
                      "crop": out_path}, ensure_ascii=False))
    orig.close()
    if ans is not None:
        ans.close()
    return 0


def main():
    from PIL import Image, ImageDraw
    if len(sys.argv) >= 2 and sys.argv[1] == "--headertext":
        a = sys.argv[2:]
        if len(a) != 8:
            print("usage: --headertext <raw_dir> <page> "
                  "<x> <y> <w> <h> <png_w> <png_h>")
            sys.exit(1)
        sys.exit(headertext(a[0], int(a[1]),
                            tuple(float(v) for v in a[2:6]),
                            (float(a[6]), float(a[7]))))
    if len(sys.argv) >= 2 and sys.argv[1] == "--ordering":
        a = sys.argv[2:]
        if len(a) != 8:
            print("usage: --ordering <raw_dir> <page> "
                  "<x> <y> <w> <h> <png_w> <png_h>")
            sys.exit(1)
        sys.exit(ordering(a[0], int(a[1]),
                          tuple(float(v) for v in a[2:6]),
                          (float(a[6]), float(a[7]))))
    if len(sys.argv) >= 2 and sys.argv[1] == "--redetect":
        a = sys.argv[2:]
        if len(a) not in (9, 10):
            print("usage: --redetect <raw_dir> <page> "
                  "<x> <y> <w> <h> <png_w> <png_h> <out_crop.png> [kind]")
            sys.exit(1)
        sys.exit(redetect(a[0], int(a[1]),
                          tuple(float(v) for v in a[2:6]),
                          (float(a[6]), float(a[7])), a[8],
                          kind=a[9] if len(a) == 10 else "circle"))
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
            x0, y0, x1, y1 = ex["band"]
            n_corr = sum(o["isCorrect"] for o in ex["options"])
            print(f"  band ({x0:.0f},{y0:.0f})..({x1:.0f},{y1:.0f}): "
                  f"{len(ex['options'])} options, {n_corr} correct, "
                  f"circleCount={ex['circleCount']}")
            drw.rectangle([x0 * zoom + 4, y0 * zoom, x1 * zoom - 4, y1 * zoom - 4],
                          outline=(160, 0, 200), width=3)
            for o in ex["options"]:
                color = (255, 0, 0) if o["isCorrect"] else (0, 120, 255)
                drw.rectangle([v * zoom for v in o["bbox"]], outline=color, width=3)
        img.save(os.path.join(out_dir, f"page_{pno:03d}_circle.png"))
    orig.close(); ans.close()


if __name__ == "__main__":
    main()
