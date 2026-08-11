"""Build word-level karaoke timing for one audio passage.

Given a crop rectangle (in PNG pixel space) over a passage on a PDF page and
the audio file that narrates it, this:
  1. pulls the words + bboxes under the rect from the PDF text layer,
  2. forced-aligns that KNOWN text to the audio with whisperx (align-only,
     no ASR -> zero transcription errors),
  3. maps timestamps back onto the words, and
  4. merges the result into <book>/audio/audio.json keyed by the audio
     filename (e.g. "4.mp3").

Word bboxes are stored in the same PNG pixel space as everything else in
config.json, as {x,y,w,h}. config.json itself only needs "karaoke": true on
the audio section; all timing data lives here.

A word is either spoken text or a cloze blank:
  {"text": "cat",      "bbox": {...}, "start": 1.2, "end": 1.5}
  {"text": "________", "bbox": {...}, "start": 1.6, "end": 2.1, "blank": true,
   "answer": "elephant", "fill": {"x":.., "y":.., "w":.., "h":..}}
A blank is the reader's cue to open the fill box under it at "start". This
script only emits "blank" + timing; "answer"/"fill" are stamped by the editor
(PageDetails.linkKaraokeBlanks), which is the side that knows config.json's
fill boxes. "fill" carries the box's coords rather than its text because two
fills on one page can hold the same answer — coordinates identify it, text
does not.

Usage:
  align_audio.py <raw_dir> <page_index> <x> <y> <w> <h> \
                 <png_width> <png_height> <audio_path> <audio_json_path> <lang>
Coordinates are PNG pixels; <x> <y> <w> <h> is the crop rect (not x1/y1).
"""
import sys
import os
import json
import re
import difflib

# Force UTF-8 on stdout/stderr. On Windows the console/pipe default is cp1252,
# which can't encode passage characters like '⁴' (superscript 4) and would
# crash the whole run with a UnicodeEncodeError mid-print.
for _stream in (sys.stdout, sys.stderr):
    try:
        _stream.reconfigure(encoding="utf-8")
    except (AttributeError, ValueError):
        pass

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from _bootstrap import ensure_runtime_deps, ensure_align_deps

ensure_runtime_deps()   # fitz
ensure_align_deps()     # whisperx (+ torch)

import fitz

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

# faster-whisper model for intro detection (see _asr_word_timeline). "base" is
# accurate enough to locate where the passage starts and keeps the one-time
# model download small; timing precision is irrelevant here.
_ASR_MODEL = "base"

# Below this mean alignment confidence we flag the passage for human review.
# Calibrated on 121 aligned passages across four books: healthy runs sit at
# 0.74–0.84 (mean 0.81), the two known-broken ones at 0.35 and 0.45. The old
# 0.30 was under every observed value, so needs_review never once fired — a
# badly desynced passage shipped looking exactly like a good one.
REVIEW_SCORE = 0.65

# Structural sanity limits, checked alongside the score (see review_flags). A
# passage can align with a respectable mean score and still be plainly wrong;
# these catch the shapes that score alone misses. Bounds are set clear of the
# healthy population measured on the same 121 passages (largest internal start
# gap 4.0s, speaking rate 1.78–3.22 words/s).
_MAX_INTERNAL_GAP = 8.0     # silence between consecutive words mid-passage
_RATE_MIN, _RATE_MAX = 0.8, 6.0   # words per second across the passage span

# Tail compression. When the forced pass runs short of audio it does not fail —
# it packs whatever words are left into a sliver and finishes early, so the
# highlight sprints through the closing sentence and the voice then says it.
# 20.000 Leagues p20 ended that way: the last five words shared half a second at
# 119.8s while the narrator was still reading them at 122s. Nothing else caught
# it — score 0.80, nothing clamped, no internal gap, pace 2.07 words/s — so it
# shipped and only a listening human noticed.
#
# The signature is two things at once: a tail far shorter than the passage's own
# word length, and clip left over that nobody is speaking during. Measured over
# 121 passages the broken one sits at 36% of median with 3.3s spare, the worst
# healthy one at 59% with 0.7s — so requiring both, at these cuts, separates
# them cleanly. Only checked on passages long enough for a median to mean
# something; short ones are better served by the score and pace tests.
_TAIL_WORDS = 6
_TAIL_MIN_LEN = 20          # passage words needed before this test is meaningful
_TAIL_RATIO = 0.5           # tail mean vs median word duration
_TAIL_LEFTOVER = 1.5        # seconds of unused clip after the passage ends

# Shortest span a highlight can occupy and still be seen. The reader lights the
# last word whose start has passed, so a zero-length word is drawn for no frames
# at all and the highlight visibly skips it.
_MIN_WORD = 0.06


def find_original_pdf(raw_dir):
    """Find the original (unanswered) PDF in raw/ directory."""
    if not os.path.exists(raw_dir):
        return None
    pdfs = [f for f in os.listdir(raw_dir) if f.lower().endswith(".pdf")]
    if not pdfs:
        return None
    for f in pdfs:
        n = f.lower()
        if "original" in n or "soru" in n:
            return os.path.join(raw_dir, f)
    for f in pdfs:
        if not any(k in f.lower() for k in ("cevap", "answer", "key")):
            return os.path.join(raw_dir, f)
    return os.path.join(raw_dir, pdfs[0])


# Highlight box vertical extent, as fractions of the font size measured from
# the text baseline. fitz word rects span the font's full ascender→descender
# (the ascender is often ~0.9·size, well above the actual caps at ~0.70·size),
# so drawing them raw makes the highlight sit noticeably high and miss the
# bottom of the glyphs. Anchoring on the real baseline + font size instead hugs
# the word identically in every font and size (validated on a script and a sans
# book). x stays glyph-tight (from the character boxes), which was already good.
_HL_CAP = 0.78     # top above caps/ascenders (cap height ≈ 0.70)
_HL_DESC = 0.25    # bottom below the baseline to cover descenders (g, y, p)


def words_in_crop(pdf_path, page_idx, rect_px, png_w, png_h):
    """Words whose center falls inside the crop rect, in reading order.

    Returns [{text, bbox:{x,y,w,h}}] with bbox in PNG pixel space. The box is
    baseline-anchored (see _HL_CAP/_HL_DESC) so the karaoke highlight hugs the
    word rather than floating above it.
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


def setup_align_runtime():
    """macOS python.org Python lacks CA certs and whisperx needs nltk punkt;
    make first-run downloads work without manual setup."""
    # whisperx.load_audio shells out to `ffmpeg`. When the app is launched from
    # Finder/launchd (macOS) the PATH lacks Homebrew; on Windows ffmpeg is
    # expected next to the bundled interpreter or on PATH. Make common spots
    # findable per-platform.
    if os.name == "nt":
        extra_paths = [os.path.dirname(sys.executable),
                       os.path.join(os.path.dirname(sys.executable), "ffmpeg", "bin")]
    else:
        extra_paths = ["/opt/homebrew/bin", "/usr/local/bin", "/usr/bin"]
    parts = os.environ.get("PATH", "").split(os.pathsep)
    for p in extra_paths:
        if p and p not in parts:
            parts.append(p)
    os.environ["PATH"] = os.pathsep.join(parts)
    try:
        import certifi
        os.environ.setdefault("SSL_CERT_FILE", certifi.where())
        os.environ.setdefault("REQUESTS_CA_BUNDLE", certifi.where())
    except Exception:
        pass
    try:
        import nltk
        for pkg in ("punkt", "punkt_tab"):
            try:
                nltk.data.find(f"tokenizers/{pkg}")
            except LookupError:
                nltk.download(pkg, quiet=True)
    except Exception:
        pass


def _model_cache_status():
    """Inspect the torch-hub checkpoint cache (where the wav2vec align model
    lives). Returns (present, dir, size_mb). Same location on every OS: the
    torch cache, i.e. %USERPROFILE%/.cache/torch/hub on Windows, unless
    TORCH_HOME / XDG_CACHE_HOME override it. Lets the editor show — and the log
    record — whether a run downloads the model or just loads it from cache."""
    try:
        import torch
        ckpt = os.path.join(torch.hub.get_dir(), "checkpoints")
        names = os.listdir(ckpt) if os.path.isdir(ckpt) else []
        if names:
            mb = sum(os.path.getsize(os.path.join(ckpt, n)) for n in names) / (1024 * 1024)
            return True, ckpt, mb
        return False, ckpt, 0.0
    except Exception:
        return None, "", 0.0


# How much audio to keep on each side of the located passage window, in
# seconds — a little lead-in/out so forced alignment has room at the edges.
_WINDOW_PAD = 0.5


def _held_out(w):
    """True for a token kept in the passage but excluded from forced alignment —
    timed from the ASR timeline instead (see time_held_out).

    Only cloze blanks now: nobody wrote down the answer, so there is genuinely
    no text to align. Numerals used to be held out too, but they are spelled out
    for the aligner (say_number) and take their timing from the forced pass like
    any other word; one that cannot be spelled falls back here."""
    if w.get("blank"):
        return True
    if w.get("num"):
        return not say_number(w["text"])
    return False


def expand_for_align(words):
    """The text handed to the forced aligner, plus who owns each token.

    Returns (tokens, owner): owner[k] is the index in `words` that produced
    tokens[k]. Mostly one-to-one, but a numeral expands to however many words it
    is read as ("1828" -> eighteen twenty eight), which is exactly why the
    mapping has to be carried rather than recomputed — attach_timing then gives
    the numeral the span from the first of its tokens to the last."""
    tokens, owner = [], []
    prev_text = None
    for i, w in enumerate(words):
        if _held_out(w):
            prev_text = None      # a gap breaks the month/day adjacency
            continue
        if w.get("num"):
            said = say_number(w["text"], prev_text)
            for t in said:
                tokens.append(t)
                owner.append(i)
        else:
            tokens.append(w["text"])
            owner.append(i)
        prev_text = w["text"]
    return tokens, owner


def _asr_word_timeline(audio_path, lang):
    """Transcribe the WHOLE clip and return a word-level timeline
    [{w, start, end}] (w normalized). Used ONLY to locate where the passage
    begins — many clips open with a spoken instruction ("Revision 1. Page 6…
    Then listen and check.") that isn't in the passage crop, and forced-aligning
    the passage across the whole clip leaks its first words onto that intro.

    Transcribes with faster-whisper and VAD DISABLED, on purpose. whisperx's own
    transcribe() runs a pyannote VAD frontend that, on some clips, drops the
    quieter lead-in speech (book title / "Page N" / instructions) entirely and
    collapses the timeline so the passage looks like it starts at ~1s. That made
    the window below fall back to the whole clip, and the first passage words
    leaked onto the intro (highlight firing ~10s early). Bypassing VAD sees the
    full clip, intro included. Timing precision here is irrelevant; the real
    timestamps still come from the forced pass. Returns [] if ASR is unavailable
    so the caller falls back to a whole-clip align."""
    try:
        from faster_whisper import WhisperModel
        model = WhisperModel(_ASR_MODEL, device="cpu", compute_type="int8")
        segments, _info = model.transcribe(audio_path, language=lang,
                                           word_timestamps=True, vad_filter=False)
        out = []
        for seg in segments:
            for w in (seg.words or []):
                if w.start is not None:
                    out.append({"w": norm(w.word),
                                "start": w.start, "end": w.end})
        return [x for x in out if x["w"]]
    except Exception as e:
        print(f"PROGRESS: Intro detection unavailable ({e}); aligning whole clip",
              flush=True)
        return []


def _locate_passage_window(words, asr, dur):
    """Find the [t0, t1] audio window the passage actually occupies by matching
    the passage tokens against the ASR timeline. Returns (t0, t1, j0, j1) — the
    padded window plus the ASR index range it covers — or the whole clip if the
    passage can't be located confidently."""
    if not asr:
        return 0.0, dur, 0, len(asr) - 1
    a = [norm(w["text"]) for w in words]
    a = [t for t in a if t]                      # drop blanks (e.g. "____")
    b = [x["w"] for x in asr]
    if not a:
        return 0.0, dur, 0, len(asr) - 1
    whole = (0.0, dur, 0, len(asr) - 1)
    sm = difflib.SequenceMatcher(None, a, b, autojunk=False)
    blocks = [bl for bl in sm.get_matching_blocks() if bl.size > 0]
    if not blocks:
        return whole
    # Anchor on the LONGEST run, not on whichever block comes first. difflib
    # maximizes the total match count, so a stray one-word coincidence far from
    # the passage is happily included — and taking blocks[0] then let that stray
    # define where the window starts. On FiveChildrenandIT p12 the 8-word crop
    # ("We will never see them again!" said Robert.) matched a lone "we" at 40s
    # on top of its real 4-word run at 105s, so the window opened at 39.5s and
    # the aligner spread all 8 words over the 68s that followed — the highlight
    # ran a full minute ahead of the voice. The longest run is the passage; a
    # coincidence is short by definition.
    anchor = max(blocks, key=lambda bl: (bl.size, -bl.b))
    off = anchor.b - anchor.a                    # asr index of passage token 0
    # Keep only blocks consistent with that projection. Real matches share the
    # anchor's offset up to whatever the transcript inserted or dropped inside
    # the passage; strays sit hundreds of words away.
    slack = max(10, len(a) // 2)
    kept = [bl for bl in blocks if abs((bl.b - bl.a) - off) <= slack]
    matched = sum(bl.size for bl in kept)
    if matched < max(3, 0.3 * len(a)):
        return whole                             # too weak -> whole clip
    # Project through the head/tail tokens that did not match, so a passage whose
    # first or last words the transcript misheard still gets its own audio: the
    # window must start before the first spoken word, not at the first *matched*
    # one. (On p12 the opening "We" never matched its true position, and without
    # this the window would have opened after it and clipped the word off.)
    first, last = kept[0], kept[-1]
    j_start = max(0, first.b - first.a)
    j_end = min(len(asr) - 1,
                last.b + last.size - 1 + (len(a) - (last.a + last.size)))
    # Start the window at the END of the last intro word (the ASR word right
    # before the passage), not at the passage word's own ASR start. ASR timing
    # on that first passage word is jittery and often lands late; anchoring on
    # its start can clip the word's true onset, so forced align crams it against
    # the next word and it only flashes for a frame. The gap between the intro
    # and the passage is inter-content silence, so reaching back to the intro's
    # end is safe — it captures the full first word without grabbing intro
    # speech.
    if j_start > 0:
        t0 = min(asr[j_start - 1]["end"], asr[j_start]["start"] - _WINDOW_PAD)
        t0 = max(0.0, t0)
    else:
        t0 = max(0.0, asr[j_start]["start"] - _WINDOW_PAD)
    t1 = min(dur, asr[j_end]["end"] + _WINDOW_PAD)
    return t0, t1, j_start, j_end


def align(words, audio_path, lang):
    """Forced-align the known passage text to audio.

    Returns (aligned, dur, asr, tokens, owner) — the last two map the aligned
    tokens back onto the passage words (see expand_for_align).

    First transcribes the clip to find where the passage begins (skipping any
    spoken intro/instruction that isn't in the crop), then forced-aligns the
    passage text only within that window — so leading words are timed to when
    they are actually spoken, not leaked onto the intro. Cloze blanks are held
    out of the aligned text; the returned ASR timeline times them."""
    import whisperx
    device = "cpu"
    # Blanks have no spoken form the character-level aligner can use; numerals
    # are written out the way they are read (see expand_for_align).
    tokens, owner = expand_for_align(words)
    text = " ".join(tokens)
    audio = whisperx.load_audio(audio_path)
    dur = len(audio) / 16000.0
    # The ~370MB wav2vec model is downloaded only once (it lives in the torch
    # cache); every run still has to load it into memory, which is the slow
    # part here (~15s on CPU) since each align runs in a fresh process. Report
    # the cache state so "is it downloading again?" is answerable from the UI/log.
    present, ckpt_dir, mb = _model_cache_status()
    if present:
        print(f"PROGRESS: Loading the speech model from cache ({mb:.0f}MB)… ~15s, "
              f"not re-downloaded", flush=True)
        print(f"CACHE: torch model cache present at {ckpt_dir} ({mb:.0f}MB)", flush=True)
    elif present is False:
        print(f"PROGRESS: Speech model NOT cached — downloading ~370MB once now…",
              flush=True)
        print(f"CACHE: torch model cache EMPTY at {ckpt_dir} — downloading this run",
              flush=True)
    else:
        print("PROGRESS: Loading the speech model… ~15s", flush=True)
    model_a, meta = whisperx.load_align_model(language_code=lang, device=device)

    # Locate the passage in the clip and align only that window.
    print("PROGRESS: Finding where the passage begins in the audio…", flush=True)
    asr = _asr_word_timeline(audio_path, lang)
    t0, t1, j0, j1 = _locate_passage_window(words, asr, dur)
    # Everything downstream (repair_drift, time_held_out) re-matches the passage
    # against this timeline, and outside the window it hits the same stray
    # coincidences the locator just rejected — a word can then be "confirmed" by
    # a transcript hit a minute away and keep its wrong timestamp. Hand back only
    # the window's slice so those passes see the passage's own audio and nothing
    # else.
    asr = asr[j0:j1 + 1]
    i0, i1 = int(t0 * 16000), int(t1 * 16000)
    clip = audio[i0:i1] if (t0 > 0.0 or t1 < dur) else audio
    if t0 > 0.0 or t1 < dur:
        print(f"PROGRESS: Passage runs {t0:.1f}s–{t1:.1f}s; skipping "
              f"{t0:.0f}s of intro before it", flush=True)

    n_spoken = sum(1 for w in words if not _held_out(w))
    print(f"PROGRESS: Aligning {n_spoken} words to {(len(clip)/16000.0):.0f}s "
          f"of audio…", flush=True)
    segs = [{"text": text, "start": 0.0, "end": len(clip) / 16000.0}]
    res = whisperx.align(segs, model_a, meta, clip, device,
                         return_char_alignments=False)
    aligned = []
    for seg in res["segments"]:
        for w in seg.get("words", []):
            # Shift window-relative timestamps back onto the full-clip timeline.
            if w.get("start") is not None:
                w["start"] += t0
                w["end"] += t0
            aligned.append(w)
    return aligned, dur, asr, tokens, owner


def attach_timing(words, aligned, tokens, owner):
    """Map aligned timestamps onto the pdf words by normalized sequence
    alignment. Returns mean score and count of words with no own timestamp."""
    # Match against what was actually sent to the aligner — the expanded token
    # list, not the passage words. Held-out blanks have no counterpart in
    # `aligned`, and a numeral is several tokens there ("eighteen twenty eight"
    # for one "1828,"), so pairing the two lists directly would slide every
    # later word onto the wrong timestamp.
    a = [norm(t) for t in tokens]
    b = [norm(w.get("word", "")) for w in aligned]
    sm = difflib.SequenceMatcher(a=a, b=b, autojunk=False)
    for w in words:
        w["start"] = None
        w["end"] = None
        w["score"] = None
    # A word takes the span of all its tokens: first onset to last release, so a
    # spelled-out year stays lit for as long as it is being said.
    spans = {}
    for tag, i1, i2, j1, j2 in sm.get_opcodes():
        if tag in ("equal", "replace"):
            for k in range(min(i2 - i1, j2 - j1)):
                aw = aligned[j1 + k]
                if aw.get("start") is not None:
                    spans.setdefault(owner[i1 + k], []).append(
                        (aw["start"], aw["end"], float(aw.get("score", 0))))
    for wi, sp in spans.items():
        w = words[wi]
        w["start"] = round(min(s for s, _, _ in sp), 3)
        w["end"] = round(max(e for _, e, _ in sp), 3)
        w["score"] = round(sum(c for _, _, c in sp) / len(sp), 3)
    scores = [w["score"] for w in words if w["score"] is not None]
    mean_score = round(sum(scores) / len(scores), 3) if scores else 0.0
    # Held-out tokens never get a forced timestamp (they're not in the aligned
    # text) and are timed separately — don't count them as unaligned.
    missing = sum(1 for w in words if not _held_out(w) and w["start"] is None)
    # Forward-fill gaps so the reader's highlight never stalls.
    last = 0.0
    for w in words:
        if w["start"] is None:
            w["start"] = last
        if w["end"] is None:
            w["end"] = w["start"]
        last = w["end"]
    return mean_score, missing


def _map_to_asr(words, asr, exact_only):
    """words-index -> asr-index for the force-aligned words, by sequence match
    against the ASR timeline. exact_only keeps just the runs whose text matches
    the transcript verbatim (used where a wrong pairing would move a correct
    word); otherwise near-misses count too (enough to bracket a gap)."""
    spoken = [i for i, w in enumerate(words) if not _held_out(w)]
    a = [norm(words[i]["text"]) for i in spoken]
    b = [x["w"] for x in asr]
    sm = difflib.SequenceMatcher(a=a, b=b, autojunk=False)
    tags = ("equal",) if exact_only else ("equal", "replace")
    word_asr = [None] * len(words)
    for tag, i1, i2, j1, j2 in sm.get_opcodes():
        if tag in tags:
            for k in range(min(i2 - i1, j2 - j1)):
                word_asr[spoken[i1 + k]] = j1 + k
    return word_asr


# How far a forced timestamp may sit from where the transcript heard the same
# word before we stop believing it. Measured on a narrated passage: ordinary
# jitter between the two is well under 0.8s, so anything past this is not
# imprecision, it's the aligner having placed the word somewhere else entirely.
_DRIFT_MAX = 1.2


def repair_drift(words, asr):
    """Re-anchor words the forced pass placed grossly wrong. Returns the count.

    Held-out tokens leave audio with no text to match (nobody wrote down the
    cloze answer; a numeral is spelled with digits the character aligner cannot
    read). Forced alignment must still consume that audio, and it can do so by
    dragging the words that FOLLOW the hole back into it — on the passage that
    prompted this, "…on April [24,] [1942,] in Toronto." aligned "in Toronto."
    onto the spoken "twenty-four", 2.8s early, so the tail flashed past.

    The transcript did hear those words. Where the two disagree by more than
    _DRIFT_MAX the forced timestamp is not merely imprecise, so we take the
    transcript's. Only verbatim text matches are trusted as anchors."""
    if not asr:
        return 0
    word_asr = _map_to_asr(words, asr, exact_only=True)
    fixed = 0
    for i, w in enumerate(words):
        if _held_out(w) or word_asr[i] is None or w["start"] is None:
            continue
        a = asr[word_asr[i]]
        if abs(w["start"] - a["start"]) > _DRIFT_MAX:
            w["start"] = round(a["start"], 3)
            w["end"] = round(max(a["end"], a["start"]), 3)
            fixed += 1
    return fixed


def enforce_monotonic(words):
    """Reading-order start times must never go backwards — the reader picks the
    last word whose start has passed, so one out-of-order start stalls the
    highlight there. Returns how many words had to be pushed forward.

    That count is a quality signal in its own right (see review_flags): a sound
    alignment clamps nothing, because the aligner already produced the words in
    order. Clamping many means the forced pass placed a stretch of the passage
    somewhere it does not belong and this pass is only hiding it."""
    clamped = 0
    last = 0.0
    for w in words:
        if w["start"] < last:
            w["start"] = last
            clamped += 1
        if w["end"] < w["start"]:
            w["end"] = w["start"]
        last = w["start"]
    _spread_ties(words)
    return clamped


def _spread_ties(words):
    """Give every word a visible span, keeping starts non-decreasing.

    Clamping above collapses each out-of-order word onto its predecessor's
    start, so it ends up zero-length — and a zero-length word is drawn for no
    frames at all: the highlight freezes on the word before it, then jumps past
    a whole stretch of text. That "es geçiyor" skip is what the collapse looks
    like on screen (13 consecutive words shared one timestamp on DavidCopperfield
    p17). The timing is already wrong at that point and this cannot invent the
    truth, but sweeping the tied run across the room available to it degrades to
    a slightly-off highlight instead of an invisible one.

    Held-out blanks and numerals reach here zero-length too whenever their ASR
    gap collapsed (time_held_out's `hi <= lo` branch), which is why a spoken year
    would light up for no time at all; they get the same treatment."""
    n = len(words)
    i = 0
    while i < n:
        # words[i..j] share one start (j == i in the healthy case).
        j = i
        while j + 1 < n and words[j + 1]["start"] <= words[i]["start"]:
            j += 1
        run = j - i + 1
        s = words[i]["start"]
        nxt = words[j + 1]["start"] if j + 1 < n else None   # always > s
        if run > 1:
            limit = nxt if nxt is not None else max(words[j]["end"],
                                                    s + run * _MIN_WORD)
            if limit <= s:
                limit = s + run * _MIN_WORD
            step = (limit - s) / run
            for k in range(run):
                w = words[i + k]
                w["start"] = round(s + k * step, 3)
                w["end"] = round(s + (k + 1) * step, 3)
        else:
            # A single word that merely came out very short: lengthen it to the
            # visibility floor, never past where the next word begins.
            w = words[i]
            floor = s + _MIN_WORD if nxt is None else min(s + _MIN_WORD, nxt)
            if w["end"] < floor:
                w["end"] = round(floor, 3)
        i = j + 1


def time_held_out(words, asr):
    """Give each held-out token (a blank "______" or a numeral) a timespan from
    the ASR gap between its neighbouring force-aligned words, so its box lights
    up while the answer / the number is spoken. Runs after attach_timing,
    overwriting the forward-filled placeholder times. No-op (placeholders kept)
    if ASR is unavailable.

    The forced pass can't time these — nobody wrote down the cloze answer, so a
    neighbour absorbs its audio. But the whole-clip ASR *did* hear it, so we map
    the real words onto the ASR timeline and read the span from the gap: [end of
    the previous word in ASR, start of the next word in ASR].

    Numerals used to come through here too and it went badly: one gap holding
    "February 8, 1828," was split evenly between the two, so the year got the
    same slice as the day and lit for 0.09s. They are spelled out for the forced
    aligner now (say_number) and only land here if they cannot be spelled."""
    if not asr:
        return
    # Map each force-aligned word (in reading order) to its ASR index.
    word_asr = _map_to_asr(words, asr, exact_only=False)

    bi = 0
    while bi < len(words):
        if not _held_out(words[bi]):
            bi += 1
            continue
        # A run of adjacent held-out tokens shares one gap ("November 30, 1874,"
        # holds two). They must split it: the reader highlights the LAST word
        # whose start has passed, so identical spans would hide all but the last.
        bj = bi
        while bj < len(words) and _held_out(words[bj]):
            bj += 1
        prev_sp = next((i for i in range(bi - 1, -1, -1)
                        if word_asr[i] is not None), None)
        next_sp = next((i for i in range(bj, len(words))
                        if word_asr[i] is not None), None)
        gs = asr[word_asr[prev_sp]]["end"] if prev_sp is not None else 0.0
        ge = (asr[word_asr[next_sp]]["start"] if next_sp is not None
              else (words[prev_sp]["end"] if prev_sp is not None else gs))
        # Clamp inside the neighbours' FORCED starts so reading-order start times
        # stay monotonic — the reader's active-word logic depends on that.
        lo = words[prev_sp]["start"] + 0.01 if prev_sp is not None else 0.0
        hi = words[next_sp]["start"] - 0.01 if next_sp is not None else max(ge, lo)
        if hi <= lo:                     # neighbours too close for a real gap
            mid = round((lo + hi) / 2, 3)
            for i in range(bi, bj):
                words[i]["start"] = words[i]["end"] = mid
            bi = bj
            continue
        gs = min(max(gs, lo), hi)
        ge = min(max(ge, gs), hi)
        # ASR words heard inside the gap. A numeral usually comes back from ASR
        # as digits ("1874"), so we can time it exactly instead of by its share
        # of the gap; `pool` only moves forward so two numerals in one gap can't
        # match the same ASR word.
        pool = list(range((word_asr[prev_sp] + 1) if prev_sp is not None else 0,
                          word_asr[next_sp] if next_sp is not None else len(asr)))
        n = bj - bi
        step = (ge - gs) / n
        cursor = gs
        for k, i in enumerate(range(bi, bj)):
            w = words[i]
            s, e = gs + k * step, gs + (k + 1) * step
            if w.get("num"):
                key = norm(w["text"])
                m = next((p for p in pool if asr[p]["w"] == key), None)
                if m is not None:
                    s, e = asr[m]["start"], asr[m]["end"]
                    pool = [p for p in pool if p > m]
            s = min(max(s, cursor), hi)
            e = min(max(e, s), hi)
            w["start"], w["end"] = round(s, 3), round(e, 3)
            cursor = s
        bi = bj


def review_flags(words, mean_score, missing, clamped, dur):
    """Reasons this passage should not be trusted, as short human-readable
    strings (empty == looks sound).

    Mean score alone is not enough: the passage that started this — an 8-word
    crop whose highlight ran a minute ahead of the voice — still scored 0.35 and
    shipped silently, because the old threshold sat under every value the metric
    ever produces. These add the shapes a score cannot see: a stretch of words
    the aligner had to be forced back into order, a silent chasm inside what is
    supposed to be continuous narration, and a passage read at a speed no human
    reads at."""
    flags = []
    if mean_score < REVIEW_SCORE:
        flags.append(f"low confidence (score {mean_score:.2f} "
                     f"< {REVIEW_SCORE})")
    if missing > len(words) * 0.2:
        flags.append(f"{missing} of {len(words)} words got no timestamp")
    if clamped > max(2, 0.05 * len(words)):
        flags.append(f"{clamped} words were out of order and had to be clamped")
    gaps = [(words[i + 1]["start"] - words[i]["start"], i)
            for i in range(len(words) - 1)]
    if gaps:
        g, gi = max(gaps)
        if g > _MAX_INTERNAL_GAP:
            flags.append(f"{g:.0f}s silence inside the passage after "
                         f"'{words[gi]['text']}'")
    span = words[-1]["end"] - words[0]["start"] if words else 0.0
    if span > 0.5:
        rate = len(words) / span
        if rate < _RATE_MIN or rate > _RATE_MAX:
            flags.append(f"implausible pace ({rate:.1f} words/s over "
                         f"{span:.0f}s of a {dur:.0f}s clip)")
    if len(words) >= _TAIL_MIN_LEN and dur > 0:
        lens = sorted(w["end"] - w["start"] for w in words)
        median = lens[len(lens) // 2]
        tail = words[-_TAIL_WORDS:]
        tail_mean = sum(w["end"] - w["start"] for w in tail) / len(tail)
        leftover = dur - words[-1]["end"]
        if (median > 0 and tail_mean < _TAIL_RATIO * median
                and leftover > _TAIL_LEFTOVER):
            flags.append(f"the last {_TAIL_WORDS} words average "
                         f"{tail_mean:.2f}s against {median:.2f}s for the "
                         f"passage, and {leftover:.0f}s of clip goes unused — "
                         f"the ending is running ahead of the voice")
    return flags


def merge_into_audio_json(path, audio_id, entry):
    data = {}
    if os.path.exists(path):
        try:
            with open(path, encoding="utf-8") as f:
                data = json.load(f)
        except Exception:
            data = {}
    data[audio_id] = entry
    os.makedirs(os.path.dirname(path), exist_ok=True)
    tmp = path + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2, ensure_ascii=False)
    os.replace(tmp, path)


def main():
    if len(sys.argv) != 12:
        print("ERROR: Usage: align_audio.py <raw_dir> <page_index> <x> <y> "
              "<w> <h> <png_width> <png_height> <audio_path> "
              "<audio_json_path> <lang>", flush=True)
        sys.exit(1)

    raw_dir = sys.argv[1]
    page_idx = int(sys.argv[2])
    rect_px = (float(sys.argv[3]), float(sys.argv[4]),
               float(sys.argv[5]), float(sys.argv[6]))
    png_w, png_h = float(sys.argv[7]), float(sys.argv[8])
    audio_path = sys.argv[9]
    audio_json_path = sys.argv[10]
    lang = sys.argv[11]

    pdf_path = find_original_pdf(raw_dir)
    if not pdf_path:
        print(f"ERROR: No PDF found in: {raw_dir}", flush=True)
        sys.exit(1)
    if not os.path.exists(audio_path):
        print(f"ERROR: Audio not found: {audio_path}", flush=True)
        sys.exit(1)

    # Lines prefixed "PROGRESS:" are surfaced live in the editor's karaoke
    # status so the author sees what stage the (multi-second) align is at,
    # instead of a bare spinner.
    print("PROGRESS: Reading passage text from the page…", flush=True)
    try:
        words = words_in_crop(pdf_path, page_idx, rect_px, png_w, png_h)
    except IndexError as e:
        print(f"ERROR: {e}", flush=True)
        sys.exit(1)
    if not words:
        print("ERROR: No text-layer words inside the crop rect (scanned page "
              "or empty selection?)", flush=True)
        sys.exit(1)
    print(f"Passage: {len(words)} words -> "
          f"{' '.join(w['text'] for w in words)}", flush=True)

    print(f"PROGRESS: Found {len(words)} words. Preparing the aligner…",
          flush=True)
    setup_align_runtime()
    # align() emits its own "Loading model…" / "Aligning…" progress lines.
    aligned, dur, asr, tokens, owner = align(words, audio_path, lang)
    print(f"Aligned {len(aligned)} words against {dur:.2f}s audio", flush=True)
    mean_score, missing = attach_timing(words, aligned, tokens, owner)
    # Order matters: repair first, so the held-out tokens are bracketed by
    # timings that are actually where the words are spoken.
    fixed = repair_drift(words, asr)
    if fixed:
        print(f"Re-anchored {fixed} word(s) the forced pass placed more than "
              f"{_DRIFT_MAX}s from the transcript", flush=True)
    time_held_out(words, asr)   # time blanks + numerals off the ASR timeline
    clamped = enforce_monotonic(words)
    flags = review_flags(words, mean_score, missing, clamped, dur)
    needs_review = bool(flags)
    print(f"Mean score={mean_score}, unaligned={missing}, clamped={clamped}, "
          f"needs_review={needs_review}", flush=True)
    for f in flags:
        print(f"REVIEW: {f}", flush=True)
    print(f"PROGRESS: Aligned {len(words)} words (score {mean_score}). Saving…",
          flush=True)

    audio_id = os.path.basename(audio_path)
    entry = {
        "passage": {"x": round(rect_px[0]), "y": round(rect_px[1]),
                    "w": round(rect_px[2]), "h": round(rect_px[3])},
        "page_index": page_idx,
        "duration": round(dur, 3),
        "lang": lang,
        "mean_score": mean_score,
        "needs_review": needs_review,
        "review": flags,
        "words": words,
    }
    merge_into_audio_json(audio_json_path, audio_id, entry)
    print(f"Wrote {audio_id} -> {audio_json_path}", flush=True)
    # Compact summary for the C++ caller (parsed off stdout, before "OK").
    summary = {"audio_id": audio_id, "words": len(words),
               "mean_score": mean_score, "needs_review": needs_review,
               "review": flags}
    print("SUMMARY: " + json.dumps(summary, ensure_ascii=False), flush=True)
    print("OK", flush=True)


if __name__ == "__main__":
    main()
