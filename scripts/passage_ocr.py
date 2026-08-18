"""Reading a passage that the PDF draws as a picture.

Most books hand the crop a text layer and passage_text simply reads it. Some do
not: on Switch to CLIL p49 the whole paragraph — nine lines of it — is one
grayscale image dropped on the page, and the text layer over that region is
empty. The aligner then had nothing to align, wrote a passage made of the six
answer boxes alone, and the highlight sat on the boxes while the narrator read a
paragraph nobody had told it about.

The words are legible; they are simply not text yet. So render the crop and read
them, and hand back the same {text, bbox} shape passage_text produces, in the
same PNG pixel space, so everything downstream (gaps from the answer boxes,
marker numbers, reading order, alignment) works exactly as it does for a page
that came with its text.

tesseract is used rather than a pip-installable engine because this needs
WORD boxes, and the pip-only engines do not give them. rapidocr-onnxruntime
(13.8MB, no binary, 1.2s on this crop) returns one box per line — twelve for the
whole paragraph — and splitting those into words by the whitespace columns, with
cv2, came out ±1-3 words per line on this very page. One wrong split shifts every
box after it on the line, which is precisely the thing the highlight cannot
survive. tesseract's --psm 6 tsv output is word boxes by construction.

It is a native binary, so it is not required: this module reports itself absent
(available() -> False) and the caller says what to install. Nothing else in the
pipeline needs it, and only a crop with no text layer at all ever calls in here.
"""
import os
import shutil
import subprocess
import sys
import tempfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

# Rendering scale over PDF points. The page images are ~2.08x point size, and
# OCR wants more than that; 4x put every real word on this page over 95%
# confidence. Higher costs render time and buys nothing measurable.
_ZOOM = 4.0

# Confidence is NOT what separates the passage from the noise here — see
# _clean(). This only drops what tesseract itself calls a non-result.
_MIN_CONF = -1.0

# A token shorter than this fraction of the median token height is not part of
# the running text. Two things hit it, and both are exactly what we want gone:
# the dotted cloze gaps, which are a baseline rule and come back 2px tall against
# 17px for the body, and the superscript numerals labelling them, at 9px. It is
# the same test passage_text applies to the text layer with the font size
# (_MARKER_SIZE); the image just measures it a different way.
_MIN_HEIGHT = 0.6

_WINDOWS_GUESSES = (
    r"C:\Program Files\Tesseract-OCR\tesseract.exe",
    r"C:\Program Files (x86)\Tesseract-OCR\tesseract.exe",
)


def _binary():
    """Path to tesseract, or None. Cached on the function."""
    if not hasattr(_binary, "_cached"):
        found = shutil.which("tesseract")
        if not found and os.name == "nt":
            found = next((p for p in _WINDOWS_GUESSES if os.path.exists(p)), None)
        if not found and sys.platform == "darwin":
            found = next((p for p in ("/opt/homebrew/bin/tesseract",
                                      "/usr/local/bin/tesseract")
                          if os.path.exists(p)), None)
        _binary._cached = found
    return _binary._cached


def available():
    return _binary() is not None


INSTALL_HINT = ("install tesseract — macOS: 'brew install tesseract', "
                "Windows: the UB-Mannheim installer")


def _clean(toks):
    """Drop what is on the page but not in the passage.

    Confidence looked like the obvious filter and is the wrong one: on the page
    that prompted this, 'sea' and 'and' — ordinary words, correctly read — came
    back at 0.0 because they sit on a line the dotted gaps also cross, while the
    gap garbage itself scored 24.9. Height separates them cleanly and for a
    reason: a rule of dots has no x-height, and a superscript is a superscript.
    """
    if not toks:
        return []
    heights = sorted(t["bbox"]["h"] for t in toks)
    body = heights[len(heights) // 2]
    return [t for t in toks if t["bbox"]["h"] >= _MIN_HEIGHT * body]


def _run(png_path, lang):
    """tesseract's TSV for one image: [{text, conf, left, top, width, height,
    line}] . Empty when it fails — a passage that cannot be read is reported by
    the caller as no words, never as a crash."""
    cmd = [_binary(), png_path, "stdout", "--psm", "6", "tsv"]
    if lang:
        cmd[3:3] = ["-l", lang]
    try:
        res = subprocess.run(cmd, capture_output=True, text=True, timeout=120)
    except Exception as e:
        print(f"  WARNING: tesseract failed: {e}", flush=True)
        return []
    rows = [r.split("\t") for r in res.stdout.splitlines()]
    if not rows:
        return []
    idx = {k: i for i, k in enumerate(rows[0])}
    need = ("text", "conf", "left", "top", "width", "height", "line_num")
    if not all(k in idx for k in need):
        return []
    out = []
    for r in rows[1:]:
        if len(r) != len(rows[0]) or not r[idx["text"]].strip():
            continue
        try:
            conf = float(r[idx["conf"]])
            box = [int(r[idx[k]]) for k in ("left", "top", "width", "height")]
            line = int(r[idx["line_num"]])
        except ValueError:
            continue
        if conf <= _MIN_CONF:
            continue
        out.append({"text": r[idx["text"]], "conf": conf,
                    "box": box, "line": line})
    return out


# tesseract writes ISO 639-2 ("eng"), the book writes what whisperx wants ("en").
_LANG = {"en": "eng", "de": "deu", "tr": "tur", "fr": "fra", "es": "spa",
         "it": "ita", "pt": "por", "ru": "rus", "ar": "ara"}


def read_crop(page, rect_px, png_w, png_h, lang=None):
    """The words under `rect_px`, read off the rendered page.

    `page` is an open fitz page; rect_px is (x, y, w, h) in PNG pixels, the space
    every box in config.json and audio.json is in. Returns
    [{text, bbox:{x,y,w,h}, _size, _line}] in that same space, in reading order,
    unclassified — the caller decides what is a word, a gap and a number, with
    the same rules it applies to a text layer.

    None (not []) means tesseract is not installed, which is a different thing
    from a crop it could not read and is reported differently.
    """
    if not available():
        return None
    import fitz              # the caller already has it; this module may not
    sx = png_w / page.rect.width          # PDF points -> PNG pixels
    sy = png_h / page.rect.height
    x, y, w, h = rect_px
    clip = fitz.Rect(x / sx, y / sy, (x + w) / sx, (y + h) / sy)
    pix = page.get_pixmap(matrix=fitz.Matrix(_ZOOM, _ZOOM), clip=clip,
                          colorspace=fitz.csGRAY)
    tmp = tempfile.NamedTemporaryFile(suffix=".png", delete=False)
    tmp.close()
    try:
        pix.save(tmp.name)
        toks = _clean(_to_png_space(_run(tmp.name, _LANG.get((lang or "").lower())),
                                    x, y, sx, sy))
    finally:
        try:
            os.unlink(tmp.name)
        except OSError:
            pass
    return toks


def _to_png_space(toks, x0, y0, sx, sy):
    """Rendered-image pixels -> page-PNG pixels."""
    out = []
    for t in toks:
        l, tp, w, h = t["box"]
        bbox = {"x": round(x0 + (l / _ZOOM) * sx), "y": round(y0 + (tp / _ZOOM) * sy),
                "w": round((w / _ZOOM) * sx), "h": round((h / _ZOOM) * sy)}
        out.append({"text": t["text"], "bbox": bbox,
                    "_size": bbox["h"], "_line": t["line"]})
    return out
