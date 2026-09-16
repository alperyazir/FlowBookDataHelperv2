"""Keep a book's videos in the one format every FlowBook reader can play.

Windows customers get the Qt 5.15 reader, and its FFmpeg is cut down on purpose
(LGPL, Win7-safe, software decoding only): the mov demuxer, the H.264 decoder,
AAC and MP3 — nothing else. A video outside that does not open at all. CHASE 5
arrived as HEVC, one of its videos 10-bit, and not one of the twenty played on
Windows, while a Mac played every one of them: its decoders take HEVC in their
stride, so nothing looked wrong in the editor.

The rule, in one place:

  container   .mp4 / .m4v / .mov        the only demuxer the reader has
  video       H.264, 8-bit 4:2:0        the only decoder; 10-bit, 4:2:2 and 4:4:4
                                        H.264 also trip the older DirectShow path
  size        up to 1080p               decoded in software on old smartboards
  audio       AAC or MP3 (or none)      the only audio decoders

Package ▸ Book Details asks check_book() about every video. A video that breaks
the rule is converted by optimize_book() into the project's .pkgcache/videos/,
named after its content, and export swaps the converted copy into book_export/
(apply_to_export). The project's own files are never rewritten: the editor
keeps playing what the author handed over, and a re-export finds the work done.

Only ffmpeg is needed, never ffprobe: Help ▸ Dependencies installs ffmpeg from
the imageio-ffmpeg wheel, which ships no ffprobe. So streams are read from what
`ffmpeg -i` prints.
"""
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import time
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import flowbook_normalize as fn
# The karaoke converter's lookup: PATH, then where Help ▸ Dependencies puts it.
from audio_cbr import _ffmpeg as find_ffmpeg

VIDEO_EXTS = {".mp4", ".m4v", ".mov", ".mkv", ".webm", ".avi", ".wmv", ".flv",
              ".mpg", ".mpeg", ".3gp", ".ts", ".mts", ".m2ts", ".ogv"}
PLAYABLE_EXTS = {".mp4", ".m4v", ".mov"}
PLAYABLE_PIX = {"yuv420p", "yuvj420p"}
PLAYABLE_AUDIO = {"aac", "mp3"}
MAX_LONG, MAX_SHORT = 1920, 1080

# Part of every cache key: change the conversion below and bump this, and every
# copy made the old way is made again instead of shipping.
RECIPE = 1

# The editor starts Python without a console; without this every ffmpeg it
# starts would open a console window of its own on Windows.
_NO_WINDOW = subprocess.CREATE_NO_WINDOW if os.name == "nt" else 0

_NAMES = {"hevc": "HEVC (H.265)", "h264": "H.264", "vp8": "VP8", "vp9": "VP9",
          "av1": "AV1", "mpeg4": "MPEG-4 Part 2", "mpeg2video": "MPEG-2",
          "prores": "ProRes", "opus": "Opus", "vorbis": "Vorbis", "ac3": "AC-3",
          "eac3": "E-AC-3", "flac": "FLAC", "alac": "ALAC"}


def _name(codec):
    if codec.startswith("pcm_"):
        return "PCM"
    return _NAMES.get(codec, codec.upper())


def _split_top(text):
    """Split an ffmpeg stream description on the commas that separate fields,
    not the ones inside "(tv, bt709, progressive)"."""
    out, depth, cur = [], 0, []
    for ch in text:
        if ch in "([":
            depth += 1
        elif ch in ")]":
            depth -= 1
        if ch == "," and depth == 0:
            out.append("".join(cur).strip())
            cur = []
        else:
            cur.append(ch)
    out.append("".join(cur).strip())
    return [f for f in out if f]


_STREAM_RE = re.compile(r"^\s*Stream #\d+:\d+\S*: (Video|Audio): (.*)$")


def probe(path, ffmpeg):
    """{duration, video, audio} for a file, or {error} when ffmpeg can't open it.

    video: {codec, pix_fmt, width, height, rotation}; audio: {codec}. Only the
    first stream of each kind counts — the one a player picks — and a cover
    image (an "attached pic" video stream) is not a video.
    """
    try:
        run = subprocess.run([ffmpeg, "-hide_banner", "-nostdin", "-i", str(path)],
                             capture_output=True, timeout=120, creationflags=_NO_WINDOW)
    except (OSError, subprocess.TimeoutExpired) as e:
        return {"error": str(e)}
    text = run.stderr.decode("utf-8", "replace")
    if "Input #0" not in text:
        lines = [l.strip() for l in text.splitlines() if l.strip()]
        return {"error": lines[-1] if lines else "ffmpeg could not open it"}

    info = {"duration": None, "video": None, "audio": None}
    m = re.search(r"Duration: (\d+):(\d+):(\d+(?:\.\d+)?)", text)
    if m:
        info["duration"] = int(m[1]) * 3600 + int(m[2]) * 60 + float(m[3])

    # Each stream line plus the indented lines under it (its side data).
    blocks = []
    for line in text.splitlines():
        s = _STREAM_RE.match(line)
        if s:
            blocks.append([s[1], s[2], line])
        elif blocks and line.startswith("    "):
            blocks[-1][2] += "\n" + line
        elif not line.startswith("    "):
            blocks.append([None, "", ""])        # anything else ends a block

    for kind, desc, block in blocks:
        if kind is None:
            continue
        fields = _split_top(desc)
        codec = fields[0].split()[0] if fields else ""
        if kind == "Video" and info["video"] is None and "(attached pic)" not in desc:
            pix = None
            if len(fields) > 1 and not re.match(r"\d+x\d+", fields[1]):
                pm = re.match(r"[a-z0-9_]+", fields[1])
                pix = pm[0] if pm else None
            width = height = 0
            for f in fields:
                dm = re.match(r"(\d+)x(\d+)\b", f)
                if dm:
                    width, height = int(dm[1]), int(dm[2])
                    break
            rm = re.search(r"rotation of (-?\d+(?:\.\d+)?) degrees", block)
            info["video"] = {"codec": codec, "pix_fmt": pix, "width": width,
                             "height": height,
                             "rotation": round(float(rm[1])) % 360 if rm else 0}
        elif kind == "Audio" and info["audio"] is None:
            info["audio"] = {"codec": codec}
    return info


def _pix_text(pix):
    if not pix:
        return "unknown pixel format"
    bits = re.search(r"p(\d+)(?:le|be)$", pix)
    chroma = next((c for c in ("422", "444", "440", "411", "410") if c in pix), None)
    parts = []
    if bits and bits[1] != "8":
        parts.append(f"{bits[1]}-bit")
    if chroma:
        parts.append(f"{chroma[0]}:{chroma[1]}:{chroma[2]}")
    return f"{' '.join(parts)} colour ({pix})" if parts else f"{pix} pixels"


def _too_large(v):
    w, h = v["width"], v["height"]
    return max(w, h) > MAX_LONG or min(w, h) > MAX_SHORT


def problems(path, info):
    """Why this video won't play on the Windows reader; [] when it will."""
    out = []
    ext = Path(path).suffix.lower()
    if ext not in PLAYABLE_EXTS:
        out.append(f"{ext} container")
    v = info["video"]
    if v["codec"] != "h264":
        out.append(f"{_name(v['codec'])} video")
    if v["pix_fmt"] not in PLAYABLE_PIX:
        out.append(_pix_text(v["pix_fmt"]))
    if _too_large(v):
        out.append(f"{v['width']}×{v['height']}, over 1080p")
    a = info["audio"]
    if a and a["codec"] not in PLAYABLE_AUDIO:
        out.append(f"{_name(a['codec'])} audio")
    return out


def content_key(path):
    """Names a video's converted copy by what the file holds, not where it is:
    export renames files ("CHASE 5  STORY 3.mp4" becomes CHASE_5_STORY_3.mp4),
    and the copy it looks up has to be the one made from the same bytes.

    Size plus the first and last megabyte. Re-encoding or trimming a video
    rewrites its index, which an MP4 keeps at one end or the other, so a
    changed video gets a new key; hashing whole files would read gigabytes
    every time the dialog opens."""
    size = os.path.getsize(path)
    h = hashlib.sha1(f"r{RECIPE}:{size}:".encode())
    with open(path, "rb") as f:
        h.update(f.read(1 << 20))
        if size > 2 << 20:
            f.seek(-(1 << 20), os.SEEK_END)
            h.update(f.read(1 << 20))
    return h.hexdigest()[:24]


def cache_dir(book):
    return Path(book) / ".pkgcache" / "videos"


def cached_copy(cache, key):
    """The finished converted copy for key, or None. The .json is written only
    after the copy verified, so a run cut short leaves nothing that counts."""
    out = cache / f"{key}.mp4"
    try:
        meta = json.loads((cache / f"{key}.json").read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return None
    if out.is_file() and out.stat().st_size == meta.get("bytes"):
        return out
    return None


def find_videos(book):
    """Every video file that ships with the book. raw/ ships only its PDFs,
    and the module's junk (.pkgcache, temp, ...) never ships at all."""
    book = Path(book)
    out = []
    for p in sorted(book.rglob("*")):
        rel = p.relative_to(book)
        if (rel.parts[0] == "raw" or p.suffix.lower() not in VIDEO_EXTS
                or any(part.startswith(".") for part in rel.parts)
                or not p.is_file() or fn.is_junk_path(p, book)):
            continue
        out.append(p)
    return out


def survey(book, ffmpeg):
    """Probe every video in the book. Each row: {path, dosya, info, sorun} or
    {path, dosya, hata}. Probes run side by side — most of a probe is starting
    ffmpeg, and a book can have a hundred videos."""
    book = Path(book)
    videos = find_videos(book)
    with ThreadPoolExecutor(max_workers=min(8, os.cpu_count() or 4)) as pool:
        infos = list(pool.map(lambda p: probe(p, ffmpeg), videos))
    rows = []
    for p, info in zip(videos, infos):
        row = {"path": p, "dosya": p.relative_to(book).as_posix()}
        if info.get("error"):
            row["hata"] = info["error"]
        elif not info["video"]:
            row["hata"] = "no video stream"
        else:
            row["info"] = info
            row["sorun"] = problems(p, info)
        rows.append(row)
    return rows


FFMPEG_MISSING = ("ffmpeg isn't installed, so the videos can't be checked or "
                  "converted — install it from Help ▸ Dependencies")


def check_book(book):
    """For the Package dialog; touches nothing.

    {toplam, ffmpeg_yok, sorunlu: [{dosya, sorun, hazir}], okunamayan: [{dosya, hata}]}
    hazir: Optimize already made its converted copy.
    """
    book = Path(book)
    videos = find_videos(book)
    r = {"toplam": len(videos), "ffmpeg_yok": False, "sorunlu": [], "okunamayan": []}
    if not videos:
        return r
    ffmpeg = find_ffmpeg()
    if not ffmpeg:
        r["ffmpeg_yok"] = True
        return r
    cache = cache_dir(book)
    for row in survey(book, ffmpeg):
        if "hata" in row:
            r["okunamayan"].append({"dosya": row["dosya"], "hata": row["hata"]})
        elif row["sorun"]:
            r["sorunlu"].append({
                "dosya": row["dosya"], "sorun": ", ".join(row["sorun"]),
                "hazir": cached_copy(cache, content_key(row["path"])) is not None})
    return r


def _has_libx264(ffmpeg):
    try:
        run = subprocess.run([ffmpeg, "-hide_banner", "-nostdin", "-encoders"],
                             capture_output=True, timeout=60, creationflags=_NO_WINDOW)
    except (OSError, subprocess.TimeoutExpired):
        return False
    return re.search(rb"\blibx264\b", run.stdout) is not None


def _remove(path):
    """Delete, giving Windows a moment: a file ffmpeg was just killed over can
    stay locked for a beat after the process is gone."""
    for _ in range(20):
        try:
            os.remove(path)
            return
        except FileNotFoundError:
            return
        except PermissionError:
            time.sleep(0.25)


def convert(src, info, out, ffmpeg, on_pct, stop):
    """Convert one video to out (an .mp4). Returns {} on success, {hata} or {iptal}.

    Only what breaks the rule is redone: an H.264 video with the wrong audio
    keeps its picture untouched (-c:v copy), and the reverse. Written beside
    out and moved into place only after the result probes clean and runs as
    long as the source, so a failure or a Stop never leaves a copy that counts.
    """
    v, a = info["video"], info["audio"]
    redo_video = v["codec"] != "h264" or v["pix_fmt"] not in PLAYABLE_PIX or _too_large(v)
    redo_audio = a is not None and a["codec"] not in PLAYABLE_AUDIO
    part = out.with_name(out.stem + ".part.mp4")

    cmd = [ffmpeg, "-hide_banner", "-nostdin", "-y", "-v", "error", "-nostats",
           "-progress", "pipe:1", "-i", str(src),
           # the first real video (V skips cover art) and the first audio, if any
           "-map", "0:V:0", "-map", "0:a:0?", "-sn", "-dn", "-map_chapters", "-1"]
    if redo_video:
        # ffmpeg turns a rotated phone video upright while re-encoding, so the
        # size to fit is the upright one.
        w, h = v["width"], v["height"]
        if v["rotation"] in (90, 270):
            w, h = h, w
        f = min(1.0, MAX_LONG / max(w, h), MAX_SHORT / min(w, h))
        # x264 wants even sides for 4:2:0.
        nw, nh = max(2, int(w * f) // 2 * 2), max(2, int(h * f) // 2 * 2)
        cmd += ["-vf", f"scale={nw}:{nh}",
                "-c:v", "libx264", "-preset", "medium", "-crf", "20",
                "-profile:v", "high", "-pix_fmt", "yuv420p",
                # no bitrate spike an old board can't decode in time
                "-maxrate", "6M", "-bufsize", "12M",
                # a keyframe every 2 s: the reader seeks to the one before
                # the slider position and decodes forward from there
                "-force_key_frames", "expr:gte(t,n_forced*2)"]
    else:
        cmd += ["-c:v", "copy"]
    cmd += ["-c:a", "aac", "-b:a", "160k"] if redo_audio else ["-c:a", "copy"]
    cmd += ["-movflags", "+faststart", "-f", "mp4", str(part)]

    duration = info["duration"] or 0
    errors, last = [], -1
    try:
        proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                creationflags=_NO_WINDOW)
    except OSError as e:
        return {"hata": f"ffmpeg could not start: {e}"}
    for raw in proc.stdout:
        if stop():
            proc.kill()
            break
        line = raw.decode("utf-8", "replace").strip()
        key, eq, val = line.partition("=")
        if eq and re.fullmatch(r"[a-z0-9_]+", key):
            # out_time_ms is microseconds too, despite its name
            if key in ("out_time_us", "out_time_ms") and val.isdigit() and duration:
                pct = min(99, int(int(val) / 1e6 / duration * 100))
                if pct != last:
                    last = pct
                    on_pct(pct)
        elif line:
            errors.append(line)
    proc.wait()

    if stop():
        _remove(part)
        return {"iptal": True}
    if proc.returncode != 0:
        _remove(part)
        return {"hata": "ffmpeg failed: " + (" / ".join(errors[-3:]) or f"exit {proc.returncode}")}
    after = probe(part, ffmpeg)
    left = ["no video stream"] if not after.get("video") else problems(out, after)
    if after.get("error") or left:
        _remove(part)
        return {"hata": "the converted copy still won't play: "
                        + (after.get("error") or ", ".join(left))}
    if duration and after["duration"] and abs(after["duration"] - duration) > max(1.0, duration * 0.02):
        _remove(part)
        return {"hata": f"the converted copy runs {after['duration']:.1f} s, "
                        f"the original {duration:.1f} s"}
    os.replace(part, out)
    return {}


def optimize_book(book, progress, stop):
    """Make the converted copy of every video in the book that needs one.

    progress(i, n, dosya, pct) as each conversion moves; stop() is polled and
    ends the run early (the video in hand is dropped, finished ones are kept).
    Returns {donusen: [{dosya, sorun, mb}], basarisiz: [{dosya, hata}]},
    plus {iptal: true} after a stop or {hata} when nothing could be tried.
    """
    book = Path(book)
    ffmpeg = find_ffmpeg()
    if not ffmpeg:
        return {"hata": FFMPEG_MISSING}
    cache = cache_dir(book)
    cache.mkdir(parents=True, exist_ok=True)
    for stale in cache.glob("*.part.mp4"):        # left by a run that was killed
        _remove(stale)

    todo = []
    for row in survey(book, ffmpeg):
        if row.get("sorun"):
            key = content_key(row["path"])
            if cached_copy(cache, key) is None:
                todo.append((row, key))
    r = {"donusen": [], "basarisiz": []}
    if todo and not _has_libx264(ffmpeg):
        return {**r, "hata": f"this ffmpeg ({ffmpeg}) has no H.264 encoder (libx264) — "
                             f"install ffmpeg again from Help ▸ Dependencies"}

    for i, (row, key) in enumerate(todo):
        if stop():
            r["iptal"] = True
            break
        progress(i, len(todo), row["dosya"], 0)
        out = cache / f"{key}.mp4"
        res = convert(row["path"], row["info"], out, ffmpeg,
                      lambda pct: progress(i, len(todo), row["dosya"], pct), stop)
        if res.get("iptal"):
            r["iptal"] = True
            break
        if res.get("hata"):
            r["basarisiz"].append({"dosya": row["dosya"], "hata": res["hata"]})
            continue
        src_bytes, out_bytes = row["path"].stat().st_size, out.stat().st_size
        meta = {"kaynak": row["dosya"], "sorun": row["sorun"], "recipe": RECIPE,
                "kaynak_bytes": src_bytes, "bytes": out_bytes}
        tmp = cache / f"{key}.json.tmp"
        tmp.write_text(json.dumps(meta, ensure_ascii=False, indent=1), encoding="utf-8")
        os.replace(tmp, cache / f"{key}.json")
        r["donusen"].append({"dosya": row["dosya"], "sorun": ", ".join(row["sorun"]),
                             "mb": [round(src_bytes / 1048576, 1), round(out_bytes / 1048576, 1)]})
    return r


def _rewrite_refs(book, renamed):
    """Point config.json/games.json at videos whose extension changed. Paths
    are matched whole, so no other string that merely contains one moves."""
    for name in ("config.json", "games.json"):
        cfg = book / name
        if not cfg.is_file():
            continue
        data = json.loads(cfg.read_text(encoding="utf-8"))
        count = [0]

        def walk(node):
            if isinstance(node, dict):
                return {k: walk(v) for k, v in node.items()}
            if isinstance(node, list):
                return [walk(v) for v in node]
            if isinstance(node, str) and node in renamed:
                count[0] += 1
                return renamed[node]
            return node

        data = walk(data)
        if count[0]:
            cfg.write_text(json.dumps(data, ensure_ascii=False, indent=4), encoding="utf-8")


def apply_to_export(dest, cache, folder):
    """Swap each video in an export that breaks the rule for its converted copy.

    A video without one stops the export ({hata}) rather than ship: the dialog
    will not let a book through with such a video, so this only happens when
    a file changed after the check, and the fix is the dialog's Optimize.
    Returns {toplam, degisen: [{dosya, sorun, mb}]} or {hata}.
    """
    dest, cache = Path(dest), Path(cache)
    videos = find_videos(dest)
    if not videos:
        return {"toplam": 0, "degisen": []}
    ffmpeg = find_ffmpeg()
    if not ffmpeg:
        return {"hata": FFMPEG_MISSING}
    rows = survey(dest, ffmpeg)
    bad = [r for r in rows if "hata" in r]
    if bad:
        return {"hata": f"{len(bad)} video(s) can't be read: "
                        + "; ".join(f"{r['dosya']} ({r['hata']})" for r in bad[:5])}
    plan, missing = [], []
    for row in rows:
        if row["sorun"]:
            copy = cached_copy(cache, content_key(row["path"]))
            (plan.append((row, copy)) if copy else missing.append(row["dosya"]))
    if missing:
        return {"hata": f"{len(missing)} video(s) won't play on Windows and have no optimized "
                        f"copy — use Optimize videos in Book Details: "
                        + ", ".join(missing[:5]) + (", …" if len(missing) > 5 else "")}

    degisen, renamed = [], {}
    for row, copy in plan:
        old = row["path"]
        # The mov demuxer reads an MP4 under a .mov or .m4v name just the same;
        # only a container the reader has no demuxer for changes its name.
        new = old if old.suffix.lower() in PLAYABLE_EXTS else old.with_suffix(".mp4")
        if new != old and new.exists():
            return {"hata": f"{row['dosya']} becomes .mp4, but {new.name} is already there"}
        was = old.stat().st_size
        tmp = new.with_name(new.name + ".tmp")
        shutil.copyfile(copy, tmp)
        os.replace(tmp, new)
        if new != old:
            fn.safe_remove(old)
            prefix = f"{fn.BOOKS_PREFIX}{folder}/"
            renamed[prefix + row["dosya"]] = prefix + new.relative_to(dest).as_posix()
        degisen.append({"dosya": new.relative_to(dest).as_posix(),
                        "sorun": ", ".join(row["sorun"]),
                        "mb": [round(was / 1048576, 1), round(new.stat().st_size / 1048576, 1)]})
    if renamed:
        _rewrite_refs(dest, renamed)
    return {"toplam": len(videos), "degisen": degisen}
