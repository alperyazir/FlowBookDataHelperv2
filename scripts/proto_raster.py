"""Raster-diff channel: pixel-level answer evidence from the render cache.

Complements the text/vector diffs (proto_inventory) with a third signal
computed on the ALIGNED render pair produced by proto_prep:

  changed-pixel mask  ->  what visibly differs on the answered page
  blobs               ->  connected changed regions + features, in
                          ORIGINAL-page PDF points

Two consumers:
  - fusion guard (proto_snap): a text-diff "answer" whose bbox contains
    ~no changed pixels renders identically after alignment — a phantom
    (span-splitting / re-typeset echo). Real typed answers always leave ink.
  - recovery: blobs overlapping NO text-diff answer are non-text marks
    (graphic checkmarks, stamped answers, raster text) that the text
    diff cannot see at all — candidates for tick-fills / AI review.

Everything is deterministic; when the render cache is missing the
channel reports None and callers keep the pre-raster behaviour.

Usage (diagnostic):
  python3 proto_raster.py <book_dir | config.json> [first last] [--save]
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from proto_inventory import (_cached, _book_dir, find_image_rects, get_spans,
                             page_offset)

try:
    import cv2
    import numpy as np
    from PIL import Image
    from proto_prep import DPI, render_path
    HAVE_RASTER = True
except ImportError:
    HAVE_RASTER = False

# Changed-pixel detection (144 dpi renders, 2 px per pt).
DIFF_THRESH = 60          # per-channel |orig - ans| for a "changed" pixel
OPEN_KERNEL = (2, 2)      # kills 1px antialias fringes along glyph edges
GROUP_DILATE = (5, 9)     # merge px this close into one blob (h, w)
MIN_AREA_PX = 40          # blob area (changed px) below this = speck
INK_THRESH = 200          # original gray below this = printed ink

# Blob-extraction sanity caps. Pages whose answered side RE-RENDERS its
# artwork (Rise Up p101: 827k drawings on the answered side) produce a
# page-wide noise mask — tens of thousands of components that cost
# minutes to walk and mean nothing for mark recovery. Real answer pages
# measure far below both caps.
MAX_CHANGED_FRAC = 0.10   # >10% of the page changed = re-render, not marks
MAX_COMPONENTS = 3000     # component count above this = noise flood


def _load_gray_rgb(path):
    with Image.open(path) as im:
        rgb = np.asarray(im.convert("RGB"), dtype=np.uint8)
    return rgb


def change_data(po, pa):
    """Aligned pixel-diff data for one page, or None (no cache/deps).

    dict: mask (uint8 0/255, original-render frame), scale (px per pt),
    orig (RGB), ans_aligned (RGB)."""
    if not HAVE_RASTER:
        return None
    return _cached(po, ("raster_diff", id(pa)),
                   lambda: _build_change_data(po, pa))


def _build_change_data(po, pa):
    bo, ba = _book_dir(po), _book_dir(pa)
    if not (bo and ba):
        return None
    pno = po.number + 1
    p_o = render_path(bo, "orig", pno, expect_pdf=getattr(po.parent, "name", None))
    p_a = render_path(ba, "ans", pno, expect_pdf=getattr(pa.parent, "name", None))
    if not (p_o and p_a):
        return None
    o = _load_gray_rgb(p_o)
    a = _load_gray_rgb(p_a)
    h, w = min(o.shape[0], a.shape[0]), min(o.shape[1], a.shape[1])
    o, a = o[:h, :w], a[:h, :w]
    # px per pt is fixed by the render DPI (both sides rendered at DPI),
    # NOT w/po.rect.width: when the two exports differ in page width, w is
    # the CROPPED (min) width, so that ratio understates the scale and every
    # original-space bbox lookup lands left/high of the real pixels. DPI/72
    # is exact for the original render frame the mask lives in.
    scale = DPI / 72.0                             # px per pt

    off = page_offset(po, pa)
    dx, dy = off["dx"] * scale, off["dy"] * scale  # answered-minus-original, px
    if abs(dx) > 0.01 or abs(dy) > 0.01:
        M = np.float32([[1, 0, -dx], [0, 1, -dy]])
        a = cv2.warpAffine(a, M, (w, h), flags=cv2.INTER_LINEAR,
                           borderMode=cv2.BORDER_CONSTANT,
                           borderValue=(255, 255, 255))

    diff = cv2.absdiff(o, a).max(axis=2)
    mask = (diff > DIFF_THRESH).astype(np.uint8) * 255
    mask = cv2.morphologyEx(mask, cv2.MORPH_OPEN,
                            np.ones(OPEN_KERNEL, np.uint8))
    return {"mask": mask, "diff": diff, "scale": scale, "orig": o, "ans": a,
            "changed_frac": float(mask.mean()) / 255.0}


def support_fraction(po, pa, bbox_pt, pad_pt=1.0):
    """Share of a bbox (original-space pt) covered by changed pixels.
    None when the raster channel is unavailable for this page."""
    cd = change_data(po, pa)
    if cd is None:
        return None
    # Page-wide re-render (answered side re-rasterized its artwork): the mask
    # is noise, so EVERY bbox would read high support and phantoms would be
    # "rescued". Report no evidence instead — callers then keep the answer
    # rather than trust a poisoned measurement (same fail-safe as no cache).
    if cd["changed_frac"] > MAX_CHANGED_FRAC:
        return None
    s = cd["scale"]
    H, W = cd["mask"].shape
    x0 = max(0, int((bbox_pt[0] - pad_pt) * s))
    y0 = max(0, int((bbox_pt[1] - pad_pt) * s))
    x1 = min(W, int((bbox_pt[2] + pad_pt) * s) + 1)
    y1 = min(H, int((bbox_pt[3] + pad_pt) * s) + 1)
    if x1 <= x0 or y1 <= y0:
        return 0.0
    return float(cd["mask"][y0:y1, x0:x1].mean()) / 255.0


def raster_blobs(po, pa):
    """Connected changed regions with features, or None (no channel).

    Each blob: bbox_pt (original space), area_px (changed pixels),
    fill_ratio (changed px / bbox px), on_ink (share of changed px on
    original print), on_text (share inside original text spans),
    in_image (share inside embedded photo rects — photo interiors differ
    between exports through recompression/resampling, so changes there
    are untrusted), mean_diff (mean |orig-ans| over changed px: strong
    overlays ~200, recompression noise barely over threshold),
    color (mean answered RGB of changed px)."""
    cd = change_data(po, pa)
    if cd is None:
        return None
    return _cached(po, ("raster_blobs", id(pa)),
                   lambda: _build_blobs(po, cd))


def _build_blobs(po, cd):
    mask, scale = cd["mask"], cd["scale"]
    if float(mask.mean()) / 255.0 > MAX_CHANGED_FRAC:
        return []          # page-wide re-render noise, not answer marks
    grouped = cv2.dilate(mask, np.ones(GROUP_DILATE, np.uint8))
    n, labels, stats, _ = cv2.connectedComponentsWithStats(grouped)
    if n > MAX_COMPONENTS:
        return []          # noise flood: walking it costs minutes
    orig_gray = cv2.cvtColor(cd["orig"], cv2.COLOR_RGB2GRAY)
    ink = orig_gray < INK_THRESH
    spans = [s["bbox"] for s in get_spans(po)]
    img_rects = [r["bbox"] for r in find_image_rects(po)]

    def rect_cover(x0, y0, x1, y1, rects):
        """Fraction of the blob box lying inside the given pt-rects."""
        area = max(1, (x1 - x0) * (y1 - y0))
        cov = 0
        for b in rects:
            bx0, by0 = int(b[0] * scale), int(b[1] * scale)
            bx1, by1 = int(b[2] * scale), int(b[3] * scale)
            ix = min(x1, bx1) - max(x0, bx0)
            iy = min(y1, by1) - max(y0, by0)
            if ix > 0 and iy > 0:
                cov += ix * iy
        return min(1.0, cov / area)

    blobs = []
    for i in range(1, n):
        x, y, w, h = (int(v) for v in stats[i][:4])
        region = mask[y:y + h, x:x + w]
        sub = (labels[y:y + h, x:x + w] == i) & (region > 0)
        area = int(sub.sum())
        if area < MIN_AREA_PX:
            continue
        ys, xs = np.nonzero(sub)
        bx0, bx1 = x + int(xs.min()), x + int(xs.max()) + 1
        by0, by1 = y + int(ys.min()), y + int(ys.max()) + 1
        local = sub[by0 - y:by1 - y, bx0 - x:bx1 - x]
        changed_orig_ink = ink[by0:by1, bx0:bx1][local]
        colors = cd["ans"][by0:by1, bx0:bx1][local]
        amps = cd["diff"][by0:by1, bx0:bx1][local]
        blobs.append({
            "bbox_pt": [bx0 / scale, by0 / scale, bx1 / scale, by1 / scale],
            "area_px": area,
            "fill_ratio": area / max(1, (bx1 - bx0) * (by1 - by0)),
            "on_ink": float(changed_orig_ink.mean()) if area else 0.0,
            "on_text": rect_cover(bx0, by0, bx1, by1, spans),
            "in_image": rect_cover(bx0, by0, bx1, by1, img_rects),
            "mean_diff": float(amps.mean()) if area else 0.0,
            "color": [int(c) for c in colors.mean(axis=0)] if area else [0, 0, 0],
        })
    blobs.sort(key=lambda b: (b["bbox_pt"][1], b["bbox_pt"][0]))
    return blobs


# Raster-only mark recovery. Graphic checkmarks (Rise Up "Listen and ✓":
# green ticks stamped on the artwork) exist in NO text or vector layer the
# fill stage reads — the raster channel is the only detector that sees
# them. Conservative gates; every emitted candidate is needs_review.
TICK_MIN_PT, TICK_MAX_PT = 6.0, 40.0   # side length of a stamped mark
TICK_MEAN_DIFF_MIN = 100.0             # strong overlay, not recompression
TICK_FILL_MIN = 0.10                   # stroke coverage inside the bbox
TICK_IN_IMAGE_MAX = 0.5                # photo interiors are untrusted
TICK_ON_TEXT_MAX = 0.3                 # re-typeset glyph noise sits on text
TICK_PAGE_CAP = 20                     # more = artwork re-render, not marks


def tick_candidates(po, pa, taken_rects_pt=None):
    """Small, strong, isolated changed marks = likely stamped answers.

    taken_rects_pt: original-space rects already claimed by other
    answers (text-diff fills) — overlapping blobs are theirs, not new.
    Returns [] when the channel is off or the page fails sanity gates."""
    if not get_spans(po):
        return []          # no text baseline: page diff is unreliable
    if page_offset(po, pa)["method"] == "raster_low":
        return []          # re-laid-out page: changed pixels are noise
    blobs = raster_blobs(po, pa)
    if not blobs:
        return []
    taken = taken_rects_pt or []

    def free(b):
        x0, y0, x1, y1 = b["bbox_pt"]
        for r in taken:
            if min(x1, r[2]) > max(x0, r[0]) and min(y1, r[3]) > max(y0, r[1]):
                return False
        return True

    out = []
    for b in blobs:
        w = b["bbox_pt"][2] - b["bbox_pt"][0]
        h = b["bbox_pt"][3] - b["bbox_pt"][1]
        if not (TICK_MIN_PT <= w <= TICK_MAX_PT and
                TICK_MIN_PT <= h <= TICK_MAX_PT):
            continue
        if b["mean_diff"] < TICK_MEAN_DIFF_MIN:
            continue
        if b["fill_ratio"] < TICK_FILL_MIN:
            continue
        if b["in_image"] > TICK_IN_IMAGE_MAX:
            continue
        if b["on_text"] > TICK_ON_TEXT_MAX:
            continue
        if not free(b):
            continue
        out.append(b)
    if len(out) > TICK_PAGE_CAP:
        return []          # page-wide artwork re-render, defer to AI
    return out


# ---------------------------------------------------------------------------

def main():
    import fitz
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    save = "--save" in sys.argv
    book = args[0]
    if book.endswith(".json"):
        book = os.path.dirname(os.path.abspath(book))
    from ai_analyzer import find_answered_pdf, find_original_pdf
    cfg = os.path.join(book, "config.json")
    orig = fitz.open(find_original_pdf(cfg))
    ans = fitz.open(find_answered_pdf(cfg))
    n = min(len(orig), len(ans))
    first, last = (int(args[1]), int(args[2])) if len(args) >= 3 else (1, n)

    out_dir = os.path.join(book, "cache", "raster_diag")
    if save:
        os.makedirs(out_dir, exist_ok=True)
    total = pages_with = 0
    for pno in range(first, last + 1):
        po, pa = orig[pno - 1], ans[pno - 1]
        blobs = raster_blobs(po, pa)
        if blobs is None:
            print(f"  p{pno}: raster channel unavailable")
            continue
        if blobs:
            pages_with += 1
            total += len(blobs)
            big = sum(1 for b in blobs if b["area_px"] > 400)
            print(f"  p{pno}: blobs={len(blobs)} big={big} "
                  f"on_text_avg={sum(b['on_text'] for b in blobs)/len(blobs):.2f}")
        if save and blobs:
            cd = change_data(po, pa)
            img = cd["ans"].copy()
            s = cd["scale"]
            for b in blobs:
                x0, y0, x1, y1 = [int(v * s) for v in b["bbox_pt"]]
                cv2.rectangle(img, (x0, y0), (x1, y1), (255, 0, 0), 2)
            Image.fromarray(img).save(
                os.path.join(out_dir, f"page_{pno:03d}_blobs.png"))
        po = pa = None
    print(f"== {os.path.basename(book)}: pages {first}-{last}, "
          f"pages_with_blobs={pages_with}, total_blobs={total}")
    orig.close(); ans.close()


if __name__ == "__main__":
    main()
