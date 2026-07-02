"""analyze_core — dev harness for running detection stages standalone.

The production path is ai_analyzer.py (the editor's Analyze). This core
lets a stage module (currently stage_fill) run on its own from the CLI
for quick iteration — with FB_PAGE_RANGE=1-30 to limit pages. It owns:

  - opening the answered/original PDF pair + settings/overrides
  - the per-page loop (image resolve, scale factors, monster-page guard)
  - MERGE semantics: a stage replaces only the section types it OWNS and
    leaves every other stage's sections untouched, so you can run "just
    fills", then later "just audio", and nothing gets clobbered.
  - incremental config save

A stage is any object exposing:
    name          : str
    owned_types   : set[str]   # config section types it (re)generates
    detect(ctx, state) -> list[section dict]

`state` is a dict persisted across pages (cross-page counters, e.g.
next_video_no). `ctx` is the per-page PageCtx below.
"""

import os
import sys

os.environ["PYTHONUNBUFFERED"] = "1"
sys.stdout.reconfigure(line_buffering=True)

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from _bootstrap import ensure_runtime_deps
ensure_runtime_deps()

import json
import fitz

from ai_analyzer import (
    load_settings, parse_hex_color, load_config,
    find_answered_pdf, find_original_pdf, get_all_pages,
    MONSTER_DRAW_CAP,
)
from proto_inventory import page_drawings


# ---------------------------------------------------------------------------

def section_type(sec):
    """Type of a config section, whether it is stored top-level (fill,
    audio, video) or under `activity` (circle, dragdrop, ...)."""
    if "type" in sec:
        return sec["type"]
    return sec.get("activity", {}).get("type", "")


def merge_page_sections(page_ref, new_sections, owned_types):
    """Replace only the OWNED section types on the page; keep the rest.

    Runs before re-adding so a stage re-run is idempotent and never
    duplicates or wipes another stage's work."""
    kept = [s for s in page_ref.get("sections", [])
            if section_type(s) not in owned_types]
    page_ref["sections"] = kept + list(new_sections)


def safe(name, page_num, fn, default):
    """One detector failing must not kill the whole book run."""
    try:
        return fn()
    except Exception as e:
        print(f"  {name} FAILED on page {page_num}: {e}", flush=True)
        return default


class PageCtx:
    """Everything a stage needs to detect one page."""
    def __init__(self, **kw):
        self.__dict__.update(kw)


# ---------------------------------------------------------------------------

def open_book(config_path, settings_path):
    answer_color = load_settings(settings_path)
    answer_rgb = parse_hex_color(answer_color)
    config = load_config(config_path)
    config_dir = os.path.dirname(os.path.abspath(config_path))

    overrides = {}
    overrides_path = os.path.join(config_dir, "ai_overrides.json")
    if os.path.exists(overrides_path):
        with open(overrides_path, encoding="utf-8") as f:
            overrides = json.load(f)
        print(f"AI overrides loaded: {overrides}", flush=True)

    # Render cache for the raster-fusion fill pipeline (no-op when
    # fresh; skipped when no fast rasterizer exists).
    try:
        from proto_prep import ensure_prepped
        ensure_prepped(config_path)
    except Exception as e:
        print(f"prep hook failed: {e}", flush=True)

    answered_doc = fitz.open(find_answered_pdf(config_path))
    original_pdf_path = find_original_pdf(config_path)
    original_doc = fitz.open(original_pdf_path) if original_pdf_path else None
    if original_doc is None:
        print("WARNING: original PDF not found — staged analyzer needs the "
              "diff pair; nothing will be detected.", flush=True)

    return {
        "config": config, "config_dir": config_dir,
        "answer_rgb": answer_rgb, "overrides": overrides,
        "answered_doc": answered_doc, "original_doc": original_doc,
        "all_pages": get_all_pages(config),
    }


def run_stages(config_path, settings_path, stages):
    """Run the given stages over every page, one shared loop.

    stages: ordered list of stage objects. Each contributes only its
    owned section types; others are preserved."""
    names = ", ".join(s.name for s in stages)
    print(f"=== staged dev run: [{names}] ===", flush=True)
    print("PROGRESS:0%", flush=True)

    bk = open_book(config_path, settings_path)
    config = bk["config"]
    config_dir = bk["config_dir"]
    answered_doc = bk["answered_doc"]
    original_doc = bk["original_doc"]
    all_pages = bk["all_pages"]

    # Dev/test shortcut: FB_PAGE_RANGE="1-30" (or "5") limits the run to
    # those page numbers; other pages keep their existing sections.
    page_range = os.environ.get("FB_PAGE_RANGE", "").strip()
    if page_range:
        a, _, b = page_range.partition("-")
        lo, hi = int(a), int(b or a)
        all_pages = [p for p in all_pages if lo <= p["page_number"] <= hi]
        print(f"FB_PAGE_RANGE={page_range}: {len(all_pages)} page(s)", flush=True)
    answered_page_count = len(answered_doc)
    total = len(all_pages)
    if total == 0:
        print("Error: No pages found in config", flush=True)
        sys.exit(1)

    state = {"next_video_no": 1}
    analyzed = skipped = 0

    for i, page_info in enumerate(all_pages):
        page_num = page_info["page_number"]
        image_path = page_info["image_path"]
        page_ref = page_info["page_ref"]

        print(f"PROGRESS:{15 + int((i / total) * 80)}%", flush=True)
        print(f"Analyzing page {page_num} "
              f"({page_info['module_name']}) [{i+1}/{total}]...", flush=True)

        # Resolve the rendered PNG (needed for scale factors).
        parts = image_path.replace("\\", "/").split("/")
        try:
            j = parts.index("images")
            original_image_path = os.path.join(config_dir, "/".join(parts[j:]))
        except ValueError:
            original_image_path = os.path.join(config_dir, image_path.lstrip("./"))
        if not os.path.exists(original_image_path):
            print(f"  Warning: image not found: {original_image_path} (page kept)", flush=True)
            skipped += 1
            continue

        pdf_page_idx = page_num - 1
        if not (0 <= pdf_page_idx < answered_page_count):
            print(f"  Warning: answered PDF has no page {page_num} (page kept)", flush=True)
            skipped += 1
            continue

        pix = fitz.Pixmap(original_image_path)
        png_w, png_h = pix.width, pix.height
        pix = None

        pdf_page = answered_doc.load_page(pdf_page_idx)

        # Load the original page only when it exists (a longer answered/key
        # PDF must not crash load_page mid-book).
        original_page = None
        heavy = False
        if original_doc is not None and pdf_page_idx < len(original_doc):
            original_page = original_doc.load_page(pdf_page_idx)

        # PNGs render from the ORIGINAL PDF and fill coords are original-space,
        # so scale off the original rect; answered rect is the fallback.
        scale_ref = original_page if original_page is not None else pdf_page
        scale_x = png_w / scale_ref.rect.width
        scale_y = png_h / scale_ref.rect.height

        if original_page is not None:
            try:
                n_draw = len(page_drawings(original_page))
            except Exception:
                n_draw = 0
            if n_draw > MONSTER_DRAW_CAP:
                print(f"  page {page_num}: {n_draw} drawings — too complex; "
                      f"stages skipped (defer to AI)", flush=True)
                heavy = True

        # Section image dir + section_path prefix (for crop-producing stages).
        ip = image_path.replace("\\", "/").split("/")
        try:
            k = ip.index("images")
            module_dir_name = ip[k + 1] if k + 1 < len(ip) else "Module_1"
            section_path_prefix = "/".join(ip[:k + 2]) + "/"
            images_dir = os.path.join(config_dir, "images", module_dir_name)
        except ValueError:
            section_path_prefix = "./images/"
            images_dir = os.path.join(config_dir, "images")
        os.makedirs(images_dir, exist_ok=True)

        ctx = PageCtx(
            page_num=page_num, page_ref=page_ref,
            original_page=original_page, pdf_page=pdf_page,
            scale_x=scale_x, scale_y=scale_y, heavy=heavy,
            images_dir=images_dir, section_path_prefix=section_path_prefix,
            book_prefix=section_path_prefix.split("/images/")[0],
            config_dir=config_dir, overrides=bk["overrides"],
            answer_rgb=bk["answer_rgb"],
        )

        produced = 0
        for stage in stages:
            secs = safe(stage.name, page_num, lambda: stage.detect(ctx, state), [])
            merge_page_sections(page_ref, secs, stage.owned_types)
            produced += len(secs)

        if produced:
            analyzed += 1
            print(f"  -> {produced} section(s) this run", flush=True)

        with open(config_path, "w", encoding="utf-8") as f:
            json.dump(config, f, indent=4, ensure_ascii=False)

    if original_doc:
        original_doc.close()
    answered_doc.close()

    print("PROGRESS:95%", flush=True)
    with open(config_path, "w", encoding="utf-8") as f:
        json.dump(config, f, indent=4, ensure_ascii=False)
    print(f"Config saved: {config_path}", flush=True)
    print("PROGRESS:100%", flush=True)
    print(f"staged dev run done. pages with new sections: {analyzed}, skipped: {skipped}", flush=True)
