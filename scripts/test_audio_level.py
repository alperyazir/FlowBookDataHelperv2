#!/usr/bin/env python3
"""audio_level + package_book'un ses adimi icin bagimsiz test.

Sentetik, kisik ve boguk (alcak geciren filtreli gurultu) MP3'ler ve bir video
ile bir kitap kurar; kontrolu (bogukluk dahil), boguk kitabin kendiliginden net
sesle, parlak kitabin duz kazancla duzeltilmesini, sonradan eklenen dosyanin
kitabin geri kalani gibi yapilmasini, ikinci calistirmanin hicbir seye
dokunmamasini ve videonun goruntusunun aynen kalmasini dogrular. ffmpeg (libmp3lame, libx264 ile) gerektirir; yoksa
atlanir.

    python3 test_audio_level.py
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
import audio_cbr
import audio_level as al
import package_book

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


FFMPEG = audio_cbr._ffmpeg()
# Pembe gurultu, 1.2 kHz'te kesilmis: konusmanin boguk kaydi gibi koyu, kisik.
BOGUK = "anoisesrc=color=pink:amplitude=0.08:duration={sure}:seed={tohum},lowpass=f=1200,lowpass=f=1200"
# Ayni gurultu, kesilmeden: kisik ama acik.
ACIK = "anoisesrc=color=pink:amplitude=0.03:duration={sure}:seed={tohum}"


def mp3(hedef, sure=6, tohum=1, kaynak=BOGUK):
    hedef.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run([FFMPEG, "-v", "error", "-y", "-f", "lavfi",
                    "-i", kaynak.format(sure=sure, tohum=tohum),
                    "-ac", "2", "-ar", "44100", "-c:a", "libmp3lame", "-b:a", "128k",
                    "-write_xing", "1", str(hedef)], check=True)


def video(hedef, sure=6):
    hedef.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run([FFMPEG, "-v", "error", "-y",
                    "-f", "lavfi", "-i", f"testsrc2=size=320x240:rate=25:duration={sure}",
                    "-f", "lavfi", "-i", BOGUK.format(sure=sure, tohum=9),
                    "-c:v", "libx264", "-pix_fmt", "yuv420p", "-c:a", "aac", "-b:a", "128k",
                    "-shortest", str(hedef)], check=True)


def goruntu_md5(p):
    return subprocess.run([FFMPEG, "-v", "error", "-i", str(p), "-map", "0:v", "-c", "copy",
                           "-f", "md5", "-"], capture_output=True, text=True).stdout


def calistir(*args):
    out = io.StringIO()
    with redirect_stdout(out):
        kod = package_book.main(list(args))
    satir = [s for s in out.getvalue().splitlines() if s.startswith("RESULT_JSON:")]
    return kod, json.loads(satir[-1][12:]) if satir else {}


def kitap_kur(kok):
    b = kok / "SesKitap"
    (b / "config.json").parent.mkdir(parents=True, exist_ok=True)
    (b / "config.json").write_text("{}", encoding="utf-8")
    for i in range(4):
        mp3(b / "audio" / f"Pg-{i + 1}.mp3", tohum=i + 1)
    # Pg-1'in karaoke zamanlamasi var: kare sayisi ve gecikme korunmali.
    (b / "audio" / "audio.json").write_text(json.dumps({"Pg-1.mp3": []}), encoding="utf-8")
    video(b / "videos" / "tema.mp4")
    return b


def main():
    if not FFMPEG:
        print("ffmpeg yok, atlandi")
        return 0
    kok = Path(tempfile.mkdtemp(prefix="ses_test_"))
    try:
        b = kitap_kur(kok)
        resim = goruntu_md5(b / "videos" / "tema.mp4")
        kareler = audio_cbr.scan_frames(str(b / "audio" / "Pg-1.mp3"))["frames"]

        print("kontrol")
        r = al.check_book(b)
        kontrol("4 mp3 + 1 video", r["toplam"] == 5, r["toplam"])
        kontrol("hepsi kisik", r["duzeltilecek"] == 5, r["duzeltilecek"])
        kontrol("boguk bulundu", r["boguk"] and r["koyuluk"] > al.MUFFLED, (r["boguk"], r["koyuluk"]))
        kontrol("video satiri isaretli", any(s["video"] for s in r["sesler"]))

        print("boguk kitap: Optimize net sesi kendisi secer")
        kod, s = calistir("audio", str(b))
        kontrol("cikis 0", kod == 0, (kod, s))
        kontrol("net ses secildi", s.get("netlik") is True, s.get("netlik"))
        yeni = s.get("normalize_edilen", [])
        kontrol("5 dosya islendi", len(yeni) == 5, s)
        kontrol("hepsi -16 ±0.5 LUFS", all(abs(x["yeni_i"] + 16) <= 0.5 for x in yeni),
                [x["yeni_i"] for x in yeni])
        kontrol("tepe -0.3 dBTP altinda", all(x["yeni_tp"] < -0.3 for x in yeni),
                [x["yeni_tp"] for x in yeni])
        kontrol("karaokeli dosya atlanmadi, karesi ayni",
                not s.get("hizali_atlanan")
                and audio_cbr.scan_frames(str(b / "audio" / "Pg-1.mp3"))["frames"] == kareler)
        kontrol("video goruntusu aynen", goruntu_md5(b / "videos" / "tema.mp4") == resim)
        r = al.check_book(b)
        kontrol("hepsi isaretli ve uygun",
                all(x["netlik"] and x["durum"] == "uygun" for x in r["sesler"]), r["sesler"])
        kontrol("yapilacak bir sey kalmadi", r["duzeltilecek"] == 0 and not r["boguk"],
                (r["duzeltilecek"], r["boguk"]))

        print("ikinci calistirma")
        kod, s = calistir("audio", str(b))
        kontrol("hicbir sey degismedi", kod == 0 and not s.get("normalize_edilen"), s)

        print("sonradan eklenen dosya")
        mp3(b / "audio" / "Pg-9.mp3", tohum=9)
        r = al.check_book(b)
        kontrol("tek dosya boguk sayilmaz ama kitap net sesli",
                not r["boguk"] and r["netlik"] and r["duzeltilecek"] == 1,
                (r["boguk"], r["netlik"], r["duzeltilecek"]))
        kod, s = calistir("audio", str(b))
        kontrol("o da net sesle yapildi",
                [x["dosya"] for x in s.get("normalize_edilen", [])] == ["audio/Pg-9.mp3"]
                and s["normalize_edilen"][0]["netlik"], s)

        print("acik ama kisik kitap: duz kazanc")
        a = kok / "AcikKitap"
        (a / "config.json").parent.mkdir(parents=True, exist_ok=True)
        (a / "config.json").write_text("{}", encoding="utf-8")
        for i in range(4):
            mp3(a / "audio" / f"Pg-{i + 1}.mp3", tohum=i + 1, kaynak=ACIK)
        r = al.check_book(a)
        kontrol("boguk degil, hepsi kisik",
                not r["boguk"] and not r["netlik"] and r["duzeltilecek"] == 4,
                (r["koyuluk"], r["boguk"], r["duzeltilecek"]))
        kod, s = calistir("audio", str(a))
        kontrol("duz kazanc, isaret yok",
                kod == 0 and s.get("netlik") is False and len(s.get("normalize_edilen", [])) == 4
                and not any(x["netlik"] for x in s["normalize_edilen"]), s)
        kod, s = calistir("audio", str(a))
        kontrol("ikinci calistirma bos", kod == 0 and not s.get("normalize_edilen"), s)
    finally:
        shutil.rmtree(kok, ignore_errors=True)

    print(f"\n{len(GECTI)} gecti, {len(KALDI)} kaldi")
    return 1 if KALDI else 0


if __name__ == "__main__":
    raise SystemExit(main())
