"""Prototype step 3: CV fallback for answers with no vector blank.

Some books draw the write-on areas as part of a raster illustration
(banners, boxes inside artwork). Those never appear in the vector or
text layers, so snap-to-blank fails. This module finds them with
classic CV on a render of the ORIGINAL page (the area under the answer
is empty there):

  flood fill from seed points in/around the answer bbox -> the
  connected near-uniform colored region (banner/box) -> bounding rect.

Returns None when the filled region fails sanity checks, so callers
keep the needs_review flag.
"""

import time

import cv2
import fitz
import numpy as np

CV_ZOOM = 3.0

# Flood fill tolerance per channel.
TOLERANCE = (18, 18, 18)

# Sanity limits for an accepted region (PDF points).
MAX_W, MAX_H = 260.0, 90.0
MAX_AREA_RATIO = 60.0      # region area vs answer area

# Render only a neighbourhood of the answer, not the whole page: some
# pages cost >60s to rasterize in full (pathological vector art) but a
# small clip renders in ~0.04s. We start TIGHT and only grow the clip
# when the found box runs into an artificial (non-page) clip edge — a
# banner that was cut off. If a render is itself slow (the pathological
# content sits right by the answer) we stop growing rather than pay an
# even bigger slow render. Margins are the half-extent around the answer
# in PDF points; y is scaled down (banners are wider than tall).
CV_MARGINS = (40.0, 140.0, 320.0)
CV_MARGIN_Y_RATIO = 0.7
CV_RENDER_BUDGET = 3.0      # a render slower than this => pathological page
EDGE_SLACK = 16.0           # clip edge this close to the page edge != a cut


def render_page_bgr(page, zoom=CV_ZOOM):
    pix = page.get_pixmap(matrix=fitz.Matrix(zoom, zoom))
    img = np.frombuffer(pix.samples, dtype=np.uint8).reshape(pix.height, pix.width, pix.n)
    return cv2.cvtColor(img, cv2.COLOR_RGB2BGR)


def _seed_points(bbox_px, img_shape):
    """Candidate seeds: center plus points just outside the text bbox,
    all clamped to the image."""
    x0, y0, x1, y1 = bbox_px
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    h = y1 - y0
    pts = [
        (cx, cy),
        (cx, y0 - h * 0.4), (cx, y1 + h * 0.4),
        (x0 - h * 0.6, cy), (x1 + h * 0.6, cy),
        ((x0 + cx) / 2, cy), ((x1 + cx) / 2, cy),
    ]
    H, W = img_shape[:2]
    return [(int(min(max(x, 0), W - 1)), int(min(max(y, 0), H - 1))) for x, y in pts]


def _flood_region(img, bbox_px, answer_area, zoom):
    """Best flood-filled region around the answer, as clip-local pixels
    (x0, y0, x1, y1), or None. bbox_px = answer bbox in clip-local px."""
    ax0, ay0, ax1, ay1 = bbox_px
    img = cv2.GaussianBlur(img, (3, 3), 0)   # knock out print noise
    H, W = img.shape[:2]
    best = None
    best_score = 0.0
    for seed in _seed_points(bbox_px, img.shape):
        mask = np.zeros((H + 2, W + 2), np.uint8)
        try:
            cv2.floodFill(img.copy(), mask, seed, 0,
                          loDiff=TOLERANCE, upDiff=TOLERANCE,
                          flags=cv2.FLOODFILL_MASK_ONLY
                          | cv2.FLOODFILL_FIXED_RANGE | 8)
        except cv2.error:
            continue
        region = mask[1:-1, 1:-1]
        ys, xs = np.nonzero(region)
        if len(xs) == 0:
            continue
        x0, x1 = int(xs.min()), int(xs.max())
        y0, y1 = int(ys.min()), int(ys.max())

        w_pt, h_pt = (x1 - x0) / zoom, (y1 - y0) / zoom
        area = (x1 - x0) * (y1 - y0)
        if w_pt > MAX_W or h_pt > MAX_H:
            continue                      # bled into the background
        if area > answer_area * MAX_AREA_RATIO:
            continue
        # Region must cover most of the answer horizontally; vertically the
        # text often overflows small banners, so be lenient.
        cover_x = min(ax1, x1) - max(ax0, x0)
        cover_y = min(ay1, y1) - max(ay0, y0)
        if cover_x < (ax1 - ax0) * 0.6 or cover_y < (ay1 - ay0) * 0.35:
            continue
        # Prefer the largest sane region (full banner beats partial fills).
        if area > best_score:
            best_score = area
            best = (x0, y0, x1, y1)
    return best


def cv_snap_box(page, answer_bbox_pt, zoom=CV_ZOOM):
    """Find the raster box/banner the answer is written on.

    Renders a clip around the answer (NOT the whole page — some pages
    take >60s to rasterize) and flood-fills within it. Starts tight and
    grows the clip only when the found box hits an artificial clip edge
    (a banner that was cut); stops growing on a slow render.
    answer_bbox_pt: bbox in PDF points. Returns rect in PDF points or None.
    """
    ax0p, ay0p, ax1p, ay1p = answer_bbox_pt
    pr = page.rect
    best = None
    for margin in CV_MARGINS:
        mx, my = margin, margin * CV_MARGIN_Y_RATIO
        cx0, cy0 = max(pr.x0, ax0p - mx), max(pr.y0, ay0p - my)
        cx1, cy1 = min(pr.x1, ax1p + mx), min(pr.y1, ay1p + my)
        clip = fitz.Rect(cx0, cy0, cx1, cy1)
        t0 = time.time()
        pix = page.get_pixmap(matrix=fitz.Matrix(zoom, zoom), clip=clip)
        slow = (time.time() - t0) > CV_RENDER_BUDGET
        img = np.frombuffer(pix.samples, dtype=np.uint8).reshape(
            pix.height, pix.width, pix.n)
        img = cv2.cvtColor(img, cv2.COLOR_RGB2BGR)
        ox, oy = pix.x, pix.y          # clip top-left in device (zoomed) px
        H, W = img.shape[:2]

        bbox_px = [ax0p * zoom - ox, ay0p * zoom - oy,
                   ax1p * zoom - ox, ay1p * zoom - oy]
        answer_area = max((bbox_px[2] - bbox_px[0]) *
                          (bbox_px[3] - bbox_px[1]), 1.0)
        reg = _flood_region(img, bbox_px, answer_area, zoom)
        if reg:
            x0, y0, x1, y1 = reg
            best = [(ox + x0) / zoom, (oy + y0) / zoom,
                    (ox + x1) / zoom, (oy + y1) / zoom]
            # Did the region run into a clip edge that is NOT (near) the
            # page boundary? If so the banner was cut — grow and retry.
            # SLACK: a clip edge within a few pt of the page edge has no
            # room to cut a banner, so don't grow for it (avoids a slow
            # render chasing answers that sit in the page margin).
            S = EDGE_SLACK
            cut = ((x0 <= 1 and cx0 > pr.x0 + S) or
                   (x1 >= W - 2 and cx1 < pr.x1 - S) or
                   (y0 <= 1 and cy0 > pr.y0 + S) or
                   (y1 >= H - 2 and cy1 < pr.y1 - S))
            if not cut:
                break          # complete box, no need for a bigger clip
        if slow:
            break              # pathological render — don't pay a bigger one

    if best:
        # The clickable must cover the answer text even where it
        # overflows the banner artwork.
        best = [min(best[0], ax0p), min(best[1], ay0p),
                max(best[2], ax1p), max(best[3], ay1p)]
    return best
