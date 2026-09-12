"""Prototype step 8: audio (headphone) icon detection.

Listening icons are vector glyphs, not embedded images: a tight
cluster of small curve drawings. Detection needs no template:

  1. merge nearby small drawings into icon-sized clusters
  2. keep clusters that sit on a text line whose text says
     "Listen ..." (the instruction the icon belongs to)

audio_path stays empty — the mp3 mapping is a separate step (file
order / transcript match), and the editor can assign it manually.

Debug:
  python3 proto_audio.py <original.pdf> <page> [<page> ...]
"""

import os
import re
import sys

import fitz

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from proto_inventory import page_dict, page_drawings

LISTEN_RE = re.compile(r"\b(listen|dinle)", re.IGNORECASE)
ICON_MIN, ICON_MAX = 10.0, 36.0
PAD_PT = 3.0               # grow the click box a little around the glyph

# Illustration-heavy pages decompose their artwork into 100k+ tiny
# vector fragments (Rise Up p13: 358k icon-sized pieces). The
# icon-cluster heuristic is meaningless there — every paint-splatter or
# character outline looks icon-sized — and the O(n*m) merge below is
# quadratic. Above this many candidates we bail and let the AI vision
# layer place the audio/video icons instead (see memory:
# audio-video-icon-detection).
ICON_DENSITY_CAP = 5000


def icon_clusters(page):
    """Icon-sized clusters of small vector drawings."""
    items = []
    for d in page_drawings(page):
        r = d["rect"]
        if r.width > ICON_MAX + 6 or r.height > ICON_MAX + 6 or r.width <= 0:
            continue
        items.append([r.x0, r.y0, r.x1, r.y1])
    if len(items) > ICON_DENSITY_CAP:
        return []
    merged = []
    for b in sorted(items, key=lambda b: (b[1], b[0])):
        host = None
        for m in merged:
            if min(m[2], b[2]) - max(m[0], b[0]) > -3 and \
               min(m[3], b[3]) - max(m[1], b[1]) > -3:
                host = m
                break
        if host:
            host[0] = min(host[0], b[0]); host[1] = min(host[1], b[1])
            host[2] = max(host[2], b[2]); host[3] = max(host[3], b[3])
        else:
            merged.append(list(b))
    return [m for m in merged
            if ICON_MIN <= m[2] - m[0] <= ICON_MAX
            and ICON_MIN <= m[3] - m[1] <= ICON_MAX]


def detect_audio_icons(page):
    """Headphone-icon bboxes: an icon cluster on a 'Listen ...' line."""
    spans = []
    for b in page_dict(page)["blocks"]:
        if b["type"] != 0:
            continue
        for l in b["lines"]:
            for s in l["spans"]:
                if s["text"].strip():
                    spans.append({"text": s["text"], "bbox": s["bbox"]})
    icons = []
    for c in icon_clusters(page):
        cy = (c[1] + c[3]) / 2
        line = [s for s in spans
                if s["bbox"][1] - 6 <= cy <= s["bbox"][3] + 6
                and abs((s["bbox"][0] + s["bbox"][2]) / 2 - c[0]) < 280]
        # Instruction sentences only — a lone all-caps "LISTENING"
        # banner title marks a section header, not an audio button.
        hits = [s for s in line if LISTEN_RE.search(s["text"])]
        if any(not re.fullmatch(r"[A-ZĞÜŞİÖÇI\s]+", s["text"].strip())
               for s in hits):
            icons.append(c)
    return icons


# Case-SENSITIVE: instructions start with a capital ("Listen and
# repeat.") — lowercase "listen to music" is exercise content
# (word-pool chips, option texts) and must not spawn buttons.
LISTEN_LINE_RE = re.compile(r"^\s*[A-H]?[.)]?\s*Listen\b")
WATCH_LINE_RE = re.compile(r"^\s*[A-H]?[.)]?\s*Watch\b")


def instruction_spots(page, line_re):
    """Lines whose text STARTS an instruction matching line_re —
    publishers without a printed icon still mark listening/watching
    exercises in text; the media button goes at the line start."""
    spots = []
    for b in page_dict(page)["blocks"]:
        if b["type"] != 0:
            continue
        for l in b["lines"]:
            spans = [s for s in l["spans"] if s["text"].strip()]
            if not spans:
                continue
            text = " ".join(s["text"].strip() for s in spans)
            if line_re.match(text) and len(text) > 8:
                x0 = min(s["bbox"][0] for s in spans)
                y0 = min(s["bbox"][1] for s in spans)
                y1 = max(s["bbox"][3] for s in spans)
                h = y1 - y0
                spots.append([x0 - h - 4, y0, x0 - 4, y1])
    return spots


def listen_instruction_spots(page):
    return instruction_spots(page, LISTEN_LINE_RE)


# ---------------------------------------------------------------------------
# Video planning (2026-09-06). Video files are named by UNIT, not page
# ("Unit_1.mp4", "UG4-UNIT_3.mp4", "NEXT_LEVEL_2_-_UNIT_1.mp4", "K1-S_16-11.mp4"),
# so the mapping needs the book's module structure: page-coded names go to
# their page, unit-coded names go to that module's "Watch ..." pages.
# ---------------------------------------------------------------------------
VIDEO_EXTS = (".mp4", ".m4v", ".mov", ".webm")
# Video-exercise signals, strongest first. The button belongs on the page
# that tells the student to watch NOW ("Watch the video", "Watch video 2.1"),
# not on the warm-up page ("Before you watch, discuss in pairs") nor on a
# lone "VIDEO" banner (Switch To CLIL prints one a page early).
WATCH_DIRECT_RE = re.compile(
    r"^\s*(?:\d{1,2}|[A-H])?\s*[.)]?\s*(?:watch|schau(?:t|en)?|sieh|seht)\b", re.I)
WATCH_WHILE_RE = re.compile(
    r"^\s*(?:\d{1,2}|[A-H])?\s*[.)]?\s*while\s+you\s+watch\b", re.I)
WATCH_SOFT_RE = re.compile(
    r"^\s*(?:\d{1,2}|[A-H])?\s*[.)]?\s*(?:before|after)\s+you\s+watch\b"
    r"|\bwatch\b[^.]{0,30}\b(video|film|clip)\b", re.I)
VIDEO_WORD_RE = re.compile(r"\b(video|film|clip)\b", re.I)
WATCH_HEAD_RE = re.compile(r"^\s*(video|let'?s\s+watch)\s*[.:!]?\s*$", re.I)
# A follow-up page ("After you watch ...") gets its own button in some books
# (Next Level); a warm-up page ("Before you watch ...") never does.
AFTER_WATCH_RE = re.compile(r"\bafter\s+you\s+watch\b", re.I)
_FILE_PAGE_RE = re.compile(r"(?:\bS_?|\bpage[\s_-]*|\bpg[\s_-]*)(\d{1,3})(?:-(\d{1,3}))?", re.I)
_FILE_UNIT_RE = re.compile(r"(?:unit|ünite|kapitel|lektion|theme|chapter|module|einheit)[\s_-]*(\d{1,2})(?!\d)|\bK(\d{1,2})(?!\d)", re.I)
_FILE_START_RE = re.compile(r"starter|einstieg|intro|^W-", re.I)
_MOD_UNIT_RE = re.compile(r"\b(?:unit|ünite|unite|kapitel|lektion|theme|chapter|module|einheit|practice\s+test|topic)\s*[-:]?\s*(\d{1,2})\b", re.I)


def watch_spots(page):
    """[(bbox, tier)] for lines that signal a video exercise.
    tier 3 = "Watch ..." imperative on a page that mentions a video,
    tier 2 = "While you watch ...", tier 1 = warm-up / soft mention or a
    lone VIDEO banner, 0 = not a signal (never returned)."""
    blocks = page_dict(page)["blocks"]
    lines, has_video = [], False
    for b in blocks:
        if b["type"] != 0:
            continue
        for l in b["lines"]:
            spans = [s for s in l["spans"] if s["text"].strip()]
            if not spans:
                continue
            text = " ".join(s["text"].strip() for s in spans)
            if VIDEO_WORD_RE.search(text):
                has_video = True
            lines.append((text, spans))
    spots = []
    for text, spans in lines:
        if len(text) > 200:
            continue
        if WATCH_HEAD_RE.match(text):
            tier = 1
        elif WATCH_SOFT_RE.match(text) or WATCH_SOFT_RE.search(text):
            tier = 3 if (WATCH_DIRECT_RE.match(text) and has_video) else 1
        elif WATCH_WHILE_RE.match(text):
            tier = 2 if has_video else 1
        elif WATCH_DIRECT_RE.match(text) and len(text) > 8:
            tier = 3 if has_video else 1
        else:
            continue
        x0 = min(s["bbox"][0] for s in spans)
        y0 = min(s["bbox"][1] for s in spans)
        y1 = max(s["bbox"][3] for s in spans)
        h = y1 - y0
        spots.append(([x0 - h - 4, y0, x0 - 4, y1], tier))
    return spots


def page_tier(doc, pg):
    sp = watch_spots(doc[pg - 1])
    return max((t for _, t in sp), default=0)


def _has_after_watch(doc, pg):
    return bool(AFTER_WATCH_RE.search(doc[pg - 1].get_text("text")))


def watch_pages(doc, pages, want=1):
    """The `want` best video pages among `pages`: highest tier first,
    then page order; the chosen set is returned in PAGE order. A single
    video also lands on the page right after it when that page is the
    exercise's "After you watch" half."""
    cands = [(pg, page_tier(doc, pg)) for pg in pages]
    cands = [(pg, t) for pg, t in cands if t > 0]
    if not cands:
        return []
    cands.sort(key=lambda c: (-c[1], c[0]))
    chosen = sorted(pg for pg, _ in cands[:max(1, want)])
    if want == 1 and chosen:
        nxt = chosen[0] + 1
        if nxt in pages and _has_after_watch(doc, nxt) \
                and not _has_after_watch(doc, chosen[0]):
            chosen.append(nxt)
    return chosen


def _video_files(videos_dir):
    out = []
    for dp, dns, fns in os.walk(videos_dir):
        dns[:] = sorted(d for d in dns if not d.startswith("."))
        rel = os.path.relpath(dp, videos_dir).replace(os.sep, "/")
        for f in sorted(fns):
            if f.lower().endswith(VIDEO_EXTS) and not f.startswith("._"):
                out.append(f if rel == "." else f"{rel}/{f}")
    return out


def _file_rank(name):
    """Base unit video first, its "plus" second, story/extra videos last."""
    base = os.path.basename(name).lower()
    m = _FILE_UNIT_RE.search(base) or _FILE_START_RE.search(base)
    prefix = base[:m.start()] if m else base
    # a long descriptive prefix ("Ollie_and_His_Friends_Unit_1") is a story
    # /extra video; a short series tag ("UG4-", "NEXT_LEVEL_2_-_") is not
    extra = 1 if len(prefix) > 16 else 0
    plus = 1 if "plus" in base else 0
    return (extra, plus, base)


def plan_videos(original_doc, all_pages, videos_dir):
    """{page_number: [{"file": rel_path, "needs_review": bool}]}.

    all_pages: ai_analyzer's page list ({page_number, module_name}). Pages
    are looked up in original_doc by page_number (1-based)."""
    if not videos_dir or not os.path.isdir(videos_dir):
        return {}
    files = _video_files(videos_dir)
    if not files:
        return {}
    n = original_doc.page_count
    # module index -> unit number (first module = 0 = starter/intro)
    modules, order = {}, []
    for p in all_pages:
        m = p.get("module_name", "")
        if m not in modules:
            modules[m] = []
            order.append(m)
        modules[m].append(p["page_number"])
    unit_of = {}
    for idx, m in enumerate(order):
        mm = _MOD_UNIT_RE.search(m or "")
        unit_of[m] = int(mm.group(1)) if mm else (0 if idx == 0 else None)
    by_unit = {u: m for m, u in unit_of.items() if u is not None}

    plan = {}
    unit_files = {}
    seq_files = []
    for f in files:
        base = os.path.basename(f)
        stem = os.path.splitext(base)[0]
        if re.fullmatch(r"\d{1,3}", stem):
            # bare sequential numbering (1.mp4, 2.mp4 ...): book order, not
            # page or unit — resolved against the watch pages below.
            seq_files.append((int(stem), f))
            continue
        mp = _FILE_PAGE_RE.search(base)
        if mp:
            a = int(mp.group(1))
            b = int(mp.group(2)) if mp.group(2) and a < int(mp.group(2)) <= a + 3 else a
            for pg in range(a, b + 1):
                if 1 <= pg <= n:
                    plan.setdefault(pg, []).append({"file": f, "needs_review": False})
            continue
        mu = _FILE_UNIT_RE.search(base)
        if mu:
            u = int(mu.group(1) or mu.group(2))
        elif _FILE_START_RE.search(base):
            u = 0
        else:
            continue
        unit_files.setdefault(u, []).append(f)

    if seq_files:
        seq_files.sort()
        # One file per module is the common shape (a unit's video); fall back
        # to a flat run over the strong watch pages.
        per_module = []
        for m in order:
            wp = watch_pages(original_doc, [p for p in modules[m] if 1 <= p <= n], 1)
            if wp:
                per_module.append(wp[0])
        if len(per_module) >= len(seq_files):
            targets = per_module[:len(seq_files)]
        else:
            targets = watch_pages(original_doc, list(range(1, n + 1)), len(seq_files))
        for i, (_, f) in enumerate(seq_files):
            if i < len(targets):
                plan.setdefault(targets[i], []).append({"file": f, "needs_review": False})
                nxt = targets[i] + 1
                if nxt <= n and _has_after_watch(original_doc, nxt) \
                        and not _has_after_watch(original_doc, targets[i]) \
                        and nxt not in targets:
                    # a follow-up "After you watch" page: some books repeat the
                    # button there, some do not — emit it, but flag it.
                    plan.setdefault(nxt, []).append({"file": f, "needs_review": True})
            else:
                park = targets[-1] if targets else 1
                plan.setdefault(park, []).append({"file": f, "needs_review": True})

    for u, fl in unit_files.items():
        fl = sorted(fl, key=_file_rank)
        m = by_unit.get(u)
        if m is None:
            continue
        pages = [p for p in modules[m] if 1 <= p <= n]
        wpages = watch_pages(original_doc, pages, len(fl))
        if len(fl) == 1:
            targets = wpages or [pages[0]]
            for pg in targets:
                plan.setdefault(pg, []).append({"file": fl[0], "needs_review": not wpages})
        else:
            for i, f in enumerate(fl):
                if i < len(wpages):
                    plan.setdefault(wpages[i], []).append({"file": f, "needs_review": False})
                else:
                    park = wpages[-1] if wpages else pages[0]
                    plan.setdefault(park, []).append({"file": f, "needs_review": True})
    return plan


def build_planned_video_sections(po, sx, sy, entries, video_prefix=""):
    """Editor-format video sections for one page from plan_videos()."""
    sp = watch_spots(po)
    best = max((t for _, t in sp), default=0)
    spots = sorted((b for b, t in sp if t == best), key=lambda b: (b[1], b[0]))
    out = []
    for i, e in enumerate(entries):
        if i < len(spots):
            b = spots[i]
            review = e["needs_review"]
        else:
            b = [28 + 30 * i, 60, 50 + 30 * i, 82]
            review = True
        sec = {
            "type": "video",
            "coords": {
                "x": int((b[0] - PAD_PT) * sx),
                "y": int((b[1] - PAD_PT) * sy),
                "w": int((b[2] - b[0] + 2 * PAD_PT) * sx),
                "h": int((b[3] - b[1] + 2 * PAD_PT) * sy),
            },
            "video_path": f"{video_prefix}{e['file']}",
        }
        if review:
            sec["needs_review"] = True
        out.append(sec)
    return out


def build_video_section(po, sx, sy, video_no, videos_dir=None,
                        video_prefix="", icon_regions=None):
    """One video section per video page — files are numbered in book
    order (1.mp4 for the first video page, ...).

    Position: a play/film icon located by the AI vision layer
    (icon_regions, primary) or, as a fallback, a 'Watch ...' instruction
    line. The keyword fallback stays for now because, unlike audio, it
    did not over-fire; drop it once AI video-icon detection is proven."""
    if icon_regions:
        spots = [list(b) for b in icon_regions]
    else:
        spots = instruction_spots(po, WATCH_LINE_RE)
    if not spots:
        return None
    b = sorted(spots, key=lambda b: (b[1], b[0]))[0]
    path = ""
    if videos_dir and os.path.isdir(videos_dir):
        for ext in ("mp4", "m4v", "mov", "webm"):
            if os.path.exists(os.path.join(videos_dir, f"{video_no}.{ext}")):
                path = f"{video_prefix}{video_no}.{ext}"
                break
    return {
        "type": "video",
        "coords": {
            "x": int((b[0] - PAD_PT) * sx),
            "y": int((b[1] - PAD_PT) * sy),
            "w": int((b[2] - b[0] + 2 * PAD_PT) * sx),
            "h": int((b[3] - b[1] + 2 * PAD_PT) * sy),
        },
        "video_path": path,
    }


AUDIO_EXTS = (".mp3", ".wav", ".m4a", ".ogg")


def page_audio_files(audio_dir, page_num):
    """Audio files whose name encodes this page number. Handles both the
    bare form (``4.mp3``, ``9a.mp3``, ``23c.mp3``) and the labelled form
    some publishers use (``PAGE 10.1.mp3``, ``Page 12 audio.mp3`` — Rise
    Up names 113/117 files this way). The page number must match on a
    word boundary so page 1 does not swallow 10/100."""
    if not audio_dir or page_num is None or not os.path.isdir(audio_dir):
        return []
    n = int(page_num)
    pats = [
        rf"^0*{n}[a-z]?\.",                 # 4.mp3, 9a.mp3
        rf"^0*{n}[_-]\d+\.",               # 15_10.mp3 (page_track), 38-1.mp3
        rf"\bpage[\s_-]*0*{n}\b",          # PAGE_012.mp3, Unit-8-Page-63-Part-3.mp3
        rf"\bpg[\s_-]*0*{n}\b",            # Pg-63.mp3, Unit-7-Pg-78-Part-2.mp3
        rf"\bS_?0*{n}-",                   # K3-S43-15.mp3, S_6-2.mp3 (German "Seite")
    ]
    rx = [re.compile(x, re.IGNORECASE) for x in pats]
    out = []
    # Some publishers nest audio per chapter (Daumen Hoch: audio/K1/...);
    # return paths relative to audio_dir with "/" separators.
    for dp, dns, fns in os.walk(audio_dir):
        dns[:] = sorted(d for d in dns if not d.startswith("."))
        rel = os.path.relpath(dp, audio_dir).replace(os.sep, "/")
        for f in fns:
            if not f.lower().endswith(AUDIO_EXTS) or f.startswith("._"):
                continue
            if any(r.search(f) for r in rx):
                out.append(f if rel == "." else f"{rel}/{f}")
    return sorted(out)


def build_audio_sections(po, sx, sy, page_num=None, audio_dir=None,
                         audio_prefix="", icon_regions=None):
    """Editor-format audio sections.

    Position evidence comes from icon_regions — headphone/speaker icons
    located by the AI vision layer (PDF-point bboxes, written into
    ai_overrides.json). The old deterministic spawners were removed: the
    'Listen ...' keyword line over-fired on illustrated pages and the
    icon-cluster geometry could not tell a headphone from artwork (Rise
    Up emitted 377 phantom audio buttons). See memory:
    audio-video-icon-detection.

    File evidence: audio files named by page number fill in audio_path;
    a file with no position evidence still emits a (needs_review) button
    near the page top for the AI/human to place."""
    spots = [list(b) for b in icon_regions] if icon_regions else []
    spots.sort(key=lambda b: (b[1], b[0]))
    files = page_audio_files(audio_dir, page_num)

    sections = []
    for i in range(max(len(spots), len(files))):
        if i < len(spots):
            b = spots[i]
        else:   # file with no anchor: park it top-left, ask for review
            b = [28 + 30 * (i - len(spots)), 28, 50 + 30 * (i - len(spots)), 50]
        entry = {
            "type": "audio",
            "coords": {
                "x": int((b[0] - PAD_PT) * sx),
                "y": int((b[1] - PAD_PT) * sy),
                "w": int((b[2] - b[0] + 2 * PAD_PT) * sx),
                "h": int((b[3] - b[1] + 2 * PAD_PT) * sy),
            },
            "audio_path": f"{audio_prefix}{files[i]}" if i < len(files) else "",
        }
        if i >= len(spots):
            entry["needs_review"] = True
        sections.append(entry)
    return sections


def main():
    if len(sys.argv) < 3:
        print(__doc__)
        sys.exit(1)
    doc = fitz.open(sys.argv[1])
    for pno in (int(p) for p in sys.argv[2:]):
        icons = detect_audio_icons(doc[pno - 1])
        print(f"page {pno}: {len(icons)} audio icon(s) "
              f"{[[round(v) for v in b] for b in icons]}")


if __name__ == "__main__":
    main()
