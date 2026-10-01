"""Bring a book's MP3s to one loudness, so a quiet classroom board is not the
author's problem.

Measured on the published books: about half of them ship their MP3s peaking at
exactly -9.3 dBFS with an integrated loudness of -22…-25 LUFS — some 9 dB of
headroom never used, from the publisher's source files (Lavf59 / LAME3.101),
not from anything the editor does. On a smartboard's small speakers that reads
as "the audio is broken". Their videos sit at -12.6 LUFS, so a page went from a
quiet clip to a loud video. A few books are mixed, ~8 dB apart clip to clip.

The rule, in one place:

  target      -16 LUFS integrated   speech, comfortable on small speakers
  ceiling     -1.5 dBTP true peak   headroom for the MP3 decoder's overshoot
  tolerance   ±1 LU                 a clip already there is left alone, so
                                    a normal book and a second run change nothing

The change is a plain gain (ffmpeg `volume`), never `loudnorm`'s own
processing: in linear mode loudnorm quietly falls back to dynamic compression
whenever the gain would cross the ceiling, and it resamples to 192 kHz on the
way. A gain cannot change how a recording sounds, only how loud it is. When
the ceiling allows less than the full gain the clip lands a little under
-16 — quieter than asked, never squashed.

The re-encode keeps the clip's form: libmp3lame at the same constant bitrate,
sample rate and channel count, with a Xing header, exactly like audio_cbr.

Karaoke: normalize BEFORE aligning, so audio.json's timings describe the file
that ships (the same reasoning as audio_cbr). For books aligned long ago,
measure_shift() reports how far a re-encode moved the audio.
"""
import json
import os
import re
import subprocess
import sys
import tempfile
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import audio_cbr

TARGET_I = -16.0
TARGET_TP = -1.5
TOLERANCE = 1.0
# Under this a "gain" is noise in the measurement, not a change worth a
# re-encode.
MIN_GAIN = 0.5

_NO_WINDOW = subprocess.CREATE_NO_WINDOW if os.name == "nt" else 0


def _run(cmd, timeout=600):
    return subprocess.run(cmd, capture_output=True, timeout=timeout,
                          creationflags=_NO_WINDOW)


def measure(path, ffmpeg=None):
    """{"i": LUFS, "tp": dBTP}, or raises.

    ffmpeg's ebur128 filter, not loudnorm's analysis pass: the same numbers
    (loudnorm is built on it) at about five times the speed, because loudnorm
    resamples to 192 kHz first. Silence, or a clip too short to gate, comes
    back as i=None so callers leave it alone."""
    ffmpeg = ffmpeg or audio_cbr._ffmpeg()
    if not ffmpeg:
        raise RuntimeError("ffmpeg not found")
    r = _run([ffmpeg, "-hide_banner", "-nostdin", "-i", path, "-vn",
              "-af", "ebur128=peak=true", "-f", "null", "-"])
    err = r.stderr.decode("utf-8", "replace")
    tail = err[err.rfind("Summary:"):] if "Summary:" in err else ""
    mi = re.search(r"I:\s*(-?[\d.]+|-inf) LUFS", tail)
    mp = re.search(r"True peak:\s*Peak:\s*(-?[\d.]+|-inf) dBFS", tail)
    if not mi or not mp:
        raise RuntimeError("could not measure: " + err.strip()[-300:])

    def num(v):
        try:
            v = float(v)
        except ValueError:
            return None
        return v if v > -70 else None

    return {"i": num(mi.group(1)), "tp": num(mp.group(1))}


def gain_for(m):
    """dB to add for measurement m: up to the target, capped by the ceiling.
    0 when the clip is silent or already within tolerance."""
    if m["i"] is None or m["tp"] is None:
        return 0.0
    if abs(m["i"] - TARGET_I) <= TOLERANCE:
        return 0.0
    g = min(TARGET_I - m["i"], TARGET_TP - m["tp"])
    return round(g, 2) if abs(g) >= MIN_GAIN else 0.0


def _stream_info(path, ffmpeg):
    """(sample_rate, channels) from `ffmpeg -i`, either may be None."""
    r = _run([ffmpeg, "-hide_banner", "-nostdin", "-i", path], timeout=60)
    err = r.stderr.decode("utf-8", "replace")
    m = re.search(r"Audio: mp3[^\n]*?(\d+) Hz, (mono|stereo)", err)
    if not m:
        return None, None
    return int(m.group(1)), (1 if m.group(2) == "mono" else 2)


def _lame_delay(path):
    """(encoder delay, padding) from the Xing/Info frame's LAME tag, or None.
    A decoder that ignores the tag plays the delay as silence, so two files
    with the same frames and the same delay start every word on the same
    sample."""
    try:
        with open(path, "rb") as fh:
            d = fh.read(64 * 1024)
    except OSError:
        return None
    i = audio_cbr._id3_size(d)
    for magic in (b"Xing", b"Info"):
        k = d.find(magic, i, i + 200)
        if k >= 0:
            break
    else:
        return None
    for enc in (b"LAME", b"Lavc", b"Lavf"):
        tag = d.find(enc, k, k + 200)
        if tag >= 0:
            b = d[tag + 21:tag + 24]
            if len(b) == 3:
                return ((b[0] << 4) | (b[1] >> 4), ((b[1] & 0xF) << 8) | b[2])
    return None


def normalize_file(path, ffmpeg=None, m=None, keep_timing=False):
    """Bring one MP3 to the target in place. Returns a result dict:

        {"dosya", "degisti": False, "i", "tp"}                      left alone
        {"dosya", "degisti": True, "i", "tp", "gain", "yeni_i", "yeni_tp", "kbps"}
        {"dosya", "hata"}                                            failed
        {"dosya", "hata", "hizali": True}   keep_timing and the re-encode
                                            would have moved the audio

    Written beside the original and swapped in only once ffmpeg succeeded and
    the result reads back as a CBR MP3, so a failure or a kill never leaves a
    truncated clip in the book."""
    name = os.path.basename(path)
    ffmpeg = ffmpeg or audio_cbr._ffmpeg()
    if not ffmpeg:
        return {"dosya": name, "hata": "ffmpeg not found"}
    try:
        m = m or measure(path, ffmpeg)
    except Exception as e:  # noqa: BLE001 - reported per file
        return {"dosya": name, "hata": str(e)}
    out = {"dosya": name, "degisti": False, "i": m["i"], "tp": m["tp"]}
    g = gain_for(m)
    if not g:
        return out

    info = audio_cbr.scan_frames(path)
    if info["frames"] == 0:
        return {"dosya": name, "hata": "not an mp3"}
    kbps = (info["bitrates"][0] if len(info["bitrates"]) == 1
            else audio_cbr.target_kbps(info["kbps_avg"]))
    rate, ch = _stream_info(path, ffmpeg)
    cmd = [ffmpeg, "-y", "-hide_banner", "-nostdin", "-loglevel", "error",
           "-i", path, "-map", "0:a:0", "-af", f"volume={g}dB",
           "-c:a", "libmp3lame", "-b:a", f"{kbps}k", "-write_xing", "1"]
    if rate:
        cmd += ["-ar", str(rate)]
    if ch:
        cmd += ["-ac", str(ch)]
    # Keep the ID3 tags (title, artist) the source had.
    cmd += ["-map_metadata", "0", "-id3v2_version", "3"]
    tmp = tempfile.mktemp(suffix=".mp3", dir=os.path.dirname(path) or ".")
    try:
        r = _run(cmd + [tmp])
        if r.returncode != 0:
            raise RuntimeError("ffmpeg failed: "
                               + r.stderr.decode("utf-8", "replace").strip()[-300:])
        after = audio_cbr.scan_frames(tmp)
        if after["frames"] == 0 or len(after["bitrates"]) != 1:
            raise RuntimeError("the re-encode is not a constant-bitrate MP3")
        # A source with no LAME tag (old LAME 3.101 files) gains one: an Info
        # frame and a recorded delay. A decoder that reads the tag (ffmpeg,
        # the reader) plays the same samples at the same times; one that
        # ignores it is off by that one frame, ~26 ms — far inside what the
        # aligner itself resolves. Anything more is left alone.
        if keep_timing and (abs(after["frames"] - info["frames"]) > 1
                            or (_lame_delay(path) is not None
                                and _lame_delay(tmp) != _lame_delay(path))):
            os.remove(tmp)
            return {"dosya": name, "hizali": True,
                    "hata": "the re-encode would move the audio under its karaoke "
                            "timings — normalize it, then re-run karaoke"}
        m2 = measure(tmp, ffmpeg)
        # Windows refuses to replace a file another process holds open (the
        # editor's player, once a clip has been auditioned).
        for attempt in range(8):
            try:
                os.replace(tmp, path)
                break
            except PermissionError:
                if attempt == 7:
                    raise RuntimeError("the file is open in another program — "
                                       "stop playback and try again")
                time.sleep(0.25)
    except Exception as e:  # noqa: BLE001 - reported per file
        if os.path.exists(tmp):
            os.remove(tmp)
        return {"dosya": name, "hata": str(e)}
    out.update(degisti=True, gain=g, yeni_i=m2["i"], yeni_tp=m2["tp"], kbps=kbps)
    return out


# ---------------------------------------------------------------------------
# Whole book

AUDIO_DIRS = {"audio"}


def find_audio(book):
    """Every MP3 under the book's audio folder, junk and hidden files left out."""
    from pathlib import Path
    import flowbook_normalize as fn
    book = Path(book)
    out = []
    try:
        roots = [d for d in book.iterdir() if d.is_dir() and d.name.lower() in AUDIO_DIRS]
    except OSError:
        return out
    for root in roots:
        for p in root.rglob("*"):
            rel = p.relative_to(book)
            if (p.suffix.lower() != ".mp3" or not p.is_file()
                    or any(part.startswith(".") for part in rel.parts)
                    or fn.is_junk_path(p, book)):
                continue
            out.append(p)
    return sorted(out)


def _aligned_names(book):
    """File names audio/audio.json has karaoke timings for."""
    from pathlib import Path
    for d in AUDIO_DIRS:
        f = Path(book) / d / "audio.json"
        if f.is_file():
            try:
                data = json.loads(f.read_text(encoding="utf-8"))
            except (OSError, ValueError, UnicodeDecodeError):
                return set()
            return set(data) if isinstance(data, dict) else set()
    return set()


def _cache_file(book):
    # .pkgcache sits next to config.json and never leaves the editor: export
    # and the zip both drop it.
    return os.path.join(str(book), ".pkgcache", "audio_levels.json")


def _measure_all(book, paths, ffmpeg):
    """{path: measurement or {"hata"}}; a measurement is reused while the
    file's size and mtime are unchanged, so checking a book a second time is
    instant."""
    from concurrent.futures import ThreadPoolExecutor
    cache_path = _cache_file(book)
    try:
        with open(cache_path, encoding="utf-8") as fh:
            cache = json.load(fh)
    except (OSError, ValueError):
        cache = {}
    out, todo = {}, []
    for p in paths:
        st = p.stat()
        key = p.relative_to(book).as_posix()
        c = cache.get(key)
        if c and c.get("size") == st.st_size and c.get("mtime") == int(st.st_mtime):
            out[p] = {"i": c["i"], "tp": c["tp"]}
        else:
            todo.append(p)

    def one(p):
        try:
            return p, measure(str(p), ffmpeg)
        except Exception as e:  # noqa: BLE001 - reported per file
            return p, {"hata": str(e)}

    with ThreadPoolExecutor(max_workers=max(2, min(8, (os.cpu_count() or 4)))) as ex:
        for p, m in ex.map(one, todo):
            out[p] = m
            if "hata" not in m:
                st = p.stat()
                cache[p.relative_to(book).as_posix()] = {
                    "size": st.st_size, "mtime": int(st.st_mtime), "i": m["i"], "tp": m["tp"]}
    if todo:
        try:
            os.makedirs(os.path.dirname(cache_path), exist_ok=True)
            with open(cache_path, "w", encoding="utf-8") as fh:
                json.dump(cache, fh)
        except OSError:
            pass
    return out


def check_book(book):
    """Every MP3 in the book against the rule; writes nothing but the cache.

    {toplam, duzeltilecek, okunamayan, ffmpeg_yok, hedef, sesler: [row]}; each
    row {dosya, durum ("uygun" | "duzeltilecek" | "sessiz" | "okunamayan"),
    i, tp, gain} or {dosya, durum, hata}.
    """
    from pathlib import Path
    book = Path(book)
    paths = find_audio(book)
    r = {"toplam": len(paths), "duzeltilecek": 0, "okunamayan": 0, "ffmpeg_yok": False,
         "hedef": TARGET_I, "sesler": []}
    if not paths:
        return r
    ffmpeg = audio_cbr._ffmpeg()
    if not ffmpeg:
        r["ffmpeg_yok"] = True
        return r
    for p, m in _measure_all(book, paths, ffmpeg).items():
        row = {"dosya": p.relative_to(book).as_posix()}
        if "hata" in m:
            row.update(durum="okunamayan", hata=m["hata"])
            r["okunamayan"] += 1
        elif m["i"] is None:
            row.update(durum="sessiz")
        else:
            g = gain_for(m)
            row.update(i=m["i"], tp=m["tp"], gain=g, durum="duzeltilecek" if g else "uygun")
            if g:
                r["duzeltilecek"] += 1
        r["sesler"].append(row)
    r["sesler"].sort(key=lambda x: x["dosya"])
    return r


def optimize_book(book, progress=None, stopped=lambda: False):
    """Normalizes every clip check_book calls "duzeltilecek", in place.

    progress(i, n, dosya) before each clip. A clip audio.json has karaoke
    timings for is only replaced when the re-encode keeps its frame count and
    encoder delay — then every timing still lands on the same sample;
    otherwise it is left as it is and listed under hizali_atlanan.

    {normalize_edilen: [row], basarisiz: [{dosya, hata}],
     hizali_atlanan: [dosya], iptal?} or {hata}.
    """
    from pathlib import Path
    book = Path(book)
    ffmpeg = audio_cbr._ffmpeg()
    if not ffmpeg:
        return {"hata": "ffmpeg isn't installed — install it from Help ▸ Dependencies"}
    aligned = _aligned_names(book)
    measured = _measure_all(book, find_audio(book), ffmpeg)
    todo = [(p, m) for p, m in measured.items()
            if "hata" not in m and m["i"] is not None and gain_for(m)]
    done, failed, skipped = [], [], []
    for i, (p, m) in enumerate(sorted(todo)):
        if stopped():
            return {"normalize_edilen": done, "basarisiz": failed,
                    "hizali_atlanan": skipped, "iptal": True}
        rel = p.relative_to(book).as_posix()
        if progress:
            progress(i, len(todo), rel)
        r = normalize_file(str(p), ffmpeg, m, keep_timing=p.name in aligned)
        r["dosya"] = rel
        if r.get("hizali"):
            skipped.append(rel)
        elif "hata" in r:
            failed.append({"dosya": rel, "hata": r["hata"]})
        elif r["degisti"]:
            done.append(r)
    return {"normalize_edilen": done, "basarisiz": failed, "hizali_atlanan": skipped}
