"""Reading a passage off the page: the words, and the gaps between them.

Split out of align_audio so it can be used without the aligner. Importing
align_audio imports whisperx, which imports torch — seconds of start-up and a
few hundred megabytes — and the editor now wants the words of a crop the moment
it is drawn, before anything is aligned. This module needs only PyMuPDF.
"""
import os
import re
import json
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from _bootstrap import ensure_runtime_deps
ensure_runtime_deps()   # fitz

import fitz

from book_files import find_original_pdf   # one rule, shared (see book_files)


_NORM = re.compile(r"[^a-z0-9']")
# Fold typographic apostrophes/quotes to ASCII so PDF text ("I’m" with U+2019)
# matches ASR output ("I'm") — otherwise contractions never line up.
_APOS = str.maketrans({"’": "'", "‘": "'", "ʼ": "'",
                       "′": "'", "´": "'", "`": "'"})
norm = lambda s: _NORM.sub("", s.lower().translate(_APOS))

# A token is "spoken" — alignable as written — only if it contains at least one
# letter. Fill-in-the-blank (cloze) passages also carry gap runs ("________",
# "……………") and bare question numbers ("1", "2") that are never read aloud.
# The three kinds are treated differently:
#   - blank runs are kept + flagged, so the box lights up while the unwritten
#     answer is spoken. Nobody wrote that answer down, so there is no text to
#     align: they are HELD OUT and timed from the ASR gap (time_held_out).
#   - digit tokens ("1874", "20") are kept too — a narrative passage reads them
#     aloud ("She was born on November 30, 1874"), and dropping them left a hole
#     in the highlight. They are spelled out the way they are spoken before the
#     forced pass (say_number), so they get real timings rather than a share of
#     a gap. Only tokens that really are question/enumeration numbers are
#     dropped (see _is_enum_number).
_HAS_LETTER = re.compile(r"[a-z]")
def _is_spoken(text):
    return bool(_HAS_LETTER.search(text.lower().translate(_APOS)))

# A cloze gap is not always an underscore run. Exercise pages just as often draw
# it with dots — "The children lived in …………….." — and those tokens carry no
# letters, so they used to fall through to the punctuation branch and be dropped
# outright: the gap disappeared from the passage and the highlight jumped over
# the spoken answer instead of resting on it. Two or more gap characters and
# nothing else; a lone "…" is ordinary narrative punctuation and stays dropped.
_GAP_RUN = re.compile(r"^[_.…․‥]{2,}$")
def _is_gap(text):
    return "__" in text or bool(_GAP_RUN.match(text.strip()))

# A digit token: no letters, but a normalized form that is all digits ("30,",
# "1874," -> "30", "1874"). Superscript cloze markers ("⁵") normalize to "" and
# so are not numbers — they are dropped like punctuation.
def _is_number(text):
    n = norm(text)
    return bool(n) and n.isdigit()

# Enumeration/question markers to drop. Two shapes cover what books actually do.
# This is the one decidable from the token alone: a short number opening a line
# at a sentence boundary — an exercise number ("1 Complete the paragraph…"), a
# page number, a section number. The sentence-boundary test is what keeps a
# wrapped narrative numeral ("…published 20 / novels"), whose previous token does
# not end a sentence, from being mistaken for a marker. 3+ digits are never
# markers (years). The other shape — the number labelling a cloze gap — needs
# lookahead and is handled at the end of words_in_crop.
_ENUM = re.compile(r"^\(?\d{1,2}[.)]?$")
def _ends_sentence(text):
    return bool(text) and text[-1] in ".!?:;"

def _is_enum_number(text, line_first, prev_text):
    return bool(line_first and _ENUM.match(text)
                and (prev_text is None or _ends_sentence(prev_text)))


# ----- Saying numbers out loud ------------------------------------------------
# The character-level aligner reads letters; "1828" has no spelling it can match,
# so numerals used to be pulled out of the forced pass and timed from the gap
# between their neighbours instead. That gap is split evenly, which is wrong
# whenever one gap holds numerals of very different spoken length: on
# "born on February 8, 1828," the year — nearly a second of speech — came out
# 0.09s long and the highlight flicked past it, while "8," opened before
# "February" had finished. Writing the number the way the narrator says it puts
# it back through forced alignment, where it earns its own timing like any word.
#
# Hand-rolled rather than pulled from num2words: this is a few dozen lines, and
# a new pip dependency would have to be installed on every authoring machine and
# bundled into the Windows deploy.
_ONES = ["zero", "one", "two", "three", "four", "five", "six", "seven", "eight",
         "nine", "ten", "eleven", "twelve", "thirteen", "fourteen", "fifteen",
         "sixteen", "seventeen", "eighteen", "nineteen"]
_TENS = ["", "", "twenty", "thirty", "forty", "fifty", "sixty", "seventy",
         "eighty", "ninety"]
_ORDINAL = {"one": "first", "two": "second", "three": "third", "five": "fifth",
            "eight": "eighth", "nine": "ninth", "twelve": "twelfth"}
_MONTHS = {"january", "february", "march", "april", "may", "june", "july",
           "august", "september", "october", "november", "december"}


def _cardinal(n):
    """1828 -> [one, thousand, eight, hundred, twenty, eight]"""
    if n < 20:
        return [_ONES[n]]
    if n < 100:
        t = _TENS[n // 10]
        return [t] if n % 10 == 0 else [t, _ONES[n % 10]]
    for div, name in ((1000000000, "billion"), (1000000, "million"),
                      (1000, "thousand"), (100, "hundred")):
        if n >= div:
            out = _cardinal(n // div) + [name]
            return out + (_cardinal(n % div) if n % div else [])
    return [_ONES[0]]


def _year(n):
    """Years are read in pairs, not as cardinals: 1828 is "eighteen twenty
    eight", not "one thousand eight hundred twenty eight"."""
    if 2000 <= n <= 2009:          # "two thousand five", not "twenty oh five"
        return _cardinal(n)
    hi, lo = divmod(n, 100)
    if lo == 0:
        return _cardinal(hi) + ["hundred"]      # 1900 -> nineteen hundred
    if lo < 10:
        return _cardinal(hi) + ["oh", _ONES[lo]]  # 1905 -> nineteen oh five
    return _cardinal(hi) + _cardinal(lo)


def _ordinal(n):
    """24 -> [twenty, fourth]. Only the last word inflects."""
    ws = _cardinal(n)
    last = ws[-1]
    if last in _ORDINAL:
        ws[-1] = _ORDINAL[last]
    elif last.endswith("y"):
        ws[-1] = last[:-1] + "ieth"             # twenty -> twentieth
    else:
        ws[-1] = last + "th"
    return ws


def say_number(text, prev_text=None):
    """How a narrator reads this numeral, as alignable tokens ([] if we can't
    tell). prev_text supplies the one piece of context that changes the reading:
    a day-of-month after a month name is spoken as an ordinal ("February 8" is
    "February eighth", never "February eight")."""
    n = norm(text)
    if not n.isdigit():
        return []
    v = int(n)
    if prev_text and norm(prev_text) in _MONTHS and 1 <= v <= 31:
        return _ordinal(v)
    # Four digits in this range are years in these books ("in 1836.", "March 24,
    # 1905."); a bare 20,000 is not, and reads as a plain cardinal.
    if 1100 <= v <= 2099:
        return _year(v)
    if v >= 1000000000000:
        return []                                # beyond what _cardinal covers
    return _cardinal(v)

# ----- Cloze gaps, located by the answer boxes rather than by the text --------
# A gap used to be found by what it looks like in the text layer, and books draw
# it every possible way: a run of underscores, a run of dots, and — the one that
# started this — underscores with spaces between them ("(1) _ _ _ _ _ _ _"),
# which arrive as seven separate one-character tokens and were thrown away as
# punctuation. Each new book brought a new shape, and missing the gap costs
# twice: the highlight skips the spoken answer, and the "(1)" labelling the gap
# survives as a numeral, so the aligner is handed a word nobody says.
#
# The author has already told us where every gap is, by drawing the fill box
# that reveals the answer. That is authored data, not a guess about typography,
# and it carries the answer text as well as the position. Reading gaps from it
# is format-proof by construction.


def fills_for_page(book_dir, page_idx):
    """Answer boxes the author drew on this page: [{x, y, w, h, text}] in page
    image pixels — the same space words_in_crop reports word boxes in. Empty
    when there is no config, no such page, or no fills on it."""
    path = os.path.join(book_dir, "config.json")
    if not os.path.exists(path):
        return []
    try:
        with open(path, encoding="utf-8") as f:
            cfg = json.load(f)
    except Exception:
        return []
    want = page_idx + 1            # config numbers pages from 1
    out, stack = [], [cfg]
    while stack:
        node = stack.pop()
        if isinstance(node, dict):
            if (node.get("page_number") == want
                    and isinstance(node.get("sections"), list)):
                for sec in node["sections"]:
                    if sec.get("type") != "fill":
                        continue
                    for a in (sec.get("answer") or []):
                        c = a.get("coords") or {}
                        t = str(a.get("text") or "").strip()
                        if t and all(k in c for k in ("x", "y", "w", "h")):
                            out.append({"x": c["x"], "y": c["y"], "w": c["w"],
                                        "h": c["h"], "text": t})
            stack.extend(node.values())
        elif isinstance(node, list):
            stack.extend(node)
    return out


def _reading_position(words, f):
    """Where this box falls in the passage's reading order.

    The words are already in reading order, so walk them and stop at the first
    one that comes after the box: further right on the same line, or on a line
    below it. Same line is decided on vertical centres, which survives the
    difference in height between a word and a drawn answer box."""
    fcy = f["y"] + f["h"] / 2.0
    for i, w in enumerate(words):
        b = w["bbox"]
        wcy = b["y"] + b["h"] / 2.0
        same_line = abs(wcy - fcy) < 0.6 * max(b["h"], f["h"])
        if same_line:
            if b["x"] > f["x"]:
                return i
        elif wcy > fcy:
            return i
    return len(words)


def _box_overlap(a, b):
    """Intersection as a fraction of the smaller box."""
    ix = max(0, min(a["x"] + a["w"], b["x"] + b["w"]) - max(a["x"], b["x"]))
    iy = max(0, min(a["y"] + a["h"], b["y"] + b["h"]) - max(a["y"], b["y"]))
    small = min(a["w"] * a["h"], b["w"] * b["h"]) or 1
    return (ix * iy) / small


def _insert_fill_blanks(out, fills, rect_px):
    """Put a blank in the passage wherever the author drew an answer box.

    Only boxes whose centre is inside the crop count, which is what keeps a word
    bank or a column of ✓/✗ marks elsewhere on the page from being mistaken for
    gaps in this passage — on the page that prompted this, that filter picks the
    right 8 of the page's 26 boxes with nothing else to tune.

    A box that lands on a gap the text layer already found upgrades it in place
    — it gains the answer and the exact box — rather than adding a second blank
    over the same gap.

    Boxes are only allowed to CREATE blanks when the text layer found no gaps at
    all in this crop. Being inside the crop does not make a box part of the
    passage: a broad crop can take in a neighbouring exercise, and on two
    MyEnglishPath pages it does — a dozen answer boxes sitting on their own
    lines, nothing to do with the underscored sentences above them. Geometry
    cannot reliably tell those apart, but it does not have to. Where the text
    layer shows the gaps it already knows how many there are, so boxes there only
    annotate; where it shows none, as in the book that prompted this, they are
    the only evidence and are trusted completely. The rule cannot inflate the
    count of a passage that already worked."""
    cx0, cy0, cw, ch = rect_px
    cx1, cy1 = cx0 + cw, cy0 + ch
    inside = [f for f in fills
              if cx0 <= f["x"] + f["w"] / 2.0 <= cx1
              and cy0 <= f["y"] + f["h"] / 2.0 <= cy1]
    may_create = not any(w.get("blank") for w in out)
    claimed = set()
    added = merged = 0
    for f in sorted(inside, key=lambda f: (f["y"], f["x"])):
        box = {"x": round(f["x"]), "y": round(f["y"]),
               "w": round(f["w"]), "h": round(f["h"])}
        hit = next((w for w in out
                    if w.get("blank") and id(w) not in claimed
                    and _box_overlap(w["bbox"], box) > 0.5), None)
        if hit is not None:
            claimed.add(id(hit))
            hit["answer"] = f["text"]
            hit["fill"] = dict(box)
            hit["bbox"] = dict(box)
            merged += 1
            continue
        if not may_create:
            continue
        w = {
            "text": "______",       # what the page shows; `answer` is what is said
            "bbox": dict(box),
            "blank": True,
            "answer": f["text"],
            "fill": dict(box),      # already linked: no matching pass needed
        }
        out.insert(_reading_position(out, f), w)
        claimed.add(id(w))
        added += 1
    return added, merged


# Highlight box vertical extent, as fractions of the font size measured from
# the text baseline. fitz word rects span the font's full ascender→descender
# (the ascender is often ~0.9·size, well above the actual caps at ~0.70·size),
# so drawing them raw makes the highlight sit noticeably high and miss the
# bottom of the glyphs. Anchoring on the real baseline + font size instead hugs
# the word identically in every font and size (validated on a script and a sans
# book). x stays glyph-tight (from the character boxes), which was already good.
_HL_CAP = 0.78     # top above caps/ascenders (cap height ≈ 0.70)
_HL_DESC = 0.25    # bottom below the baseline to cover descenders (g, y, p)


def words_in_crop(pdf_path, page_idx, rect_px, png_w, png_h, fills=None):
    """Words whose center falls inside the crop rect, in reading order.

    Returns [{text, bbox:{x,y,w,h}}] with bbox in PNG pixel space. The box is
    baseline-anchored (see _HL_CAP/_HL_DESC) so the karaoke highlight hugs the
    word rather than floating above it.

    `fills` are the answer boxes the author drew on this page (fills_for_page).
    Each one inside the crop becomes a blank at its place in the reading order,
    carrying the answer — which is how a gap is found regardless of how the book
    happens to draw it.
    """
    doc = fitz.open(pdf_path)
    if page_idx < 0 or page_idx >= len(doc):
        doc.close()
        raise IndexError(f"Page index {page_idx} out of range (0-{len(doc)-1})")
    page = doc.load_page(page_idx)
    sx, sy = png_w / page.rect.width, png_h / page.rect.height
    cx0, cy0, cw, ch = rect_px
    cx1, cy1 = cx0 + cw, cy0 + ch
    out = []
    # Some source PDFs stack the same text layer multiple times (invisible
    # duplicate words at identical coordinates). Left unchecked that inflates
    # the passage with repeats and wrecks forced alignment (every word matches
    # several audio positions). Drop a word if one with the same text AND a
    # near-identical position was already kept; genuine repeats sit at distinct
    # positions (different line/column) and survive.
    seen = set()
    # Position context for classifying digit tokens (see _is_enum_number):
    # whether this is the line's first token, and the token that preceded it.
    line_first = True
    prev_text = None

    def emit(run, size):
        nonlocal line_first, prev_text
        if not run:
            return
        text = "".join(c["c"] for c in run)
        was_first, was_prev = line_first, prev_text
        line_first, prev_text = False, text
        # Classify the token. Spoken words (have a letter) align normally. Blank
        # lines ("______") and numbers are kept but flagged: they're held OUT of
        # the forced align (a blank has no phonemes, a numeral no reliable one, so
        # aligning them makes them swallow multi-second bogus time and desyncs
        # everything) and timed from the ASR gap instead, so their box lights up
        # while the answer / the number is spoken (see time_held_out + _is_spoken).
        # Question and page numbers are dropped, as is bare punctuation.
        kind = None
        if _is_spoken(text):
            kind = "word"
        elif _is_gap(text):
            kind = "blank"
        elif _is_number(text) and not _is_enum_number(text, was_first, was_prev):
            kind = "num"
        else:
            return
        x0 = min(c["bbox"][0] for c in run) * sx
        x1 = max(c["bbox"][2] for c in run) * sx
        if size > 0:
            baseline = run[0]["origin"][1]
            y0 = (baseline - _HL_CAP * size) * sy
            y1 = (baseline + _HL_DESC * size) * sy
        else:  # size unavailable — fall back to the raw glyph-cell extent
            y0 = min(c["bbox"][1] for c in run) * sy
            y1 = max(c["bbox"][3] for c in run) * sy
        mx, my = (x0 + x1) / 2, (y0 + y1) / 2
        if not (cx0 <= mx <= cx1 and cy0 <= my <= cy1):
            return
        key = (text, round(x0 / 3), round(y0 / 3))  # ~3px position tolerance
        if key in seen:
            return
        seen.add(key)
        entry = {
            "text": text,
            "bbox": {"x": round(x0), "y": round(y0),
                     "w": round(x1 - x0), "h": round(y1 - y0)},
        }
        if kind == "blank":
            entry["blank"] = True
        elif kind == "num":
            entry["num"] = True
        out.append(entry)

    # rawdict yields blocks→lines→spans→chars; split each span into words on
    # whitespace. Each span carries the font size, and every char its baseline
    # origin, which is what the baseline-anchored box needs.
    # sort=True is essential: without it blocks come in content-stream order,
    # which is whatever order the layout tool wrote them and often has nothing
    # to do with the page. On DavidCopperfield p3 the title and first paragraph
    # are written LAST, so the passage handed to the aligner started at the
    # second paragraph and ended with "…CHARLES DICKENS" — the words were all
    # there but in an order the narration never follows, so forced alignment
    # scattered the highlights. Cropping a single paragraph hid the bug because
    # order only goes wrong *between* blocks.
    rd = page.get_text("rawdict", sort=True)
    for block in rd.get("blocks", []):
        for line in block.get("lines", []):
            line_first = True
            for span in line.get("spans", []):
                size = span.get("size", 0) or 0
                run = []
                prev_x1 = None
                for c in span.get("chars", []):
                    if c["c"].isspace():
                        emit(run, size)
                        run, prev_x1 = [], None
                        continue
                    # Some PDFs separate words by position with no space glyph;
                    # break on a wide gap too so a whole line doesn't collapse
                    # into one "word" (well above intra-word letter spacing).
                    x0c = c["bbox"][0]
                    if (prev_x1 is not None and size > 0
                            and x0c - prev_x1 > 0.3 * size):
                        emit(run, size)
                        run = []
                    run.append(c)
                    prev_x1 = c["bbox"][2]
                emit(run, size)
    doc.close()
    # Before the lookahead below, so a gap the text layer failed to show still
    # gets its "(1)" label dropped: the label is only recognised by what follows
    # it, and what follows it is now a blank whatever the typography did.
    if fills:
        _insert_fill_blanks(out, fills, rect_px)
    # Second pass for the one marker shape that needs lookahead: the number
    # labelling a cloze gap ("People will 1 ______ serious problems"). Test the
    # next token for an underscore run rather than for the "blank" flag — a
    # sloppy text layer can glue the gap to the word after it ("15 ____drawing"),
    # which classifies as a spoken word but still labels a gap. Iterating
    # backwards keeps the indices valid while deleting.
    for i in range(len(out) - 2, -1, -1):
        if out[i].get("num") and _is_gap(out[i + 1]["text"]):
            del out[i]
    return out


def words_in_crops(pdf_path, page_idx, rects_px, png_w, png_h, fills=None):
    """The passage as the author assembled it: each crop read in turn, in the
    order it was drawn, concatenated.

    Reading order BETWEEN separate pieces of a page cannot be inferred
    reliably. PyMuPDF's block sort orders by bottom edge, which reads two
    columns interleaved; a callout bridging the gutter defeats a column split
    as well; and a passage scattered around a picture defeats geometry
    altogether. On GOALS5 that put the right column before the left on four
    pages and the alignment scored 0.19–0.44 against 0.78–0.83 everywhere else.

    The author can see the page. The order they crop in IS the reading order, so
    nothing is inferred at all. Within one piece the block sort is right,
    because a piece is a single column.

    Each word carries `piece`, the index of the crop it came from, so the editor
    can show the pieces apart and the order stays checkable after the fact.
    """
    out = []
    for i, rect in enumerate(rects_px):
        for w in words_in_crop(pdf_path, page_idx, rect, png_w, png_h, fills):
            w["piece"] = i
            out.append(w)
    return out


def _rect_tuple(r):
    """Accept {x,y,w,h} (how audio.json stores it) or [x,y,w,h]."""
    if isinstance(r, dict):
        return (float(r["x"]), float(r["y"]), float(r["w"]), float(r["h"]))
    return tuple(float(v) for v in r)


def main():
    """Words under one or more crops, without aligning anything.

    The editor calls this while the author is still drawing: each piece is read
    and shown under Words straight away, so the passage can be checked — and the
    order corrected — before the minutes of alignment are spent on it."""
    if len(sys.argv) != 6:
        print("ERROR: Usage: passage_text.py <raw_dir> <page_index> "
              "<png_width> <png_height> <rects_json>", flush=True)
        sys.exit(1)
    raw_dir = sys.argv[1]
    page_idx = int(sys.argv[2])
    png_w, png_h = float(sys.argv[3]), float(sys.argv[4])
    try:
        rects = [_rect_tuple(r) for r in json.loads(sys.argv[5])]
    except Exception as e:
        print(f"ERROR: Bad rects argument: {e}", flush=True)
        sys.exit(1)
    if not rects:
        print("ERROR: No crop rectangles given", flush=True)
        sys.exit(1)

    pdf_path = find_original_pdf(raw_dir)
    if not pdf_path:
        print(f"ERROR: No PDF found in: {raw_dir}", flush=True)
        sys.exit(1)
    book_dir = os.path.dirname(os.path.normpath(raw_dir))
    fills = fills_for_page(book_dir, page_idx)
    try:
        words = words_in_crops(pdf_path, page_idx, rects, png_w, png_h, fills)
    except IndexError as e:
        print(f"ERROR: {e}", flush=True)
        sys.exit(1)
    print("WORDS: " + json.dumps(words, ensure_ascii=False), flush=True)
    print("OK", flush=True)


if __name__ == "__main__":
    main()
