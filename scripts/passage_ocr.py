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

# Where a Windows tesseract ends up. shutil.which() is tried first and usually
# answers -- but not in the process that just ran the installer: PATH there is a
# copy taken when that process started, and the entry the installer adds only
# reaches processes started after it. So a fresh install has to be recognised by
# looking, and the installer's "just for me" option puts it under LOCALAPPDATA
# rather than in either Program Files.
_WINDOWS_GUESSES = tuple(p for p in (
    r"C:\Program Files\Tesseract-OCR\tesseract.exe",
    r"C:\Program Files (x86)\Tesseract-OCR\tesseract.exe",
    os.path.join(os.environ.get("LOCALAPPDATA") or "",
                 "Programs", "Tesseract-OCR", "tesseract.exe"),
    os.path.join(os.environ.get("LOCALAPPDATA") or "",
                 "Tesseract-OCR", "tesseract.exe"),
) if os.path.isabs(p))


def app_data_dir():
    """Where the app keeps what it downloaded for itself, per platform.

    Mirrors Qt's QStandardPaths::AppDataLocation, where the editor already
    extracts its scripts. Computed here rather than derived from this file's own
    location so it names the same directory whether the scripts run from the
    extracted copy or from a source checkout (FLOWBOOK_SCRIPTS_DIR) — a language
    pack downloaded once should not go missing because the author started the
    app the other way."""
    if os.name == "nt":
        base = os.environ.get("APPDATA") or os.path.expanduser(r"~\AppData\Roaming")
    elif sys.platform == "darwin":
        base = os.path.expanduser("~/Library/Application Support")
    else:
        base = os.environ.get("XDG_DATA_HOME") or os.path.expanduser("~/.local/share")
    return os.path.join(base, "FlowBookDataHelper")


def tessdata_dir():
    """Our own language-data directory. Packs land here rather than in the
    tesseract installation, which on Windows sits under Program Files and would
    need an elevation prompt to write to. deps.py writes it, this reads it, and
    both ask this function so they cannot disagree about where it is."""
    return os.path.join(app_data_dir(), "tessdata")


def _registry_guesses():
    """Where the UB-Mannheim installer recorded that it put itself.

    The fixed guesses above cover the two usual directories; this covers the
    rest, because the installer lets the user pick one. Its own uninstall key is
    written wherever that was, so it is the one answer that is right for any
    install -- and it costs nothing when tesseract is absent, because then the
    key is absent too."""
    if os.name != "nt":
        return []
    try:
        import winreg
    except Exception:
        return []
    key = r"SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Tesseract-OCR"
    out = []
    for root in (winreg.HKEY_LOCAL_MACHINE, winreg.HKEY_CURRENT_USER):
        for flag in (0, winreg.KEY_WOW64_64KEY, winreg.KEY_WOW64_32KEY):
            try:
                with winreg.OpenKey(root, key, 0, winreg.KEY_READ | flag) as k:
                    loc = winreg.QueryValueEx(k, "InstallLocation")[0]
            except Exception:
                continue
            if loc:
                out.append(os.path.join(loc, "tesseract.exe"))
    return out


def _binary():
    """Path to tesseract, or None. Cached on the function."""
    if not hasattr(_binary, "_cached"):
        found = shutil.which("tesseract")
        if not found and os.name == "nt":
            found = next((p for p in list(_WINDOWS_GUESSES) + _registry_guesses()
                          if os.path.exists(p)), None)
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


def installed_langs():
    """Language codes this machine can OCR with — ours and tesseract's own."""
    if not available():
        return set()
    out = set()
    try:
        res = subprocess.run([_binary(), "--list-langs"],
                             capture_output=True, text=True, timeout=30)
        for line in res.stdout.splitlines()[1:]:
            code = line.strip()
            if code:
                out.add(code)
    except Exception:
        pass
    d = tessdata_dir()
    if os.path.isdir(d):
        out |= {f[:-len(".traineddata")] for f in os.listdir(d)
                if f.endswith(".traineddata")}
    return out


def _resolve_lang(code):
    """Where to read `code` from: (tessdata dir | None, code | None, note | None).

    A missing language pack is the quiet failure this exists to prevent. The
    Windows installer ships English and nothing else unless the user ticks the
    extra languages, and a German book handed to a tesseract without `deu` does
    not complain — it returns nothing, and the author reads that as "OCR could
    not read the page" rather than "you are missing a 1.5MB file".

    --tessdata-dir REPLACES the search path rather than adding to it, so it is
    passed only when the language we want is in ours; one the tesseract
    installation already has is read from there."""
    if not code:
        return None, None, None
    d = tessdata_dir()
    if os.path.exists(os.path.join(d, code + ".traineddata")):
        return d, code, None
    if code in installed_langs():
        return None, code, None
    return None, None, (f"'{code}' dil paketi kurulu degil — Ingilizce ile "
                        f"okundu. Dependencies penceresinden yukleyebilirsiniz.")


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


def _run(png_path, lang, data_dir=None):
    """tesseract's TSV for one image: [{text, conf, left, top, width, height,
    line}] . Empty when it fails — a passage that cannot be read is reported by
    the caller as no words, never as a crash."""
    # TSV is asked for with -c rather than by naming the `tsv` config file: that
    # file lives in the tesseract installation's tessdata/configs/, and
    # --tessdata-dir points the whole search elsewhere. With our own language
    # directory in play `tsv` stopped being found ("read_params_file: Can't open
    # tsv") and the run quietly produced plain text, which parses to no words.
    cmd = [_binary(), png_path, "stdout", "--psm", "6",
           "-c", "tessedit_create_tsv=1"]
    if lang:
        cmd[3:3] = ["-l", lang]
    if data_dir:
        cmd[3:3] = ["--tessdata-dir", data_dir]
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
    data_dir, code, note = _resolve_lang(_LANG.get((lang or "").lower()))
    if note:
        print(f"  WARNING: {note}", flush=True)
    try:
        pix.save(tmp.name)
        toks = _clean(_to_png_space(_run(tmp.name, code, data_dir), x, y, sx, sy))
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
