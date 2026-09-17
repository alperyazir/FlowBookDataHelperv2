#!/usr/bin/env python3
"""Package-time normalization for Project > Package.

flowbook_normalize.py next to this file is a verbatim copy of the workspace
module and is not edited here -- a fix goes into the workspace copy and is
copied over. This file adds only what belongs to the editor:

  check <book_dir>
      check_book() (touches nothing) plus what the Package dialog has to ask
      about before anything is written: is there an answered PDF, do the
      config's pages fit the PDF, the publisher logo path, and which videos
      won't play on Windows.

  video-check <book_dir>
      Only the videos: video_compat.check_book(), for Project ▸ Videos and the
      warning when a book opens. Runs at below-normal priority.

  title --baslik T [--yayinevi P]
      The folder the title becomes and the title warnings, for the dialog's
      live preview -- the same title_to_folder the export uses.

  normalize <book_dir> <export_root> --baslik T (--yayinevi P | --yayinevi-yok)
            [--answered PDF | --answered-original] [--geri-yaz]
      normalize_book() into <export_root>/<Folder>/, then:
        * --yayinevi-yok: publisher_name cleared (the module only ever sets
          one; the logo fields are left alone)
        * answered.pdf missing: the chosen PDF, or a copy of original.pdf
        * raw/: a file byte-identical to original.pdf/answered.pdf is deleted;
          any other extra is kept and reported, never silently dropped
        * the editor's own files (fbinf, settings.json, review/, *.ini, ...)
          removed from the export, whatever their letter case
        * stops before copying anything if a video won't play on Windows
        * --geri-yaz: book_title/publisher_name written back to the project's
          config.json, those two fields and nothing else

  videos <book_dir> [--stdin-stop]
      Converts the book's videos the Windows reader can't play, in the book's
      own folder, replacing the originals (video_compat.optimize_book) — the
      Optimize of Book Details and Project ▸ Videos.
      Prints "PROGRESS: {i, n, dosya, pct}" lines as it goes; --stdin-stop ends
      the run when stdin closes, which is how the editor stops it (killing
      Python would leave ffmpeg running on Windows). Exit 0 all converted,
      1 some failed, 2 error, 3 stopped.

  zip <export_dir> [--klasoru-sil]
      <export_dir>.zip with the book under one top-level folder, leaving out
      OS and editor junk and every raw/ file but the two canonical PDFs;
      --klasoru-sil removes the folder once the zip has been verified.

Prints one "RESULT_JSON: {...}" line. Exit 0 clean, 1 broken references
remain, 2 error ("hata" holds a message for the user).
"""
import argparse
import importlib.util
import json
import os
import re
import shutil
import sys
import threading
import traceback
import zipfile
from pathlib import Path

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import flowbook_normalize as fn
import video_compat

# How many more pages the PDF may have than the config reaches before it is
# worth a word (a trailing blank or back cover is normal). The other way round
# is always reported: config pages past the end of the PDF are images with no
# page behind them (My English Path 1 Workbook: PDF 112, config up to 147).
PAGE_SLACK = 2


def emit(result, code):
    print("RESULT_JSON: " + json.dumps(result, ensure_ascii=False), flush=True)
    return code


def error_text(exc):
    """The message the editor shows for an unexpected failure.

    A path over 260 characters is refused by Windows unless LongPathsEnabled
    is set, and the bare OSError says only "cannot find the path specified".
    """
    text = f"{type(exc).__name__}: {exc}"
    path = str(getattr(exc, "filename", "") or "")
    if isinstance(exc, OSError) and len(path) > 240:
        text += (f"  (that path is {len(path)} characters; Windows refuses paths over 260 "
                 f"unless LongPathsEnabled is on)")
    return text


def raw_pdfs(raw):
    """The PDFs place_pdfs() picks from, split the way it splits them.

    Asked before normalizing, so the dialog knows whether an answered PDF will
    exist without copying the book first.
    """
    if not raw.is_dir():
        return [], []
    hepsi = [f for f in sorted(raw.iterdir(), key=fn.natkey)
             if f.is_file() and f.suffix.lower() == ".pdf"
             and not f.name.startswith("._")
             and not fn.TEMP_RE.match(f.name)
             and not fn.COVER_RE.search(f.stem)]
    cevapli = [f for f in hepsi if fn.ANS_RE.search(f.name) and not fn.NEG_RE.search(f.name)]
    return [f for f in hepsi if f not in cevapli], cevapli


def pypdf_warning(parts, have_pypdf):
    """Multi-part PDFs need pypdf; without it original.pdf stays one part.

    The module skips the merge and says so, but by then the book is already
    exported. Everything else pypdf touches is optional -- this is the one
    case that silently costs pages, so the dialog asks first.
    """
    if have_pypdf or parts < 2:
        return ""
    return (f"pypdf is not installed and raw/ has {parts} PDFs to merge into one — "
            f"install it from Help > Dependencies, or the book ships one part only")


def pdf_pages(pdf):
    try:
        import fitz
        with fitz.open(str(pdf)) as doc:
            return doc.page_count
    except ImportError:
        pass
    except Exception:
        return None
    try:
        from pypdf import PdfReader
        return len(PdfReader(str(pdf)).pages)
    except Exception:
        return None


def config_last_page(conf):
    nums = [p.get("page_number")
            for b in conf.get("books") or [] if isinstance(b, dict)
            for m in b.get("modules") or [] if isinstance(m, dict)
            for p in m.get("pages") or [] if isinstance(p, dict)]
    nums = [n for n in nums if isinstance(n, int)]
    return max(nums) if nums else None


def page_warning(pages, last):
    if pages is None or last is None:
        return ""
    if last > pages:
        return f"config.json goes up to page {last} but original.pdf has only {pages} pages"
    if pages - last > PAGE_SLACK:
        return f"original.pdf has {pages} pages but config.json stops at page {last}"
    return ""


def logo_warning(conf):
    # An open decision: editor output carries publisher_logo+.png, published
    # books publisher_logo.png. Shown, never changed, until that is decided.
    path = conf.get("publisher_logo_path") or ""
    if "+" in os.path.basename(path):
        return (f"publisher_logo_path is {path} (published books use "
                f"publisher_logo.png) — left unchanged")
    return ""


def clean_raw(raw):
    """Delete byte-identical copies of the canonical PDFs; report the rest.

    The module leaves them on disk (a duplicate it skipped, the non-canonical
    source it copied from). A canonical file is never touched -- original.pdf
    and answered.pdf may legitimately be the same bytes (no answer key).
    """
    kanon = [raw / n for n in sorted(fn.KANON_PDF) if (raw / n).is_file()]
    ozet = {}
    silinen, ek = [], []
    for f in sorted(raw.iterdir()):
        if not f.is_file() or f.name in fn.KANON_PDF or f.name.startswith("._"):
            continue
        ayni = False
        for k in kanon:
            if k.stat().st_size != f.stat().st_size:
                continue
            if k not in ozet:
                ozet[k] = fn._digest(k)
            if fn._digest(f) == ozet[k]:
                ayni = True
                break
        if ayni and fn.safe_remove(f):
            silinen.append(f.name)
        else:
            ek.append(f.name)
    return {"silinen_kopya": silinen, "ek": ek}


def broken_refs(book, folder=None):
    """Every config/games path with no file behind it, and where it sits.

    check_book counts them and shows ten bare paths; the author needs the
    whole list with module and page to fix them. In a project (folder=None) a
    path the module will repair -- exactly one loose match on disk -- is not
    listed, same rule as check_book. In an export (folder given) nothing is
    repaired any more and the prefix must be the export's folder, same rule as
    normalize_book's final check.
    """
    idx = fn.build_index(book)
    out, seen = [], set()

    def check(path, modul, sayfa):
        parts = path[len(fn.BOOKS_PREFIX):].split("/", 1)
        if len(parts) != 2:
            if folder is None:
                return
            rel, aday = path, 0
        else:
            rel = parts[1]
            if (folder is None or parts[0] == folder) and (book / rel).exists():
                return
            aday = len(idx.get(fn.loose(rel), []))
            if folder is None and aday == 1:
                return
        key = (modul, sayfa, rel)
        if key in seen:
            return
        seen.add(key)
        where = modul if sayfa is None else f"{modul} · page {sayfa}"
        metin = f"{where} · {rel}"
        if aday > 1:
            metin += f"  ({aday} matching files — ambiguous)"
        out.append({"modul": modul, "sayfa": sayfa, "yol": rel, "metin": metin})

    conf = json.loads((book / "config.json").read_text(encoding="utf-8"))
    for path in fn.iter_book_paths({k: v for k, v in conf.items() if k != "books"}):
        check(path, "(book)", None)
    for b in conf.get("books") or []:
        if not isinstance(b, dict):
            continue
        for path in fn.iter_book_paths({k: v for k, v in b.items() if k != "modules"}):
            check(path, "(book)", None)
        for m in b.get("modules") or []:
            if not isinstance(m, dict):
                continue
            for p in m.get("pages") or []:
                if isinstance(p, dict):
                    for path in fn.iter_book_paths(p):
                        check(path, m.get("name") or "?", p.get("page_number"))
    games = book / "games.json"
    if games.is_file():
        try:
            for path in fn.iter_book_paths(json.loads(games.read_text(encoding="utf-8"))):
                check(path, "games.json", None)
        except json.JSONDecodeError:
            pass
    # iter_book_paths walks a stack; put the list back in page order.
    return sorted(out, key=lambda o: (o["sayfa"] is None, o["sayfa"] or 0, o["yol"]))


def cover_path(src, conf, kapak):
    """The cover the book uses (config's book_cover), else the one check_book saw."""
    bc = conf.get("book_cover") or ""
    if bc.startswith(fn.BOOKS_PREFIX):
        parts = bc[len(fn.BOOKS_PREFIX):].split("/", 1)
        if len(parts) == 2 and (src / parts[1]).is_file():
            return (src / parts[1]).resolve().as_posix()
    return (src / "images" / kapak).resolve().as_posix() if kapak else None


def write_back(src, title, publisher):
    cfg = src / "config.json"
    data = json.loads(cfg.read_text(encoding="utf-8"))
    if data.get("book_title") == title and data.get("publisher_name") == publisher:
        return False
    data["book_title"] = title
    data["publisher_name"] = publisher
    tmp = cfg.with_name("config.json.tmp")
    tmp.write_text(json.dumps(data, ensure_ascii=False, indent=4), encoding="utf-8")
    os.replace(tmp, cfg)
    return True


def cmd_check(a):
    src = Path(a.book_dir)
    try:
        r = fn.check_book(src)
    except fn.FlowbookError as exc:
        return emit({"hata": str(exc)}, 2)
    conf = json.loads((src / "config.json").read_text(encoding="utf-8"))
    raw = src / "raw"
    duz, cevapli = raw_pdfs(raw)
    r["original"] = "var" if (raw / "original.pdf").is_file() or duz else "yok"
    r["answered"] = "var" if (raw / "answered.pdf").is_file() or cevapli else "yok"
    if (raw / "original.pdf").is_file():
        kaynak = [raw / "original.pdf"]
    else:
        kaynak = fn.dedupe_pdfs(duz)[0] if duz else []
    # How many files each canonical PDF would be merged from (after the
    # module's own de-duplication), and whether pypdf is there to do it.
    cevapli_tekil = fn.dedupe_pdfs(cevapli)[0] if cevapli else []
    parca = max(len(kaynak), len(cevapli_tekil))
    r["pdf_parca"] = parca
    r["pypdf"] = importlib.util.find_spec("pypdf") is not None
    r["pypdf_uyari"] = pypdf_warning(parca, r["pypdf"])
    sayilar = [pdf_pages(f) for f in kaynak]
    r["pdf_sayfa"] = sum(sayilar) if sayilar and None not in sayilar else None
    r["config_sayfa_son"] = config_last_page(conf)
    r["sayfa_uyari"] = page_warning(r["pdf_sayfa"], r["config_sayfa_son"])
    r["publisher_logo_path"] = conf.get("publisher_logo_path")
    r["logo_uyari"] = logo_warning(conf)
    r["kapak_yolu"] = cover_path(src, conf, r.get("kapak"))
    r["kirik_detay"] = broken_refs(src)
    r["video"] = video_compat.check_book(src)
    return emit(r, 1 if r.get("ref_kayip") or r["kirik_detay"] else 0)


def cmd_title(a):
    title = a.baslik.strip()
    if not title:
        return emit({"hata": "Book title is required."}, 2)
    try:
        folder = fn.title_to_folder(title)
    except fn.FlowbookError as exc:
        return emit({"hata": str(exc)}, 2)
    return emit({"klasor": folder,
                 "baslik_uyari": fn._title_problems(a.baslik, a.yayinevi.strip())}, 0)


def cmd_normalize(a):
    title = a.baslik.strip()
    publisher = "" if a.yayinevi_yok else a.yayinevi.strip()
    if not title:
        return emit({"hata": "Book title is required."}, 2)
    if not publisher and not a.yayinevi_yok:
        return emit({"hata": "Publisher is required."}, 2)
    if a.answered and not Path(a.answered).is_file():
        return emit({"hata": f"Answered PDF not found: {a.answered}"}, 2)

    src = Path(a.book_dir)
    video = video_compat.check_export(src)
    if "hata" in video:
        return emit({"hata": video["hata"]}, 2)
    try:
        rapor = fn.normalize_book(src, a.export_root, title=title, publisher=publisher)
    except fn.FlowbookError as exc:
        return emit({"hata": str(exc)}, 2)
    rapor["geri_yazildi"] = write_back(src, title, publisher) if a.geri_yaz else False
    rapor["video"] = video

    dest = Path(rapor["hedef"])
    raw = dest / "raw"
    orig, ans = raw / "original.pdf", raw / "answered.pdf"
    # Decided by the files on disk -- what gets packaged -- not by the wording
    # of rapor["pdf"].
    if not orig.is_file():
        return emit({**rapor, "hata": "raw/ has no original PDF — the book can't be packaged."}, 2)
    if not ans.is_file():
        if a.answered:
            shutil.copyfile(a.answered, ans)
            rapor["answered_kaynak"] = f"chosen: {a.answered}"
        elif a.answered_original:
            shutil.copyfile(orig, ans)
            rapor["answered_kaynak"] = "copy of original.pdf (no answer key)"
        else:
            return emit({**rapor, "hata": "raw/ has no answered PDF. Choose one, or "
                                          "confirm the book has no answer key."}, 2)

    rapor["raw"] = clean_raw(raw)
    rapor["editor_dosyalari"] = strip_editor_files(dest)
    conf = json.loads((dest / "config.json").read_text(encoding="utf-8"))
    if a.yayinevi_yok and conf.get("publisher_name"):
        # normalize_book writes a publisher only when given one, so "None"
        # would otherwise keep whatever the project had.
        conf["publisher_name"] = ""
        (dest / "config.json").write_text(json.dumps(conf, ensure_ascii=False, indent=4),
                                          encoding="utf-8")
    rapor["publisher_name"] = publisher
    rapor["sayfa_uyari"] = page_warning(pdf_pages(orig), config_last_page(conf))
    rapor["logo_uyari"] = logo_warning(conf)
    # Everything above wrote into the export after the module's own sweep.
    rapor["appledouble_silindi"] += fn.sweep_appledouble(dest)
    rapor["mb"] = round(sum(f.stat().st_size for f in dest.rglob("*") if f.is_file())
                        / 1048576, 1)
    # The module checked before the steps above ran; they delete files too.
    rapor["dogrulama"] = final_check(dest, rapor["klasor"])
    if rapor["dogrulama"]["kirik_referans"]:
        rapor["kirik_detay"] = broken_refs(dest, rapor["klasor"])
    return emit(rapor, 1 if rapor["dogrulama"]["kirik_referans"] else 0)


# The editor's own files, which never ship -- on top of the module's junk rules
# (fn.is_junk) and matched ignoring case, since a copy that went through
# Windows can come back as FBINF or Settings.json. fbinf is the editor's
# encrypted install/lock state: older builds wrote it next to whatever they
# had open, which is how it reached published books (Countdown 3).
#
# Folders and work files count ONLY at the book's root, where the editor
# writes them (next to config.json). A name like that further down is the
# publisher's content: Next Level 1-3 keep real, referenced pages in
# images/Review/, and matching "review" at any depth deleted them.
# pdfprocess.cpp isExcludedFromPackage follows the same rule.
EDITOR_ROOT_DIRS = {"review", "temp", "tmp", ".pkgcache"}
EDITOR_ANY_DIRS = {"__macosx"}
EDITOR_ROOT_FILES = {"ai_overrides.json", "audit_log.jsonl"}
EDITOR_ANY_FILES = {"fbinf", "settings.json"}
EDITOR_RE = re.compile(r"\.ini$|\.fbinf$|\.bak(\.|$)|\.tmp$|^~\$", re.I)


def editor_junk(name, is_dir, at_root):
    low = name.lower()
    if is_dir:
        return low in EDITOR_ANY_DIRS or (at_root and low in EDITOR_ROOT_DIRS)
    return (low in EDITOR_ANY_FILES or bool(EDITOR_RE.search(name))
            or (at_root and low in EDITOR_ROOT_FILES))


def strip_editor_files(book):
    """Remove the editor's files from an export, so book_export never holds
    them either. raw/ is clean_raw's."""
    removed = []
    for p in sorted(book.rglob("*"), key=lambda q: -len(q.parts)):
        rel = p.relative_to(book)
        if rel.parts[0] == "raw" or not p.exists():
            continue
        is_dir = p.is_dir()
        if editor_junk(p.name, is_dir, len(rel.parts) == 1):
            fn.safe_rmtree(p) if is_dir else fn.safe_remove(p)
            removed.append(rel.as_posix() + ("/" if is_dir else ""))
    return sorted(removed)


def final_check(book, folder):
    """normalize_book's closing check, run again after this file's own steps:
    they delete files too, and a wrong deletion must not pass silently."""
    kalan = []
    for name in ("config.json", "games.json"):
        cfg = book / name
        if not cfg.exists():
            continue
        for yol in fn.iter_book_paths(json.loads(cfg.read_text(encoding="utf-8"))):
            parts = yol[len(fn.BOOKS_PREFIX):].split("/", 1)
            if len(parts) != 2 or parts[0] != folder or not (book / parts[1]).exists():
                kalan.append(yol)
    return {"kirik_referans": len(kalan), "ornek": kalan[:10]}


def cmd_video_check(a):
    src = Path(a.book_dir)
    if not src.is_dir():
        return emit({"hata": f"Book folder not found: {src}"}, 2)
    # Runs in the background while the author works (a book just opened):
    # it must never be what makes the editor feel slow.
    video_compat.lower_priority()
    return emit(video_compat.check_book(src), 0)


def cmd_videos(a):
    src = Path(a.book_dir)
    if not (src / "config.json").is_file():
        return emit({"hata": f"Not a book (no config.json): {src}"}, 2)
    stopped = threading.Event()
    if a.stdin_stop:
        def watch():
            # Returns when the editor closes our stdin. Read off the descriptor,
            # not sys.stdin: a daemon thread parked inside the buffered reader
            # holds its lock, and when the run ends normally Python aborts at
            # shutdown ("could not acquire lock for <stdin>") — macOS reports
            # that as "Python quit unexpectedly".
            try:
                while os.read(sys.stdin.fileno(), 4096):
                    pass
            except OSError:
                pass
            stopped.set()
        threading.Thread(target=watch, daemon=True).start()

    def progress(i, n, dosya, pct):
        print("PROGRESS: " + json.dumps({"i": i, "n": n, "dosya": dosya, "pct": pct},
                                        ensure_ascii=False), flush=True)

    r = video_compat.optimize_book(src, progress, stopped.is_set)
    if "hata" in r:
        return emit(r, 2)
    if r.get("iptal"):
        return emit(r, 3)
    return emit(r, 1 if r["basarisiz"] else 0)


# Already compressed: deflating them costs time and saves nothing.
ZIP_STORED = {".png", ".jpg", ".jpeg", ".gif", ".webp", ".mp3", ".m4a", ".wav",
              ".ogg", ".mp4", ".m4v", ".mov", ".webm", ".pdf", ".zip"}


def cmd_zip(a):
    src = Path(a.export_dir)
    if not (src / "config.json").is_file():
        return emit({"hata": f"Not an exported book (no config.json): {src}"}, 2)
    target = src.with_name(src.name + ".zip")
    tmp = src.with_name(src.name + ".zip.tmp")
    eklenen, atlanan = 0, []
    with zipfile.ZipFile(tmp, "w", allowZip64=True) as z:
        for root, dirs, files in os.walk(src):
            here = Path(root)
            rel_dir = here.relative_to(src)
            at_root = not rel_dir.parts
            kept = []
            for d in sorted(dirs):
                if d.startswith(".") or editor_junk(d, True, at_root) or fn.is_junk(here / d):
                    atlanan.append((rel_dir / d).as_posix() + "/")
                else:
                    kept.append(d)
            dirs[:] = kept
            in_raw = rel_dir.parts[:1] == ("raw",)
            for name in sorted(files):
                path = here / name
                rel = (rel_dir / name).as_posix()
                if (name.startswith(".") or editor_junk(name, False, at_root) or fn.is_junk(path)
                        # raw/ ships exactly original.pdf and answered.pdf
                        or (in_raw and (len(rel_dir.parts) > 1 or name not in fn.KANON_PDF))):
                    atlanan.append(rel)
                    continue
                kind = (zipfile.ZIP_STORED if path.suffix.lower() in ZIP_STORED
                        else zipfile.ZIP_DEFLATED)
                z.write(path, f"{src.name}/{rel}", compress_type=kind)
                eklenen += 1
    with zipfile.ZipFile(tmp) as z:
        bozuk = z.testzip()
    if bozuk:
        tmp.unlink()
        return emit({"hata": f"The zip came out damaged at {bozuk} — nothing was replaced."}, 2)
    os.replace(tmp, target)
    r = {"zip": target.as_posix(), "dosya": eklenen,
         "mb": round(target.stat().st_size / 1048576, 1),
         "atlanan_sayi": len(atlanan), "atlanan": atlanan[:20]}
    if a.klasoru_sil:
        fn.safe_rmtree(src)
        r["klasor_silindi"] = not src.exists()
    return emit(r, 0)


def main(argv=None):
    # stderr too: a Windows console is cp1252, and a traceback carrying a
    # Turkish path would fail to print there.
    for stream in (sys.stdout, sys.stderr):
        if hasattr(stream, "reconfigure"):
            stream.reconfigure(encoding="utf-8")
    ap = argparse.ArgumentParser(description="Package-time book normalization.")
    sub = ap.add_subparsers(dest="cmd", required=True)
    c = sub.add_parser("check")
    c.add_argument("book_dir")
    t = sub.add_parser("title")
    t.add_argument("--baslik", required=True)
    t.add_argument("--yayinevi", default="")
    n = sub.add_parser("normalize")
    n.add_argument("book_dir")
    n.add_argument("export_root")
    n.add_argument("--baslik", required=True)
    p = n.add_mutually_exclusive_group(required=True)
    p.add_argument("--yayinevi")
    p.add_argument("--yayinevi-yok", action="store_true")
    g = n.add_mutually_exclusive_group()
    g.add_argument("--answered")
    g.add_argument("--answered-original", action="store_true")
    n.add_argument("--geri-yaz", action="store_true")
    vc = sub.add_parser("video-check")
    vc.add_argument("book_dir")
    v = sub.add_parser("videos")
    v.add_argument("book_dir")
    v.add_argument("--stdin-stop", action="store_true")
    zp = sub.add_parser("zip")
    zp.add_argument("export_dir")
    zp.add_argument("--klasoru-sil", action="store_true")
    a = ap.parse_args(argv)
    try:
        return {"check": cmd_check, "title": cmd_title, "normalize": cmd_normalize,
                "video-check": cmd_video_check, "videos": cmd_videos,
                "zip": cmd_zip}[a.cmd](a)
    except Exception as exc:
        # The result line FIRST: printing a traceback can itself fail on a
        # console that can't encode the path in it, and the editor would then
        # have no result to show. Exit 1 tells the editor "broken references";
        # nothing unexpected may read as that.
        code = emit({"hata": error_text(exc)}, 2)
        traceback.print_exc()
        return code


if __name__ == "__main__":
    raise SystemExit(main())
