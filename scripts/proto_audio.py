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
    labelled = re.compile(rf"\bpage\s*0*{page_num}\b", re.IGNORECASE)
    bare = re.compile(rf"^0*{page_num}[a-z]?\.", re.IGNORECASE)
    out = []
    for f in os.listdir(audio_dir):
        if not f.lower().endswith(AUDIO_EXTS):
            continue
        if labelled.search(f) or bare.match(f):
            out.append(f)
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
