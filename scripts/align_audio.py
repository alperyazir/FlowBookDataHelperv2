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

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from _bootstrap import ensure_runtime_deps, ensure_align_deps

ensure_runtime_deps()   # fitz
ensure_align_deps()     # whisperx (+ torch)

import fitz

_NORM = re.compile(r"[^a-z0-9']")
norm = lambda s: _NORM.sub("", s.lower())

# Below this mean alignment confidence we flag the passage for human review.
REVIEW_SCORE = 0.30


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


def words_in_crop(pdf_path, page_idx, rect_px, png_w, png_h):
    """Words whose center falls inside the crop rect, in reading order.

    Returns [{text, bbox:{x,y,w,h}}] with bbox in PNG pixel space.
    """
    doc = fitz.open(pdf_path)
    if page_idx < 0 or page_idx >= len(doc):
        doc.close()
        raise IndexError(f"Page index {page_idx} out of range (0-{len(doc)-1})")
    page = doc.load_page(page_idx)
    sx, sy = png_w / page.rect.width, png_h / page.rect.height
    cx0, cy0, cw, ch = rect_px
    cx1, cy1 = cx0 + cw, cy0 + ch
    ws = page.get_text("words")
    ws.sort(key=lambda w: (w[5], w[6], w[7]))  # block, line, word
    out = []
    # Some source PDFs stack the same text layer multiple times (invisible
    # duplicate words at identical coordinates). Left unchecked that inflates
    # the passage with repeats and wrecks forced alignment (every word matches
    # several audio positions). Drop a word if one with the same text AND a
    # near-identical position was already kept; genuine repeats sit at distinct
    # positions (different line/column) and survive.
    seen = set()
    for w in ws:
        x0, y0, x1, y1 = w[0] * sx, w[1] * sy, w[2] * sx, w[3] * sy
        mx, my = (x0 + x1) / 2, (y0 + y1) / 2
        if not (cx0 <= mx <= cx1 and cy0 <= my <= cy1):
            continue
        key = (w[4], round(x0 / 3), round(y0 / 3))  # ~3px position tolerance
        if key in seen:
            continue
        seen.add(key)
        out.append({
            "text": w[4],
            "bbox": {"x": round(x0), "y": round(y0),
                     "w": round(x1 - x0), "h": round(y1 - y0)},
        })
    doc.close()
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


def align(words, audio_path, lang):
    """Forced-align the known passage text to audio. Returns (aligned, dur)."""
    import whisperx
    device = "cpu"
    text = " ".join(w["text"] for w in words)
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
    print(f"PROGRESS: Aligning {len(words)} words to {dur:.0f}s of audio…",
          flush=True)
    segs = [{"text": text, "start": 0.0, "end": dur}]
    res = whisperx.align(segs, model_a, meta, audio, device,
                         return_char_alignments=False)
    aligned = []
    for seg in res["segments"]:
        aligned.extend(seg.get("words", []))
    return aligned, dur


def attach_timing(words, aligned):
    """Map aligned timestamps onto the pdf words by normalized sequence
    alignment. Returns mean score and count of words with no own timestamp."""
    a = [norm(w["text"]) for w in words]
    b = [norm(w.get("word", "")) for w in aligned]
    sm = difflib.SequenceMatcher(a=a, b=b, autojunk=False)
    for w in words:
        w["start"] = None
        w["end"] = None
        w["score"] = None
    for tag, i1, i2, j1, j2 in sm.get_opcodes():
        if tag in ("equal", "replace"):
            for k in range(min(i2 - i1, j2 - j1)):
                aw = aligned[j1 + k]
                if aw.get("start") is not None:
                    words[i1 + k]["start"] = round(aw["start"], 3)
                    words[i1 + k]["end"] = round(aw["end"], 3)
                    words[i1 + k]["score"] = round(float(aw.get("score", 0)), 3)
    scores = [w["score"] for w in words if w["score"] is not None]
    mean_score = round(sum(scores) / len(scores), 3) if scores else 0.0
    missing = sum(1 for w in words if w["start"] is None)
    # Forward-fill gaps so the reader's highlight never stalls.
    last = 0.0
    for w in words:
        if w["start"] is None:
            w["start"] = last
        if w["end"] is None:
            w["end"] = w["start"]
        last = w["end"]
    return mean_score, missing


def merge_into_audio_json(path, audio_id, entry):
    data = {}
    if os.path.exists(path):
        try:
            with open(path) as f:
                data = json.load(f)
        except Exception:
            data = {}
    data[audio_id] = entry
    os.makedirs(os.path.dirname(path), exist_ok=True)
    tmp = path + ".tmp"
    with open(tmp, "w") as f:
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
    aligned, dur = align(words, audio_path, lang)
    print(f"Aligned {len(aligned)} words against {dur:.2f}s audio", flush=True)
    mean_score, missing = attach_timing(words, aligned)
    needs_review = (mean_score < REVIEW_SCORE) or (missing > len(words) * 0.2)
    print(f"Mean score={mean_score}, unaligned={missing}, "
          f"needs_review={needs_review}", flush=True)
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
        "words": words,
    }
    merge_into_audio_json(audio_json_path, audio_id, entry)
    print(f"Wrote {audio_id} -> {audio_json_path}", flush=True)
    # Compact summary for the C++ caller (parsed off stdout, before "OK").
    summary = {"audio_id": audio_id, "words": len(words),
               "mean_score": mean_score, "needs_review": needs_review}
    print("SUMMARY: " + json.dumps(summary, ensure_ascii=False), flush=True)
    print("OK", flush=True)


if __name__ == "__main__":
    main()
