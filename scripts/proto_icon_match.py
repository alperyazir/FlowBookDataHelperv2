"""Locate audio/video icons by template matching ONE user-supplied crop,
then write audio/video sections straight into config.json.

This REPLACES AI-vision icon location. The user crops one example icon
(headphone for audio, play/film for video) in the editor; we slide that
template (multi-scale, grayscale) over each page render and keep the
peaks. Matching happens on the SAME page PNG the editor uses, so the
match coordinates are already in PNG-pixel space — no PDF-point
conversion needed.

Icon presence is bimodal within a book (the icon asset is pixel-identical
on every page): on Glory_6 the real icons score 0.74-0.99. Scoped to the
pages that actually have a media file, a 0.7 threshold gives 30/30 real
icons and 0 false positives. (At 0.6, or when scanning icon-free pages,
spurious 0.6-0.7 peaks slip in — hence both the 0.7 default and the
page-scoping below.)

File pairing (which mp3/mp4 a button plays) is unchanged: page-numbered
names (``...Pg-12-...``, ``4.mp3``) pair per page in reading order;
otherwise all found icons pair with all files in book order. Files with
no icon are parked top-left + needs_review (extra tracks of a listening
exercise have no printed glyph — nothing to match).

Usage:
  proto_icon_match.py <config.json> [--audio-icon P] [--video-icon P]
                      [--threshold 0.6] [--no-backup]
"""
import argparse
import json
import os
import re
import shutil
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from _bootstrap import ensure_runtime_deps
ensure_runtime_deps()

import cv2
import numpy as np

AUDIO_EXTS = (".mp3", ".wav", ".m4a", ".ogg")
VIDEO_EXTS = (".mp4", ".m4v", ".mov", ".webm")
MIN_KEEP = 0.45            # collect peaks above this, then threshold filters
# On-page glyph size is unknown up front; sweep template down to these
# target heights (px) and let the best scale win per peak.
SCALE_TARGETS = list(range(24, 92, 6))


# Reading-order helpers — mirror of ai_analyzer.{section_top_y,section_box,
# order_page_sections}, kept local so this standalone tool needs no heavy
# detector import. See ai_analyzer for the full rationale.
def section_top_y(section):
    act = section.get("activity")
    if isinstance(act, dict):
        c = act.get("coords")
        if isinstance(c, dict) and ("x" in c or "y" in c):
            return (c.get("y", 0), c.get("x", 0))
    c = section.get("coords")
    if isinstance(c, dict) and ("x" in c or "y" in c):
        return (c.get("y", 0), c.get("x", 0))
    coords = [a["coords"] for a in section.get("answer", [])
              if isinstance(a, dict) and isinstance(a.get("coords"), dict)]
    if coords:
        return (min(c.get("y", 0) for c in coords),
                min(c.get("x", 0) for c in coords))
    return (0, 0)


def section_box(section):
    act = section.get("activity")
    if isinstance(act, dict) and isinstance(act.get("coords"), dict):
        c = act["coords"]
    elif isinstance(section.get("coords"), dict):
        c = section["coords"]
    else:
        xs, ys = [], []
        for a in section.get("answer", []):
            if isinstance(a, dict) and isinstance(a.get("coords"), dict):
                cc = a["coords"]
                xs += [cc.get("x", 0), cc.get("x", 0) + cc.get("w", 0)]
                ys += [cc.get("y", 0), cc.get("y", 0) + cc.get("h", 0)]
        if not xs:
            return None
        return (min(xs), min(ys), max(xs), max(ys))
    return (c.get("x", 0), c.get("y", 0),
            c.get("x", 0) + c.get("w", 0), c.get("y", 0) + c.get("h", 0))


def order_page_sections(sections, page_width_px=0):
    if len(sections) < 2:
        return list(sections)
    boxes = [section_box(s) for s in sections]
    if page_width_px and all(b is not None for b in boxes):
        mid = page_width_px / 2.0
        margin = page_width_px * 0.06
        def center(b):
            return (b[0] + b[2]) / 2.0
        straddles = any(b[0] < mid - margin and b[2] > mid + margin
                        for b in boxes)
        # Clean two-column only when the midline is an EMPTY gutter: every box
        # sits clearly left or clearly right, none straddling or centered near
        # the middle. A box centered near mid means a 3-column grid or jittery
        # single column, where plain (y,x) row-major is the correct order.
        near_mid = any(mid - margin <= center(b) <= mid + margin for b in boxes)
        has_left = any(center(b) < mid - margin for b in boxes)
        has_right = any(center(b) > mid + margin for b in boxes)
        if has_left and has_right and not straddles and not near_mid:
            order = sorted(
                zip(sections, boxes),
                key=lambda sb: (0 if center(sb[1]) < mid else 1,
                                sb[1][1], sb[1][0]))
            return [s for s, _ in order]
    return sorted(sections, key=section_top_y)


def load_template(path):
    if not path or not os.path.exists(path):
        return None
    t = cv2.imread(path, cv2.IMREAD_GRAYSCALE)
    return t if t is not None and t.size else None


def scaled_templates(tmpl):
    out = []
    for target in SCALE_TARGETS:
        sc = target / tmpl.shape[0]
        w = max(8, int(round(tmpl.shape[1] * sc)))
        h = max(8, int(round(tmpl.shape[0] * sc)))
        out.append((cv2.resize(tmpl, (w, h), interpolation=cv2.INTER_AREA), w, h))
    return out


def find_icons(page_gray, templates, threshold):
    """Return [(cx, cy, size, score), ...] for distinct peaks >= threshold."""
    hits = []
    for t, w, h in templates:
        if page_gray.shape[0] < h or page_gray.shape[1] < w:
            continue
        res = cv2.matchTemplate(page_gray, t, cv2.TM_CCOEFF_NORMED)
        ys, xs = np.where(res >= MIN_KEEP)
        for x, y in zip(xs, ys):
            hits.append((x + w / 2.0, y + h / 2.0, max(w, h), float(res[y, x])))
    hits.sort(key=lambda hh: -hh[3])
    kept = []
    for cx, cy, sz, sc in hits:
        if sc < threshold:
            continue
        if all((cx - k[0]) ** 2 + (cy - k[1]) ** 2 > (sz * 0.7) ** 2 for k in kept):
            kept.append((cx, cy, sz, sc))
    # reading order: top-to-bottom, then left-to-right
    kept.sort(key=lambda k: (round(k[1] / 40), k[0]))
    return kept


def page_files(media_dir, exts, page_num):
    """Media files whose name encodes this page number (bare or labelled)."""
    if not media_dir or page_num is None or not os.path.isdir(media_dir):
        return []
    labelled = re.compile(rf"\bp(?:age|g)?\s*-?\s*0*{page_num}\b", re.IGNORECASE)
    bare = re.compile(rf"^0*{page_num}[a-z]?\.", re.IGNORECASE)
    out = [f for f in os.listdir(media_dir)
           if f.lower().endswith(exts) and (labelled.search(f) or bare.match(f))]
    return sorted(out)


def all_media(media_dir, exts):
    if not media_dir or not os.path.isdir(media_dir):
        return []
    return sorted(f for f in os.listdir(media_dir) if f.lower().endswith(exts))


def resolve_png(book_dir, image_path):
    """image_path like ./books/<name>/images/.. -> abs path under book_dir."""
    name = os.path.basename(book_dir.rstrip("/"))
    key = f"{name}/"
    rel = image_path.split(key, 1)[-1] if key in image_path else image_path.lstrip("./")
    return os.path.join(book_dir, rel)


def icon_box(cx, cy, size):
    s = int(round(size))
    return {"x": int(cx - s / 2), "y": int(cy - s / 2), "w": s, "h": s}


def build_sections(found, files, prefix, kind):
    """Pair found icon positions with media files; park leftover files."""
    path_key = "audio_path" if kind == "audio" else "video_path"
    secs = []
    for i in range(max(len(found), len(files))):
        if i < len(found):
            cx, cy, sz, _ = found[i]
            coords = icon_box(cx, cy, sz)
        else:                       # file with no icon -> park top-left
            off = 30 * (i - len(found))
            coords = {"x": 28 + off, "y": 28, "w": 28, "h": 28}
        sec = {"type": kind, "coords": coords,
               path_key: f"{prefix}{files[i]}" if i < len(files) else ""}
        # Flag for human review when parked (no icon) OR when there is no
        # media file to play (more icons than files) — a path-less button
        # should never look "done".
        if i >= len(found) or not sec[path_key]:
            sec["needs_review"] = True
        secs.append(sec)
    return secs


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("config")
    ap.add_argument("--audio-icon", default="")
    ap.add_argument("--video-icon", default="")
    ap.add_argument("--threshold", type=float, default=0.7)
    ap.add_argument("--no-backup", action="store_true")
    a = ap.parse_args()

    book_dir = os.path.dirname(os.path.abspath(a.config))
    name = os.path.basename(book_dir)
    with open(a.config) as fh:
        cfg = json.load(fh)

    a_tmpl = scaled_templates(load_template(a.audio_icon)) if load_template(a.audio_icon) is not None else None
    v_tmpl = scaled_templates(load_template(a.video_icon)) if load_template(a.video_icon) is not None else None
    if not a_tmpl and not v_tmpl:
        print("no usable icon template given (audio or video) - nothing to do")
        sys.exit(2)

    audio_dir = os.path.join(book_dir, "audio")
    # publishers use either "video" or "videos"; match whichever exists so the
    # matcher and Analyze's fallback agree on where the files live.
    video_dir = next((os.path.join(book_dir, d)
                      for d in ("video", "videos")
                      if os.path.isdir(os.path.join(book_dir, d))),
                     os.path.join(book_dir, "video"))
    a_prefix = f"./books/{name}/audio/"
    v_prefix = f"./books/{name}/video/"

    # collect pages
    pages = []
    for m in cfg.get("books", [{}])[0].get("modules", []):
        for pg in m.get("pages", []):
            pages.append(pg)

    # any page-encoded media names? decides per-page vs book-order pairing.
    # When page-encoded, we ONLY scan pages that actually have a file: this
    # both kills false positives on icon-free pages and is ~6x faster
    # (Glory_6: 24 audio pages vs 223 total).
    audio_files_all = all_media(audio_dir, AUDIO_EXTS)
    video_files_all = all_media(video_dir, VIDEO_EXTS)
    audio_page_encoded = any(page_files(audio_dir, AUDIO_EXTS, pg.get("page_number"))
                             for pg in pages)
    video_page_encoded = any(page_files(video_dir, VIDEO_EXTS, pg.get("page_number"))
                             for pg in pages)

    # The matcher OWNS the section types it is asked to find. Clear them on
    # EVERY page up front so a re-run is idempotent — pages skipped by the
    # per-page prefilter below (no media file there now) must not keep a stale
    # icon section from a previous run. Types we are NOT matching are left
    # untouched (running audio-only must not wipe video sections).
    clear_types = set()
    if a_tmpl is not None:
        clear_types.add("audio")
    if v_tmpl is not None:
        clear_types.add("video")
    for pg in pages:
        pg["sections"] = [s for s in pg.get("sections", [])
                          if s.get("type") not in clear_types]

    stats = {"audio_icons": 0, "video_icons": 0}
    seq_audio_found = []   # for book-order audio pairing
    total = max(1, len(pages))
    step = max(1, total // 50)

    for idx, pg in enumerate(pages):
        if idx % step == 0:
            print(f"PROGRESS: {int(95 * idx / total)}%", flush=True)
        pn = pg.get("page_number")
        a_files = page_files(audio_dir, AUDIO_EXTS, pn) if audio_page_encoded else None
        v_files = page_files(video_dir, VIDEO_EXTS, pn) if video_page_encoded else None
        do_audio = a_tmpl is not None and (not audio_page_encoded or a_files)
        do_video = v_tmpl is not None and (not video_page_encoded or v_files)
        if not (do_audio or do_video):
            continue
        png = resolve_png(book_dir, pg.get("image_path", ""))
        g = cv2.imread(png, cv2.IMREAD_GRAYSCALE) if os.path.exists(png) else None
        if g is None:
            continue
        pg["_img_w"] = int(g.shape[1])   # image-pixel width, for reordering
        keep_other = [s for s in pg.get("sections", [])
                      if s.get("type") not in clear_types]
        new_av = []

        if do_audio:
            found = find_icons(g, a_tmpl, a.threshold)
            if audio_page_encoded:
                new_av += build_sections(found, a_files, a_prefix, "audio")
                stats["audio_icons"] += len(found)
            else:
                for f in found:
                    seq_audio_found.append((pn, f))   # pair after the loop
                stats["audio_icons"] += len(found)

        if do_video:
            vfound = find_icons(g, v_tmpl, a.threshold)
            if video_page_encoded:
                new_av += build_sections(vfound, v_files, v_prefix, "video")
                stats["video_icons"] += len(vfound)
            elif vfound:                       # book-order, resolve after loop
                pg["_vfound"] = vfound

        pg["sections"] = keep_other + new_av
        pg["_reorder"] = True

    # book-order audio pairing (sequential file names like 1.mp3, 2.mp3)
    if a_tmpl is not None and not audio_page_encoded and seq_audio_found:
        seq_audio_found.sort(key=lambda pf: (pf[0], pf[1][1]))   # page, then y
        n = max(len(seq_audio_found), len(audio_files_all))
        per_page = {}
        for i in range(n):
            pn = seq_audio_found[i][0] if i < len(seq_audio_found) else None
            f = seq_audio_found[i][1] if i < len(seq_audio_found) else None
            fname = audio_files_all[i] if i < len(audio_files_all) else None
            per_page.setdefault(pn, []).append((f, fname))
        for pg in pages:
            items = per_page.get(pg.get("page_number"))
            if not items:
                continue
            found = [it[0] for it in items if it[0]]
            files = [it[1] for it in items if it[1]]
            pg["sections"] = ([s for s in pg["sections"] if s.get("type") != "audio"]
                              + build_sections(found, files, a_prefix, "audio"))
            pg["_reorder"] = True

    # book-order video pairing
    if v_tmpl is not None:
        vpages = [pg for pg in pages if pg.get("_vfound")]
        vpages.sort(key=lambda pg: pg.get("page_number") or 0)
        vi = 0
        for pg in vpages:
            secs = []
            for f in pg.pop("_vfound"):
                fname = video_files_all[vi] if vi < len(video_files_all) else None
                cx, cy, sz, _ = f
                sec = {"type": "video", "coords": icon_box(cx, cy, sz),
                       "video_path": f"{v_prefix}{fname}" if fname else ""}
                if not fname:
                    sec["needs_review"] = True
                secs.append(sec)
                vi += 1
                stats["video_icons"] += 1
            pg["sections"] = pg.get("sections", []) + secs
            pg["_reorder"] = True

    # Icon matching re-appends audio/video to the end of a page; restore
    # reading order (left column top-to-bottom, then right) for the pages
    # we touched. Untouched pages keep the order Analyze already gave them.
    for pg in pages:
        w = pg.pop("_img_w", 0)
        if pg.pop("_reorder", False) and pg.get("sections"):
            pg["sections"] = order_page_sections(pg["sections"], w)

    if not a.no_backup:
        shutil.copy(a.config, a.config + ".bak.iconmatch")
    # Serialize fully before truncating config.json — a dump error must not
    # leave the primary config half-written.
    data = json.dumps(cfg, ensure_ascii=False, indent=2)
    with open(a.config, "w") as fh:
        fh.write(data)
    print("PROGRESS: 100%", flush=True)
    print(f"icon-match done: {stats}  (threshold {a.threshold})")
    print(f"wrote {a.config}" + ("" if a.no_backup else " (backup .bak.iconmatch)"))


if __name__ == "__main__":
    main()
