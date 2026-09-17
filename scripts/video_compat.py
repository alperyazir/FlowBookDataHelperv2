"""Keep a book's videos in the one format every FlowBook reader can play.

Windows customers get the Qt 5.15 reader, and its FFmpeg is cut down on purpose
(LGPL, Win7-safe, software decoding only): the mov demuxer, the H.264 decoder,
AAC and MP3 — nothing else. A video outside that does not open at all. CHASE 5
arrived as HEVC, one of its videos 10-bit, and not one of them played on
Windows, while a Mac played every one: its decoders take HEVC in their stride,
so nothing looked wrong in the editor.

The rule, in one place:

  container   .mp4 / .m4v / .mov        the only demuxer the reader has
  video       H.264, 8-bit 4:2:0        the only decoder; 10-bit, 4:2:2 and 4:4:4
                                        H.264 also trip the older DirectShow path
  size        up to 1080p               decoded in software on old smartboards
  audio       AAC or MP3 (or none)      the only audio decoders

check_book() reports every video against it — for Project ▸ Videos, the toast
when a book opens, and Package ▸ Book Details. optimize_book() converts the
videos that break it IN the book's own folder, replacing the originals: Test
copies books/<book> as it is into a FlowBook, so a fix kept anywhere else
would never reach it. Export only checks (check_export) and stops if one is
left.

Only ffmpeg is needed, never ffprobe: Help ▸ Dependencies installs ffmpeg from
the imageio-ffmpeg wheel, which ships no ffprobe. So streams are read from what
`ffmpeg -i` prints.
"""
import json
import os
import re
import subprocess
import sys
import time
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import flowbook_normalize as fn
# The karaoke converter's lookup: PATH, then where Help ▸ Dependencies puts it.
from audio_cbr import _ffmpeg as find_ffmpeg

# Where a book keeps its videos (the editor's video/, the export's videos/).
# Nowhere else is looked at: audio/ holds .mp4 files with no picture, which
# read as broken videos, and walking images/ on every open costs time for
# nothing.
VIDEO_DIRS = {"video", "videos"}
VIDEO_EXTS = {".mp4", ".m4v", ".mov", ".mkv", ".webm", ".avi", ".wmv", ".flv",
              ".mpg", ".mpeg", ".3gp", ".ts", ".mts", ".m2ts", ".ogv"}
PLAYABLE_EXTS = {".mp4", ".m4v", ".mov"}
PLAYABLE_PIX = {"yuv420p", "yuvj420p"}
PLAYABLE_AUDIO = {"aac", "mp3"}
MAX_LONG, MAX_SHORT = 1920, 1080

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


def find_videos(book):
    """Every video file in the book's video folder(s), junk left out."""
    book = Path(book)
    out = []
    try:
        roots = [d for d in book.iterdir() if d.is_dir() and d.name.lower() in VIDEO_DIRS]
    except OSError:
        return out
    for root in roots:
        for p in sorted(root.rglob("*")):
            rel = p.relative_to(book)
            if (p.suffix.lower() not in VIDEO_EXTS
                    or any(part.startswith(".") for part in rel.parts)
                    or not p.is_file() or fn.is_junk_path(p, book)):
                continue
            out.append(p)
    return sorted(out)


def survey(book, ffmpeg):
    """Probe every video in the book. Each row: {path, dosya, info, sorun} or
    {path, dosya, hata}. A few probes run side by side — most of a probe is
    starting ffmpeg — but not so many that a check started as a book opens
    competes with the editor for an old machine's cores."""
    book = Path(book)
    videos = find_videos(book)
    with ThreadPoolExecutor(max_workers=min(3, os.cpu_count() or 2)) as pool:
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


def _summary(info):
    """"H.264 · 854×480 · AAC · 2:36", for the Videos dialog."""
    v, a = info["video"], info["audio"]
    parts = [_name(v["codec"]), f"{v['width']}×{v['height']}",
             _name(a["codec"]) if a else "no audio"]
    if info["duration"]:
        m, sec = divmod(int(round(info["duration"])), 60)
        parts.append(f"{m}:{sec:02d}")
    return " · ".join(parts)


def lower_priority():
    """Run this process, and every ffmpeg it starts, below the editor. Windows
    children inherit a below-normal priority class; POSIX children the nice
    value."""
    try:
        if os.name == "nt":
            import ctypes
            BELOW_NORMAL_PRIORITY_CLASS = 0x00004000
            k32 = ctypes.windll.kernel32
            k32.SetPriorityClass(k32.GetCurrentProcess(), BELOW_NORMAL_PRIORITY_CLASS)
        else:
            os.nice(10)
    except (OSError, AttributeError):
        pass


def check_book(book):
    """Every video in the book against the rule; touches nothing.

    {toplam, sorunlu, okunamayan, ffmpeg_yok, videolar: [row]}. Each row is
    {dosya, mb, durum} plus, by durum:
      "uygun"       plays on Windows              ozet
      "sorunlu"     won't; Optimize fixes it      ozet, sorun
      "okunamayan"  ffmpeg can't open it          hata
      "bilinmiyor"  no ffmpeg to ask (ffmpeg_yok)
    """
    book = Path(book)
    videos = find_videos(book)
    r = {"toplam": len(videos), "sorunlu": 0, "okunamayan": 0,
         "ffmpeg_yok": False, "videolar": []}
    if not videos:
        return r
    ffmpeg = find_ffmpeg()
    if not ffmpeg:
        r["ffmpeg_yok"] = True
        r["videolar"] = [{"dosya": p.relative_to(book).as_posix(), "durum": "bilinmiyor",
                          "mb": round(p.stat().st_size / 1048576, 1)} for p in videos]
        return r
    for row in survey(book, ffmpeg):
        out = {"dosya": row["dosya"], "mb": round(row["path"].stat().st_size / 1048576, 1)}
        if "hata" in row:
            out.update(durum="okunamayan", hata=row["hata"])
            r["okunamayan"] += 1
        elif row["sorun"]:
            out.update(durum="sorunlu", ozet=_summary(row["info"]),
                       sorun=", ".join(row["sorun"]))
            r["sorunlu"] += 1
        else:
            out.update(durum="uygun", ozet=_summary(row["info"]))
        r["videolar"].append(out)
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


def _replace(src, dst):
    """Move src over dst; None, or why it couldn't. On Windows a file another
    program holds open can't be replaced — the editor's own player holds a
    video it has shown, and a FlowBook started from Test may too — so the
    handle gets a moment to go before we give up and say what is in the way."""
    for attempt in range(8):
        try:
            os.replace(src, dst)
            return None
        except PermissionError:
            if attempt == 7:
                return (f"{Path(dst).name} is open in another program (a video player, "
                        f"or a FlowBook started from Test) — close it and optimize again")
            time.sleep(0.25)


def convert(src, info, out, ffmpeg, on_pct, stop):
    """Convert one video into out, a scratch .mp4 the caller moves into place.
    Returns {} once out probes clean and runs as long as the source, else
    {hata} or {iptal} with out removed.

    Only what breaks the rule is redone: an H.264 video with the wrong audio
    keeps its picture untouched (-c:v copy), and the reverse.
    """
    v, a = info["video"], info["audio"]
    redo_video = v["codec"] != "h264" or v["pix_fmt"] not in PLAYABLE_PIX or _too_large(v)
    redo_audio = a is not None and a["codec"] not in PLAYABLE_AUDIO

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
    cmd += ["-movflags", "+faststart", "-f", "mp4", str(out)]

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
        _remove(out)
        return {"iptal": True}
    if proc.returncode != 0:
        _remove(out)
        return {"hata": "ffmpeg failed: " + (" / ".join(errors[-3:]) or f"exit {proc.returncode}")}
    after = probe(out, ffmpeg)
    left = ["no video stream"] if not after.get("video") else problems(out, after)
    if after.get("error") or left:
        _remove(out)
        return {"hata": "the converted video still won't play: "
                        + (after.get("error") or ", ".join(left))}
    if duration and after["duration"] and abs(after["duration"] - duration) > max(1.0, duration * 0.02):
        _remove(out)
        return {"hata": f"the converted video runs {after['duration']:.1f} s, "
                        f"the original {duration:.1f} s"}
    return {}


def _rewrite_refs(book, renamed):
    """Point config.json and games.json at videos whose extension changed.
    renamed maps book-relative paths ("video/a.webm" -> "video/a.mp4"); a path
    matches whole, after the "./books/<folder>/" in front of it."""
    for name in ("config.json", "games.json"):
        cfg = Path(book) / name
        if not cfg.is_file():
            continue
        data = json.loads(cfg.read_text(encoding="utf-8"))
        count = [0]

        def walk(node):
            if isinstance(node, dict):
                return {k: walk(v) for k, v in node.items()}
            if isinstance(node, list):
                return [walk(v) for v in node]
            if isinstance(node, str) and node.startswith(fn.BOOKS_PREFIX):
                folder, _, rel = node[len(fn.BOOKS_PREFIX):].partition("/")
                if rel in renamed:
                    count[0] += 1
                    return f"{fn.BOOKS_PREFIX}{folder}/{renamed[rel]}"
            return node

        data = walk(data)
        if count[0]:
            tmp = cfg.with_name(cfg.name + ".tmp")
            tmp.write_text(json.dumps(data, ensure_ascii=False, indent=4), encoding="utf-8")
            os.replace(tmp, cfg)


def optimize_book(book, progress, stop):
    """Convert every video in the book that won't play on Windows, in place.

    Each converted video replaces its original under the same name; one in a
    container the reader can't open (.webm, .mkv, ...) becomes .mp4, and
    config.json/games.json follow it. A conversion is written to the book's
    .pkgcache/videos/ first and moved over the original only once it has
    verified, so a failure or a stop leaves that original as it was.

    progress(i, n, dosya, pct) as each conversion moves; stop() is polled and
    ends the run early (the video in hand is dropped, finished ones stay).
    Returns {donusen: [{dosya, eski?, sorun, mb}], basarisiz: [{dosya, hata}],
    yeniden_adlandirilan: {old: new}}, plus {iptal: true} after a stop or
    {hata} when nothing could be tried.
    """
    book = Path(book)
    ffmpeg = find_ffmpeg()
    if not ffmpeg:
        return {"hata": FFMPEG_MISSING}
    work = book / ".pkgcache" / "videos"
    work.mkdir(parents=True, exist_ok=True)
    # The folder is Optimize's own scratch space: anything in it is left over,
    # a conversion from a run that was killed, or a whole cached copy from the
    # editor before 3.3.18 (which converted into here and never into the book).
    for stale in work.iterdir():
        if stale.is_file():
            _remove(stale)

    todo = [row for row in survey(book, ffmpeg) if row.get("sorun")]
    r = {"donusen": [], "basarisiz": [], "yeniden_adlandirilan": {}}
    if todo and not _has_libx264(ffmpeg):
        return {**r, "hata": f"this ffmpeg ({ffmpeg}) has no H.264 encoder (libx264) — "
                             f"install ffmpeg again from Help ▸ Dependencies"}

    for i, row in enumerate(todo):
        if stop():
            r["iptal"] = True
            break
        old = row["path"]
        # The mov demuxer reads an MP4 under a .mov or .m4v name just the same;
        # only a container the reader has no demuxer for changes its name.
        new = old if old.suffix.lower() in PLAYABLE_EXTS else old.with_suffix(".mp4")
        if new != old and new.exists():
            r["basarisiz"].append({"dosya": row["dosya"],
                                   "hata": f"it would become {new.name}, which is already there"})
            continue
        progress(i, len(todo), row["dosya"], 0)
        scratch = work / f"{i}.part.mp4"
        res = convert(old, row["info"], scratch, ffmpeg,
                      lambda pct: progress(i, len(todo), row["dosya"], pct), stop)
        if res.get("iptal"):
            r["iptal"] = True
            break
        if res.get("hata"):
            r["basarisiz"].append({"dosya": row["dosya"], "hata": res["hata"]})
            continue
        was = old.stat().st_size
        why = _replace(scratch, new)
        if why:
            _remove(scratch)
            r["basarisiz"].append({"dosya": row["dosya"], "hata": why})
            continue
        new_rel = new.relative_to(book).as_posix()
        entry = {"dosya": new_rel, "sorun": ", ".join(row["sorun"]),
                 "mb": [round(was / 1048576, 1), round(new.stat().st_size / 1048576, 1)]}
        if new != old:
            _remove(old)
            r["yeniden_adlandirilan"][row["dosya"]] = new_rel
            entry["eski"] = row["dosya"]
        r["donusen"].append(entry)

    if r["yeniden_adlandirilan"]:
        _rewrite_refs(book, r["yeniden_adlandirilan"])
    for d in (work, work.parent):                 # only when nothing else is in them
        try:
            d.rmdir()
        except OSError:
            break
    return r


def check_export(book):
    """For export: {toplam}, or {hata} naming the videos that would ship
    unplayable on Windows. Asked of the project before anything is copied:
    normalizing renames files but never changes what is in a video."""
    book = Path(book)
    videos = find_videos(book)
    if not videos:
        return {"toplam": 0}
    ffmpeg = find_ffmpeg()
    if not ffmpeg:
        return {"hata": FFMPEG_MISSING}
    rows = survey(book, ffmpeg)
    bad = [r for r in rows if "hata" in r]
    if bad:
        return {"hata": f"{len(bad)} video(s) can't be read: "
                        + "; ".join(f"{r['dosya']} ({r['hata']})" for r in bad[:5])}
    wrong = [r["dosya"] for r in rows if r["sorun"]]
    if wrong:
        return {"hata": f"{len(wrong)} video(s) won't play on Windows — optimize them in "
                        f"Book Details or Project ▸ Videos: "
                        + ", ".join(wrong[:5]) + (", …" if len(wrong) > 5 else "")}
    return {"toplam": len(videos)}
