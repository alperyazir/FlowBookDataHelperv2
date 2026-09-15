#!/usr/bin/env python3
"""flowbook_normalize icin bagimsiz test.

Bilinen HER tuzagi iceren sentetik bir kitap kurar, normalize eder, sonucu
dogrular. Disaridan veri gerektirmez; gecici dizinde calisir.

    python3 test_flowbook_normalize.py
"""

import json
import shutil
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import flowbook_normalize as fn

GECTI, KALDI = [], []


def kontrol(ad: str, kosul, ayrinti=""):
    (GECTI if kosul else KALDI).append(ad)
    print(f"  {'✓' if kosul else '✗'} {ad}" + (f"   {ayrinti}" if not kosul and ayrinti else ""))


def png(path: Path, w=40, h=40):
    path.parent.mkdir(parents=True, exist_ok=True)
    try:
        from PIL import Image
        Image.new("RGB", (w, h), (120, 60, 200)).save(path)
    except ImportError:
        path.write_bytes(b"\x89PNG\r\n\x1a\n" + b"\0" * 64)


def kitap_kur(kok: Path) -> Path:
    """Her tuzagi iceren ham kitap."""
    b = kok / "HamKitap"
    (b / "images").mkdir(parents=True)

    # 1) Turkce noktasiz i klasor adi + buyuk harfli uzanti
    png(b / "images" / "Unıt_1" / "2.PNG")
    # 2) tumu-buyuk kisaltma korunmali
    png(b / "images" / "Addıtıonal_Guıde_For_LGS" / "1.png")
    # 3) kapak standart disi adla
    png(b / "images" / "book_cover_koko.png")
    # 4) bosluklu ses dosyasi + '+' iceren iki AYRI dosya
    (b / "audio").mkdir()
    (b / "audio" / "PAGE 8.5.mp3").write_bytes(b"a")
    (b / "audio" / "Unit 1 +.mp3").write_bytes(b"b")
    (b / "audio" / "Unit 1.mp3").write_bytes(b"c")
    # 5) umlautlu gercek dosya. Disk 'Schildkröte.mp3' -> normalize 'Schildkrote.mp3'
    #    olur; config ise 'oe' ACILIMIYLA yazilmis ('Schildkroete.mp3'). Ikisi
    #    normalizasyonla ORTUSMEZ -- repair_refs'in gevsek anahtari cozer.
    (b / "audio" / "Schildkröte.mp3").write_bytes(b"d")
    # 6) 'asset' dizini + buyuk gorsel (kucultulmeli)
    png(b / "asset" / "oyun1.png", 1200, 800)
    # 7) images/ altindaki buyuk gorsel kucultulmemeli
    png(b / "images" / "Unıt_1" / "buyuk.png", 1600, 1200)
    # 13) editor kirpinti artiklari: referansi olmayan silinmeli; referansli ya da
    #     adi herhangi bir JSON metninde gecen korunmali
    png(b / "images" / "Unıt_1" / "p5s1.png")                      # referanssiz
    png(b / "images" / "Unıt_1" / "p5_crop_1788338539900.png")     # referanssiz
    png(b / "images" / "Unıt_1" / "p6s1.png")                      # section_path ile referansli
    png(b / "images" / "Unıt_1" / "p7s2.png")                      # adi yalnizca duz metinde geciyor
    png(b / "images" / "Kirpinti" / "p9s1.png")                    # tek dosya; dizin de bosalmali
    # oynatici .srt'yi video adindan, audio.json'u klasorden bulur: images/ disina dokunulmaz
    (b / "audio" / "yetim.mp3").write_bytes(b"e")
    # 8) bos dizinler
    (b / "video").mkdir()
    (b / "temp").mkdir()
    # 9) cop dosyalar
    (b / ".DS_Store").write_bytes(b"x")
    (b / "config.json.bak").write_bytes(b"x")
    (b / "config.json.bak.safe").write_bytes(b"x")
    (b / "icon_template_audio.png").write_bytes(b"x")
    (b / "icon_template_video.png").write_bytes(b"x")
    (b / "._gizli").write_bytes(b"x")
    (b / ".pkgcache").mkdir()
    (b / ".pkgcache" / "veri.bin").write_bytes(b"x")
    (b / "settings.json").write_text("{}")
    # editorun kilit dosyasi (kokte ve alt dizinde) + harf duyarsiz eslesme.
    # 'Settings.json' ayri dizinde: macOS'ta kokteki settings.json ile ayni dosya olurdu.
    (b / "fbinf").write_bytes(b"x")
    (b / "asset").mkdir(exist_ok=True)
    (b / "asset" / "FBINF").write_bytes(b"x")
    (b / "images" / "Settings.json").write_text("{}")
    # ayni adli KLASOR cop degil: icindeki dosya korunmali
    (b / "audio").mkdir(exist_ok=True)
    (b / "audio" / "fbinf").mkdir()
    (b / "audio" / "fbinf" / "icerik.mp3").write_bytes(b"g")
    # 'Review' gercek icerik klasoru olabilir (Next_Level): cop sayilmamali
    png(b / "images" / "Review" / "3.png")
    # karaoke: anahtarlar ses dosyasinin ADI. Dosyalar yeniden adlandirilinca
    # anahtarlar da ayni fonksiyonla yeniden adlandirilmali.
    (b / "audio").mkdir(exist_ok=True)
    (b / "audio" / "Pg 6.MP3").write_bytes(b"f")
    (b / "audio" / "audio.json").write_text(json.dumps({
        "PAGE 8.5.mp3": {"duration": 1.5},
        "Unit 1 +.mp3": {"duration": 2.5},
        "Unit 1.mp3": {"duration": 3.5},
        "Pg 6.MP3": {"duration": 4.5},    # -> Pg_6.mp3, ama o anahtar zaten var: cakisma
        "Pg_6.mp3": {"duration": 5.5},
        "yok.mp3": {"duration": 6.5},     # ses dosyasi hic yok
    }, ensure_ascii=False), encoding="utf-8")
    # 10) PDF: original + answered + original'in BIREBIR kopyasi
    (b / "raw").mkdir()
    icerik = b"%PDF-1.4 original govde" + b"\0" * 500
    (b / "raw" / "original.pdf").write_bytes(icerik)
    (b / "raw" / "HAM KITAP ADI.pdf").write_bytes(icerik)          # birebir kopya
    (b / "raw" / "answered.pdf").write_bytes(b"%PDF-1.4 cevapli" + b"\0" * 400)
    # ANS deseni "Answer" yakalar; bu AYRI bir ek belge, answered.pdf'e eklenmemeli
    (b / "raw" / "Chapter Quiz Answer Key - HAM KITAP.pdf").write_bytes(
        b"%PDF-1.4 quiz cevap anahtari" + b"\0" * 300)
    # 11) bos games.json
    (b / "games.json").write_text("{}")
    # 12) config: bozuk metin + aksansiz (kirik) referans + camelCase olmayan baslik
    conf = {
        "book_title": "The Chase 7 Practice Book",
        "publisher_name": "Universal ELT",
        "book_cover": "./books/HamKitap/images/book_cover_koko.png",
        "language": "en",
        "books": [{
            "sections": [
                {"type": "audio", "audio_path": "./books/HamKitap/audio/Schildkroete.mp3"},
                {"type": "image", "path": "./books/HamKitap/images/Unıt_1/2.PNG"},
                {"type": "image", "path": "./books/HamKitap/images/Addıtıonal_Guıde_For_LGS/1.png"},
                {"type": "asset", "path": "./books/HamKitap/asset/oyun1.png"},
                {"type": "audio", "audio_path": "./books/HamKitap/audio/Unit 1 +.mp3"},
                {"type": "image", "path": "./books/HamKitap/images/Unıt_1/buyuk.png"},
                {"type": "fill", "magnifier": {
                    "section_path": "./books/HamKitap/images/Unıt_1/p6s1.png"}},
                {"type": "not", "aciklama": "eski kirpinti p7s2.png elle eklenmisti"},
                {"type": "image", "path": "./books/HamKitap/images/Review/3.png"},
                {"bozuk": "\x00\x00Gerçek Metin", "yok_olmus": "\x00\x00\x00"},
            ]
        }],
    }
    (b / "config.json").write_text(json.dumps(conf, ensure_ascii=False, indent=4),
                                   encoding="utf-8")
    return b


def main() -> int:
    tmp = Path(tempfile.mkdtemp(prefix="fbtest_"))
    try:
        src = kitap_kur(tmp)
        out = tmp / "paketler"

        print("\n--- check_book (salt okunur) ---")
        c = fn.check_book(src)
        onceki = sorted(p.name for p in src.rglob("*"))
        kontrol("kontrol kaynagi degistirmedi",
                sorted(p.name for p in src.rglob("*")) == onceki)
        kontrol("cop tespit edildi", c["cop"] >= 8, f"cop={c['cop']}")
        kontrol("ad degisikligi tespit edildi", c["ad_degisecek"] >= 5)
        kontrol("kirik referans onarilabilir isaretlendi",
                c["ref_onarilabilir"] >= 1, f"onarilabilir={c['ref_onarilabilir']}")
        kontrol("bozuk metin tespit edildi", c["bozuk_metin"] == 2, f"={c['bozuk_metin']}")
        kontrol("ayni icerikli PDF kopyasi tespit edildi",
                c["pdf_kopya"] == ["HAM KITAP ADI.pdf"], f"={c['pdf_kopya']}")
        kontrol("bos dizinler tespit edildi", set(c["bos_dizin"]) >= {"video"},
                f"={c['bos_dizin']}")
        kontrol("bos games.json tespit edildi", c["games_bos"] is True)
        kontrol("referanssiz kirpintilar tespit edildi", c["referanssiz_gorsel"] == 3,
                f"={c['referanssiz_gorsel']} {c['referanssiz_ornek']}")

        print("\n--- normalize_book ---")
        r = fn.normalize_book(src, out)
        d = Path(r["hedef"])

        kontrol("klasor adi baslikta turetildi",
                d.name == "The_Chase_7_Practice_Book", d.name)
        kontrol("kaynak dizin bozulmadi", (src / "config.json.bak").exists())

        ad = {p.name for p in d.rglob("*")}
        kontrol("cop silindi", not (ad & {".DS_Store", "config.json.bak",
                                          "config.json.bak.safe", "settings.json",
                                          ".pkgcache", "temp"}))
        kontrol("icon_template_* silindi",
                not (ad & {"icon_template_audio.png", "icon_template_video.png"}))
        kontrol("AppleDouble kalmadi", not any(n.startswith("._") for n in ad))

        kontrol("Turkce karakter kalmadi",
                not [p for p in d.rglob("*") if any(ch in p.name for ch in "ıİşŞğĞüÜöÖçÇ")])
        kontrol("noktasiz i duzeltildi", (d / "images" / "Unit_1").is_dir())
        kontrol("LGS kisaltmasi korundu",
                (d / "images" / "Additional_Guide_For_LGS").is_dir(),
                str(sorted(p.name for p in (d / "images").iterdir())))
        kontrol("uzanti kucultuldu", (d / "images" / "Unit_1" / "2.png").exists())
        kontrol("kapak standartlastirildi", (d / "images" / "book_cover.png").exists())

        kontrol("'+' kelimeye cevrildi, iki dosya da korundu",
                (d / "audio" / "Unit_1_plus.mp3").exists()
                and (d / "audio" / "Unit_1.mp3").exists())
        kontrol("bosluklu ses adi duzeltildi", (d / "audio" / "PAGE_8.5.mp3").exists())

        kontrol("asset -> assets", (d / "assets").is_dir() and not (d / "asset").exists())
        kontrol("bos dizinler silindi", not (d / "video").exists() and not (d / "videos").exists())
        kontrol("bos games.json silindi", not (d / "games.json").exists())

        conf = json.loads((d / "config.json").read_text(encoding="utf-8"))
        kontrol("book_title yazildi", conf["book_title"] == "The Chase 7 Practice Book")
        kontrol("book_cover yolu guncellendi",
                conf["book_cover"] == "./books/The_Chase_7_Practice_Book/images/book_cover.png",
                conf["book_cover"])

        kontrol("config'de TR karakterli yol kalmadi",
                "Unıt_1" not in json.dumps(conf, ensure_ascii=False))
        kontrol("aksansiz kirik referans onarildi", r["referans"]["onarilan"] >= 1,
                str(r["referans"]))

        sec = conf["books"][0]["sections"][-1]
        kontrol("null siyrilip gercek metin kurtarildi",
                sec["bozuk"] == "Gerçek Metin", repr(sec.get("bozuk")))
        kontrol("tamamen null alan None yapildi", sec["yok_olmus"] is None,
                repr(sec.get("yok_olmus")))

        kontrol("ayni icerikli PDF BIRLESTIRILMEDI",
                (d / "raw" / "original.pdf").read_bytes()
                == (src / "raw" / "original.pdf").read_bytes())
        kontrol("ek belge answered.pdf'e BIRLESTIRILMEDI",
                (d / "raw" / "answered.pdf").read_bytes()
                == (src / "raw" / "answered.pdf").read_bytes())
        kontrol("ek belge raporlandi",
                r["pdf"].get("ek_belge_birlestirilmedi")
                == ["Chapter_Quiz_Answer_Key_-_HAM_KITAP.pdf"],
                str(r["pdf"].get("ek_belge_birlestirilmedi")))
        kontrol("kopya PDF raporlandi",
                r["pdf"].get("ayni_icerikli_kopya_elendi") == ["HAM_KITAP_ADI.pdf"],
                str(r["pdf"].get("ayni_icerikli_kopya_elendi")))

        try:
            from PIL import Image
            with Image.open(d / "assets" / "oyun1.png") as im:
                kontrol("assets gorseli 500px'e indi", max(im.size) <= 500, str(im.size))
            with Image.open(d / "images" / "Unit_1" / "buyuk.png") as im:
                kontrol("images gorseline DOKUNULMADI", max(im.size) == 1600, str(im.size))
        except ImportError:
            print("  - Pillow yok, gorsel testleri atlandi")

        kontrol("son dogrulama: kirik referans yok",
                r["dogrulama"]["kirik_referans"] == 0, str(r["dogrulama"]))

        rg = r.get("referanssiz_gorsel", {})
        kontrol("referanssiz kirpintilar silindi",
                rg.get("silinen") == 3
                and not (d / "images" / "Unit_1" / "p5s1.png").exists()
                and not (d / "images" / "Unit_1" / "p5_crop_1788338539900.png").exists(),
                str(rg))
        kontrol("bosalan images alt dizini silindi",
                not (d / "images" / "Kirpinti").exists(), str(rg.get("bos_dizin_silindi")))
        kontrol("referansli kirpinti korundu", (d / "images" / "Unit_1" / "p6s1.png").exists())
        kontrol("adi JSON metninde gecen gorsel korundu",
                (d / "images" / "Unit_1" / "p7s2.png").exists())
        kontrol("images disindaki referanssiz dosyaya dokunulmadi",
                (d / "audio" / "yetim.mp3").exists())
        kontrol("kapak ve sayfa gorselleri korundu",
                (d / "images" / "book_cover.png").exists()
                and (d / "images" / "Unit_1" / "2.png").exists())

        kontrol("fbinf ve harf duyarsiz cop silindi (kok, alt dizin, Settings.json)",
                not (d / "fbinf").exists() and not (d / "assets" / "FBINF").exists()
                and not (d / "assets" / "fbinf").exists()
                and not (d / "images" / "Settings.json").exists())
        kontrol("'Review' icerik klasoru korundu", (d / "images" / "Review" / "3.png").exists())
        kontrol("cop adini tasiyan KLASOR (audio/fbinf/) korundu",
                (d / "audio" / "fbinf" / "icerik.mp3").exists())

        aj = json.loads((d / "audio" / "audio.json").read_text(encoding="utf-8"))
        ra = r.get("audio_json", {})
        kontrol("audio.json anahtarlari ses adlariyla ayni fonksiyonla yeniden adlandirildi",
                set(aj) == {"PAGE_8.5.mp3", "Unit_1_plus.mp3", "Unit_1.mp3",
                            "Pg 6.MP3", "Pg_6.mp3", "yok.mp3"}
                and aj["Unit_1_plus.mp3"] == {"duration": 2.5}, str(sorted(aj)))
        kontrol("audio.json cakismada iki kayit da korundu",
                ra.get("cakisma") == ["Pg 6.MP3"] and aj["Pg 6.MP3"] == {"duration": 4.5}
                and aj["Pg_6.mp3"] == {"duration": 5.5}, str(ra))
        kontrol("audio.json kopuk anahtar raporlandi",
                "yok.mp3" in ra.get("kopuk", []), str(ra.get("kopuk")))
        kontrol("audio.json esleme ikinci calistirmada degisiklik yapmaz",
                fn.remap_audio_json(d).get("yeniden_adlandirilan") == 0)

        print("\n--- ayni icerikli original/answered (cevap anahtari olmayan kitap) ---")
        jk = tmp / "JoeyTipi"
        (jk / "raw").mkdir(parents=True)
        (jk / "config.json").write_text(json.dumps(
            {"book_title": "Joey Tipi", "publisher_name": "Universal ELT"}), encoding="utf-8")
        ayni = b"%PDF-1.4 cevap anahtari yok" + b"\0" * 300
        (jk / "raw" / "original.pdf").write_bytes(ayni)
        (jk / "raw" / "answered.pdf").write_bytes(ayni)
        cj = fn.check_book(jk)
        kontrol("check_book kanonik PDF'leri kopya saymadi", cj["pdf_kopya"] == [],
                str(cj["pdf_kopya"]))
        rj = fn.normalize_book(jk, out)
        kontrol("ikisi de kanonik raporlandi, 'kaynak yok' yok",
                rj["pdf"].get("original.pdf") == "kanonik dosya var, dokunulmadi"
                and rj["pdf"].get("answered.pdf") == "kanonik dosya var, dokunulmadi"
                and "ayni_icerikli_kopya_elendi" not in rj["pdf"], str(rj["pdf"]))
        kontrol("ayni icerik bilgisi raporlandi",
                rj["pdf"].get("original_answered_ayni") is True, str(rj["pdf"]))
        jd = Path(rj["hedef"]) / "raw"
        kontrol("iki PDF de yerinde", (jd / "original.pdf").read_bytes() == ayni
                and (jd / "answered.pdf").read_bytes() == ayni)

        print("\n--- hata yollari ---")
        bos = tmp / "Bossuz"
        bos.mkdir()
        (bos / "config.json").write_text('{"book_title": "  "}')
        try:
            fn.normalize_book(bos, out)
            kontrol("bos baslik FlowbookError firlatir", False)
        except fn.FlowbookError:
            kontrol("bos baslik FlowbookError firlatir", True)
        try:
            fn.check_book(tmp / "yok-boyle-dizin")
            kontrol("olmayan dizin FlowbookError firlatir", False)
        except fn.FlowbookError:
            kontrol("olmayan dizin FlowbookError firlatir", True)

    finally:
        shutil.rmtree(tmp, ignore_errors=True)

    print(f"\n{len(GECTI)} geçti, {len(KALDI)} kaldı")
    for k in KALDI:
        print("  KALDI:", k)
    return 1 if KALDI else 0


if __name__ == "__main__":
    raise SystemExit(main())
