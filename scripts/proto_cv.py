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

import cv2
import fitz
import numpy as np

CV_ZOOM = 3.0

# Flood fill tolerance per channel.
TOLERANCE = (18, 18, 18)

# Sanity limits for an accepted region (PDF points).
MAX_W, MAX_H = 260.0, 90.0
MAX_AREA_RATIO = 60.0      # region area vs answer area


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


def cv_snap_box(page_bgr, answer_bbox_pt, zoom=CV_ZOOM):
    """Find the raster box/banner the answer is written on.

    answer_bbox_pt: bbox in PDF points. Returns rect in PDF points or None.
    """
    bbox_px = [v * zoom for v in answer_bbox_pt]
    ax0, ay0, ax1, ay1 = bbox_px
    answer_area = max((ax1 - ax0) * (ay1 - ay0), 1.0)

    # Light blur knocks out print noise/halftone before flood filling.
    img = cv2.GaussianBlur(page_bgr, (3, 3), 0)
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
        x0, x1 = xs.min(), xs.max()
        y0, y1 = ys.min(), ys.max()

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
            best = [x0 / zoom, y0 / zoom, x1 / zoom, y1 / zoom]

    if best:
        # The clickable must cover the answer text even where it
        # overflows the banner artwork.
        best = [min(best[0], answer_bbox_pt[0]), min(best[1], answer_bbox_pt[1]),
                max(best[2], answer_bbox_pt[2]), max(best[3], answer_bbox_pt[3])]
    return best
