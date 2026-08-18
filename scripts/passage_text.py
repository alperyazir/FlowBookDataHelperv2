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
# Only reached when a crop turns out to have no text layer; imports nothing heavy.
import passage_ocr


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
# The gap does not always arrive alone in its token: the text layer glues the
# punctuation that follows it on ("………………………,"), and such a token is neither a
# word nor a gap run, so it used to be dropped as punctuation. '.' is left in
# place deliberately -- it is a gap character itself, so a dotted gap ending in
# a full stop already matches.
_GAP_TAIL = re.compile(r"[,;:!?)\]}»”’'\"]+$")
def _is_gap(text):
    if "__" in text:
        return True
    return bool(_GAP_RUN.match(_GAP_TAIL.sub("", text.strip())))

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


# The third marker shape, and the one that survived both rules above: the
# superscript numeral labelling a cloze gap mid-sentence ("...or ³ ……… , and").
# It is not line-first, and the rule that drops a numeral sitting in front of a
# gap only fires when the gap itself was recognised -- so whenever the typography
# defeats the gap test, the marker is left behind AND inherits the answer's slot
# in the audio, putting the highlight on a 7x14px digit. Size decides it with no
# such dependency: a marker is set in a fraction of the body size (6.4pt against
# 11pt in the book that prompted this), while every numeral the narrator really
# reads -- a year, a price, a measurement -- is set in the body size.
_MARKER_SIZE = 0.8      # of the passage's body size


def _drop_marker_numbers(out):
    """Delete the digit tokens that are set too small to be part of the text."""
    sizes = sorted(w["_size"] for w in out
                   if not w.get("num") and not w.get("blank") and w.get("_size"))
    if not sizes:
        return
    body = sizes[len(sizes) // 2]
    # A token whose size the PDF did not report is never judged by this rule.
    out[:] = [w for w in out
              if not (w.get("num") and w.get("_size")
                      and w["_size"] < _MARKER_SIZE * body)]


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


def _same_line(b, box):
    """Whether a word sits on the line an answer box was drawn on.

    Decided on how much of the WORD the box covers vertically, not on the
    distance between the two centres. An author draws the box by eye and by
    taste: on the page that prompted this they are 35px tall against 17px of
    text and sit a third of a line high, so their centre lands between two lines
    and a centre test either claims both lines or neither. How much of a word
    the box actually covers is unambiguous — half of it or more, and the word is
    on that line."""
    ov = min(b["y"] + b["h"], box["y"] + box["h"]) - max(b["y"], box["y"])
    return ov >= 0.5 * b["h"]


def _line_overlap(b, box):
    """How much of a word the box covers vertically, as a fraction of the word."""
    ov = min(b["y"] + b["h"], box["y"] + box["h"]) - max(b["y"], box["y"])
    return ov / max(1.0, b["h"])


def _reading_position(words, f):
    """Where this box falls in the passage's reading order.

    Which LINE the box is on is settled first, and by a contest rather than a
    threshold: the word it covers the most of wins. A threshold cannot do it.
    The boxes are drawn by eye — twice the height of the text and sitting a third
    of a line high on the page this was built for — so a word with a descender on
    the line above ("enjoys", 22px to its neighbours' 17) clears any threshold
    that the intended line also clears, and the blank lands a line early. Overlap
    on the intended line is near 1.0 and on its neighbour near 0.5, every time,
    so the maximum is never in doubt.

    Then it is ordinary reading order within that line: before the first word to
    the right of the box, or after the line if there is none."""
    # Only real text can be the anchor. A blank carries the author's box, which
    # is taller than the text and drawn high, so the blank placed for one gap
    # overlaps the NEXT gap's box (0.91) better than that gap's own line of text
    # does (0.83) — and two boxes on one line would then anchor the second one to
    # the first and place it a line early.
    best_i, best_ov = None, 0.0
    for i, w in enumerate(words):
        if w.get("blank"):
            continue
        ov = _line_overlap(w["bbox"], f)
        if ov > best_ov:
            best_ov, best_i = ov, i
    if best_i is None or best_ov < 0.25:
        # The box is on no line of this passage — keep it in y order.
        fcy = f["y"] + f["h"] / 2.0
        for i, w in enumerate(words):
            if w["bbox"]["y"] + w["bbox"]["h"] / 2.0 > fcy:
                return i
        return len(words)
    anchor = words[best_i]["bbox"]
    acy = anchor["y"] + anchor["h"] / 2.0
    on_line = [i for i, w in enumerate(words)
               if abs(w["bbox"]["y"] + w["bbox"]["h"] / 2.0 - acy) < 0.6 * anchor["h"]]
    if not on_line:                 # a zero-height anchor excludes even itself
        return best_i
    # Past the box's RIGHT edge, not its left. A sloppy text layer can glue the
    # gap to the word after it ("_____________drawing"), and that token starts
    # where the box does — testing its left edge puts the blank after the word it
    # is supposed to precede.
    for i in on_line:
        b = words[i]["bbox"]
        if b["x"] + b["w"] > f["x"] + f["w"]:
            return i
    return on_line[-1] + 1


def _box_overlap(a, b):
    """Intersection as a fraction of the smaller box."""
    ix = max(0, min(a["x"] + a["w"], b["x"] + b["w"]) - max(a["x"], b["x"]))
    iy = max(0, min(a["y"] + a["h"], b["y"] + b["h"]) - max(a["y"], b["y"]))
    small = min(a["w"] * a["h"], b["w"] * b["h"]) or 1
    return (ix * iy) / small


def _on_text_line(words, box):
    """Whether an answer box sits inside a line of the passage's text.

    A cloze gap is part of a sentence, so there is a word beside it on its own
    line, a space or two away. A box with its line to itself belongs to some
    other exercise the crop merely takes in."""
    near = 2.0 * box["h"]          # a couple of characters, not a column away
    for w in words:
        if w.get("blank") or not _same_line(w["bbox"], box):
            continue
        b = w["bbox"]
        if max(box["x"] - (b["x"] + b["w"]), b["x"] - (box["x"] + box["w"]), 0) <= near:
            return True
    return False


def _insert_fill_blanks(out, fills, rect_px):
    """Put a blank in the passage wherever the author drew an answer box.

    Only boxes whose centre is inside the crop count, which is what keeps a word
    bank or a column of ✓/✗ marks elsewhere on the page from being mistaken for
    gaps in this passage — on the page that prompted this, that filter picks the
    right 8 of the page's 26 boxes with nothing else to tune.

    A box that lands on a gap the text layer already found upgrades it in place
    — it gains the answer and the exact box — rather than adding a second blank
    over the same gap.

    Being inside the crop does not make a box part of the passage: a broad crop
    can take in a neighbouring exercise, and on two MyEnglishPath pages it does —
    a dozen answer boxes sitting on their own lines, nothing to do with the
    underscored sentences above them. What separates the two is not how many gaps
    the text layer happened to find, but where the box sits: a cloze gap is
    embedded in a sentence, with a word beside it on its own line (_on_text_line).
    An answer slot standing in a column of its own is not.

    The count of gaps the text layer found used to be the gate instead — boxes
    could only create blanks in a crop where it found none. That made every gap
    depend on the typography after all: one gap the text layer missed in a
    passage where it found the others (a run of dots glued to the comma after it)
    was simply lost, answer and all, and the superscript numeral labelling it
    took over the highlight. A crop with no text at all still trusts its boxes
    completely — there is nothing else to go on."""
    cx0, cy0, cw, ch = rect_px
    cx1, cy1 = cx0 + cw, cy0 + ch
    inside = [f for f in fills
              if cx0 <= f["x"] + f["w"] / 2.0 <= cx1
              and cy0 <= f["y"] + f["h"] / 2.0 <= cy1]
    no_text = all(w.get("blank") for w in out)      # nothing but boxes here
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
        if not (no_text or _on_text_line(out, box)):
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
    # Whatever was read inside an answer box IS the gap — a run of dots, or what
    # OCR made of one (" ........0.0.............", which normalises to digits and
    # would otherwise have gone to the aligner as a number). The author drew the
    # box around it and said so; nothing else on the page is under one.
    boxes = [w["fill"] for w in out if w.get("blank") and w.get("fill")]
    if boxes:
        out[:] = [w for w in out
                  if w.get("blank") or _is_spoken(w["text"])
                  or not any(_box_overlap(w["bbox"], b) > 0.6 for b in boxes)]
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


def _classify(text, line_first, prev_text):
    """What this token is: "word", "blank", "num", or None to drop it.

    The one place the three kinds are decided, so a passage read off an image
    is treated exactly like one read from a text layer."""
    if _is_spoken(text):
        return "word"
    if _is_gap(text):
        return "blank"
    if _is_number(text) and not _is_enum_number(text, line_first, prev_text):
        return "num"
    return None


def _ocr_crop(page, rect_px, png_w, png_h, lang):
    """The crop's words read off the rendered page, classified like a text layer.

    Returns [] when tesseract read nothing, and None when it is not installed —
    the caller says so, because "this book needs a program you do not have" and
    "this picture has no words in it" call for different answers."""
    toks = passage_ocr.read_crop(page, rect_px, png_w, png_h, lang)
    if toks is None:
        return None
    out = []
    line, prev_text = None, None
    for t in toks:
        line_first = t["_line"] != line
        if line_first:
            line, prev_text = t["_line"], None
        kind = _classify(t["text"], line_first, prev_text)
        prev_text = t["text"]
        if kind is None:
            continue
        entry = {"text": t["text"], "bbox": t["bbox"], "_size": t["_size"]}
        if kind == "blank":
            entry["blank"] = True
        elif kind == "num":
            entry["num"] = True
        out.append(entry)
    return out


def words_in_crop(pdf_path, page_idx, rect_px, png_w, png_h, fills=None,
                  lang=None):
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
    # Count first, and name the file. Reading len(doc) into the message AFTER
    # closing the document raised "ValueError: document closed" from inside the
    # f-string, so the console showed that instead of the range error — and the
    # range error is the one that matters, because the way to be out of range is
    # to have been handed the wrong PDF (a one-page cover, when raw/ holds
    # nothing but the cover and the answer key). Say which file it was.
    n_pages = len(doc)
    if page_idx < 0 or page_idx >= n_pages:
        doc.close()
        raise IndexError(f"Page index {page_idx} out of range (0-{n_pages - 1}) "
                         f"in {os.path.basename(pdf_path)}")
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
        kind = _classify(text, was_first, was_prev)
        if kind is None:
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
            "_size": size,          # dropped below; only _drop_marker_numbers reads it
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
    # A crop with nothing to say is a crop the PDF draws as a picture: on Switch
    # to CLIL p49 the paragraph is one grayscale image and this loop ends with
    # nothing but the answer boxes to go on. Read it instead of shipping a
    # passage that is six boxes and no words (see passage_ocr).
    if not any(w.get("text") and _is_spoken(w["text"]) for w in out):
        read = _ocr_crop(page, rect_px, png_w, png_h, lang)
        if read is None:
            print(f"  NOTE: no text layer under this crop and no OCR to read "
                  f"the page image — {passage_ocr.INSTALL_HINT}", flush=True)
        elif read:
            print(f"  Read {len(read)} word(s) off the page image (no text "
                  f"layer under this crop)", flush=True)
            out = read
    doc.close()
    # Before the boxes are placed, so a marker cannot be mistaken for the word a
    # blank is inserted after, and before "_size" is stripped.
    _drop_marker_numbers(out)
    for w in out:
        del w["_size"]
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


def words_in_crops(pdf_path, page_idx, rects_px, png_w, png_h, fills=None,
                   lang=None):
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
        for w in words_in_crop(pdf_path, page_idx, rect, png_w, png_h, fills,
                               lang):
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
