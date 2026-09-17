#!/usr/bin/env python3
"""video_compat + package_book'un video adimi icin bagimsiz test.

Kisa sentetik videolarla (HEVC 10-bit, VP9/WebM, 4K, donuk dikey video, AC-3
ses, 4:4:4, bozuk dosya) bir kitap kurar; kontrolu, yerinde Optimize'i,
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
    # audio/ may hold .mp4 files with no picture; they are not the book's videos
    (b / "audio").mkdir(parents=True)
    subprocess.run([FFMPEG, "-v", "error", "-y", "-f", "lavfi", "-i", "sine=duration=1",
                    "-c:a", "aac", str(b / "audio" / "4.mp4")], check=True)
    (b / "images").mkdir(parents=True)
    (b / "images" / "not-a-video.mp4").write_bytes(b"x")

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
        out = kok / "book_export"
        normalize = ["normalize", str(book), str(out), "--baslik=Video Test",
                     "--yayinevi=Universal ELT", "--answered-original"]

        print("\nKontrol")
        c = vc.check_book(book)
        satir = {r["dosya"]: r for r in c["videolar"]}
        kontrol("8 video bulundu, audio/ ve images/ taranmadi",
                c["toplam"] == 8 and len(satir) == 8 and all(d.startswith("videos/") for d in satir),
                sorted(satir))
        kontrol("ok.mp4 uygun", satir.get("videos/ok.mp4", {}).get("durum") == "uygun")
        kontrol("ozet okunur", satir.get("videos/ok.mp4", {}).get("ozet", "").startswith("H.264 · 320×240 · AAC"),
                satir.get("videos/ok.mp4"))
        kontrol("bozuk dosya okunamayan", c["okunamayan"] == 1
                and satir.get("videos/broken.mp4", {}).get("durum") == "okunamayan")
        kontrol("6 sorunlu video", c["sorunlu"] == 6, c["sorunlu"])
        hevc = satir.get("videos/CHASE 5  STORY 3.mp4", {}).get("sorun", "")
        kontrol("HEVC 10-bit nedeniyle", "HEVC" in hevc and "10-bit" in hevc, hevc)
        vp9 = satir.get("videos/vp9 clip.webm", {}).get("sorun", "")
        kontrol("webm: kap + VP9 + Opus", all(k in vp9 for k in (".webm", "VP9", "Opus")), vp9)
        kontrol("4K: 1080p ustu", "over 1080p" in satir.get("videos/big.mov", {}).get("sorun", ""))
        kontrol("dikey 4K: 1080p ustu", "over 1080p" in satir.get("videos/portrait.mp4", {}).get("sorun", ""))
        ac3 = satir.get("videos/ac3.mp4", {}).get("sorun", "")
        kontrol("AC-3 yalnizca ses", ac3 == "AC-3 audio", ac3)
        kontrol("4:4:4 renk", "4:4:4" in satir.get("videos/yuv444.mp4", {}).get("sorun", ""))
        code, r = calistir(["video-check", str(book)])
        kontrol("video-check komutu ayni sonucu verir", code == 0 and r.get("sorunlu") == 6, r)

        print("\nExport uyumsuz video varken durur")
        code, r = calistir(normalize)
        kontrol("hata ile durdu", code == 2 and "can't be read" in r.get("hata", ""), r.get("hata"))
        kontrol("hicbir sey kopyalanmadi", not (out / "Video_Test").exists())
        (book / "videos" / "broken.mp4").unlink()

        print("\nDurdurma")
        run = subprocess.run([sys.executable, str(Path(package_book.__file__)), "videos",
                              str(book), "--stdin-stop"],
                             stdin=subprocess.DEVNULL, capture_output=True, text=True)
        kontrol("stdin kapaninca cikis 3", run.returncode == 3, run.stdout[-300:] + run.stderr[-300:])
        # The editor's Stop: stdin closes while a conversion is running.
        proc = subprocess.Popen([sys.executable, "-u", str(Path(package_book.__file__)), "videos",
                                 str(book), "--stdin-stop"],
                                stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        for line in proc.stdout:
            if b'"pct": ' in line and not line.rstrip().endswith(b'"pct": 0}'):
                proc.stdin.close()
                break
        rest = proc.stdout.read()
        proc.wait()
        kontrol("calisirken Stop: cikis 3, cokme yok",
                proc.returncode == 3 and b"Fatal Python error" not in rest, (proc.returncode, rest[-300:]))
        kontrol("Stop sonrasi orijinal yerinde",
                vc.probe(book / "videos" / "CHASE 5  STORY 3.mp4", FFMPEG)["video"]["codec"] == "hevc")
        adimlar = []
        r = vc.optimize_book(book, lambda i, n, d, p: adimlar.append((i, n, d, p)),
                             lambda: any(p > 0 for *_, p in adimlar))
        kontrol("iptal bildirildi", r.get("iptal") is True, r)
        kontrol("durdurulan video yerinde, dokunulmamis",
                vc.probe(book / "videos" / "CHASE 5  STORY 3.mp4", FFMPEG)["video"]["codec"] == "hevc")
        kontrol("yarim dosya kalmadi", not list(book.rglob("*.part.mp4")))

        print("\nOptimize (yerinde)")
        eski = book / ".pkgcache" / "videos"
        eski.mkdir(parents=True, exist_ok=True)
        (eski / "0123456789abcdef01234567.mp4").write_bytes(b"3.3.17 onbellegi")
        (eski / "0123456789abcdef01234567.json").write_text("{}")
        adimlar.clear()
        r = vc.optimize_book(book, lambda i, n, d, p: adimlar.append((i, n, d, p)), lambda: False)
        kontrol("hata yok", "hata" not in r and not r["basarisiz"], r)
        kontrol("6 video donustu", len(r["donusen"]) == 6, r["donusen"])
        kontrol("ilerleme bildirildi", len(adimlar) > 0)
        c = vc.check_book(book)
        kontrol("kitaptaki her video artik uygun",
                c["toplam"] == 7 and all(v["durum"] == "uygun" for v in c["videolar"]), c["videolar"])
        vids = {p.name for p in (book / "videos").iterdir()}
        kontrol("webm .mp4 oldu, orijinal silindi", "vp9 clip.mp4" in vids and "vp9 clip.webm" not in vids, vids)
        kontrol("yeniden adlandirma bildirildi",
                r["yeniden_adlandirilan"] == {"videos/vp9 clip.webm": "videos/vp9 clip.mp4"}, r["yeniden_adlandirilan"])
        kontrol("altyazi yerinde", "vp9 clip.srt" in vids, vids)
        kontrol(".mov adi degismedi", "big.mov" in vids, vids)
        conf = json.loads((book / "config.json").read_text(encoding="utf-8"))
        yollar = [s["video_path"] for s in conf["books"][0]["modules"][0]["pages"][0]["sections"]]
        kontrol("config.json yeni adi gosteriyor",
                "./books/VideoKitap/videos/vp9 clip.mp4" in yollar and not any(y.endswith(".webm") for y in yollar), yollar)
        big = vc.probe(book / "videos" / "big.mov", FFMPEG)["video"]
        kontrol("4K -> 1920x1080", (big["width"], big["height"]) == (1920, 1080), big)
        por = vc.probe(book / "videos" / "portrait.mp4", FFMPEG)["video"]
        kontrol("dikey -> 1080x1920, donuksuz",
                (por["width"], por["height"], por["rotation"]) == (1080, 1920, 0), por)
        a3 = vc.probe(book / "videos" / "ac3.mp4", FFMPEG)
        kontrol("AC-3: goruntu aynen, ses AAC", (a3["video"]["width"], a3["audio"]["codec"]) == (320, "aac"), a3)
        kontrol(".pkgcache/videos temizlendi (3.3.17 onbellegi dahil)", not (book / ".pkgcache").exists())
        r2 = vc.optimize_book(book, lambda *a: None, lambda: False)
        kontrol("ikinci Optimize is yapmaz",
                r2 == {"donusen": [], "basarisiz": [], "yeniden_adlandirilan": {}}, r2)
        # stdin stays open until the run ends on its own, as with the editor:
        # the watcher must not make Python abort at exit ("Python quit unexpectedly").
        proc = subprocess.Popen([sys.executable, str(Path(package_book.__file__)), "videos",
                                 str(book), "--stdin-stop"],
                                stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        out_bytes = proc.stdout.read()
        proc.wait()
        proc.stdin.close()
        kontrol("stdin acikken normal bitis: cikis 0, cokme yok",
                proc.returncode == 0 and b"Fatal Python error" not in out_bytes, (proc.returncode, out_bytes[-300:]))

        print("\nExport")
        code, rapor = calistir(normalize)
        kontrol("normalize temiz bitti", code == 0 and "hata" not in rapor, rapor.get("hata"))
        kontrol("rapor 7 video", rapor.get("video") == {"toplam": 7}, rapor.get("video"))
        dest = Path(rapor.get("hedef", out / "Video_Test"))
        kalan = [p.name for p in vc.find_videos(dest) if vc.problems(p, vc.probe(p, FFMPEG))]
        kontrol("export'taki her video oynar", not kalan, kalan)
        kontrol("kirik referans yok", rapor.get("dogrulama", {}).get("kirik_referans") == 0,
                rapor.get("dogrulama"))
    finally:
        shutil.rmtree(kok, ignore_errors=True)

    print(f"\n{len(GECTI)} gecti, {len(KALDI)} kaldi")
    return 1 if KALDI else 0


if __name__ == "__main__":
    raise SystemExit(main())
