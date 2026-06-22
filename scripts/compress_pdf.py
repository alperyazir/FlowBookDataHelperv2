"""Shrink a book PDF by downsampling + recompressing its embedded raster
images, WITHOUT rasterizing the pages (vector text stays crisp). Used at
package time to keep raw/original.pdf small.

Two modes:
  compress_pdf.py --from-raw <raw_dir> <output.pdf> [dpi] [quality]
      Find the original (non-answered) PDF in raw_dir, compress it.
  compress_pdf.py <input.pdf> <output.pdf> [dpi] [quality]
      Compress a specific PDF.

dpi      target rendering resolution for images (default 150)
quality  JPEG quality 1-95 (default 80)

If the compressed file is not smaller than the source, the source is copied
through unchanged (compression never bloats the package). Prints "OK ..." on
success or "ERROR: ..." on failure.
"""

import io
import json
import os
import shutil
import subprocess
import sys
import time
from concurrent.futures import ThreadPoolExecutor

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from _bootstrap import ensure_runtime_deps
ensure_runtime_deps()

import fitz
from PIL import Image

ANSWERED_KEYS = ("cevap", "answer", "key")
COVER_KEYS = ("kapak", "cover", "kapag")

# Images smaller than this (raw embedded bytes) are icons/logos/rules: lots
# of them on a page, but each saves almost nothing — skip to save time.
MIN_IMAGE_BYTES = 30 * 1024
# Pre-extract guard: an image whose longest side is under this is a small
# icon/glyph. We can tell from the image tuple (no decode), so it lets us
# skip the costly extract_image for the bulk of a page's little images.
MIN_IMAGE_PIXELS = 256


def find_original_pdf(raw_dir):
    """The original (unanswered) book PDF in raw/. Prefers an
    'original'/'soru' name, skips answer keys and obvious covers."""
    if not os.path.isdir(raw_dir):
        return None
    pdfs = [f for f in os.listdir(raw_dir) if f.lower().endswith(".pdf")]
    rest = [f for f in pdfs if not any(k in f.lower() for k in ANSWERED_KEYS)]
    if not rest:
        return None
    named = [f for f in rest if any(k in f.lower() for k in ("original", "soru"))]
    if named:
        return os.path.join(raw_dir, named[0])
    no_cover = [f for f in rest if not any(k in f.lower() for k in COVER_KEYS)]
    pick = (no_cover or rest)
    return os.path.join(raw_dir, pick[0])


def _recompress_image(raw_bytes, max_px, quality):
    """Return smaller JPEG bytes for an image, or None to keep the original
    (couldn't decode, has transparency, or recompression didn't help)."""
    try:
        im = Image.open(io.BytesIO(raw_bytes))
        im.load()
    except Exception:
        return None
    # Transparency would be lost by JPEG — leave those (usually small) alone.
    if im.mode in ("RGBA", "LA", "P") or "transparency" in im.info:
        return None
    if im.mode != "RGB":
        im = im.convert("RGB")
    w, h = im.size
    longer = max(w, h)
    if longer > max_px:
        scale = max_px / float(longer)
        im = im.resize((max(1, int(w * scale)), max(1, int(h * scale))),
                       Image.LANCZOS)
    buf = io.BytesIO()
    im.save(buf, format="JPEG", quality=quality, optimize=True)
    out = buf.getvalue()
    return out if len(out) < len(raw_bytes) else None


def _compress_pymupdf(src, dst, dpi=150, quality=80):
    doc = fitz.open(src)

    # Pass 1 (sequential — the fitz doc is not thread-safe): gather the images
    # worth recompressing and their raw bytes.
    seen = set()
    jobs = []        # (page_index, xref)
    payloads = []    # (raw_bytes, max_px, quality) — fed to the worker pool
    for pno in range(doc.page_count):
        page = doc[pno]
        for img in page.get_images(full=True):
            # img tuple: (xref, smask, width, height, bpc, colorspace,
            #             alt_cs, name, filter, referencer)
            xref, smask = img[0], img[1]
            width, height = img[2], img[3]
            img_filter = str(img[8]) if len(img) > 8 else ""
            if xref in seen:
                continue
            seen.add(xref)
            if smask:                       # soft-masked: skip (keeps alpha)
                continue
            # Cheap pre-extract skip (from the tuple, no decode): a small icon
            # saves almost nothing but extracting it is the bulk of pass-1 on
            # icon-heavy pages.
            if max(width, height) < MIN_IMAGE_PIXELS:
                continue
            rects = page.get_image_rects(xref)
            if not rects:
                continue
            # Target pixel budget = displayed size (pt -> inch) * dpi.
            disp_pt = max(max(r.width, r.height) for r in rects)
            max_px = max(1, int(disp_pt / 72.0 * dpi))
            # Already JPEG and no bigger than target — re-encoding wouldn't
            # help; skip without the costly extract_image.
            if "DCTDecode" in img_filter and max(width, height) <= max_px:
                continue
            try:
                base = doc.extract_image(xref)
            except Exception:
                continue
            raw = base["image"]
            # Final byte-size guard for whatever survived the cheap skips.
            if len(raw) < MIN_IMAGE_BYTES:
                continue
            jobs.append((pno, xref))
            payloads.append((raw, max_px, quality))

    # Pass 2 (parallel): the decode/resize/encode is the CPU cost and PIL
    # releases the GIL in its C codecs, so a thread pool spreads it across
    # cores without the pickling/spawn overhead of processes.
    if payloads:
        workers = min(os.cpu_count() or 4, 8)
        if workers > 1 and len(payloads) > 1:
            with ThreadPoolExecutor(max_workers=workers) as ex:
                results = list(ex.map(lambda p: _recompress_image(*p), payloads))
        else:
            results = [_recompress_image(*p) for p in payloads]
    else:
        results = []

    # Pass 3 (sequential — touches the doc): apply the recompressed images.
    replaced = 0
    for (pno, xref), new_bytes in zip(jobs, results):
        if new_bytes is None:
            continue
        try:
            doc[pno].replace_image(xref, stream=new_bytes)
            replaced += 1
        except Exception:
            continue

    # garbage=4 drops the now-orphaned original image streams; deflate the rest.
    # (No clean=True — it sanitizes every content stream and is slow; the size
    # win comes from the image re-encode + garbage collection, not from clean.)
    doc.save(dst, garbage=4, deflate=True)
    doc.close()
    return replaced


def _ghostscript_exe():
    """Path to a Ghostscript console binary, or None. Much faster than the
    PyMuPDF path on weak machines, so prefer it when present."""
    for name in ("gswin64c", "gswin32c", "gs"):
        p = shutil.which(name)
        if p:
            return p
    return None


def _compress_ghostscript(src, dst, dpi, quality):
    """Downsample + re-encode images via Ghostscript's pdfwrite. Returns
    True on success (dst written). Vector text is preserved."""
    gs = _ghostscript_exe()
    if not gs:
        return False
    args = [
        gs, "-sDEVICE=pdfwrite", "-dCompatibilityLevel=1.5",
        "-dNOPAUSE", "-dBATCH", "-dQUIET", "-dSAFER",
        "-dDetectDuplicateImages=true",
        "-dDownsampleColorImages=true", "-dColorImageDownsampleType=/Bicubic",
        f"-dColorImageResolution={dpi}",
        "-dDownsampleGrayImages=true", "-dGrayImageDownsampleType=/Bicubic",
        f"-dGrayImageResolution={dpi}",
        "-dDownsampleMonoImages=true", "-dMonoImageDownsampleType=/Subsample",
        f"-dMonoImageResolution={dpi * 2}",
        "-dAutoFilterColorImages=false", "-dColorImageFilter=/DCTEncode",
        "-dAutoFilterGrayImages=false", "-dGrayImageFilter=/DCTEncode",
        f"-dJPEGQ={quality}",
        f"-sOutputFile={dst}", src,
    ]
    try:
        r = subprocess.run(args, stdout=subprocess.DEVNULL,
                           stderr=subprocess.DEVNULL)
    except Exception:
        return False
    return r.returncode == 0 and os.path.isfile(dst) and os.path.getsize(dst) > 0


def do_compress(src, dst, dpi=150, quality=80):
    """Compress src -> dst, preferring Ghostscript then PyMuPDF. Atomic
    (writes a temp then renames) and never bloats — if the result isn't
    smaller, the source is copied through. Never loses the PDF. Returns a
    short status string."""
    os.makedirs(os.path.dirname(os.path.abspath(dst)), exist_ok=True)
    src_size = os.path.getsize(src)
    tmp = dst + ".tmp"

    engine = None
    try:
        if _compress_ghostscript(src, tmp, dpi, quality):
            engine = "gs"
        else:
            _compress_pymupdf(src, tmp, dpi, quality)
            engine = "mupdf"
    except Exception as e:
        if os.path.exists(tmp):
            try: os.remove(tmp)
            except OSError: pass
        shutil.copy(src, dst)                       # never lose the PDF
        return f"OK copied (uncompressed, {engine or 'error'}: {e}) {src_size} bytes"

    new_size = os.path.getsize(tmp)
    if new_size < src_size:
        os.replace(tmp, dst)
        pct = 100.0 * (src_size - new_size) / src_size
        return (f"OK compressed {src_size} -> {new_size} bytes "
                f"(-{pct:.0f}%, {engine}, {dpi}dpi q{quality})")
    os.remove(tmp)
    shutil.copy(src, dst)
    return f"OK kept original {src_size} bytes (compression did not help)"


# --- cache mode --------------------------------------------------------------
# Persistent per-book cache so the slow compression runs once, ahead of
# packaging (triggered in the background when a book is opened). Lives in
# books/<book>/.pkgcache/ (a sibling of raw/, NOT inside it — so the editor's
# raw/ PDF detection never picks up the downsampled copy).

LOCK_STALE_SECS = 30 * 60        # a lock older than this is from a dead run
WAIT_POLL_SECS = 2
WAIT_MAX_SECS = 45 * 60


def _cache_paths(raw_dir):
    book_dir = os.path.dirname(os.path.abspath(raw_dir.rstrip("/\\")))
    cdir = os.path.join(book_dir, ".pkgcache")
    return cdir, os.path.join(cdir, "original.pdf"), \
        os.path.join(cdir, "stamp.json"), os.path.join(cdir, "lock")


def _stamp_for(src, dpi, quality):
    st = os.stat(src)
    return {"src": os.path.basename(src), "size": st.st_size,
            "mtime": int(st.st_mtime), "dpi": dpi, "quality": quality}


def _cache_fresh(cache_pdf, stamp_path, want):
    if not (os.path.isfile(cache_pdf) and os.path.isfile(stamp_path)):
        return False
    try:
        have = json.load(open(stamp_path))
    except Exception:
        return False
    return (have.get("src") == want["src"] and have.get("size") == want["size"]
            and abs(have.get("mtime", 0) - want["mtime"]) <= 2
            and have.get("dpi") == want["dpi"]
            and have.get("quality") == want["quality"])


def _lock_fresh(lock_path):
    try:
        return (time.time() - os.path.getmtime(lock_path)) < LOCK_STALE_SECS
    except OSError:
        return False


def cache_mode(raw_dir, dpi, quality):
    src = find_original_pdf(raw_dir)
    if not src:
        print(f"ERROR: no original PDF found in: {raw_dir}", flush=True)
        return 1
    cdir, cache_pdf, stamp_path, lock_path = _cache_paths(raw_dir)
    os.makedirs(cdir, exist_ok=True)
    want = _stamp_for(src, dpi, quality)

    if _cache_fresh(cache_pdf, stamp_path, want):
        print("OK fresh (cache up to date)", flush=True)
        return 0

    # Another run may be building it — wait for it rather than racing.
    waited = 0
    while os.path.isfile(lock_path) and _lock_fresh(lock_path) and waited < WAIT_MAX_SECS:
        time.sleep(WAIT_POLL_SECS)
        waited += WAIT_POLL_SECS
        if _cache_fresh(cache_pdf, stamp_path, want):
            print("OK fresh (built by another run)", flush=True)
            return 0

    # Take the lock and build.
    try:
        with open(lock_path, "w") as fh:
            fh.write(str(os.getpid()))
    except OSError:
        pass
    try:
        msg = do_compress(src, cache_pdf, dpi, quality)
        with open(stamp_path, "w") as fh:
            json.dump(want, fh)
        print(msg, flush=True)
        return 0
    finally:
        try: os.remove(lock_path)
        except OSError: pass


def main():
    a = sys.argv[1:]

    if a and a[0] == "--cache":
        a = a[1:]
        if not a:
            print("ERROR: usage: --cache <raw_dir> [dpi] [quality]", flush=True)
            return 1
        dpi = int(a[1]) if len(a) >= 2 else 150
        quality = int(a[2]) if len(a) >= 3 else 80
        return cache_mode(a[0], dpi, quality)

    if a and a[0] == "--from-raw":
        a = a[1:]
        if len(a) < 2:
            print("ERROR: usage: --from-raw <raw_dir> <output.pdf> [dpi] [quality]", flush=True)
            return 1
        src = find_original_pdf(a[0])
        if not src:
            print(f"ERROR: no original PDF found in: {a[0]}", flush=True)
            return 1
        dst, rest = a[1], a[2:]
    else:
        if len(a) < 2:
            print("ERROR: usage: <input.pdf> <output.pdf> [dpi] [quality]", flush=True)
            return 1
        src, dst, rest = a[0], a[1], a[2:]

    dpi = int(rest[0]) if len(rest) >= 1 else 150
    quality = int(rest[1]) if len(rest) >= 2 else 80
    if not os.path.isfile(src):
        print(f"ERROR: input PDF not found: {src}", flush=True)
        return 1
    print(do_compress(src, dst, dpi, quality), flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
