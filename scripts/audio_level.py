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

Clearer voice (clarity=True), for recordings that are muffled as well as quiet.
My English Path's LS books drew "quiet and muffled on the board" complaints
that a gain alone did not fix: the publisher's mix sits dark — boxy around
400 Hz, little in the 2–5 kHz band consonants live in. On the board this one
was heard against the original and the gain-only file and chosen:

  highpass 70 Hz, -3.5 dB at 400 Hz, +4 dB at 3 kHz, +1.5 dB at 6.5 kHz
  then the gain that puts the EQ'd clip at -16 LUFS (+0.3 for the limiter)
  then a limiter at -1.5 dBFS instead of the true-peak cap

so every clip lands on -16 instead of under it. The EQ adds ~5 ms of phase
delay and no frames, so karaoke timings still hold. A clip done this way
carries a "flowbook_audio=clarity-1" tag (ID3 TXXX, MP4 metadata): it is
never EQ'd twice, and counts as level from then on.

It is the author's choice, never automatic: a clear recording would only get
brighter. check_book() suggests it — "koyuluk", the 200–600 Hz band's level
over the 2–5 kHz band's, median over the book's clips: My English Path's books
11.2–13.1 dB, Campus (heard as clear) 9.1, My English Path after the EQ 7.4.
Over MUFFLED the book is called muffled.

Videos: the book's MP4/MOV videos are measured and leveled too, with the same
rule — only their audio is re-encoded (AAC, the source's rate and channels),
the picture is copied. My English Path 2's videos sat at -21…-24 LUFS, a drop
from the clips around them. Formats the Windows reader can't play are
video_compat's job; this leaves them alone.
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

CLARITY_EQ = ("highpass=f=70,equalizer=f=400:t=q:w=1.0:g=-3.5,"
              "equalizer=f=3000:t=q:w=0.8:g=4,equalizer=f=6500:t=q:w=1.0:g=1.5")
# 0.84 is -1.5 dBFS; release short enough that a loud syllable doesn't dip
# the next word.
CLARITY_LIMIT = "alimiter=limit=0.84:attack=5:release=60:level=disabled:asc=1"
# What the limiter takes off the integrated loudness, added back up front.
CLARITY_HEADROOM = 0.3
MARK_KEY, MARK = "flowbook_audio", "clarity-1"
# koyuluk (dB) over which a book's voices are called muffled.
MUFFLED = 10.5

# The videos whose audio is leveled here: the containers the reader opens.
VIDEO_EXTS = {".mp4", ".m4v", ".mov"}

_NO_WINDOW = subprocess.CREATE_NO_WINDOW if os.name == "nt" else 0


def _run(cmd, timeout=600):
    return subprocess.run(cmd, capture_output=True, timeout=timeout,
                          creationflags=_NO_WINDOW)


def _num(v):
    try:
        v = float(v)
    except ValueError:
        return None
    return v if v > -70 else None


# Loudness and true peak of the first audio stream, and beside it the level of
# the 200–600 Hz and 2–5 kHz bands (mono, whole clip) for koyuluk.
_MEASURE_GRAPH = (
    "[0:a:0]asplit=2[m][t];[m]ebur128=peak=true:framelog=verbose[o];"
    "[t]aformat=channel_layouts=mono,asplit=2[a][b];"
    "[a]highpass=f=200,lowpass=f=600,astats@lo[l];"
    "[b]highpass=f=2000,lowpass=f=5000,astats@hi[h]")


def measure(path, ffmpeg=None):
    """{"i": LUFS, "tp": dBTP, "koyuluk": dB, "netlik": bool}, or raises.

    ffmpeg's ebur128 filter, not loudnorm's analysis pass: the same numbers
    (loudnorm is built on it) at about five times the speed, because loudnorm
    resamples to 192 kHz first. Silence, or a clip too short to gate, comes
    back as i=None so callers leave it alone; so does a video with no sound.
    netlik: the clip carries the clearer-voice tag. One ffmpeg run for all."""
    ffmpeg = ffmpeg or audio_cbr._ffmpeg()
    if not ffmpeg:
        raise RuntimeError("ffmpeg not found")
    r = _run([ffmpeg, "-hide_banner", "-nostdin", "-i", path, "-filter_complex", _MEASURE_GRAPH,
              "-map", "[o]", "-f", "null", "-", "-map", "[l]", "-f", "null", "-",
              "-map", "[h]", "-f", "null", "-"])
    err = r.stderr.decode("utf-8", "replace")
    if "matches no streams" in err:
        return {"i": None, "tp": None, "koyuluk": None, "netlik": False}
    tail = err[err.rfind("Summary:"):] if "Summary:" in err else ""
    mi = re.search(r"I:\s*(-?[\d.]+|-inf) LUFS", tail)
    mp = re.search(r"True peak:\s*Peak:\s*(-?[\d.]+|-inf) dBFS", tail)
    if not mi or not mp:
        raise RuntimeError("could not measure: " + err.strip()[-300:])
    # astats prints each channel, then Overall: the last value is the whole clip.
    bands = []
    for name in ("lo", "hi"):
        v = re.findall(r"\[astats@" + name + r" @ [^\]]*\] RMS level dB: (-?[\d.]+|-inf)", err)
        bands.append(_num(v[-1]) if v else None)
    koyuluk = (round(bands[0] - bands[1], 1)
               if None not in bands else None)
    netlik = re.search(r"^\s*" + MARK_KEY + r"\s*:\s*" + re.escape(MARK) + r"\s*$",
                       err[:err.find("Stream #")] if "Stream #" in err else err,
                       re.M | re.I) is not None
    return {"i": _num(mi.group(1)), "tp": _num(mp.group(1)), "koyuluk": koyuluk, "netlik": netlik}


def _eq_loudness(path, ffmpeg):
    """Integrated loudness of the clip after CLARITY_EQ, or None."""
    r = _run([ffmpeg, "-hide_banner", "-nostdin", "-i", path, "-vn",
              "-af", CLARITY_EQ + ",ebur128=framelog=verbose", "-f", "null", "-"])
    err = r.stderr.decode("utf-8", "replace")
    tail = err[err.rfind("Summary:"):] if "Summary:" in err else ""
    mi = re.search(r"I:\s*(-?[\d.]+|-inf) LUFS", tail)
    return _num(mi.group(1)) if mi else None


def gain_for(m):
    """dB to add for measurement m: up to the target, capped by the ceiling.
    0 when the clip is silent, already within tolerance, or already done
    with the clearer voice."""
    if m["i"] is None or m["tp"] is None or m.get("netlik"):
        return 0.0
    if abs(m["i"] - TARGET_I) <= TOLERANCE:
        return 0.0
    g = min(TARGET_I - m["i"], TARGET_TP - m["tp"])
    return round(g, 2) if abs(g) >= MIN_GAIN else 0.0


def _chain(path, ffmpeg, m, clarity):
    """(the -af chain, its gain) that brings the clip to the rule, or
    (None, 0) to leave it as it is."""
    if m["i"] is None or m.get("netlik"):
        return None, 0.0
    if clarity:
        i = _eq_loudness(path, ffmpeg)
        if i is None:
            return None, 0.0
        g = round(TARGET_I - i + CLARITY_HEADROOM, 2)
        return f"{CLARITY_EQ},volume={g}dB,{CLARITY_LIMIT}", g
    g = gain_for(m)
    return (f"volume={g}dB", g) if g else (None, 0.0)


def _swap_in(tmp, path):
    """os.replace(tmp, path), waiting out a short hold: Windows refuses to
    replace a file another process has open (the editor's player, once a clip
    has been auditioned)."""
    for attempt in range(8):
        try:
            os.replace(tmp, path)
            return
        except PermissionError:
            if attempt == 7:
                raise RuntimeError("the file is open in another program — "
                                   "stop playback and try again")
            time.sleep(0.25)


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


def normalize_file(path, ffmpeg=None, m=None, keep_timing=False, clarity=False):
    """Bring one MP3 to the target in place; clarity: with the clearer voice
    (see the top of this file). Returns a result dict:

        {"dosya", "degisti": False, "i", "tp"}                      left alone
        {"dosya", "degisti": True, "i", "tp", "gain", "yeni_i", "yeni_tp", "kbps",
         "netlik"}
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
    af, g = _chain(path, ffmpeg, m, clarity)
    if not af:
        return out

    info = audio_cbr.scan_frames(path)
    if info["frames"] == 0:
        return {"dosya": name, "hata": "not an mp3"}
    kbps = (info["bitrates"][0] if len(info["bitrates"]) == 1
            else audio_cbr.target_kbps(info["kbps_avg"]))
    rate, ch = _stream_info(path, ffmpeg)
    cmd = [ffmpeg, "-y", "-hide_banner", "-nostdin", "-loglevel", "error",
           "-i", path, "-map", "0:a:0", "-af", af,
           "-c:a", "libmp3lame", "-b:a", f"{kbps}k", "-write_xing", "1"]
    if rate:
        cmd += ["-ar", str(rate)]
    if ch:
        cmd += ["-ac", str(ch)]
    # Keep the ID3 tags (title, artist) the source had.
    cmd += ["-map_metadata", "0", "-id3v2_version", "3"]
    if clarity:
        cmd += ["-metadata", f"{MARK_KEY}={MARK}"]
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
        _swap_in(tmp, path)
    except Exception as e:  # noqa: BLE001 - reported per file
        if os.path.exists(tmp):
            os.remove(tmp)
        return {"dosya": name, "hata": str(e)}
    out.update(degisti=True, gain=g, yeni_i=m2["i"], yeni_tp=m2["tp"], kbps=kbps,
               netlik=clarity)
    return out


def _video_audio(path, ffmpeg):
    """(sample_rate, channels, kbps) of a video's first audio stream from
    `ffmpeg -i`, any of them None."""
    r = _run([ffmpeg, "-hide_banner", "-nostdin", "-i", path], timeout=60)
    err = r.stderr.decode("utf-8", "replace")
    line = re.search(r"Stream #[^\n]*Audio:[^\n]*", err)
    if not line:
        return None, None, None
    line = line.group(0)
    rate = re.search(r"(\d+) Hz", line)
    ch = re.search(r"Hz, (mono|stereo|[\d.]+(?:\(\w+\))?)", line)
    kb = re.search(r"(\d+) kb/s", line)
    chans = None
    if ch:
        chans = 1 if ch.group(1) == "mono" else 2
    return (int(rate.group(1)) if rate else None, chans,
            int(kb.group(1)) if kb else None)


def normalize_video(path, ffmpeg=None, m=None, clarity=False):
    """Bring one video's audio to the target in place, the picture copied as
    it is. Result dicts as normalize_file (no "kbps" for a video).

    The audio becomes AAC at the source's sample rate, stereo or mono as it
    was, at the next of 128/160/192/256 kb/s at or over the source's. Swapped
    in only once the result still has its picture and runs as long as the
    source."""
    import video_compat
    name = os.path.basename(path)
    ffmpeg = ffmpeg or audio_cbr._ffmpeg()
    if not ffmpeg:
        return {"dosya": name, "hata": "ffmpeg not found"}
    try:
        m = m or measure(path, ffmpeg)
    except Exception as e:  # noqa: BLE001 - reported per file
        return {"dosya": name, "hata": str(e)}
    out = {"dosya": name, "degisti": False, "i": m["i"], "tp": m["tp"]}
    af, g = _chain(path, ffmpeg, m, clarity)
    if not af:
        return out

    rate, ch, src_kbps = _video_audio(path, ffmpeg)
    kbps = next((k for k in (128, 160, 192, 256) if k >= (src_kbps or 0) * 0.95), 256)
    ext = os.path.splitext(path)[1].lower()
    cmd = [ffmpeg, "-y", "-hide_banner", "-nostdin", "-loglevel", "error", "-i", path,
           # the picture (V: not a cover image) and the first audio, as video_compat
           "-map", "0:V:0?", "-map", "0:a:0", "-c:v", "copy", "-af", af,
           "-c:a", "aac", "-b:a", f"{kbps}k"]
    if rate:
        cmd += ["-ar", str(rate)]
    if ch:
        cmd += ["-ac", str(ch)]
    # use_metadata_tags lets the tag below in; it would also write the brands
    # -map_metadata carries over a second time, as tags of their own.
    cmd += ["-map_metadata", "0", "-movflags", "+faststart+use_metadata_tags",
            "-metadata", "major_brand=", "-metadata", "minor_version=",
            "-metadata", "compatible_brands="]
    if clarity:
        cmd += ["-metadata", f"{MARK_KEY}={MARK}"]
    tmp = tempfile.mktemp(suffix=ext, dir=os.path.dirname(path) or ".")
    try:
        before = video_compat.probe(path, ffmpeg)
        r = _run(cmd + [tmp], timeout=1800)
        if r.returncode != 0:
            raise RuntimeError("ffmpeg failed: "
                               + r.stderr.decode("utf-8", "replace").strip()[-300:])
        after = video_compat.probe(tmp, ffmpeg)
        if after.get("error") or not after.get("audio") or (
                before.get("video") and not after.get("video")):
            raise RuntimeError("the re-encoded video lost a stream")
        d0, d1 = before.get("duration") or 0, after.get("duration") or 0
        if d0 and abs(d1 - d0) > max(0.5, d0 * 0.01):
            raise RuntimeError(f"the re-encoded video runs {d1:.1f} s, the original {d0:.1f} s")
        m2 = measure(tmp, ffmpeg)
        _swap_in(tmp, path)
    except Exception as e:  # noqa: BLE001 - reported per file
        if os.path.exists(tmp):
            os.remove(tmp)
        return {"dosya": name, "hata": str(e)}
    out.update(degisti=True, gain=g, yeni_i=m2["i"], yeni_tp=m2["tp"], netlik=clarity)
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


def find_videos(book):
    """The book's videos in a container the reader opens (VIDEO_EXTS); the
    rest are video_compat's to convert first."""
    import video_compat
    return [p for p in video_compat.find_videos(book) if p.suffix.lower() in VIDEO_EXTS]


def _is_video(p):
    return p.suffix.lower() in VIDEO_EXTS


def _aligned_names(book):
    """File names any audio.json under the audio folders has karaoke timings
    for. Each audio.json sits next to its audio, so sub-folders have their
    own. Matched by name only, which can over-protect a same-named clip in
    another folder: leaving a clip's level alone is safe, shifting an aligned
    one's timing is not."""
    from pathlib import Path
    names = set()
    book = Path(book)
    try:
        roots = [d for d in book.iterdir() if d.is_dir() and d.name.lower() in AUDIO_DIRS]
    except OSError:
        return names
    for root in roots:
        for f in root.rglob("audio.json"):
            try:
                data = json.loads(f.read_text(encoding="utf-8"))
            except (OSError, ValueError, UnicodeDecodeError):
                continue
            if isinstance(data, dict):
                names.update(data)
    return names


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
        # An entry from before koyuluk/netlik were measured is measured again.
        if (c and c.get("size") == st.st_size and c.get("mtime") == int(st.st_mtime)
                and "koyuluk" in c):
            out[p] = {"i": c["i"], "tp": c["tp"], "koyuluk": c["koyuluk"],
                      "netlik": c.get("netlik", False)}
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
                    "size": st.st_size, "mtime": int(st.st_mtime), "i": m["i"], "tp": m["tp"],
                    "koyuluk": m["koyuluk"], "netlik": m["netlik"]}
    if todo:
        try:
            os.makedirs(os.path.dirname(cache_path), exist_ok=True)
            with open(cache_path, "w", encoding="utf-8") as fh:
                json.dump(cache, fh)
        except OSError:
            pass
    return out


def _median(xs):
    xs = sorted(xs)
    n = len(xs)
    if not n:
        return None
    return xs[n // 2] if n % 2 else round((xs[n // 2 - 1] + xs[n // 2]) / 2, 1)


def check_book(book):
    """Every MP3 and video in the book against the rule; writes nothing but
    the cache.

    {toplam, duzeltilecek, okunamayan, ffmpeg_yok, hedef, koyuluk, boguk,
     netlik_bekleyen, sesler: [row]}; each row {dosya, video, durum ("uygun" |
    "duzeltilecek" | "sessiz" | "okunamayan"), i, tp, gain, koyuluk, netlik} or
    {dosya, video, durum, hata}.

    koyuluk is the median over the MP3s not yet done with the clearer voice —
    videos carry music, which would skew it; boguk when it is over MUFFLED
    and there are at least three of them. netlik_bekleyen: the clips the
    clearer voice would still change.
    """
    from pathlib import Path
    book = Path(book)
    paths = find_audio(book) + find_videos(book)
    r = {"toplam": len(paths), "duzeltilecek": 0, "okunamayan": 0, "ffmpeg_yok": False,
         "hedef": TARGET_I, "koyuluk": None, "boguk": False, "netlik_bekleyen": 0,
         "sesler": []}
    if not paths:
        return r
    ffmpeg = audio_cbr._ffmpeg()
    if not ffmpeg:
        r["ffmpeg_yok"] = True
        return r
    dark = []
    for p, m in _measure_all(book, paths, ffmpeg).items():
        row = {"dosya": p.relative_to(book).as_posix(), "video": _is_video(p)}
        if "hata" in m:
            row.update(durum="okunamayan", hata=m["hata"])
            r["okunamayan"] += 1
        elif m["i"] is None:
            row.update(durum="sessiz")
        else:
            g = gain_for(m)
            row.update(i=m["i"], tp=m["tp"], gain=g, koyuluk=m["koyuluk"], netlik=m["netlik"],
                       durum="duzeltilecek" if g else "uygun")
            if g:
                r["duzeltilecek"] += 1
            if not m["netlik"]:
                r["netlik_bekleyen"] += 1
                if not row["video"] and m["koyuluk"] is not None:
                    dark.append(m["koyuluk"])
        r["sesler"].append(row)
    r["sesler"].sort(key=lambda x: x["dosya"])
    r["koyuluk"] = _median(dark)
    r["boguk"] = len(dark) >= 3 and r["koyuluk"] > MUFFLED
    return r


def optimize_book(book, progress=None, stopped=lambda: False, clarity=False):
    """Normalizes every clip check_book calls "duzeltilecek", in place — with
    clarity, every clip not yet done with the clearer voice, level or not.

    progress(i, n, dosya) before each clip. A clip audio.json has karaoke
    timings for is only replaced when the re-encode keeps its frame count and
    encoder delay — then every timing still lands on the same sample;
    otherwise it is left as it is and listed under hizali_atlanan.

    {normalize_edilen: [row], basarisiz: [{dosya, hata}],
     hizali_atlanan: [dosya], netlik, iptal?} or {hata}.
    """
    from pathlib import Path
    book = Path(book)
    ffmpeg = audio_cbr._ffmpeg()
    if not ffmpeg:
        return {"hata": "ffmpeg isn't installed — install it from Help ▸ Dependencies"}
    aligned = _aligned_names(book)
    measured = _measure_all(book, find_audio(book) + find_videos(book), ffmpeg)
    todo = [(p, m) for p, m in measured.items()
            if "hata" not in m and m["i"] is not None and not m["netlik"]
            and (clarity or gain_for(m))]
    done, failed, skipped = [], [], []
    for i, (p, m) in enumerate(sorted(todo)):
        if stopped():
            return {"normalize_edilen": done, "basarisiz": failed,
                    "hizali_atlanan": skipped, "netlik": clarity, "iptal": True}
        rel = p.relative_to(book).as_posix()
        if progress:
            progress(i, len(todo), rel)
        if _is_video(p):
            r = normalize_video(str(p), ffmpeg, m, clarity=clarity)
        else:
            r = normalize_file(str(p), ffmpeg, m, keep_timing=p.name in aligned,
                               clarity=clarity)
        r["dosya"] = rel
        if r.get("hizali"):
            skipped.append(rel)
        elif "hata" in r:
            failed.append({"dosya": rel, "hata": r["hata"]})
        elif r["degisti"]:
            done.append(r)
    return {"normalize_edilen": done, "basarisiz": failed, "hizali_atlanan": skipped,
            "netlik": clarity}
