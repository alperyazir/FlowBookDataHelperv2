"""Keep book audio constant-bitrate, because seeking a VBR MP3 is a guess.

An MP3 carries no index. To seek, a decoder converts "2:05" into a byte offset,
and that conversion is only exact while every frame is the same size. A VBR file
instead ships a Xing table of 100 entries — one per 1% of the file — and the
decoder interpolates inside it. On a two-minute clip a 1% bracket is over a
second wide, so the decoder starts playing up to ~1.2s away from where it says
it is. The player reports the second you asked for; the audio is elsewhere.

That is why the karaoke highlight drifts only after using the slider or clicking
a word, never when a clip plays from the start: playing straight through never
consults the estimate. And it is why it only shows on some Windows machines —
there the decoder is the operating system's own (Media Foundation), whose
interpolation has changed between versions, while the timings in audio.json are
perfectly sound.

Of 120 clips in the library 118 are CBR 128 kbps. The two that are not are
exactly the two pages that were reported.

The fix is to make the audio seekable rather than to compensate in the reader:
convert to CBR *before* aligning, so the timings describe the file that ships.
Aligning first and converting after would leave the timings describing a file
nobody plays — encoder delay and padding shift things by a frame or two.
"""
import json
import os
import shutil
import subprocess
import sys
import tempfile
import time

# Layer III bitrate tables, indexed by the header's 4-bit bitrate index.
_BITRATES_V1 = (0, 32, 40, 48, 56, 64, 80, 96, 112, 128, 160, 192, 224, 256, 320, 0)
_BITRATES_V2 = (0, 8, 16, 24, 32, 40, 48, 56, 64, 80, 96, 112, 128, 144, 160, 0)
_RATES = {3: (44100, 48000, 32000),    # MPEG1
          2: (22050, 24000, 16000),    # MPEG2
          0: (11025, 12000, 8000)}     # MPEG2.5
# What libmp3lame will accept as a constant rate.
_STANDARD = (32, 40, 48, 56, 64, 80, 96, 112, 128, 160, 192, 224, 256, 320)


def _id3_size(data):
    """Bytes of ID3v2 tag at the head of the file (0 if absent). The tag is not
    audio and contains bytes that look like frame syncs, so frame walking has to
    start after it."""
    if len(data) < 10 or data[:3] != b"ID3":
        return 0
    if any(b & 0x80 for b in data[6:10]):     # not a valid syncsafe integer
        return 0
    size = 0
    for b in data[6:10]:
        size = (size << 7) | (b & 0x7F)
    footer = 10 if (data[5] & 0x10) else 0
    return 10 + size + footer


def _parse_frame(data, i):
    """(bitrate_kbps, frame_length, is_layer3) for the frame at i, or None."""
    if i + 4 > len(data):
        return None
    b0, b1, b2, b3 = data[i], data[i + 1], data[i + 2], data[i + 3]
    if b0 != 0xFF or (b1 & 0xE0) != 0xE0:
        return None
    version = (b1 >> 3) & 0x03
    layer = (b1 >> 1) & 0x03
    if version == 1 or layer == 0:            # reserved
        return None
    br_index = (b2 >> 4) & 0x0F
    sr_index = (b2 >> 2) & 0x03
    if br_index in (0, 15) or sr_index == 3:  # free-form / invalid
        return None
    table = _BITRATES_V1 if version == 3 else _BITRATES_V2
    kbps = table[br_index]
    rate = _RATES[version][sr_index]
    if not kbps or not rate:
        return None
    padding = (b2 >> 1) & 0x01
    if layer == 3:                            # Layer I
        length = (12 * kbps * 1000 // rate + padding) * 4
    elif layer == 2:                          # Layer II
        length = 144 * kbps * 1000 // rate + padding
    else:                                     # Layer III
        coef = 144 if version == 3 else 72
        length = coef * kbps * 1000 // rate + padding
    if length < 4:
        return None
    return kbps, length, layer == 1


def scan_frames(path, max_frames=0):
    """Walk the MP3 frame headers. Returns {bitrates, frames, xing, kbps_avg}.

    ffprobe's average bit_rate cannot answer this: a VBR file averages to
    something entirely plausible (the reported page averaged 152169), and a
    single number can never show that the frames disagree. Only the headers can,
    so we read them directly rather than trusting a summary.
    """
    with open(path, "rb") as f:
        data = f.read()
    i = _id3_size(data)
    bitrates = {}
    frames = 0
    xing = False
    # Frame walking must start on a real sync; a little slack in case the ID3
    # size is off or the file has junk at the head.
    limit = len(data) - 4
    while i < limit:
        parsed = _parse_frame(data, i)
        if parsed is None:
            i += 1
            continue
        kbps, length, _ = parsed
        # The first frame of a VBR file is a header frame carrying the Xing/Info
        # table, not audio. Its bitrate is arbitrary and must not count.
        if frames == 0 and (b"Xing" in data[i:i + length]
                            or b"Info" in data[i:i + length]
                            or b"VBRI" in data[i:i + length]):
            xing = True
            i += length
            continue
        bitrates[kbps] = bitrates.get(kbps, 0) + 1
        frames += 1
        i += length
        if max_frames and frames >= max_frames:
            break
    total = sum(bitrates.values()) or 1
    avg = sum(k * n for k, n in bitrates.items()) / total
    return {"bitrates": sorted(bitrates), "counts": bitrates, "frames": frames,
            "xing": xing, "kbps_avg": round(avg, 1)}


def is_cbr(path):
    """True if every audio frame carries the same bitrate. None when the file
    has no MP3 frames at all (not an MP3 — nothing for us to say)."""
    info = scan_frames(path)
    if info["frames"] == 0:
        return None
    return len(info["bitrates"]) == 1


def target_kbps(avg):
    """Smallest standard rate at or above the source average, so re-encoding
    never costs quality (a 152 kbps average becomes 160, not 128)."""
    for k in _STANDARD:
        if k >= avg - 0.5:
            return k
    return _STANDARD[-1]


def _ffmpeg():
    exe = shutil.which("ffmpeg")
    if exe:
        return exe
    # Same spots setup_align_runtime() teaches the aligner about.
    cands = ([os.path.join(os.path.dirname(sys.executable), "ffmpeg.exe"),
              os.path.join(os.path.dirname(sys.executable), "ffmpeg", "bin",
                           "ffmpeg.exe")] if os.name == "nt"
             else ["/opt/homebrew/bin/ffmpeg", "/usr/local/bin/ffmpeg",
                   "/usr/bin/ffmpeg"])
    for c in cands:
        if os.path.exists(c):
            return c
    return None


def to_cbr(path, kbps=None):
    """Re-encode path in place at a constant bitrate. Returns a result dict.

    Writes beside the original and swaps it in only once ffmpeg has succeeded
    and the result verifies as CBR, so a failure or a kill can never leave the
    book holding a truncated clip.
    """
    info = scan_frames(path)
    if info["frames"] == 0:
        return {"ok": False, "reason": "not an mp3", "converted": False}
    if len(info["bitrates"]) == 1:
        return {"ok": True, "converted": False, "kbps": info["bitrates"][0]}
    exe = _ffmpeg()
    if not exe:
        return {"ok": False, "reason": "ffmpeg not found", "converted": False}
    rate = kbps or target_kbps(info["kbps_avg"])
    tmp = tempfile.mktemp(suffix=".mp3", dir=os.path.dirname(path) or ".")
    cmd = [exe, "-y", "-loglevel", "error", "-i", path,
           "-c:a", "libmp3lame", "-b:a", f"{rate}k", "-write_xing", "1", tmp]
    try:
        subprocess.run(cmd, check=True, capture_output=True)
        after = scan_frames(tmp)
        if after["frames"] == 0 or len(after["bitrates"]) != 1:
            os.remove(tmp)
            return {"ok": False, "reason": "re-encode is still not CBR",
                    "converted": False}
        # Windows refuses to replace a file another process holds open, and the
        # editor's own player holds this one as soon as the clip has been
        # auditioned. The panel lets go when a run starts, but the handle can
        # outlive the request by a moment, so give it one.
        for attempt in range(8):
            try:
                os.replace(tmp, path)
                break
            except PermissionError:
                if attempt == 7:
                    os.remove(tmp)
                    return {"ok": False, "converted": False,
                            "reason": "the file is open in another program — "
                                      "stop playback and run karaoke again"}
                time.sleep(0.25)
    except subprocess.CalledProcessError as e:
        if os.path.exists(tmp):
            os.remove(tmp)
        err = (e.stderr or b"").decode("utf-8", "replace").strip()[:300]
        return {"ok": False, "reason": f"ffmpeg failed: {err}", "converted": False}
    except Exception as e:
        if os.path.exists(tmp):
            os.remove(tmp)
        return {"ok": False, "reason": str(e), "converted": False}
    return {"ok": True, "converted": True, "kbps": rate,
            "was": info["bitrates"], "frames": after["frames"]}


def ensure_cbr(path, log=print):
    """Make one clip seekable before it is aligned.

    Returns a dict describing what happened when the file was rewritten, so the
    caller can tell the author their audio was changed:
        {"kbps": 160, "was": [...]}                 converted
        {"failed": "reason"}                        needed it, could not
    or None when there was nothing to do. Rewriting someone's audio is not a
    detail to keep to ourselves — the file on disk is not the one they handed
    us any more.
    """
    try:
        info = scan_frames(path)
    except Exception as e:
        log(f"PROGRESS: Could not inspect the audio ({e}); using it as is")
        return None
    if info["frames"] == 0:
        return None                      # not an mp3; nothing to say about it
    if len(info["bitrates"]) == 1:
        return None
    rate = target_kbps(info["kbps_avg"])
    log(f"PROGRESS: This clip is variable bitrate ({info['bitrates'][0]}–"
        f"{info['bitrates'][-1]} kbps), which makes seeking inexact — "
        f"converting to a constant {rate} kbps first…")
    res = to_cbr(path, rate)
    if res.get("converted"):
        log(f"Converted {os.path.basename(path)} to CBR {res['kbps']} kbps "
            f"(was {res['was']})")
        return {"kbps": res["kbps"], "was": res["was"]}
    log(f"PROGRESS: Could not convert to CBR ({res.get('reason')}); "
        f"aligning the file as it is — seeking may drift on Windows")
    return {"failed": res.get("reason", "unknown")}


def main():
    if len(sys.argv) < 3 or sys.argv[1] not in ("check", "convert"):
        print("Usage: audio_cbr.py check|convert <file-or-dir> [...]")
        sys.exit(2)
    mode = sys.argv[1]
    targets = []
    for arg in sys.argv[2:]:
        if os.path.isdir(arg):
            for root, _dirs, files in os.walk(arg):
                targets += [os.path.join(root, f) for f in sorted(files)
                            if f.lower().endswith(".mp3")]
        elif arg.lower().endswith(".mp3"):
            targets.append(arg)
    report = []
    for p in targets:
        try:
            info = scan_frames(p)
        except Exception as e:
            report.append({"file": p, "error": str(e)})
            continue
        cbr = info["frames"] > 0 and len(info["bitrates"]) == 1
        row = {"file": p, "cbr": cbr, "bitrates": info["bitrates"],
               "kbps_avg": info["kbps_avg"], "frames": info["frames"],
               "xing": info["xing"]}
        if mode == "convert" and not cbr and info["frames"] > 0:
            row["result"] = to_cbr(p)
        report.append(row)
    bad = [r for r in report if not r.get("cbr") and "error" not in r
           and r.get("frames", 0) > 0]
    print(json.dumps({"checked": len(report), "vbr": len(bad),
                      "files": report}, ensure_ascii=False, indent=2))
    sys.exit(1 if (mode == "check" and bad) else 0)


if __name__ == "__main__":
    main()
