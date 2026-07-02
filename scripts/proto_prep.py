"""Book prep: one-time render cache for the analysis pipeline.

Renders both raw PDFs (original + answered) to per-page PNGs at a fixed
DPI and stores them under <book>/cache/render/{orig,ans}/page_NNN.png.
Every later analysis step (raster diff, CV snap, review renders) reads
these files instead of rasterizing with MuPDF, because MuPDF chokes on
two page pathologies real books ship with:

  - overprint/pattern spreads (Glory: 240-270 s/page, resolution-
    independent — poppler renders the same page in 0.5 s)
  - vector floods (Rise Up p13: 380k drawings)

Engine order: pdftoppm (poppler) -> ghostscript -> PyMuPDF (last
resort, warns). All pages of a book pair are rendered by the SAME
engine so a pixel diff never compares two rasterizers' antialiasing.
Renders are deterministic (verified byte-identical across runs).

144 DPI == fitz zoom 2.0 (the analysis scale); px->pt mapping must
always be computed from actual PNG size / page rect, never assumed.

A manifest ties the cache to the source PDFs (size+mtime+dpi+engine);
prep_book() is a no-op when the cache is fresh.

Usage:
  python3 proto_prep.py <config.json | book_dir>   [--force] [--jobs N]
  python3 proto_prep.py --pdf <file.pdf> <out_dir> [--force] [--jobs N]
"""

import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import time
from concurrent.futures import ThreadPoolExecutor

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

DPI = 144
CACHE_VERSION = 1

_PAGE_RE = re.compile(r"-(\d+)\.png$")


# ---------------------------------------------------------------------------
# Engine discovery
# ---------------------------------------------------------------------------

def _which(names, env_var):
    cand = os.environ.get(env_var)
    if cand and os.path.exists(cand):
        return cand
    for n in names:
        p = shutil.which(n)
        if p:
            return p
    # Common install locations not always on the analysis process's PATH.
    # The deployed app runs Python with an un-augmented PATH (only the
    # dep-check process calls deps._augment_path), so tools shipped next to
    # the interpreter — the standard Windows layout, e.g. poppler unzipped
    # beside python.exe — must be searched explicitly here or the render
    # cache is silently skipped and the raster channel stays off.
    exe_dir = os.path.dirname(sys.executable)
    extra = [
        "/opt/homebrew/bin", "/usr/local/bin", "/usr/bin",
        exe_dir,
        os.path.join(exe_dir, "Library", "bin"),   # conda/Windows poppler
        os.path.join(exe_dir, "poppler", "bin"),
        os.path.join(os.path.dirname(os.path.abspath(__file__)), "bin"),
    ]
    for d in extra:
        for n in names:
            p = os.path.join(d, n)
            if os.path.exists(p):
                return p
    return None


def find_pdftoppm():
    return _which(["pdftoppm", "pdftoppm.exe"], "FLOWBOOK_PDFTOPPM")


def find_gs():
    return _which(["gs", "gswin64c.exe", "gswin64c"], "FLOWBOOK_GS")


def _default_jobs():
    return max(1, min(4, (os.cpu_count() or 2) // 2))


# ---------------------------------------------------------------------------
# Rendering (one PDF -> out_dir/page_NNN.png)
# ---------------------------------------------------------------------------

def _page_count(pdf_path):
    import fitz
    with fitz.open(pdf_path) as doc:
        return len(doc)


def _chunks(n_pages, jobs):
    size = max(1, (n_pages + jobs - 1) // jobs)
    return [(a, min(a + size - 1, n_pages))
            for a in range(1, n_pages + 1, size)]


def _run_pdftoppm(tool, pdf_path, out_dir, first, last, dpi):
    """Render a page range into out_dir; normalize names to page_NNN.png."""
    with tempfile.TemporaryDirectory(dir=out_dir) as tmp:
        subprocess.run(
            [tool, "-png", "-r", str(dpi), "-f", str(first), "-l", str(last),
             pdf_path, os.path.join(tmp, "p")],
            check=True, capture_output=True)
        for f in os.listdir(tmp):
            m = _PAGE_RE.search(f)
            if not m:
                continue
            page = int(m.group(1))
            os.replace(os.path.join(tmp, f),
                       os.path.join(out_dir, f"page_{page:03d}.png"))


def _run_gs(tool, pdf_path, out_dir, first, last, dpi):
    """Ghostscript numbers output from 1 per run; offset back to pages."""
    with tempfile.TemporaryDirectory(dir=out_dir) as tmp:
        subprocess.run(
            [tool, "-dBATCH", "-dNOPAUSE", "-dQUIET",
             "-sDEVICE=png16m", f"-r{dpi}",
             f"-dFirstPage={first}", f"-dLastPage={last}",
             "-o", os.path.join(tmp, "p-%d.png"), pdf_path],
            check=True, capture_output=True)
        for f in os.listdir(tmp):
            m = _PAGE_RE.search(f)
            if not m:
                continue
            page = first + int(m.group(1)) - 1
            os.replace(os.path.join(tmp, f),
                       os.path.join(out_dir, f"page_{page:03d}.png"))


def _run_fitz(pdf_path, out_dir, first, last, dpi):
    import fitz
    zoom = dpi / 72.0
    with fitz.open(pdf_path) as doc:
        for pno in range(first, last + 1):
            pix = doc[pno - 1].get_pixmap(matrix=fitz.Matrix(zoom, zoom))
            pix.save(os.path.join(out_dir, f"page_{pno:03d}.png"))


def render_pdf(pdf_path, out_dir, dpi=DPI, jobs=None):
    """Render every page of pdf_path to out_dir/page_NNN.png.

    Returns (n_pages, engine_desc). Chunks the page range over `jobs`
    parallel engine processes (poppler/gs are single-threaded)."""
    os.makedirs(out_dir, exist_ok=True)
    n = _page_count(pdf_path)
    jobs = jobs or _default_jobs()

    tool = find_pdftoppm()
    if tool:
        runner, engine = (lambda a, b: _run_pdftoppm(tool, pdf_path, out_dir, a, b, dpi),
                          f"pdftoppm:{tool}")
    else:
        tool = find_gs()
        if tool:
            runner, engine = (lambda a, b: _run_gs(tool, pdf_path, out_dir, a, b, dpi),
                              f"gs:{tool}")
        else:
            print("WARNING: neither pdftoppm nor ghostscript found — "
                  "falling back to MuPDF (can be pathologically slow on "
                  "overprint/pattern pages)", flush=True)
            runner, engine = (lambda a, b: _run_fitz(pdf_path, out_dir, a, b, dpi),
                              "fitz")

    if jobs == 1 or engine == "fitz":
        runner(1, n)
    else:
        with ThreadPoolExecutor(max_workers=jobs) as ex:
            futs = [ex.submit(runner, a, b) for a, b in _chunks(n, jobs)]
            for f in futs:
                f.result()          # propagate the first failure

    missing = [p for p in range(1, n + 1)
               if not os.path.exists(os.path.join(out_dir, f"page_{p:03d}.png"))]
    if missing:
        raise RuntimeError(f"render incomplete, missing pages: {missing[:10]}")
    return n, engine


# ---------------------------------------------------------------------------
# Book-level prep + cache API
# ---------------------------------------------------------------------------

def _src_sig(path):
    st = os.stat(path)
    return {"path": os.path.abspath(path), "size": st.st_size,
            "mtime": int(st.st_mtime)}


def cache_dir_for(config_dir):
    return os.path.join(config_dir, "cache")


def _manifest_path(cache_dir):
    return os.path.join(cache_dir, "manifest.json")


def _load_manifest(cache_dir):
    try:
        with open(_manifest_path(cache_dir), encoding="utf-8") as f:
            return json.load(f)
    except (OSError, ValueError):
        return None


def _side_fresh(manifest, side, pdf_path, dpi):
    """True when this side's cached renders match pdf_path and are complete."""
    if not manifest or manifest.get("version") != CACHE_VERSION \
            or manifest.get("dpi") != dpi:
        return False
    m = manifest.get("sides", {}).get(side)
    if not m or m["src"] != _src_sig(pdf_path):
        return False
    rdir = m["dir"]
    return all(os.path.exists(os.path.join(rdir, f"page_{p:03d}.png"))
               for p in range(1, m["pages"] + 1))


def prep_book(config_path, force=False, jobs=None, dpi=DPI):
    """Ensure the render cache for a book is present and fresh.

    config_path: path to config.json OR the book directory itself.
    Returns the cache dir. No-op (fast) when the manifest matches the
    raw PDFs and all pages are on disk."""
    if os.path.isdir(config_path):
        config_path = os.path.join(config_path, "config.json")
    config_dir = os.path.dirname(os.path.abspath(config_path))

    from ai_analyzer import find_answered_pdf, find_original_pdf
    sides = {}
    orig = find_original_pdf(config_path)
    if orig:
        sides["orig"] = orig
    sides["ans"] = find_answered_pdf(config_path)

    cache = cache_dir_for(config_dir)
    old = _load_manifest(cache)
    if not force and old and all(
            _side_fresh(old, side, pdf_path, dpi)
            for side, pdf_path in sides.items()):
        print(f"Render cache fresh: {cache}", flush=True)
        return cache

    # Re-render only the side(s) whose PDF changed; carry a still-fresh
    # side's manifest entry forward (re-exporting only the answered PDF is
    # the common iteration — no point re-rendering the untouched original).
    manifest = {"version": CACHE_VERSION, "dpi": dpi, "sides": {}}
    for side, pdf_path in sides.items():
        out_dir = os.path.join(cache, "render", side)
        if not force and _side_fresh(old, side, pdf_path, dpi):
            manifest["sides"][side] = old["sides"][side]
            print(f"  {side}: cache fresh, kept", flush=True)
            continue
        if os.path.isdir(out_dir):
            shutil.rmtree(out_dir)      # stale renders must not survive
        t0 = time.time()
        n, engine = render_pdf(pdf_path, out_dir, dpi=dpi, jobs=jobs)
        print(f"  {side}: {n} pages via {engine.split(':')[0]} "
              f"in {time.time() - t0:.1f}s", flush=True)
        manifest["sides"][side] = {
            "src": _src_sig(pdf_path), "dir": out_dir, "pages": n,
            "engine": engine,
        }
    os.makedirs(cache, exist_ok=True)
    with open(_manifest_path(cache), "w", encoding="utf-8") as f:
        json.dump(manifest, f, indent=1)
    print(f"Render cache ready: {cache}", flush=True)
    return cache


def ensure_prepped(config_path, jobs=None):
    """Auto-prep hook for the analyzers. Builds/refreshes the render
    cache ONLY when a fast rasterizer (pdftoppm/gs) exists — MuPDF's
    pathological pages (overprint spreads: 240s+/page) make the fitz
    fallback unusable for a blanket pre-render. Without a fast engine
    the analyzers simply run with the raster channel off, exactly as
    before the cache existed. Never raises."""
    if not (find_pdftoppm() or find_gs()):
        print("prep: pdftoppm/ghostscript not found — render cache "
              "skipped (raster fusion off)", flush=True)
        return None
    try:
        return prep_book(config_path, jobs=jobs)
    except Exception as e:
        print(f"prep: render cache failed ({e}) — raster fusion off",
              flush=True)
        return None


def render_path(config_dir, side, page_num, expect_pdf=None):
    """Path of a cached page render, or None. side: 'orig' | 'ans'.

    expect_pdf: when given, the cache is used only if it was rendered from
    THIS PDF (manifest src match). raw/ dirs with several candidate PDFs let
    the analyzer and the editor's re-check pick different 'original' files;
    without this check a page would be phase-correlated / support-tested
    against renders of the wrong PDF and real answers dropped as phantoms."""
    if expect_pdf is not None:
        m = _load_manifest(cache_dir_for(config_dir))
        src = (m or {}).get("sides", {}).get(side, {}).get("src") or {}
        if os.path.normcase(os.path.abspath(expect_pdf)) != \
                os.path.normcase(src.get("path", "")):
            return None
    p = os.path.join(cache_dir_for(config_dir), "render", side,
                     f"page_{page_num:03d}.png")
    return p if os.path.exists(p) else None


def load_render(config_dir, side, page_num):
    """Cached render as an RGB numpy array, or None."""
    p = render_path(config_dir, side, page_num)
    if not p:
        return None
    import numpy as np
    from PIL import Image
    with Image.open(p) as im:
        return np.asarray(im.convert("RGB"))


# ---------------------------------------------------------------------------

def main():
    import argparse
    ap = argparse.ArgumentParser(add_help=False)
    ap.add_argument("target", nargs="?")
    ap.add_argument("out_dir", nargs="?")     # only with --pdf
    ap.add_argument("--pdf", action="store_true")
    ap.add_argument("--force", action="store_true")
    ap.add_argument("--jobs", type=int, default=None)
    a = ap.parse_args()
    if a.pdf:
        if not (a.target and a.out_dir):
            print(__doc__); sys.exit(1)
        t0 = time.time()
        n, engine = render_pdf(a.target, a.out_dir, jobs=a.jobs)
        print(f"{n} pages via {engine} in {time.time() - t0:.1f}s")
        return
    if not a.target:
        print(__doc__)
        sys.exit(1)
    prep_book(a.target, force=a.force, jobs=a.jobs)


if __name__ == "__main__":
    main()
