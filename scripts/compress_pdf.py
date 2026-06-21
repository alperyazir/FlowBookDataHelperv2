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
import os
import shutil
import sys
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


def compress(src, dst, dpi=150, quality=80):
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


def main():
    a = sys.argv[1:]
    if len(a) >= 1 and a[0] == "--from-raw":
        a = a[1:]
        if len(a) < 2:
            print("ERROR: usage: --from-raw <raw_dir> <output.pdf> [dpi] [quality]", flush=True)
            return 1
        src = find_original_pdf(a[0])
        if not src:
            print(f"ERROR: no original PDF found in: {a[0]}", flush=True)
            return 1
        dst = a[1]
        rest = a[2:]
    else:
        if len(a) < 2:
            print("ERROR: usage: <input.pdf> <output.pdf> [dpi] [quality]", flush=True)
            return 1
        src, dst = a[0], a[1]
        rest = a[2:]
    dpi = int(rest[0]) if len(rest) >= 1 else 150
    quality = int(rest[1]) if len(rest) >= 2 else 80

    if not os.path.isfile(src):
        print(f"ERROR: input PDF not found: {src}", flush=True)
        return 1
    os.makedirs(os.path.dirname(os.path.abspath(dst)), exist_ok=True)

    src_size = os.path.getsize(src)
    tmp = dst + ".tmp"
    try:
        replaced = compress(src, tmp, dpi, quality)
    except Exception as e:
        print(f"ERROR: compression failed: {e}", flush=True)
        # Drop any partial temp file so it can't ship in the package.
        if os.path.exists(tmp):
            try:
                os.remove(tmp)
            except OSError:
                pass
        # Never lose the PDF — fall back to copying the source through.
        try:
            shutil.copy(src, dst)
            print(f"OK copied (uncompressed) {src_size} bytes", flush=True)
            return 0
        except Exception as e2:
            print(f"ERROR: fallback copy failed: {e2}", flush=True)
            return 1

    new_size = os.path.getsize(tmp)
    if new_size < src_size:
        os.replace(tmp, dst)
        pct = 100.0 * (src_size - new_size) / src_size
        print(f"OK compressed {src_size} -> {new_size} bytes "
              f"(-{pct:.0f}%, {replaced} images, {dpi}dpi q{quality})", flush=True)
    else:
        os.remove(tmp)
        shutil.copy(src, dst)
        print(f"OK kept original {src_size} bytes (compression did not help)", flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
