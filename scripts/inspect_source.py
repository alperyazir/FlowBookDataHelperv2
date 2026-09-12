"""Read a raw source folder and describe the book it would make.

The Create flow hands the author's folder to this and gets back everything
New Project needs — the two PDFs, the media folders, a cover, and the module
table — so nothing has to be typed in by hand.

  python3 inspect_source.py <folder>   ->  JSON on stdout

Accepts either layout: the PDFs sitting directly in the folder, or under a
raw/ subfolder. Names are matched in both English and Turkish, since that is
what publishers actually ship ("... CEVAPLI.pdf", "... Kitap.pdf").
"""
import sys
import os

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from _bootstrap import ensure_runtime_deps
ensure_runtime_deps()

import json
import re

import fitz
import proto_modules

ANSWERED_WORDS = ("answered", "answer", "cevap", "key", "cevapli", "cevaplı")
ORIGINAL_WORDS = ("original", "kitap", "soru", "student", "book")
COVER_WORDS = ("kapak", "cover")
AUDIO_DIRS = ("audio", "audios", "ses", "sesler")
VIDEO_DIRS = ("video", "videos")


def _pdfs(folder):
    out = []
    for base in (folder, os.path.join(folder, "raw")):
        if not os.path.isdir(base):
            continue
        for f in sorted(os.listdir(base)):
            if f.lower().endswith(".pdf") and not f.startswith("."):
                out.append(os.path.join(base, f))
    return out


def _pick(paths, words, exclude=()):
    for p in paths:
        low = os.path.basename(p).lower()
        if any(w in low for w in words) and not any(w in low for w in exclude):
            return p
    return None


def _subdir(folder, names):
    for base in (folder, os.path.join(folder, "raw")):
        if not os.path.isdir(base):
            continue
        for d in sorted(os.listdir(base)):
            if d.lower() in names and os.path.isdir(os.path.join(base, d)):
                return os.path.join(base, d)
    return ""


def _clean(name):
    name = re.sub(r"(?i)\b(cevapli|cevaplı|cevap|answered|answer\s*key|kitap|"
                  r"soru|original|student|kapak|cover)\b", " ", name)
    name = re.sub(r"[_\-]+", " ", name)
    return re.sub(r"\s{2,}", " ", name).strip(" -_.")


def _title(folder, original, cover=None):
    """The book's title: whichever name on hand says the most.

    The folder is not always the best source ("Testing Guide" for a folder
    holding "The Chase 6 - Testing Guide Kitap.pdf"), and neither is the book
    PDF — plenty of folders ship it as a bare "original.pdf". The cover's
    filename usually carries the full title, so it counts too.
    """
    names = [os.path.basename(os.path.normpath(folder))]
    for p in (original, cover):
        if p:
            names.append(os.path.splitext(os.path.basename(p))[0])
    best = ""
    for n in names:
        c = _clean(n)
        if c.lower() in ("original", "answered", "book", "raw"):
            continue          # a generic file name says nothing
        if len(c) > len(best):
            best = c
    return best or "Untitled"


def main():
    if len(sys.argv) < 2:
        print(json.dumps({"ok": False, "error": "usage: inspect_source.py <folder>"}))
        return 1
    folder = os.path.abspath(sys.argv[1])
    if not os.path.isdir(folder):
        print(json.dumps({"ok": False, "error": "not a folder: %s" % folder}))
        return 1

    pdfs = _pdfs(folder)
    if not pdfs:
        print(json.dumps({"ok": False, "error": "no PDF found in %s" % folder}))
        return 1

    cover = _pick(pdfs, COVER_WORDS)
    rest = [p for p in pdfs if p != cover]
    answered = _pick(rest, ANSWERED_WORDS)
    original = _pick([p for p in rest if p != answered], ORIGINAL_WORDS,
                     exclude=ANSWERED_WORDS)
    # Fall back to file order: publishers are not consistent, but a folder
    # holding exactly two PDFs is unambiguous once the answered one is known.
    leftover = [p for p in rest if p not in (answered, original)]
    if original is None:
        original = leftover.pop(0) if leftover else None
    if answered is None and leftover:
        answered = leftover.pop(0)
    if original is None:
        print(json.dumps({"ok": False, "error": "could not tell which PDF is the book"}))
        return 1

    doc = fitz.open(original)
    pages = doc.page_count
    warnings = []
    if answered:
        a = fitz.open(answered)
        if a.page_count != pages:
            warnings.append("original has %d pages, answered has %d"
                            % (pages, a.page_count))
    else:
        warnings.append("no answered PDF found - nothing to diff, so no answers")

    try:
        mods, via = proto_modules.detect(folder, pdf_path=original)
    except Exception as e:                      # never block Create on this
        mods, via = [], "failed: %s" % e
    if not mods:
        mods = [{"name": "Module 1", "start": 1, "end": pages}]
        via = via or "fallback"
        warnings.append("no modules detected - using one module for the book")

    print(json.dumps({
        "ok": True,
        "folder": folder,
        "title": _title(folder, original, cover),
        "original": original,
        "answered": answered or "",
        "cover": cover or "",
        "audio": _subdir(folder, AUDIO_DIRS),
        "video": _subdir(folder, VIDEO_DIRS),
        "pages": pages,
        "modules_via": via,
        "modules": [{"module_name": m["name"], "start": m["start"], "end": m["end"]}
                    for m in mods],
        "warnings": warnings,
    }, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    sys.exit(main())
