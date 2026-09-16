#!/usr/bin/env python3
"""video_compat + package_book'un video adimi icin bagimsiz test.

Kisa sentetik videolarla (HEVC 10-bit, VP9/WebM, 4K, donuk dikey video, AC-3
ses, 4:4:4, bozuk dosya) bir kitap kurar; Book Details kontrolunu, Optimize'i,
durdurmayi ve export'u dogrular. ffmpeg (libx264, libx265, libvpx-vp9, libopus
ile) gerektirir; yoksa atlanir.

    python3 test_video_compat.py
"""

import io
import json
import shutil
import subprocess
import sys
import tempfile
from contextlib import redirect_stdout
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import package_book
import video_compat as vc

for _akis in (sys.stdout, sys.stderr):
    if hasattr(_akis, "reconfigure"):
        try:
            _akis.reconfigure(encoding="utf-8")
        except (AttributeError, ValueError, OSError):
            pass

GECTI, KALDI = [], []


def kontrol(ad, kosul, ayrinti=""):
    (GECTI if kosul else KALDI).append(ad)
    print(f"  {'✓' if kosul else '✗'} {ad}" + (f"   {ayrinti}" if not kosul and ayrinti else ""))


FFMPEG = vc.find_ffmpeg()


def uret(hedef, *args, sure=2):
    hedef.parent.mkdir(parents=True, exist_ok=True)
    cmd = [FFMPEG, "-v", "error", "-y",
           "-f", "lavfi", "-i", f"testsrc2=size=320x240:rate=25:duration={sure}",
           "-f", "lavfi", "-i", f"sine=frequency=440:duration={sure}",
           *args, str(hedef)]
    subprocess.run(cmd, check=True)


def kitap_kur(kok):
    b = kok / "VideoKitap"
    v = b / "videos"
    uret(v / "ok.mp4", "-c:v", "libx264", "-pix_fmt", "yuv420p", "-c:a", "aac")
    uret(v / "CHASE 5  STORY 3.mp4", "-c:v", "libx265", "-pix_fmt", "yuv420p10le",
         "-tag:v", "hvc1", "-c:a", "aac", "-x265-params", "log-level=error")
    uret(v / "vp9 clip.webm", "-c:v", "libvpx-vp9", "-c:a", "libopus")
    (v / "vp9 clip.srt").write_text("1\n00:00:00,000 --> 00:00:01,000\nhi\n", encoding="utf-8")
    subprocess.run([FFMPEG, "-v", "error", "-y", "-f", "lavfi", "-i",
                    "testsrc2=size=3840x2160:rate=25:duration=1",
                    "-c:v", "libx264", "-pix_fmt", "yuv420p", str(v / "big.mov")], check=True)
    # dikey telefon videosu: 3840x2160 kodlu, 90 derece donuk gosterilir
    tmp = kok / "yatay.mp4"
    subprocess.run([FFMPEG, "-v", "error", "-y", "-f", "lavfi", "-i",
                    "testsrc2=size=3840x2160:rate=25:duration=1",
                    "-c:v", "libx264", "-pix_fmt", "yuv420p", str(tmp)], check=True)
    subprocess.run([FFMPEG, "-v", "error", "-y", "-display_rotation:v:0", "90",
                    "-i", str(tmp), "-c", "copy", str(v / "portrait.mp4")], check=True)
    uret(v / "ac3.mp4", "-c:v", "libx264", "-pix_fmt", "yuv420p", "-c:a", "ac3")
    uret(v / "yuv444.mp4", "-c:v", "libx264", "-pix_fmt", "yuv444p", "-c:a", "aac")
    (v / "broken.mp4").write_bytes(b"\0not a video" * 1000)

    (b / "images").mkdir(parents=True)
    (b / "raw").mkdir()
    (b / "raw" / "original.pdf").write_bytes(b"%PDF-1.4 original" + b"\0" * 300)
    pre = "./books/VideoKitap/videos/"
    sections = [{"type": "video", "video_path": pre + n} for n in
                ("ok.mp4", "CHASE 5  STORY 3.mp4", "vp9 clip.webm", "big.mov",
                 "portrait.mp4", "ac3.mp4", "yuv444.mp4")]
    conf = {"book_title": "Video Test", "publisher_name": "Universal ELT",
            "books": [{"modules": [{"name": "Unit 1", "pages": [
                {"page_number": 1, "sections": sections}]}]}]}
    (b / "config.json").write_text(json.dumps(conf, ensure_ascii=False, indent=4), encoding="utf-8")
    return b


def calistir(argv):
    buf = io.StringIO()
    with redirect_stdout(buf):
        code = package_book.main(argv)
    satir = [l for l in buf.getvalue().splitlines() if l.startswith("RESULT_JSON:")]
    return code, json.loads(satir[-1][len("RESULT_JSON:"):]) if satir else {}


def main():
    if not FFMPEG:
        print("ffmpeg yok — test atlandi")
        return 0
    kok = Path(tempfile.mkdtemp(prefix="video_compat_"))
    try:
        print("kitap kuruluyor…")
        book = kitap_kur(kok)

        print("\nBook Details kontrolu")
        c = vc.check_book(book)
        sorunlu = {r["dosya"]: r for r in c["sorunlu"]}
        kontrol("8 video bulundu", c["toplam"] == 8, c["toplam"])
        kontrol("ok.mp4 sorunsuz", "videos/ok.mp4" not in sorunlu)
        kontrol("bozuk dosya okunamayan", [o["dosya"] for o in c["okunamayan"]] == ["videos/broken.mp4"],
                c["okunamayan"])
        kontrol("6 sorunlu video", len(sorunlu) == 6, sorted(sorunlu))
        hevc = sorunlu.get("videos/CHASE 5  STORY 3.mp4", {}).get("sorun", "")
        kontrol("HEVC 10-bit nedeniyle", "HEVC" in hevc and "10-bit" in hevc, hevc)
        vp9 = sorunlu.get("videos/vp9 clip.webm", {}).get("sorun", "")
        kontrol("webm: kap + VP9 + Opus", all(k in vp9 for k in (".webm", "VP9", "Opus")), vp9)
        kontrol("4K: 1080p ustu", "over 1080p" in sorunlu.get("videos/big.mov", {}).get("sorun", ""))
        kontrol("dikey 4K: 1080p ustu", "over 1080p" in sorunlu.get("videos/portrait.mp4", {}).get("sorun", ""))
        ac3 = sorunlu.get("videos/ac3.mp4", {}).get("sorun", "")
        kontrol("AC-3 yalnizca ses", ac3 == "AC-3 audio", ac3)
        kontrol("4:4:4 renk", "4:4:4" in sorunlu.get("videos/yuv444.mp4", {}).get("sorun", ""))
        kontrol("hicbiri hazir degil", not any(r["hazir"] for r in c["sorunlu"]))
        (book / "videos" / "broken.mp4").unlink()

        print("\nDurdurma")
        adimlar = []

        def dur_ilk_yuzdede():
            return any(p > 0 for *_, p in adimlar)

        r = vc.optimize_book(book, lambda i, n, d, p: adimlar.append((i, n, d, p)), dur_ilk_yuzdede)
        kontrol("iptal bildirildi", r.get("iptal") is True, r)
        kontrol("yarim .part kalmadi", not list(vc.cache_dir(book).glob("*.part.mp4")))
        kontrol("durdurulan video onbellege girmedi",
                sum(1 for x in vc.check_book(book)["sorunlu"] if x["hazir"]) == len(r["donusen"]))

        print("\nOptimize")
        adimlar.clear()
        r = vc.optimize_book(book, lambda i, n, d, p: adimlar.append((i, n, d, p)), lambda: False)
        kontrol("hata yok", "hata" not in r and not r["basarisiz"], r)
        kontrol("ilerleme bildirildi", len(adimlar) > 0)
        c = vc.check_book(book)
        kontrol("hepsi hazir", c["sorunlu"] and all(x["hazir"] for x in c["sorunlu"]), c["sorunlu"])
        kontrol("proje dosyalarina dokunulmadi",
                vc.probe(book / "videos" / "CHASE 5  STORY 3.mp4", FFMPEG)["video"]["codec"] == "hevc")
        r2 = vc.optimize_book(book, lambda *a: None, lambda: False)
        kontrol("ikinci Optimize is yapmaz", r2 == {"donusen": [], "basarisiz": []}, r2)

        print("\nExport")
        out = kok / "book_export"
        code, rapor = calistir(["normalize", str(book), str(out), "--baslik=Video Test",
                                "--yayinevi=Universal ELT", "--answered-original"])
        kontrol("normalize temiz bitti", code == 0 and "hata" not in rapor, rapor.get("hata"))
        dest = Path(rapor.get("hedef", out / "Video_Test"))
        kontrol("6 video degisti", len(rapor.get("video", {}).get("degisen", [])) == 6, rapor.get("video"))
        kalan = [p.name for p in vc.find_videos(dest)
                 if vc.problems(p, vc.probe(p, FFMPEG))]
        kontrol("export'taki her video oynar", not kalan, kalan)
        vids = {p.name for p in (dest / "videos").iterdir()}
        kontrol("webm .mp4 oldu", "vp9_clip.mp4" in vids and "vp9_clip.webm" not in vids, vids)
        kontrol("altyazi yerinde", "vp9_clip.srt" in vids, vids)
        conf = json.loads((dest / "config.json").read_text(encoding="utf-8"))
        yollar = [s["video_path"] for s in conf["books"][0]["modules"][0]["pages"][0]["sections"]]
        kontrol("config yeni adi gosteriyor", "./books/Video_Test/videos/vp9_clip.mp4" in yollar, yollar)
        kontrol("kirik referans yok", rapor.get("dogrulama", {}).get("kirik_referans") == 0,
                rapor.get("dogrulama"))
        big = vc.probe(dest / "videos" / "big.mov", FFMPEG)["video"]
        kontrol("4K -> 1920x1080", (big["width"], big["height"]) == (1920, 1080), big)
        por = vc.probe(dest / "videos" / "portrait.mp4", FFMPEG)["video"]
        kontrol("dikey -> 1080x1920, donuksuz",
                (por["width"], por["height"], por["rotation"]) == (1080, 1920, 0), por)
        ac3 = vc.probe(dest / "videos" / "ac3.mp4", FFMPEG)
        kontrol("AC-3: goruntu aynen, ses AAC",
                (ac3["video"]["width"], ac3["audio"]["codec"]) == (320, "aac"), ac3)
        kontrol(".pkgcache export'a gitmedi", not (dest / ".pkgcache").exists())

        print("\nOnbellek yokken export durur")
        shutil.rmtree(vc.cache_dir(book))
        code, rapor = calistir(["normalize", str(book), str(out), "--baslik=Video Test",
                                "--yayinevi=Universal ELT", "--answered-original"])
        kontrol("hata ile durdu", code == 2 and "Optimize videos" in rapor.get("hata", ""),
                rapor.get("hata"))

        print("\nvideos komutu: stdin kapaninca durur")
        run = subprocess.run([sys.executable, str(Path(package_book.__file__)), "videos",
                              str(book), "--stdin-stop"],
                             stdin=subprocess.DEVNULL, capture_output=True, text=True)
        kontrol("cikis 3 (durduruldu)", run.returncode == 3, run.stdout[-300:] + run.stderr[-300:])
    finally:
        shutil.rmtree(kok, ignore_errors=True)

    print(f"\n{len(GECTI)} gecti, {len(KALDI)} kaldi")
    return 1 if KALDI else 0


if __name__ == "__main__":
    raise SystemExit(main())
