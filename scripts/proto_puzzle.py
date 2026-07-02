"""Prototype step 9: puzzleFindWords (word-search grids).

The section carries only words[] + headerText (no coords, no crop —
the app renders its own grid), so detection is:

  1. GRID: a matrix of single-letter spans with regular row/column
     pitch (>=4x4). Some publishers print the full grid in the
     original; others leave it empty and the KEY writes the letters —
     so the grid is read from whichever page has more grid letters.
  2. WORD CANDIDATES, two independent sources:
     a. printed tokens near the grid: uppercase words (also joined
        pairs for "RECYCLE BIN") — picture labels / word lists;
     b. elongated drawings the key drew OVER the grid (rings around
        found words) — the letters they cover, read along the axis.
  3. VALIDATION: a candidate counts only if it can actually be found
     in the grid (8-direction search) — self-validating, no dictionary.

Debug:
  python3 proto_puzzle.py <original.pdf> <answered.pdf> <page> [...]
"""

import os
import re
import sys

import fitz

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from proto_inventory import diff_answer_drawings, get_spans, page_words
from proto_circle import place_button

MIN_ROWS = 4
MIN_COLS = 4
ROW_TOL = 4.0              # letters on one grid row: y0 within this
MIN_WORD = 3


def find_letter_grid(page):
    """Locate a regular matrix of single letters.

    Returns {"bbox", "rows": [[(char, x, y), ...] per row]} or None."""
    letters = []
    for s in get_spans(page):
        t = s["text"].strip()
        if len(t) == 1 and t.isalpha():
            b = s["bbox"]
            letters.append((t.upper(), (b[0] + b[2]) / 2, (b[1] + b[3]) / 2,
                            b))
    if len(letters) < MIN_ROWS * MIN_COLS:
        return None
    # Rows: cluster by y.
    rows = []
    for ch, x, y, b in sorted(letters, key=lambda l: (l[2], l[1])):
        if rows and abs(y - rows[-1][-1][2]) <= ROW_TOL:
            rows[-1].append((ch, x, y, b))
        else:
            rows.append([(ch, x, y, b)])
    rows = [sorted(r, key=lambda l: l[1]) for r in rows if len(r) >= MIN_COLS]
    if len(rows) < MIN_ROWS:
        return None
    # The grid is the largest run of consecutive rows with similar
    # length and consistent vertical pitch.
    best, cur = [], [rows[0]]
    for prev, r in zip(rows, rows[1:]):
        pitch = r[0][2] - prev[0][2]
        if 4 <= pitch <= 40 and abs(len(r) - len(prev)) <= 2:
            cur.append(r)
        else:
            if len(cur) > len(best):
                best = cur
            cur = [r]
    if len(cur) > len(best):
        best = cur
    if len(best) < MIN_ROWS:
        return None
    xs = [l[1] for r in best for l in r]
    ys = [l[2] for r in best for l in r]
    bbox = (min(xs), min(ys), max(xs), max(ys))
    return {"bbox": bbox, "rows": best}


def grid_matrix(grid):
    """Snap letters to column slots so 8-direction search works on a
    rectangular matrix (missing cells become spaces)."""
    xs = sorted(l[1] for r in grid["rows"] for l in r)
    cols = []
    for x in xs:
        if not cols or x - cols[-1][-1] > 4:
            cols.append([x])
        else:
            cols[-1].append(x)
    centers = [sum(c) / len(c) for c in cols]
    mat = []
    for r in grid["rows"]:
        row = [" "] * len(centers)
        for ch, x, y, b in r:
            ci = min(range(len(centers)), key=lambda i: abs(centers[i] - x))
            row[ci] = ch
        mat.append(row)
    return mat


def word_in_grid(mat, word):
    """8-direction word search."""
    R, C = len(mat), len(mat[0]) if mat else 0
    w = word.upper()
    n = len(w)
    dirs = [(0, 1), (0, -1), (1, 0), (-1, 0), (1, 1), (1, -1), (-1, 1), (-1, -1)]
    for r in range(R):
        for c in range(C):
            if mat[r][c] != w[0]:
                continue
            for dr, dc in dirs:
                rr, cc = r + (n - 1) * dr, c + (n - 1) * dc
                if not (0 <= rr < R and 0 <= cc < C):
                    continue
                if all(mat[r + i * dr][c + i * dc] == w[i] for i in range(n)):
                    return True
    return False


def printed_candidates(page, grid_bbox):
    """Uppercase printed words outside the grid (picture labels, word
    lists); adjacent pairs join for multi-word entries."""
    gx0, gy0, gx1, gy1 = grid_bbox
    words = []
    for w in page_words(page):
        t = re.sub(r"[^\wÇĞİÖŞÜ-]", "", w[4])
        cx, cy = (w[0] + w[2]) / 2, (w[1] + w[3]) / 2
        inside = gx0 - 8 <= cx <= gx1 + 8 and gy0 - 8 <= cy <= gy1 + 8
        if (len(t) >= MIN_WORD and t.isalpha() and t == t.upper()
                and not inside):
            words.append({"text": t, "bbox": list(w[:4]),
                          "line": (w[5], w[6])})
    cands = []
    for i, w in enumerate(words):
        cands.append((w["text"], w["text"], w["bbox"][1], w["bbox"][0]))
        nxt = words[i + 1] if i + 1 < len(words) else None
        if nxt and nxt["line"] == w["line"] and \
                0 <= nxt["bbox"][0] - w["bbox"][2] <= 12:
            cands.append((w["text"] + " " + nxt["text"],
                          w["text"] + nxt["text"],
                          w["bbox"][1], w["bbox"][0]))
    return cands           # (display, search_key, y, x)


def marked_words(po, pa, grid, grid_page):
    """Letter sequences under elongated key drawings over the grid —
    the rings the key drew around found words.

    diff_answer_drawings bboxes are mapped into ORIGINAL page space by the
    registration layer. When the grid letters are read from the ANSWERED
    page (key filled an empty original grid), lift the rings into answered
    space by the page offset, or on a shifted book the ±2pt letter hit test
    misses (Rise Up: constant -8.5pt) and words garble."""
    gx0, gy0, gx1, gy1 = grid["bbox"]
    letters = [l for r in grid["rows"] for l in r]
    dx = dy = 0.0
    if grid_page is pa:
        from proto_inventory import page_offset
        off = page_offset(po, pa)
        dx, dy = off["dx"], off["dy"]
    out = []
    for d in diff_answer_drawings(po, pa):
        x0, y0, x1, y1 = d["bbox"]
        x0 += dx; x1 += dx; y0 += dy; y1 += dy
        if x1 < gx0 - 10 or x0 > gx1 + 10 or y1 < gy0 - 10 or y0 > gy1 + 10:
            continue
        w, h = x1 - x0, y1 - y0
        if max(w, h) < 25 or max(w, h) / max(min(w, h), 1) < 1.8:
            continue   # not an elongated word mark
        hits = [l for l in letters
                if x0 - 2 <= l[1] <= x1 + 2 and y0 - 2 <= l[2] <= y1 + 2]
        if len(hits) < MIN_WORD:
            continue
        hits.sort(key=lambda l: (l[1], l[2]) if w >= h else (l[2], l[1]))
        out.append("".join(l[0] for l in hits))
    return out


def detect_puzzle(po, pa):
    """Returns {words, grid_bbox, header} or None."""
    grid = find_letter_grid(po)
    src = po
    g2 = find_letter_grid(pa)
    if g2 and (not grid or len(g2["rows"]) * len(g2["rows"][0]) >
               len(grid["rows"]) * len(grid["rows"][0])):
        grid, src = g2, pa   # key fills an empty grid: read answered
    if not grid:
        return None
    mat = grid_matrix(grid)

    found, seen = [], set()
    for disp, key, y, x in sorted(printed_candidates(po, grid["bbox"]),
                                  key=lambda c: (c[2], c[3])):
        if key in seen or len(key) < MIN_WORD:
            continue
        if word_in_grid(mat, key):
            seen.add(key)
            # A joined pair supersedes its first half ("RECYCLE BIN"
            # vs "RECYCLE") only when both match; keep both entries —
            # the human list does too.
            found.append(disp)
    for w in marked_words(po, pa, grid, src):
        if w not in seen and word_in_grid(mat, w):
            seen.add(w)
            found.append(w)
    if len(found) < 2:
        return None
    # Header: the instruction line mentioning the puzzle, else None.
    header = None
    for s in get_spans(po):
        if re.search(r"\bfind\b.{0,40}\b(word|puzzle)", s["text"], re.I) or \
                re.search(r"\bpuzzle\b", s["text"], re.I):
            header = s
            break
    return {"words": found, "grid_bbox": grid["bbox"], "header": header}


def build_puzzle_sections(po, pa, page_num, sx, sy):
    """Editor-format puzzleFindWords sections (no crop, no answer)."""
    res = detect_puzzle(po, pa)
    if not res:
        return []
    occupied = [s["bbox"] for s in get_spans(po)]
    return [{
        "activity": {
            "type": "puzzleFindWords",
            "words": res["words"],
            "circleCount": 0,
            "markCount": 0,
            "coords": place_button(res["header"], occupied,
                                   po.rect.width, sx, sy),
            "headerText": (res["header"]["text"].strip()
                           if res["header"] else ""),
        },
        "audio_extra": {},
    }]


def main():
    if len(sys.argv) < 4:
        print(__doc__)
        sys.exit(1)
    orig, ans = fitz.open(sys.argv[1]), fitz.open(sys.argv[2])
    for pno in (int(p) for p in sys.argv[3:]):
        res = detect_puzzle(orig[pno - 1], ans[pno - 1])
        if res:
            print(f"page {pno}: grid={[round(v) for v in res['grid_bbox']]} "
                  f"words={res['words']}")
        else:
            print(f"page {pno}: puzzle yok")


if __name__ == "__main__":
    main()
