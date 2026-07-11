"""Prototype step 6: dragdrop (word-pool) activities from the diff.

A dragdroppicture exercise is a fill exercise whose answers come from a
word pool printed inside the same exercise band ("Fill in the blanks
with the correct words." + a box of words). Detection is deterministic:

  1. snap the answered/original diff answers to blanks (proto_snap)
  2. per exercise band: find the printed lines that contain the answer
     TEXTS (the pool repeats every answer somewhere in the band)
  3. dense match lines = the pool; enough distinct answers covered
     -> the band is a dragdroppicture, its blanks become drop zones
     and the pool lines become words[] (extras = distractors)

The group variant (categorize-into-boxes) is NOT auto-detected here —
type selection is the AI layer's job; build_dragdrop_sections only
takes a group_mode flag and clusters the zones into column groups.

Debug mode renders an overlay png instead of writing into the book:
  python3 proto_dragdrop.py <original.pdf> <answered.pdf> <out_dir> <page> [...]
"""

import os
import random
import re
import sys

import fitz

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from proto_inventory import (diff_answer_spans, find_blank_lines,
                             get_spans, page_dict)
from proto_snap import build_clickables, find_tick_boxes
from proto_circle import (CROP_MIN_SCALE, CROP_TARGET, crop_band,
                          find_exercise_bands, image_coords_from_rect,
                          place_button)

MIN_ZONES = 3              # a pool exercise has at least this many blanks
LINE_DENSITY = 0.45        # matched chars / line chars for a pool line
POOL_DENSITY = 0.5         # matched chars / pool text — sentences fail this
LINE_JOIN_GAP = 36.0       # pool lines may be this far apart (pt)

# Pool entry separators: bullets, slashes, commas, spaced dashes,
# 2+ spaces. Single spaces stay (multi-word entries: "blonde hair").
SEP_RE = re.compile(r"\s*[•·▪◦‣|/;,*✓✦]+\s*|\s+[–—-]+\s+|\s{2,}")


def norm(t):
    t = re.sub(r"\s+", " ", t.strip()).strip("().:;,!?•·–—…'\"")
    return t.strip().lower()


def band_lines(po, band):
    """Text lines inside the band: [{text, bbox, spans}] in reading order."""
    bx0, by0, bx1, by1 = band
    lines = []
    for b in page_dict(po)["blocks"]:
        if b["type"] != 0:
            continue
        for l in b["lines"]:
            spans = [s for s in l["spans"] if s["text"].strip()]
            if not spans:
                continue
            x0 = min(s["bbox"][0] for s in spans)
            y0 = min(s["bbox"][1] for s in spans)
            x1 = max(s["bbox"][2] for s in spans)
            y1 = max(s["bbox"][3] for s in spans)
            cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
            if not (bx0 <= cx < bx1 and by0 <= cy < by1):
                continue
            # White halo twins duplicate every span, sometimes shifted
            # a pixel or two — dedupe on a coarse grid.
            seen, parts = set(), []
            for s in spans:
                k = (s["text"].strip(), int(s["bbox"][0] / 3),
                     int(s["bbox"][1] / 3))
                if k not in seen:
                    seen.add(k)
                    parts.append(s["text"].strip())
            lines.append({"text": " ".join(parts), "bbox": (x0, y0, x1, y1)})
    # PDF block order is unreliable; merge same-baseline fragments.
    lines.sort(key=lambda l: (round(l["bbox"][1] / 4), l["bbox"][0]))
    uniq, keys = [], set()
    for l in lines:
        k = (l["text"], int(l["bbox"][0] / 3), int(l["bbox"][1] / 3))
        if k not in keys:
            keys.add(k)
            uniq.append(l)
    lines = uniq
    merged = []
    for l in lines:
        if merged and abs(l["bbox"][1] - merged[-1]["bbox"][1]) < 3:
            m = merged[-1]
            gap = l["bbox"][0] - m["bbox"][2]
            m["text"] += ("  " if gap > 8 else " ") + l["text"]
            m["bbox"] = (min(m["bbox"][0], l["bbox"][0]),
                         min(m["bbox"][1], l["bbox"][1]),
                         max(m["bbox"][2], l["bbox"][2]),
                         max(m["bbox"][3], l["bbox"][3]))
        else:
            merged.append(dict(l))
    return merged


def _pat(answer):
    """Word-bounded pattern, hyphen/space agnostic: a pool chip may
    print "middle aged" while the written answer is "middle-aged"."""
    parts = re.split(r"[-\s]+", answer)
    body = r"[-\s]+".join(re.escape(p) for p in parts if p)
    return r"(?<![\w-])" + body + r"(?![\w-])"


def match_line(text, answer_texts):
    """Find answer texts in a line (longest first, word-bounded).
    Returns (matched set, leftover word tokens, matched char count)."""
    matched, low = set(), " " + norm(text) + " "
    consumed = 0
    for a in sorted(answer_texts, key=len, reverse=True):
        pat = _pat(a)
        hits = len(re.findall(pat, low))
        if hits:
            matched.add(a)
            consumed += hits * len(a)
            low = re.sub(pat, " ", low)
    leftovers = [norm(t) for t in SEP_RE.split(low) if norm(t)]
    leftovers = [t for t in leftovers for t in ([t] if " " not in t
                 else t.split())]
    return matched, leftovers, consumed


def _joined(lines):
    return " ".join(l["text"] for l in
                    sorted(lines, key=lambda l: (l["bbox"][1], l["bbox"][0])))


def find_pool(lines, answer_texts):
    """The pool = the densest run of adjacent lines whose text repeats
    the answers. Multi-word entries may wrap across pool lines, so the
    final match runs on the JOINED pool text.

    Returns (pool_lines, matched_texts, pool_text) or (None, set(), "")."""
    scored = []
    for l in lines:
        matched, leftovers, consumed = match_line(l["text"], answer_texts)
        density = consumed / max(1, len(norm(l["text"])))
        scored.append({"line": l, "matched": matched, "density": density})
    pool_rows = [s for s in scored if s["matched"] and
                 (len(s["matched"]) >= 2 or s["density"] >= LINE_DENSITY)]
    if not pool_rows:
        return None, set(), ""
    # Group rows separated by small vertical gaps; pick the group
    # covering the most distinct answers.
    pool_rows.sort(key=lambda s: s["line"]["bbox"][1])
    groups, cur = [], [pool_rows[0]]
    for s in pool_rows[1:]:
        if s["line"]["bbox"][1] - cur[-1]["line"]["bbox"][3] <= LINE_JOIN_GAP:
            cur.append(s)
        else:
            groups.append(cur)
            cur = [s]
    groups.append(cur)
    best = max(groups, key=lambda g: len(set().union(*(s["matched"] for s in g))))
    chosen = [s["line"] for s in best]

    # Wrap expansion: a neighbouring line joins the pool when matching
    # against the joined text consumes most of its characters (the rest
    # of a wrapped entry, or distractor-only rows).
    rest = [l for l in lines if l not in chosen]
    changed = True
    while changed:
        changed = False
        py0 = min(l["bbox"][1] for l in chosen)
        py1 = max(l["bbox"][3] for l in chosen)
        px0 = min(l["bbox"][0] for l in chosen)
        px1 = max(l["bbox"][2] for l in chosen)
        c0 = match_line(_joined(chosen), answer_texts)[2]
        for l in rest:
            if l["bbox"][1] - py1 > LINE_JOIN_GAP or \
                    py0 - l["bbox"][3] > LINE_JOIN_GAP:
                continue
            cx = (l["bbox"][0] + l["bbox"][2]) / 2
            if not (px0 - 60 <= cx <= px1 + 60):
                continue
            c1 = match_line(_joined(chosen + [l]), answer_texts)[2]
            if c1 - c0 >= LINE_DENSITY * len(norm(l["text"])):
                chosen.append(l)
                rest.remove(l)
                changed = True
                break
    pool_text = _joined(chosen)
    matched = match_line(pool_text, answer_texts)[0]
    return chosen, matched, pool_text


def detect_dragdrop_exercises(po, pa, bands_override=None):
    """Returns a list of exercises:
    {band, header, zones: [{rect, text, snap}], words, pool_rect}

    Pool-centric: a band that prints the answers (the word pool) OWNS
    the exercise; it claims every blank on the page whose written
    answer is one of its pool words. Bands and blanks rarely align —
    item numbers get promoted to band headers and slice one exercise
    into many bands, so membership is by ANSWER TEXT, not geometry."""
    answers = diff_answer_spans(po, pa)
    answers = [a for a in answers if not a["is_checkmark"]]
    if len(answers) < MIN_ZONES:
        return []
    blanks = find_blank_lines(po)
    obstacles = [s["bbox"] for s in get_spans(po)] + blanks
    clickables = [c for c in build_clickables(answers, blanks,
                                              find_tick_boxes(po), obstacles)
                  if not c["answer"]["is_checkmark"]]
    bands = bands_override if bands_override else find_exercise_bands(po)
    if not bands:
        bands = [{"rect": (0.0, 0.0, po.rect.width, po.rect.height),
                  "header": None}]

    # Pool keys repeat the answers verbatim; bare numbers, percentages
    # and single letters collide with numbering/tables — never keys.
    texts_all = {norm(c["answer"]["text"]) for c in clickables}
    texts_all = {t for t in texts_all
                 if len(t) > 1 and any(ch.isalpha() for ch in t)}
    if len(texts_all) < MIN_ZONES:
        return []

    # One pool per band, page-wide keys; sentence rows die on density.
    pools = []
    for b in bands:
        lines = band_lines(po, b["rect"])
        rows, matched, pool_text = find_pool(lines, texts_all)
        if not rows or len(matched) < MIN_ZONES:
            continue
        density = match_line(pool_text, matched)[2] / max(1, len(norm(pool_text)))
        if density < POOL_DENSITY:
            continue
        pb = [l["bbox"] for l in rows]
        pool_rect = (min(r[0] for r in pb), min(r[1] for r in pb),
                     max(r[2] for r in pb), max(r[3] for r in pb))
        pools.append({"band": b, "lines": lines, "rows": rows,
                      "matched": matched, "pool_text": pool_text,
                      "pool_rect": pool_rect})

    # Chip pass: pool chips may stack a multi-word entry vertically
    # ("middle" over "aged"), which row-major reading tears apart.
    # Re-read the pool region column-major (x-overlap clusters, top to
    # bottom) and keep whichever reading matches more answers.
    spans = get_spans(po)
    for p in pools:
        px0, py0, px1, py1 = p["pool_rect"]
        region = [s for s in spans
                  if px0 - 60 <= (s["bbox"][0] + s["bbox"][2]) / 2 <= px1 + 60
                  and py0 - 14 <= s["bbox"][1] <= py1 + 26]
        cols = []
        for s in sorted(region, key=lambda s: s["bbox"][0]):
            host = next((c for c in cols
                         if min(s["bbox"][2], c["x1"]) - max(s["bbox"][0], c["x0"])
                         > 0.5 * (s["bbox"][2] - s["bbox"][0])), None)
            if host:
                host["spans"].append(s)
                host["x0"] = min(host["x0"], s["bbox"][0])
                host["x1"] = max(host["x1"], s["bbox"][2])
            else:
                cols.append({"x0": s["bbox"][0], "x1": s["bbox"][2],
                             "spans": [s]})
        seen, parts = set(), []
        for c in cols:
            for s in sorted(c["spans"], key=lambda s: s["bbox"][1]):
                k = (s["text"], int(s["bbox"][0] / 3), int(s["bbox"][1] / 3))
                if k not in seen:
                    seen.add(k)
                    parts.append(s["text"].strip())
        col_text = " ".join(parts)
        m2 = match_line(col_text, texts_all)[0]
        if len(m2) > len(p["matched"]):
            used = [s["bbox"] for s in region]
            p["matched"] = p["matched"] | m2
            p["pool_text"] = col_text
            p["pool_rect"] = (min(px0, min(b[0] for b in used)), py0,
                              max(px1, max(b[2] for b in used)),
                              max(py1, max(b[3] for b in used)))

    out, claimed = [], set()
    for p in sorted(pools, key=lambda p: (p["band"]["rect"][1],
                                          p["band"]["rect"][0])):
        bx0, by0, bx1, by1 = p["band"]["rect"]
        ex_zones = []
        for c in clickables:
            if id(c) in claimed:
                continue
            t = norm(c["answer"]["text"])
            if t not in p["matched"]:
                continue
            cx = (c["rect"][0] + c["rect"][2]) / 2
            cy = (c["rect"][1] + c["rect"][3]) / 2
            # The exercise flows downward from its header/pool band and
            # stays in the same column.
            if cy < by0 - 2 or not (bx0 - 4 <= cx < bx1 + 4):
                continue
            # Two pools may share a word (sports in ex.3 AND ex.4): a
            # contested blank sitting below a LOWER pool's printed
            # words belongs to that pool, not to one further up.
            if any(q is not p and t in q["matched"]
                   and q["pool_rect"][1] > p["pool_rect"][1]
                   and cy > q["pool_rect"][1]
                   for q in pools):
                continue
            ex_zones.append(c)
        if len(ex_zones) < MIN_ZONES:
            continue
        # A real pool has about one word per blank plus a few
        # distractors; word lists / reading texts have far more.
        words = ordered_entries(p["pool_text"], p["matched"])
        if len(words) > len(ex_zones) + max(3, len(ex_zones) // 2):
            continue
        claimed.update(id(c) for c in ex_zones)
        pool_rect = p["pool_rect"]
        # The crop runs from the band top (header) to a little under
        # the lowest piece of the exercise (pool or last claimed blank).
        zy1 = max([c["rect"][3] for c in ex_zones] + [pool_rect[3]])
        band_rect = (bx0, by0, bx1, max(min(by1, zy1 + 16), zy1 + 6))
        out.append({
            "band": band_rect,
            "header": p["band"]["header"],
            "header_text": header_text(p["lines"], p["band"]["header"],
                                       p["rows"]),
            "zones": sorted(ex_zones,
                            key=lambda c: (c["rect"][1], c["rect"][0])),
            "words": words,
            "pool_rect": pool_rect,
        })
    return out


def ordered_entries(text, answer_texts):
    """Pool entries in reading order, original casing kept: known
    answers are matched as phrases, anything left over splits into
    single words (distractors)."""
    raw = " " + re.sub(r"\s+", " ", text).strip() + " "
    # Length-preserving lowercase keeps raw/low offsets aligned
    # (Turkish dotted İ lowercases to two code points).
    low = "".join(c.lower() if len(c.lower()) == 1 else c for c in raw)
    marks = []
    for a in sorted(answer_texts, key=len, reverse=True):
        pat = re.compile(_pat(a))
        while True:
            m = pat.search(low)
            if not m:
                break
            marks.append((m.start(), raw[m.start():m.end()]))
            low = low[:m.start()] + "\0" * (m.end() - m.start()) + low[m.end():]
    for seg in re.finditer(r"[^\0]+", low):
        for t in SEP_RE.split(raw[seg.start():seg.end()]):
            if norm(t):
                for w in t.split():
                    if norm(w):
                        marks.append((seg.start(), w.strip(".,;:!?•·")))
    words, seen = [], set()
    for _, a in sorted(marks, key=lambda m: m[0]):
        if a and norm(a) not in seen:
            seen.add(norm(a))
            words.append(a)
    return words


def header_text(lines, header, pool_rows=None):
    """The instruction the band starts with: the header row plus its
    wrapped continuation lines (never the pool), halo echoes dropped."""
    if header is None:
        return ""
    pool_ids = {id(l) for l in (pool_rows or [])}
    hy0 = header["bbox"][1]
    row = [l for l in lines if abs(l["bbox"][1] - hy0) < 4
           and id(l) not in pool_ids]
    if not row:
        return header["text"].strip()
    row_x0 = min(l["bbox"][0] for l in row)
    row_y1 = max(l["bbox"][3] for l in row)
    cont = [l for l in lines
            if id(l) not in pool_ids
            and -4 < l["bbox"][1] - row_y1 < 14
            and abs(l["bbox"][0] - row_x0) < 60
            and not HEADER_CONT_SKIP.match(l["text"])]
    parts, seen = [], set()
    for l in row + cont:
        t = re.sub(r"\s+", " ", l["text"]).strip()
        if t and t not in seen:
            seen.add(t)
            parts.append(t)
    text = " ".join(parts)
    # Offset halo twins echo words ("the correct correct words. words.")
    # and the leading number ("5. 5. ..."); collapse adjacent repeats.
    text = re.sub(r"^(\d{1,2}\.)( \1)+", r"\1", text)
    return re.sub(r"\b(\S+)( \1)+\b", r"\1", text).strip()


HEADER_CONT_SKIP = re.compile(r"^\d{1,2}[.)]\s")   # numbered item rows


def group_zones(zones):
    """Cluster drop zones into column groups (categorize-into-boxes):
    zones whose x ranges overlap stack into one column."""
    cols = []
    for z in sorted(zones, key=lambda z: z["rect"][0]):
        r = z["rect"]
        host = None
        for c in cols:
            ov = min(r[2], c["x1"]) - max(r[0], c["x0"])
            if ov > 0.5 * min(r[2] - r[0], c["x1"] - c["x0"]):
                host = c
                break
        if host:
            host["zones"].append(z)
            host["x0"] = min(host["x0"], r[0])
            host["x1"] = max(host["x1"], r[2])
        else:
            cols.append({"x0": r[0], "x1": r[2], "zones": [z]})
    return [c["zones"] for c in cols]


def build_dragdrop_sections(po, pa, page_num, images_dir, prefix, sx, sy,
                            start_idx=1, group_mode=False):
    """Emit editor-format dragdroppicture sections (and crop images).
    Returns (sections, consumed_rects) — the zone rects (PDF points)
    this activity owns, so the fill pipeline can drop those answers."""
    sections, consumed = [], []
    occupied = [s["bbox"] for s in get_spans(po)]
    for k, ex in enumerate(detect_dragdrop_exercises(po, pa)):
        fname = f"p{page_num}s{start_idx + k}.png"
        opts = [{"bbox": z["rect"]} for z in ex["zones"]]
        rect, scale = crop_band(po, ex["band"], opts,
                                os.path.join(images_dir, fname))
        groups = group_zones(ex["zones"]) if group_mode else None
        # The drop validates against the dragged chip, so the answer
        # text must be the POOL's spelling of the word ("middle aged"
        # chip vs a handwritten "middle-aged": hyphen-insensitive key).
        nkey = lambda s: re.sub(r"[-\s]+", " ", norm(s))
        by_norm = {nkey(w): w for w in ex["words"]}
        answers = []
        for z in ex["zones"]:
            r = z["rect"]
            t = z["answer"]["text"].strip()
            entry = {
                "coords": {
                    "x": int((r[0] - rect.x0) * scale),
                    "y": int((r[1] - rect.y0) * scale),
                    "w": int((r[2] - r[0]) * scale),
                    "h": int((r[3] - r[1]) * scale),
                },
                "opacity": 1,
            }
            if group_mode:
                col = next(g for g in groups if z in g)
                entry["group"] = [by_norm.get(nkey(c["answer"]["text"]),
                                              c["answer"]["text"].strip())
                                  for c in col]
            else:
                entry["text"] = by_norm.get(nkey(t), t)
            if z["snap"] == "none":
                entry["needs_review"] = True
            answers.append(entry)
            consumed.append(tuple(r))
        # Ship the draggable word pool shuffled — its order must not reveal the
        # answer sequence. (The editor's C++ save reshuffles too.)
        shuffled_words = list(ex["words"])
        random.shuffle(shuffled_words)
        sections.append({
            "activity": {
                "type": "dragdroppicturegroup" if group_mode
                        else "dragdroppicture",
                "answer": answers,
                "words": shuffled_words,
                "circleCount": 0,
                "markCount": 0,
                "coords": place_button(ex["header"], occupied,
                                       po.rect.width, sx, sy),
                "headerText": ex["header_text"],
                "section_path": f"{prefix}{fname}",
                "image_coords": image_coords_from_rect(rect, sx, sy),
            },
            "audio_extra": {},
        })
    return sections, consumed


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
        exercises = detect_dragdrop_exercises(po, pa)
        print(f"page {pno}: {len(exercises)} dragdrop exercise(s)")

        zoom = 2.0
        pix = po.get_pixmap(matrix=fitz.Matrix(zoom, zoom))
        img = Image.frombytes("RGB", (pix.width, pix.height), pix.samples)
        drw = ImageDraw.Draw(img)
        for ex in exercises:
            x0, y0, x1, y1 = ex["band"]
            print(f"  band ({x0:.0f},{y0:.0f})..({x1:.0f},{y1:.0f}): "
                  f"{len(ex['zones'])} zones")
            print(f"    header: {ex['header_text'][:70]}")
            print(f"    words:  {ex['words']}")
            print(f"    zones:  {[norm(z['answer']['text']) for z in ex['zones']]}")
            drw.rectangle([x0 * zoom + 4, y0 * zoom, x1 * zoom - 4, y1 * zoom - 4],
                          outline=(160, 0, 200), width=3)
            drw.rectangle([v * zoom for v in ex["pool_rect"]],
                          outline=(0, 160, 60), width=3)
            for z in ex["zones"]:
                color = (240, 180, 0) if z["snap"] != "none" else (255, 0, 0)
                drw.rectangle([v * zoom for v in z["rect"]],
                              outline=color, width=3)
        img.save(os.path.join(out_dir, f"page_{pno:03d}_dragdrop.png"))
    orig.close(); ans.close()


if __name__ == "__main__":
    main()
