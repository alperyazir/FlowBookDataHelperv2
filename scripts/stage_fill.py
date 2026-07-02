"""Fill detection engine (used by the editor's Analyze via ai_analyzer).

Diffs the answered page against the original and snaps each answer overlay
to the blank/box it belongs to. Runs with use_cv=False (tight text bboxes)
— the same path as the editor's "select fill + c" re-check: uniform box
sizes and ~5x faster than the OpenCV flood-fill fallback.

`detect_fills()` is the whole pipeline: registered diff -> snap ->
echo/prose cleanup with raster rescue -> graphic-checkmark recovery.

Standalone dev run (page range via FB_PAGE_RANGE=1-30):
    python3 stage_fill.py <config.json> <settings.json>
"""

import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from proto_snap import snap_page, px_coords
from proto_inventory import get_spans
try:
    from proto_raster import support_fraction, tick_candidates
    HAVE_RASTER = True
except ImportError:
    HAVE_RASTER = False

# An unsnapped answer that looks like a re-typeset echo (its text exists
# printed on the page) or like re-typeset prose (multi-word, no blank) can
# also be a REAL answer: option letters copied into boxes, sentences written
# into empty gaps. A real echo renders IDENTICALLY after alignment, a real
# answer leaves ink — raster support at the answer's own position tells
# them apart. Calibration: real answers measure >=0.04 (Amazing p57 'c'),
# true echoes <=0.02 (Rise Up numbers, dot-leaders, icon glyphs).
ECHO_RESCUE_SUPPORT = 0.03

name = "fill"
owned_types = {"fill"}

# STEP 2 — structure-first phantom filter (the general form of "fill + c").
#
# A real fill answer sits ON a blank line or tick box drawn in the original
# (snap "blank" / "tickbox"). Re-typeset printed content — which floods
# front-matter/content pages when the answered PDF re-exports the page with
# an offset or reworded text — snaps to NOTHING (snap "none", flagged
# needs_review) and is long prose. snap_page marks a "none" fill with
# needs_review=True, so we can tell them apart here.
#
# A needs_review (unsnapped) fill is SUSPECT when it is multi-word prose
# (>= PROSE_WORDS words: re-typeset sentences like "All rights reserved...")
# or its text exists verbatim in the original (a re-typeset echo). But a
# suspect is not proof: real answers can be long ("in the morning", a quoted
# reading answer) or short tokens that also appear printed on the page
# (option letters written into a column). The DECISIVE test is raster ink at
# the answer's own position (support_fraction). When that evidence is
# UNAVAILABLE — no rasterizer / render cache on this host — we KEEP the
# answer: a surviving phantom is fixable in the editor, a silently deleted
# real answer is not. Blank/tickbox-snapped fills and checkmarks are never
# dropped.
PROSE_WORDS = 3

_WS = re.compile(r"\s+")


def _norm(t):
    return _WS.sub("", t).lower()


def _clean_fills(original_page, pdf_page, scale_x, scale_y, secs):
    orig = {_norm(s["text"]) for s in get_spans(original_page) if s["text"].strip()}

    def raster_support(a):
        if not HAVE_RASTER:
            return None
        c = a["coords"]
        bbox_pt = [c["x"] / scale_x, c["y"] / scale_y,
                   (c["x"] + c["w"]) / scale_x,
                   (c["y"] + c["h"]) / scale_y]
        return support_fraction(original_page, pdf_page, bbox_pt)

    def is_phantom(a):
        if not a.get("needs_review"):
            return False            # snapped to a blank/tick box -> real
        t = a.get("text", "")
        if t == "✓":
            return False            # tick answer
        suspect = (len(t.split()) >= PROSE_WORDS          # re-typeset prose
                   or (_norm(t) and _norm(t) in orig))    # short echo
        if not suspect:
            return False
        # Ink at the answer's own position = real answer, not an echo.
        # No raster evidence (no cache/rasterizer) -> keep it, don't guess.
        sup = raster_support(a)
        if sup is None:
            return False
        return sup < ECHO_RESCUE_SUPPORT

    dropped = 0
    for sec in secs:
        ans = sec.get("answer", [])
        keep = [a for a in ans if not is_phantom(a)]
        dropped += len(ans) - len(keep)
        sec["answer"] = keep
    if dropped:
        print(f"  Phantom filter: dropped {dropped} unsnapped phantom fill(s)", flush=True)
    return [s for s in secs if s.get("answer")]


def detect_fills(original_page, pdf_page, scale_x, scale_y):
    """The full fill pipeline used by the main Analyze (ai_analyzer):
    registered diff -> snap -> echo/prose cleanup with raster rescue ->
    raster mark recovery."""
    # Layer 1: offset-echo removal (before snapping) kills re-typeset
    # phantoms regardless of snap — including box-snapped slot numbers.
    secs, stats = snap_page(original_page, pdf_page,
                            scale_x, scale_y, use_cv=False,
                            drop_offset_echoes=True)
    if stats:
        print(f"  Fill snap: {stats}", flush=True)
    # Layer 2: structure filter catches reworded prose the offset misses
    # (answered text edited, so no exact twin exists in the original).
    secs = _clean_fills(original_page, pdf_page, scale_x, scale_y, secs)
    # Raster-only recovery: graphic checkmarks stamped on artwork live in
    # no text/vector layer — the aligned pixel diff is the only signal.
    # All candidates are needs_review; the editor confirms them.
    if HAVE_RASTER:
        taken = []
        for sec in secs:
            for a in sec.get("answer", []):
                c = a["coords"]
                taken.append([c["x"] / scale_x, c["y"] / scale_y,
                              (c["x"] + c["w"]) / scale_x,
                              (c["y"] + c["h"]) / scale_y])
        ticks = tick_candidates(original_page, pdf_page, taken)
        if ticks:
            pad = 2.0
            answers = [{
                "coords": px_coords([b["bbox_pt"][0] - pad, b["bbox_pt"][1] - pad,
                                     b["bbox_pt"][2] + pad, b["bbox_pt"][3] + pad],
                                    scale_x, scale_y),
                "text": "✓",
                "is_text_bold": True,
                "opacity": 1,
                "needs_review": True,
            } for b in ticks]
            print(f"  Raster recovery: {len(answers)} mark candidate(s)", flush=True)
            if secs:
                secs[0]["answer"].extend(answers)
            else:
                secs = [{"type": "fill",
                         "activity": {"circleCount": 0, "markCount": 0},
                         "answer": answers, "audio_extra": {}}]
    return secs


def detect(ctx, state):
    if ctx.original_page is None or ctx.heavy:
        return []
    if ctx.page_num in set(ctx.overrides.get("skip_fill_pages", [])):
        return []
    return detect_fills(ctx.original_page, ctx.pdf_page,
                        ctx.scale_x, ctx.scale_y)


if __name__ == "__main__":
    import analyze_core
    analyze_core.run_stages(sys.argv[1], sys.argv[2], [sys.modules[__name__]])
