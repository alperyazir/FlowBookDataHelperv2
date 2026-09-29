"""Keep the images an author brings in from outside at the size the reader needs.

Game pictures (games.json, and the old games inside config.json's modules) and
the pictures put into fill-with-color blocks come from wherever the author found
them — a stock photo straight off a camera is 20+ MB and 6000 px across. The
house rule was a long side of 500 px (the 641 game images in the published
corpus sit at a median of exactly 500), but nothing enforced it. The reader's
quiz box is half the game's height and up to 1.5x as wide — about 750x500 on a
1080p screen — so 500 px pictures were drawn upscaled; the rule is now 750.

Two places now do:

  shrink_file()   when an image is picked in the editor (game cards, a fill
                  block's Browse): brought down to 750 px there and then, so a
                  big one never settles into the book.
  check_book()    Package ▸ Book Details lists the ones still too heavy, and
  optimize_book() its Optimize brings them down IN the book's own folder, like
                  Optimize videos: Test copies books/<book> as it is, so a fix
                  kept anywhere else would never reach it.

Only those images are ever touched. Page images and activity crops are cut from
the PDF at the page's own scale and must stay as they are, so an image that a
page also uses is left alone even when a game points at it too.

The file keeps its name and its format (a PNG stays a PNG, transparency and
all), so no path in config.json or games.json has to change.
"""
import json
import os
import sys
import time
from pathlib import Path

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import flowbook_normalize as fn

LONG_SIDE = 750
# Packaging only complains about what actually weighs something: an old game
# picture at 700 px and 90 KB is not worth a warning. Anything at or under
# LONG_SIDE is fine whatever it weighs — there is nothing left to take off.
HEAVY_BYTES = 1024 * 1024
IMAGE_EXTS = {".png", ".jpg", ".jpeg", ".gif", ".bmp", ".webp"}


def _image_refs(node, out):
    """Every "./books/..." string in node that names an image."""
    for path in fn.iter_book_paths(node):
        if Path(path).suffix.lower() in IMAGE_EXTS:
            out.add(path)


def _fill_images(node, out):
    """Images inside fill-with-color sections, wherever they sit in a page."""
    if isinstance(node, dict):
        if node.get("type") == "fillWithColor":
            _image_refs(node, out)
            return
        for v in node.values():
            _fill_images(v, out)
    elif isinstance(node, list):
        for v in node:
            _fill_images(v, out)


def _resolve(book, ref):
    """"./books/<Folder>/a/b.png" -> <book>/a/b.png, or None."""
    parts = ref[len(fn.BOOKS_PREFIX):].split("/", 1)
    if len(parts) != 2 or not parts[1]:
        return None
    return book / parts[1]


def _scan(book):
    """(images this module may resize, images a page uses), as file paths."""
    wanted, pages = set(), set()

    games = book / "games.json"
    if games.is_file():
        try:
            _image_refs(json.loads(games.read_text(encoding="utf-8")), wanted)
        except (json.JSONDecodeError, OSError, UnicodeDecodeError):
            pass

    conf_file = book / "config.json"
    if conf_file.is_file():
        try:
            conf = json.loads(conf_file.read_text(encoding="utf-8"))
        except (json.JSONDecodeError, OSError, UnicodeDecodeError):
            conf = {}
        _image_refs({k: v for k, v in conf.items() if k != "books"}, pages)
        for b in conf.get("books") or []:
            if not isinstance(b, dict):
                continue
            _image_refs({k: v for k, v in b.items() if k != "modules"}, pages)
            for m in b.get("modules") or []:
                if not isinstance(m, dict):
                    continue
                _image_refs(m.get("games") or [], wanted)
                for p in m.get("pages") or []:
                    fills = set()
                    _fill_images(p, fills)
                    wanted |= fills
                    everything = set()
                    _image_refs(p, everything)
                    pages |= everything - fills

    resolve = lambda refs: {f for f in (_resolve(book, r) for r in refs) if f is not None}
    return resolve(wanted), resolve(pages)


def find_targets(book):
    """{file: rel} for the images this module may resize, minus any that a page
    also uses (a page image, an activity crop)."""
    book = Path(book)
    wanted, pages = _scan(book)
    return {f: f.relative_to(book).as_posix()
            for f in sorted(wanted - pages) if f.is_file()}


def _pillow():
    try:
        from PIL import Image
        return Image
    except ImportError:
        return None


def _inspect(Image, path):
    """(width, height, animated) or raises."""
    with Image.open(path) as im:
        return im.size[0], im.size[1], getattr(im, "n_frames", 1) > 1


def _row(Image, path, rel):
    mb = round(path.stat().st_size / 1048576, 2)
    try:
        w, h, animated = _inspect(Image, path)
    except Exception as exc:  # noqa: BLE001 - any decoder error means "can't read"
        return {"dosya": rel, "mb": mb, "durum": "okunamayan", "hata": str(exc)}
    row = {"dosya": rel, "mb": mb, "w": w, "h": h}
    if animated:
        # Resizing would drop every frame but the first.
        row["durum"] = "animasyon"
    elif max(w, h) > LONG_SIDE and path.stat().st_size > HEAVY_BYTES:
        row["durum"] = "buyuk"
    else:
        row["durum"] = "uygun"
    return row


def check_book(book):
    """The book's game and fill images against the rule; touches nothing.

    {toplam, buyuk, okunamayan, pillow_yok, limit, gorseller: [row]}; each row
    {dosya, mb, durum ("uygun" | "buyuk" | "okunamayan" | "animasyon"), w, h}
    or, when unreadable, hata instead of w/h.
    """
    targets = find_targets(book)
    r = {"toplam": len(targets), "buyuk": 0, "okunamayan": 0, "pillow_yok": False,
         "limit": LONG_SIDE, "gorseller": []}
    if not targets:
        return r
    Image = _pillow()
    if Image is None:
        r["pillow_yok"] = True
        return r
    for path, rel in targets.items():
        row = _row(Image, path, rel)
        if row["durum"] == "buyuk":
            r["buyuk"] += 1
        elif row["durum"] == "okunamayan":
            r["okunamayan"] += 1
        r["gorseller"].append(row)
    return r


def shrink_file(path, long_side=LONG_SIDE):
    """Bring path down to long_side in place, same name, same format.

    {dosya, degisti, eski_mb, mb, eski: [w, h], yeni: [w, h]}; degisti is False
    (and nothing is written) when it is already small enough or animated.
    Raises on an image Pillow can't read or write.
    """
    Image = _pillow()
    if Image is None:
        raise RuntimeError("Pillow isn't installed — install it from Help ▸ Dependencies")
    from PIL import ImageOps

    path = Path(path)
    before = path.stat().st_size
    out = {"dosya": path.name, "degisti": False, "eski_mb": round(before / 1048576, 2)}
    with Image.open(path) as im:
        fmt = im.format
        out["eski"] = list(im.size)
        if getattr(im, "n_frames", 1) > 1 or max(im.size) <= long_side:
            out.update(mb=out["eski_mb"], yeni=list(im.size))
            return out
        info = dict(im.info)
        # A phone photo is stored sideways with an EXIF note to turn it; the
        # reader ignores that note, so bake the turn in.
        im = ImageOps.exif_transpose(im)
        # Palette and odd modes resample badly (or not at all); keep alpha if
        # there is any.
        has_alpha = im.mode in ("RGBA", "LA", "PA") or (im.mode == "P" and "transparency" in info)
        if fmt == "JPEG" or not has_alpha:
            im = im.convert("RGB")
        else:
            im = im.convert("RGBA")
        im.thumbnail((long_side, long_side), Image.LANCZOS)

        save = {}
        if info.get("icc_profile"):
            save["icc_profile"] = info["icc_profile"]
        if fmt == "JPEG":
            save.update(quality=85, optimize=True)
        elif fmt == "PNG":
            save.update(optimize=True)
        elif fmt == "WEBP":
            save.update(quality=85)
        # Written beside it and swapped in, so a failure halfway never leaves
        # the book with half a picture.
        tmp = path.with_name(path.name + ".shrink")
        try:
            im.save(tmp, format=fmt, **save)
        except Exception:
            tmp.unlink(missing_ok=True)
            raise
    # Windows refuses to replace a file another program has open; the editor
    # may still be reading it for the preview, so give it a moment.
    for attempt in range(10):
        try:
            os.replace(tmp, path)
            break
        except PermissionError:
            if attempt == 9:
                tmp.unlink(missing_ok=True)
                raise
            time.sleep(0.3)
    with Image.open(path) as im:
        out["yeni"] = list(im.size)
    out.update(degisti=True, mb=round(path.stat().st_size / 1048576, 2))
    return out


def shrink_picked(book, rel):
    """shrink_file for an image just picked in the editor, unless a page uses it
    too. rel is book-relative ("assets/a.png") or a "./books/<Folder>/..." path."""
    book = Path(book)
    if rel.startswith(fn.BOOKS_PREFIX):
        path = _resolve(book, rel)
    else:
        path = book / rel
    if path is None or not path.is_file():
        return {"hata": f"Image not found: {rel}"}
    if path.suffix.lower() not in IMAGE_EXTS:
        return {"dosya": rel, "degisti": False}
    # A page image picked for a game stays as it is: shrinking it would blur
    # the page. Asked of the pages only — the pick itself isn't saved into
    # games.json/config.json yet.
    if path.resolve() in {p.resolve() for p in _scan(book)[1]}:
        return {"dosya": path.relative_to(book).as_posix(), "degisti": False, "sayfada": True}
    r = shrink_file(path)
    r["dosya"] = path.relative_to(book).as_posix()
    return r


def optimize_book(book):
    """Shrinks every image check_book calls "buyuk", in place.

    {kucultulen: [{dosya, eski_mb, mb, eski, yeni}], basarisiz: [{dosya, hata}]}
    or {hata} when nothing could run.
    """
    book = Path(book)
    if _pillow() is None:
        return {"hata": "Pillow isn't installed — install it from Help ▸ Dependencies"}
    Image = _pillow()
    done, failed = [], []
    for path, rel in find_targets(book).items():
        if _row(Image, path, rel)["durum"] != "buyuk":
            continue
        try:
            r = shrink_file(path)
        except Exception as exc:  # noqa: BLE001 - reported per file
            failed.append({"dosya": rel, "hata": str(exc)})
            continue
        r["dosya"] = rel
        done.append(r)
    return {"kucultulen": done, "basarisiz": failed}
