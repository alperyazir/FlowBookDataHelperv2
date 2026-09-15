#!/usr/bin/env python3
"""
FlowBook kitap normalizasyonu -- tek dosya, gomulebilir.

Editorun icine gomulmek uzere yazildi. Sabit yol yok, plan dosyasi yok, AI yok,
ag cagrisi yok. Kitap basligi config.json'daki 'book_title' alanindan okunur --
editorde elle dogru girildigi varsayilir.

    from flowbook_normalize import normalize_book, check_book

    rapor = normalize_book("cikti/HamKitap", "paketler/")
    # -> paketler/<Baslik_Klasoru>/ olusur, rapor dict doner

    rapor = check_book("cikti/HamKitap")   # hicbir seye dokunmaz, teshis dondurur

CLI:
    python flowbook_normalize.py <kaynak> [--cikti DIZIN] [--kontrol]
                                [--baslik "..."] [--yayinevi "..."]

Bagimliliklar: Pillow (gorsel kucultme), pypdf (PDF birlestirme).
Ikisi de opsiyoneldir; yoksa o asama atlanir ve raporda belirtilir.

TASARIM ILKESI
--------------
Diskteki adlara uygulanan normalizasyon fonksiyonunun AYNISI config.json ve
games.json icindeki "./books/..." yollarina uygulanir. Boylece disk ile config
arasinda sapma matematiksel olarak imkansiz hale gelir.

ASAMA SIRASI ONEMLIDIR
----------------------
 1 cop temizligi        -- yeniden adlandirmadan ONCE (cop, ad kurallarina takilmasin)
 2 ad normalizasyonu    -- derinden yuzeye (yol gecerliligi bozulmasin)
 3 kapak standardi
 4 config/games yeniden yazimi
 5 kirik referans onarimi
 6 bozuk metin onarimi
 7 gorsel kucultme
 8 PDF yerlestirme
 9 referanssiz gorseller -- config yazimi ve referans onarimindan SONRA; YALNIZCA images/
10 AppleDouble supurgesi -- config yaziminDAN SONRA (macOS her yazmada uretir)
11 bos dizin silme       -- supurgeDEN SONRA (yalnizca ._* iceren dizin ancak o an bos gorunur)
"""

from __future__ import annotations

import hashlib
import json
import os
import re
import shutil
import unicodedata
from pathlib import Path

__all__ = ["normalize_book", "check_book", "title_to_folder", "FlowbookError"]

BOOKS_PREFIX = "./books/"


class FlowbookError(Exception):
    """Kitap islenemedi -- mesaj kullaniciya gosterilebilir."""


# =====================================================================
# macOS + exFAT Unicode guvenli dosya islemleri
# =====================================================================
# Gozlemlenen davranis (macOS 15.7, exFAT/FSKit):
#   * listdir klasor adini NFD dondurur ('Einfu' + U+0308 + 'hrung')
#   * rmdir ayni adi NFC bekler ('Einführung')
#   * shutil.rmtree'nin fd-goreli *at() yolu ASCII disi adlarda hic calismaz
# Bu yuzden her islem as-is / NFC / NFD bicimleriyle sirayla denenir.
# Baska bir dosya sisteminde de zararsizdir: ilk deneme tutar.

def _variants(path) -> list[str]:
    s = str(path)
    out = [s]
    for form in ("NFC", "NFD"):
        v = unicodedata.normalize(form, s)
        if v not in out:
            out.append(v)
    return out


def _try(op, path) -> bool:
    for cand in _variants(path):
        try:
            op(cand)
            return True
        except FileNotFoundError:
            continue
        except OSError:
            break
    return False


def safe_remove(path) -> bool:
    return _try(os.remove, path)


def safe_rmdir(path) -> bool:
    return _try(os.rmdir, path)


def safe_rename(src, dst) -> None:
    last = None
    for cand in _variants(src):
        try:
            os.rename(cand, str(dst))
            return
        except FileNotFoundError as exc:
            last = exc
    raise last if last else FileNotFoundError(str(src))


def safe_rmtree(path) -> None:
    path = Path(path)
    if not path.exists():
        return
    for root, dirs, files in os.walk(path, topdown=False):
        for name in files:
            safe_remove(os.path.join(root, name))
        for name in dirs:
            safe_rmdir(os.path.join(root, name))
    safe_rmdir(path)


def copy_tree_data_only(src, dst) -> None:
    """Yalnizca dosya VERISINI kopyala, meta veriye dokunma.

    shutil.copytree ag surucusunden exFAT'e kopyalarken copystat yuzunden
    'Errno 22 Invalid argument' veriyor ve sonda hata firlatiyor; veri dogru
    kopyalanmis oluyor, sorun yalnizca zaman damgasi/xattr'da. Normalizasyon
    icin meta veri gereksiz oldugundan hic kopyalanmaz.
    """
    src, dst = Path(src), Path(dst)
    dst.mkdir(parents=True, exist_ok=True)
    for kaynak in sorted(src.rglob("*")):
        if kaynak.name.startswith("._"):
            continue
        hedef = dst / kaynak.relative_to(src)
        if kaynak.is_dir():
            hedef.mkdir(parents=True, exist_ok=True)
        elif kaynak.is_file():
            hedef.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(kaynak, hedef)


# =====================================================================
# Ad normalizasyonu
# =====================================================================

TRANSLIT = {
    "ı": "i", "İ": "I", "ş": "s", "Ş": "S", "ğ": "g", "Ğ": "G",
    "ü": "u", "Ü": "U", "ö": "o", "Ö": "O", "ç": "c", "Ç": "C",
    "ä": "ae", "Ä": "Ae", "ß": "ss", "é": "e", "è": "e", "â": "a", "î": "i",
}

# fbinf: editorun sifreli kurulum/kilit dosyasi. Eski surumler onu acik olan
# klasore yaziyordu; yayinlanmis Countdown_3 kitaplarina (kokte) ve
# Elo_In_Der_Schule'ye (assets/ altinda) boyle girdi.
# Adlar HARF DUYARSIZ karsilastirilir: Windows'tan gecen kopyada 'FBINF',
# 'Settings.json' olarak donebiliyor.
JUNK_NAMES = {".DS_Store", "desktop.ini", "Thumbs.db", ".localized", "settings.json", "fbinf"}
_JUNK_NAMES_CF = {n.casefold() for n in JUNK_NAMES}
# 'review' BURAYA EKLENMEMELI: Next_Level_1/2/3'te images/Review gercek icerik klasoru.
JUNK_DIRS = {"__MACOSX", "temp", "tmp", ".pkgcache"}
# *.bak / *.orig / *.old yedekleri
# + icon_template_audio.png, icon_template_video.png: kitabi hazirlayan aracin
#   biraktigi sablon ikonlari. Hicbir config/games bunlara atif yapmaz.
JUNK_RE = re.compile(r"\.bak(\.|$)|\.orig$|\.old$|^icon_template[_.]", re.I)

CLEAN_RE = re.compile(r"^[A-Za-z0-9._-]+$")

# Bu uzunluga kadar tumu-buyuk kelimeler KISALTMA sayilir ve korunur (LGS, CLIL,
# A2, PDF). Daha uzunlar bagiran metin sayilir (ADDITIONAL -> Additional).
# Esik 2 iken 'Addıtıonal_Guıde_For_LGS' -> 'Additional_Guide_For_Lgs' oluyordu.
KISALTMA_MAX = 4


def to_ascii(text: str) -> str:
    out = "".join(TRANSLIT.get(ch, ch) for ch in text)
    out = unicodedata.normalize("NFKD", out)
    return "".join(c for c in out if not unicodedata.combining(c))


def expand_symbols(text: str) -> str:
    """Anlam tasiyan sembolleri kelimeye cevir.

    'Unit 1 +.mp4' ile 'Unit 1.mp4' AYRI dosyalardir; '+' silinseydi ikisi de
    'Unit_1.mp4' olur ve biri kaybolurdu.
    """
    text = re.sub(r"\s*&\s*", " and ", text)
    text = re.sub(r"\s*\+\s*", " plus ", text)
    text = re.sub(r"\s*%\s*", " yuzde ", text)
    return text


def norm_dir(name: str) -> str:
    """Klasor adi: zaten temizse dokunma, degilse ASCII + Title_Case + alt cizgi."""
    if CLEAN_RE.match(name):
        return name
    words = [w for w in re.split(r"[^A-Za-z0-9]+", to_ascii(expand_symbols(name))) if w]

    def duzelt(w: str) -> str:
        if w.isupper() and len(w) <= KISALTMA_MAX:
            return w
        if w.isalpha() or w.isupper():
            return w.capitalize()
        return w

    return "_".join(duzelt(w) for w in words) or "unnamed"


def norm_file(name: str) -> str:
    """Dosya adi: govdeyi ASCII'ye cevir, uzantiyi HER ZAMAN kucult.

    Uzanti kucultme sart: bazi paketlerde dosya '.PNG', config ise '.png'
    diyor; buyuk/kucuk harf duyarli bir dosya sisteminde kitap acilmiyordu.
    """
    stem, dot, ext = name.rpartition(".")
    if not dot:
        stem, ext = name, ""
    ext = ext.lower()
    if CLEAN_RE.match(stem) and (not ext or f"{stem}.{ext}" == name):
        return f"{stem}.{ext}" if ext else stem
    stem = to_ascii(expand_symbols(stem))
    stem = re.sub(r"[^A-Za-z0-9._-]+", "_", stem).strip("_") or "file"
    return f"{stem}.{ext}" if ext else stem


def norm_component(name: str, is_dir: bool) -> str:
    if is_dir:
        return "videos" if name == "video" else norm_dir(name)
    return norm_file(name)


def title_to_folder(title: str) -> str:
    """'The Adventures of Sherlock Holmes' -> 'The_Adventures_Of_Sherlock_Holmes'

    Kesme isareti ayirici degil, harf gibi dusulur ("Student's" -> "Students").
    Her kelimenin bas harfi buyutulur, edatlar dahil: book_title kapaktaki dogal
    yazimi korur, klasor adi ise tek bir kalibi izler. Aksi halde
    '..._of_..._Level_1' ile '..._Of_..._Level_5' ayni serinin iki farkli yazimi
    olur ve tam-eslesme yapan araclar bunlari iki ayri kitap sanar.
    Kelimenin geri kalanina dokunulmaz ('CLIL' -> 'CLIL').
    """
    cleaned = re.sub(r"['’ʼ]", "", to_ascii(title))
    words = [w for w in re.split(r"[^A-Za-z0-9]+", cleaned) if w]
    if not words:
        raise FlowbookError(f"baslik klasor adina cevrilemedi: {title!r}")
    return "_".join(w[0].upper() + w[1:] for w in words)


def is_junk(p: Path) -> bool:
    n = p.name
    # JUNK_NAMES yalnizca DOSYALARA uyar: ayni adli bir klasor (audio/fbinf/) icerigiyle
    # silinmemeli. Ad kurali klasore her derinlikte uyunca 'review' hatasi olmustu.
    return bool((n.casefold() in _JUNK_NAMES_CF and not p.is_dir())
                or n.startswith("._") or JUNK_RE.search(n)
                or (p.is_dir() and n in JUNK_DIRS))


def is_junk_path(p: Path, root: Path) -> bool:
    """p'nin kendisi ya da bir ustu cop mu? (cop dizinin icindekiler de gider)"""
    if is_junk(p):
        return True
    for parent in p.relative_to(root).parents:
        if parent == Path("."):
            continue
        if is_junk(root / parent):
            return True
    return False


# =====================================================================
# Disk islemleri
# =====================================================================

def clean_junk(root: Path) -> dict:
    silinen = []
    for path in sorted(root.rglob("*"), key=lambda p: -len(p.parts)):
        if is_junk(path):
            safe_rmtree(path) if path.is_dir() else safe_remove(path)
            silinen.append(path.relative_to(root).as_posix())
    return {"silinen": len(silinen), "ornek": silinen[:10]}


def rename_tree(root: Path) -> dict:
    """Derinden yuzeye yeniden adlandir. ASLA dosya silmez.

    Iki durum ayrilir:
      * Yalnizca buyuk/kucuk harf farki -- exFAT harf duyarsiz oldugu icin
        target.exists() True doner ama AYNI dosyadir; gecici ad uzerinden
        iki adimli takas yapilir. Tek adimda yapilirsa dosya kaybolur.
      * Gercek cakisma (iki farkli dosya ayni ada normalize oluyor) -- sonek
        verilir ve MUTLAKA raporlanir. Sessizce veri kaybetmek yasak.
    """
    renames, conflicts = [], []
    for path in sorted(root.rglob("*"), key=lambda p: -len(p.parts)):
        new_name = norm_component(path.name, path.is_dir())
        if new_name == path.name:
            continue
        target = path.parent / new_name
        try:
            if target.exists() and path.name.lower() != new_name.lower():
                stem, dot, ext = new_name.rpartition(".")
                if not dot:
                    stem, ext = new_name, ""
                n = 2
                while target.exists():
                    target = path.parent / (f"{stem}_{n}.{ext}" if ext else f"{stem}_{n}")
                    n += 1
                conflicts.append({"kaynak": path.relative_to(root).as_posix(),
                                  "istenen": new_name, "verilen": target.name})
            if target.exists():
                tmp = path.parent / (new_name + ".__casefix__")
                safe_rename(path, tmp)
                safe_rename(tmp, target)
            else:
                safe_rename(path, target)
        except OSError as exc:
            conflicts.append({"kaynak": path.relative_to(root).as_posix(),
                              "hata": str(exc)[:150]})
            continue
        renames.append((path.relative_to(root).as_posix(),
                        target.relative_to(root).as_posix()))
    return {"sayi": len(renames), "cakisma": conflicts,
            "ornek": [f"{a} -> {b}" for a, b in renames[:10]]}


def sweep_appledouble(root: Path) -> int:
    """macOS'un exFAT'e yazarken urettigi '._*' artiklarini sil.

    EN SONDA calismali: config.json cop temizliginden SONRA yazilir ve her
    yazmada yeni bir '._config.json' olusur.
    """
    n = 0
    for p in sorted(root.rglob("._*"), key=lambda q: -len(q.parts)):
        try:
            safe_rmtree(p) if p.is_dir() else p.unlink()
            n += 1
        except OSError:
            pass
    return n


def empty_dirs(root: Path) -> list[str]:
    return [d.name for d in sorted(root.iterdir())
            if d.is_dir() and not d.name.startswith("._")
            and not any(f.is_file() for f in d.rglob("*"))]


def remove_empty_dirs(root: Path) -> list[str]:
    """Bos ust duzey dizinleri sil. sweep_appledouble'DAN SONRA calismali."""
    silinen = []
    for d in sorted(root.iterdir()):
        if not d.is_dir() or d.name.startswith("._"):
            continue
        if not any(f.is_file() for f in d.rglob("*")):
            safe_rmtree(d)
            silinen.append(d.name)
    return silinen


# =====================================================================
# Referanssiz gorseller
# =====================================================================
# Editor her bolum icin kirpinti uretir (p5s1.png, p5_crop_1788338539900.png)
# ve config'ten cikarilan kirpintiyi diskte birakir. Yayinlanmis kitaplarin
# images/ klasorlerinde ~5400 boyle dosya vardi (~1.4 GB), pakete bosuna giriyordu.
#
# YALNIZCA images/ altindaki .png/.jpg/.jpeg dosyalarina bakilir. Oynatici bazi
# dosyalari config'te adi gecmeden, ADLANDIRMA KURALIYLA yukler:
#   * videos/<ad>.srt  -- video_path'in uzantisi .srt yapilarak (FlowBook configparser.cpp)
#   * audio/audio.json -- ses yolunun klasorunden (AudioController.qml)
#   * raw/*.pdf        -- klasor taranarak (pdfcropper.cpp)
# Genel bir "referansi yoksa sil" kurali bunlari da silerdi: korpus taramasinda
# 119 mp3, 6 mp4 ve 4 srt boyle gorunuyordu. images/ DISINA GENISLETME.
#
# Bir gorsel ancak su UCU birden saglanirsa referanssizdir:
#   1 kitaptaki JSON'larda './books/<klasor>/...' yollarindan hicbiri onu gostermiyor
#   2 dosya adi hicbir JSON metin degerinde gecmiyor
#   3 uzantisiz adi hicbir JSON metninde tam kelime olarak gecmiyor
# 2 ve 3 bilincli olarak temkinli: kullanilmayan bir gorseli tutmak, kullanilan
# birini silmekten iyidir. Okunamayan bir JSON varsa referanslar bilinemez ve
# HICBIR sey silinmez.

REF_IMG_EXTS = {".png", ".jpg", ".jpeg"}


def _json_strings(book: Path) -> list[str] | None:
    """Kitaptaki tum JSON dosyalarinin tum metin degerleri. Okunamayan varsa None."""
    out: list[str] = []
    for j in sorted(book.rglob("*.json")):
        if j.name.startswith("._") or not j.is_file():
            continue
        try:
            yig = [json.loads(j.read_text(encoding="utf-8"))]
        except (OSError, ValueError):
            return None
        while yig:
            n = yig.pop()
            if isinstance(n, dict):
                yig.extend(n.values())
            elif isinstance(n, list):
                yig.extend(n)
            elif isinstance(n, str):
                out.append(n)
    return out


def unreferenced_images(book: Path) -> list[Path] | None:
    """images/ altinda hicbir JSON'un gostermedigi gorseller. Diske DOKUNMAZ.

    None: okunamayan bir JSON var, referanslar bilinemiyor.
    """
    book = Path(book)
    images = book / "images"
    if not images.is_dir():
        return []
    metin = _json_strings(book)
    if metin is None:
        return None
    yollar = set()
    for s in metin:
        if s.startswith(BOOKS_PREFIX):
            parts = s[len(BOOKS_PREFIX):].split("/", 1)
            if len(parts) == 2:
                yollar.add(parts[1].casefold())
    blob = "\n".join(metin).casefold()
    out = []
    for f in sorted(images.rglob("*")):
        if (not f.is_file() or f.name.startswith("._")
                or f.suffix.lower() not in REF_IMG_EXTS):
            continue
        if f.relative_to(book).as_posix().casefold() in yollar:
            continue
        ad, kok = f.name.casefold(), f.stem.casefold()
        if ad in blob:
            continue
        if kok in blob and re.search(
                r"(?<![a-z0-9])" + re.escape(kok) + r"(?![a-z0-9])", blob):
            continue
        out.append(f)
    return out


def remove_unreferenced_images(book: Path) -> dict:
    """Referanssiz gorselleri ve bosalan images/ alt dizinlerini sil.

    config/games yazimi ve referans onarimindan SONRA calismali: yollar ancak o
    zaman diskteki son adlari gosterir.
    """
    book = Path(book)
    adaylar = unreferenced_images(book)
    if adaylar is None:
        return {"durum": "okunamayan JSON var, hicbir gorsel silinmedi", "silinen": 0}
    boyut = 0
    for f in adaylar:
        boyut += f.stat().st_size
        safe_remove(f)
    bos = []
    images = book / "images"
    if images.is_dir():
        for d in sorted((p for p in images.rglob("*") if p.is_dir()),
                        key=lambda p: -len(p.parts)):
            if d.exists() and not any(q.is_file() and not q.name.startswith("._")
                                      for q in d.rglob("*")):
                safe_rmtree(d)
                bos.append(d.relative_to(book).as_posix())
    return {"silinen": len(adaylar), "mb": round(boyut / 1048576, 1),
            "ornek": [f.relative_to(book).as_posix() for f in adaylar[:10]],
            "bos_dizin_silindi": bos}


# =====================================================================
# config.json / games.json
# =====================================================================

def remap_path(value: str, new_folder: str) -> str:
    """'./books/Eski/images/TEST 1/2.PNG' -> './books/Yeni/images/Test_1/2.png'"""
    if not value.startswith(BOOKS_PREFIX):
        return value
    parts = [p for p in value[len(BOOKS_PREFIX):].split("/") if p]
    if not parts:
        return value
    out = [new_folder]
    for i, part in enumerate(parts[1:]):
        is_last = i == len(parts) - 2
        out.append(norm_component(part, is_dir=not is_last))
    return BOOKS_PREFIX + "/".join(out)


def walk_json(node, new_folder: str, sayac: dict):
    if isinstance(node, dict):
        return {k: walk_json(v, new_folder, sayac) for k, v in node.items()}
    if isinstance(node, list):
        return [walk_json(v, new_folder, sayac) for v in node]
    if isinstance(node, str) and node.startswith(BOOKS_PREFIX):
        yeni = remap_path(node, new_folder)
        if yeni != node:
            sayac["yol"] += 1
        return yeni
    return node


def iter_book_paths(data):
    yig = [data]
    while yig:
        n = yig.pop()
        if isinstance(n, dict):
            yig.extend(n.values())
        elif isinstance(n, list):
            yig.extend(n)
        elif isinstance(n, str) and n.startswith(BOOKS_PREFIX):
            yield n


def has_games(data) -> bool:
    """games.json gercekten oyun iceriyor mu? Cogunda yalnizca bos '{}' var."""
    if not data:
        return False
    if isinstance(data, dict) and set(data.keys()) == {"levels"}:
        return any(len(l.get("games", [])) for l in data["levels"] if isinstance(l, dict))
    return True


def remap_audio_json(book: Path) -> dict:
    """audio/audio.json anahtarlarini ses dosyalariyla AYNI fonksiyonla yeniden adlandir.

    Oynatici karaoke verisini ses dosyasinin ADIYLA arar (FlowBook
    AudioController.qml). Dosyalar norm_component ile yeniden adlandirilip
    anahtarlar oldugu gibi kalinca karaoke sessizce kopuyordu: yayinlanmis 37
    kitabin 18'inde 402 anahtar. Iki anahtar ayni ada duserse hicbiri silinmez,
    eskisi yerinde kalir ve raporlanir. Idempotent (norm_component iki kez
    uygulaninca ayni sonucu verir): ikinci calistirma hicbir sey yazmaz.
    Editordeki package_book.remap_karaoke ile ayni davranis ve ayni yazim bicimi.
    """
    aj = Path(book) / "audio" / "audio.json"
    if not aj.is_file():
        return {}
    try:
        data = json.loads(aj.read_text(encoding="utf-8"))
    except (OSError, ValueError) as exc:
        return {"hata": f"audio.json okunamadi, dokunulmadi: {exc}"}
    if not isinstance(data, dict):
        return {}
    dosyalar = {f.name for f in aj.parent.rglob("*") if f.is_file()}
    yeni, ornek, cakisma, kopuk = {}, [], [], []
    for key, entry in data.items():
        ad = norm_component(key, is_dir=False)
        if ad != key and (ad in yeni or ad in data):
            ad = key
            cakisma.append(key)
        elif ad != key:
            ornek.append(f"{key} -> {ad}")
        yeni[ad] = entry
        if ad not in dosyalar:
            kopuk.append(ad)
    if ornek:
        aj.write_text(json.dumps(yeni, indent=2, ensure_ascii=False), encoding="utf-8")
    return {"yeniden_adlandirilan": len(ornek), "ornek": ornek[:10],
            "cakisma": cakisma, "kopuk_sayi": len(kopuk), "kopuk": kopuk[:10]}


# --- kirik referans onarimi ------------------------------------------------
# Sorun paketlerde zaten vardi: config'i yazan kisi umlaut/Turkce isaretleri
# dusurmus ("Schildkrote"), dosya sisteminde ise korunmus ("Schildkröte").
# Bu kitaplarda sesler ve gorseller hic calismiyordu.

FOLD = {
    "ı": "i", "İ": "i", "ş": "s", "Ş": "s", "ğ": "g", "Ğ": "g",
    "ü": "u", "Ü": "u", "ö": "o", "Ö": "o", "ç": "c", "Ç": "c",
    "ä": "a", "Ä": "a", "ß": "s", "é": "e", "è": "e", "â": "a", "î": "i",
}


def loose(text: str) -> str:
    """Aksan, buyuk/kucuk harf ve noktalama farklarini yok sayan anahtar."""
    s = "".join(FOLD.get(c, c) for c in text)
    s = unicodedata.normalize("NFKD", s)
    s = "".join(c for c in s if not unicodedata.combining(c)).lower()
    s = re.sub(r"[^a-z0-9]+", "", s)
    for a, b in (("oe", "o"), ("ae", "a"), ("ue", "u")):
        s = s.replace(a, b)
    return s


def build_index(book: Path) -> dict:
    idx = {}
    for f in book.rglob("*"):
        if f.is_file() and not f.name.startswith("._"):
            rel = f.relative_to(book).as_posix()
            idx.setdefault(loose(rel), []).append(rel)
    return idx


def repair_refs(book: Path, folder: str) -> dict:
    """config'deki kirik yollari diskteki gercek dosyalara bagla.

    Eslesme belirsizse (birden fazla aday) DOKUNULMAZ, raporlanir.
    """
    idx = build_index(book)
    stats = {"onarilan": 0, "cozulemeyen": [], "belirsiz": []}

    def fix(value: str) -> str:
        if not value.startswith(BOOKS_PREFIX):
            return value
        parts = value[len(BOOKS_PREFIX):].split("/", 1)
        if len(parts) != 2 or parts[0] != folder:
            return value
        rel = parts[1]
        if (book / rel).exists():
            return value
        cands = idx.get(loose(rel), [])
        if len(cands) == 1:
            stats["onarilan"] += 1
            return f"{BOOKS_PREFIX}{folder}/{cands[0]}"
        (stats["belirsiz"] if cands else stats["cozulemeyen"]).append(rel)
        return value

    def walk(node):
        if isinstance(node, dict):
            return {k: walk(v) for k, v in node.items()}
        if isinstance(node, list):
            return [walk(v) for v in node]
        if isinstance(node, str):
            return fix(node)
        return node

    for name in ("config.json", "games.json"):
        p = book / name
        if not p.exists():
            continue
        data = json.loads(p.read_text(encoding="utf-8"))
        yeni = walk(data)
        if yeni != data:
            p.write_text(json.dumps(yeni, ensure_ascii=False, indent=4), encoding="utf-8")
    return stats


# --- bozuk metin onarimi ---------------------------------------------------
# Dosya adi degil, config DEGERLERINDEKI bozulma: null/kontrol karakterleri,
# Wingdings ozel alani (U+F0xx), CJK/Hangul cop bloklari.

CJK_JUNK = ((0x4E00, 0x9FFF), (0xAC00, 0xD7AF), (0x3040, 0x30FF), (0x2E80, 0x4DBF))
PUA_MAP = {"": "✓", "": "✓"}


def is_corrupt(s: str) -> bool:
    for c in s:
        o = ord(c)
        if o == 0 or (o < 0x20 and c not in "\t\n\r"):
            return True
        if 0xE000 <= o <= 0xF8FF or 0xD800 <= o <= 0xDFFF:
            return True
        if any(a <= o <= b for a, b in CJK_JUNK):
            return True
    return False


def strip_junk(s: str) -> str:
    return "".join(c for c in s if ord(c) >= 0x20 or c in "\t\n\r")


def _walk_corrupt(node, path, out):
    if isinstance(node, dict):
        for k, v in node.items():
            _walk_corrupt(v, f"{path}.{k}", out)
    elif isinstance(node, list):
        for i, v in enumerate(node):
            _walk_corrupt(v, f"{path}[{i}]", out)
    elif isinstance(node, str) and is_corrupt(node):
        out.append((path, node))
    return out


def _container(root, path):
    toks = re.findall(r"\.([A-Za-z_][A-Za-z0-9_]*)|\[(\d+)\]", path)
    cur = root
    for name, idx in toks[:-1]:
        cur = cur[name] if name else cur[int(idx)]
    last = toks[-1]
    return cur, (last[0] if last[0] else int(last[1]))


def repair_config_text(book: Path) -> dict:
    """Bozuk config metinlerini onar.

    Kategoriler:
      kesin        -- temizlenmis deger yazilir
      dokunma      -- korpusta esi olmayan Wingdings; uydurmamak icin birakilir
      kurtarilamaz -- gercek deger yok edilmis; None yazilir ve raporlanir
    """
    ozet = {"kesin": 0, "dokunma": 0, "kurtarilamaz": 0, "detay": []}
    for name in ("config.json", "games.json"):
        j = book / name
        if not j.exists():
            continue
        kok = json.loads(j.read_text(encoding="utf-8"))
        hits = _walk_corrupt(kok, "$", [])
        if not hits:
            continue
        degisti = False
        for yol, deger in hits:
            if any(0xF000 <= ord(c) <= 0xF0FF for c in deger):
                if any(c in PUA_MAP for c in deger):
                    yeni = strip_junk("".join(PUA_MAP.get(c, c) for c in deger))
                    if yeni and not is_corrupt(yeni):
                        kat, val = "kesin", yeni
                    else:
                        kat, val = "dokunma", deger
                else:
                    kat, val = "dokunma", deger
            else:
                temiz = strip_junk(deger)
                if temiz and not is_corrupt(temiz):
                    kat, val = "kesin", temiz
                elif temiz == "":
                    kat, val = "kesin", None
                else:
                    kat, val = "kurtarilamaz", None
            ozet[kat] += 1
            ozet["detay"].append({"dosya": name, "yol": yol,
                                  "eski": repr(deger)[:60], "yeni": val, "karar": kat})
            if kat == "dokunma":
                continue
            par, anahtar = _container(kok, yol)
            par[anahtar] = val
            degisti = True
        if degisti:
            j.write_text(json.dumps(kok, ensure_ascii=False, indent=4), encoding="utf-8")
    ozet["detay"] = ozet["detay"][:20]
    return ozet


# =====================================================================
# Gorseller
# =====================================================================

IMG_EXTS = {".png", ".jpg", ".jpeg"}


def fix_asset_dir(book: Path) -> bool:
    """'asset' klasorunu 'assets' olarak standartlastir (config yollari dahil)."""
    src = book / "asset"
    if not src.is_dir():
        return False
    dst = book / "assets"
    if dst.exists():
        for f in src.iterdir():
            safe_rename(f, dst / f.name)
        src.rmdir()
    else:
        safe_rename(src, dst)
    for name in ("config.json", "games.json"):
        p = book / name
        if not p.exists():
            continue
        text = p.read_text(encoding="utf-8")
        yeni = text.replace(f"/{book.name}/asset/", f"/{book.name}/assets/")
        if yeni != text:
            p.write_text(yeni, encoding="utf-8")
    return True


def shrink_assets(book: Path, max_edge: int = 500) -> dict:
    """assets/ altindaki gorselleri kucult.

    images/ klasorune DOKUNULMAZ -- oradakiler sayfa taramasi, okunabilirlik
    icin yuksek cozunurlukte kalmali. Yalnizca oyun/etkinlik gorselleri kucultulur.
    """
    a = book / "assets"
    if not a.is_dir():
        return {"durum": "assets yok"}
    try:
        from PIL import Image
    except ImportError:
        return {"durum": "Pillow kurulu degil, atlandi"}
    once = sonra = 0
    degisen = atlanan = 0
    hatalar = []
    for f in sorted(a.rglob("*")):
        if not f.is_file() or f.name.startswith("._") or f.suffix.lower() not in IMG_EXTS:
            continue
        boy = f.stat().st_size
        once += boy
        try:
            with Image.open(f) as im:
                w, h = im.size
                if max(w, h) <= max_edge:
                    sonra += boy
                    atlanan += 1
                    continue
                olcek = max_edge / max(w, h)
                yeni = im.resize((max(1, round(w * olcek)), max(1, round(h * olcek))),
                                 Image.LANCZOS)
                params = {"optimize": True}
                if f.suffix.lower() in (".jpg", ".jpeg"):
                    params["quality"] = 88
                    if yeni.mode in ("RGBA", "P"):
                        yeni = yeni.convert("RGB")
                yeni.save(f, **params)
            sonra += f.stat().st_size
            degisen += 1
        except Exception as exc:
            sonra += boy
            hatalar.append(f"{f.name}: {str(exc)[:80]}")
    return {"degisen": degisen, "atlanan": atlanan, "hata": hatalar[:5],
            "once_mb": round(once / 1048576, 1), "sonra_mb": round(sonra / 1048576, 1)}


def standardize_cover(book: Path) -> str | None:
    """Kapagi images/book_cover.<ext> adina getir.

    Bazi kitaplarda 'book_cover_koko.png', 'book_cover.jpg' gibi adlar var.
    """
    images = book / "images"
    if not images.is_dir():
        return None
    cands = sorted(f for f in images.iterdir()
                   if f.is_file() and "cover" in f.name.lower()
                   and not f.name.startswith("._"))
    if not cands:
        return None
    tercih = [f for f in cands if f.name.lower().startswith("book_cover")] or cands
    src = tercih[0]
    # Kapak HER ZAMAN 'book_cover.png' adini alir -- gercek formati JPEG olsa
    # bile. Tuketici tarafta kapak adi bos kaldiginda 'book_cover.png' aranir;
    # '.jpg' adli kapak bulunamaz. Ad/format uyusmazligi sorun degil.
    hedef = images / "book_cover.png"
    if src != hedef:
        if hedef.exists():
            hedef.unlink()
        src.rename(hedef)
    return "images/book_cover.png"


# =====================================================================
# PDF
# =====================================================================

# "cevap anahtari" Turkce kalibi ayri yazilmali: eski desen "cevapl" ariyordu ve
# "FIVE-STARS-2-Quizes-cevap-anahtari.pdf" hicbir kola takilmiyordu (cvp\b de
# "cevap"i tutmaz). O kitapta answered.pdf hic uretilmiyordu.
ANS_RE = re.compile(r"cevapl|cevapli|cvpl|cvp\b|cevap[\s_.\-]*anahtar|answer|cozum|çözüm", re.I)
NEG_RE = re.compile(r"cevaps[ıi]z|unanswered", re.I)
COVER_RE = re.compile(r"kapak|cover|önkapak|onkapak", re.I)
TEMP_RE = re.compile(r"^~+\$")
KANON_PDF = {"original.pdf", "answered.pdf"}


def natkey(p: Path):
    """'10. Bolum' > '2. Bolum' olsun diye sayilari sayi olarak sirala."""
    return [int(x) if x.isdigit() else x for x in re.split(r"(\d+)", p.name.lower())]


def _digest(f: Path, blok: int = 1 << 20) -> str:
    h = hashlib.md5()
    with f.open("rb") as fh:
        for parca in iter(lambda: fh.read(blok), b""):
            h.update(parca)
    return h.hexdigest()


def dedupe_pdfs(dosyalar: list[Path]):
    """Ayni icerikli PDF'leri ele; kanonik adi olani tut.

    Bazi paketlerde raw/ icinde 'original.pdf' ile BAYT BAYT ayni bir ucuncu
    kopya bulunur ('THE CHASE 7 PRACTICE BOOK.pdf'). Tekillestirme olmadan
    ikisi de 'duz' sayilip BIRLESTIRILIR ve original.pdf iki kat uzun cikar.
    Once boyuta gore gruplanir, yalnizca ayni boyuttakiler hashlenir.
    Kopya dosya SILINMEZ, sadece birlestirmeye alinmaz.
    """
    boyut = {}
    for f in dosyalar:
        boyut.setdefault(f.stat().st_size, []).append(f)
    tut, elenen = [], []
    for grup in boyut.values():
        if len(grup) == 1:
            tut.append(grup[0])
            continue
        esit = {}
        for f in grup:
            esit.setdefault(_digest(f), []).append(f)
        for ayni in esit.values():
            # Kanonik adlilarin HEPSI tutulur. original.pdf ile answered.pdf bayt
            # bayt ayni olabilir (cevap anahtari olmayan Joey Kanga kitaplari);
            # yalnizca birini tutmak digerini "kaynak yok" diye raporlatiyordu.
            kanon = [f for f in ayni if f.name in KANON_PDF]
            tercih = kanon or [ayni[0]]
            tut.extend(tercih)
            elenen += [f.name for f in ayni if f not in tercih]
    return sorted(tut, key=natkey), elenen


def write_pdf(kaynaklar: list[Path], hedef: Path) -> dict:
    if len(kaynaklar) == 1:
        hedef.write_bytes(kaynaklar[0].read_bytes())
        return {"dosya": hedef.name, "kaynak": [kaynaklar[0].name]}
    try:
        from pypdf import PdfWriter
    except ImportError:
        return {"durum": "pypdf kurulu degil, birlestirme atlandi",
                "kaynak": [k.name for k in kaynaklar]}
    w = PdfWriter()
    for s in kaynaklar:
        w.append(str(s))
    with hedef.open("wb") as fh:
        w.write(fh)
    w.close()
    return {"dosya": hedef.name, "birlestirildi": [s.name for s in kaynaklar]}


def place_pdfs(book: Path) -> dict:
    """raw/ icinden original.pdf + answered.pdf uret."""
    raw = book / "raw"
    if not raw.is_dir():
        return {"durum": "raw klasoru yok"}
    # Uzanti BUYUK harfli olabilir. glob("*.pdf") harf duyarlidir ve
    # "...practice test CEVAPLI.PDF" dosyasini hic gormuyordu: --kontrol
    # "PDF eksik" diyordu, --uygula ise ad normalizasyonu uzantiyi kucultmus
    # oldugu icin buluyordu. Tahmin ile sonuc ayrisiyordu.
    hepsi = [f for f in sorted(raw.iterdir(), key=natkey)
             if f.is_file() and f.suffix.lower() == ".pdf"
             and not f.name.startswith("._")
             and not TEMP_RE.match(f.name)
             and not COVER_RE.search(f.stem)]
    if not hepsi:
        return {"durum": "PDF yok"}
    hepsi, kopya = dedupe_pdfs(hepsi)
    cevapli = [f for f in hepsi if ANS_RE.search(f.name) and not NEG_RE.search(f.name)]
    duz = [f for f in hepsi if f not in cevapli]
    out, ek = {}, []
    for ad, kaynaklar in (("original.pdf", duz), ("answered.pdf", cevapli)):
        hedef = raw / ad
        if not kaynaklar:
            out[ad] = "kaynak yok"
        elif hedef in kaynaklar:
            # KANONIK DOSYA YETKILIDIR: 'answered.pdf' zaten varsa uzerine baska
            # bir sey BIRLESTIRILMEZ. Klasik hikaye kitaplarinda 'Chapter Quiz
            # Answer Key - JANE EYRE.pdf' gibi AYRI bir ek belge bulunuyor; ANS
            # deseni "Answer" kelimesini yakaladigi icin bu da cevapli grubuna
            # dusuyor ve dogru answered.pdf'in arkasina ekleniyordu.
            ek += [f.name for f in kaynaklar if f != hedef]
            out[ad] = "kanonik dosya var, dokunulmadi"
        else:
            out[ad] = write_pdf(kaynaklar, hedef)
    if kopya:
        out["ayni_icerikli_kopya_elendi"] = kopya
    if ek:
        out["ek_belge_birlestirilmedi"] = ek
    # Cevap anahtari olmayan kitaplarda ikisi bayt bayt ayni; bilgi olarak raporla.
    o, a = raw / "original.pdf", raw / "answered.pdf"
    if (o.is_file() and a.is_file() and o.stat().st_size == a.stat().st_size
            and _digest(o) == _digest(a)):
        out["original_answered_ayni"] = True
    return out


# =====================================================================
# Genel akis
# =====================================================================

def _read_config(book: Path) -> dict:
    cfg = book / "config.json"
    if not cfg.exists():
        raise FlowbookError(f"config.json yok: {book}")
    try:
        return json.loads(cfg.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        raise FlowbookError(f"config.json gecerli JSON degil: {exc}") from exc


def check_book(src: Path | str) -> dict:
    """Salt-okunur teshis. HICBIR dosyaya dokunmaz."""
    src = Path(src)
    if not src.is_dir():
        raise FlowbookError(f"kaynak dizin yok: {src}")
    conf = _read_config(src)
    baslik = (conf.get("book_title") or "").strip()

    r: dict = {"kaynak": src.name, "book_title": conf.get("book_title"),
               "publisher_name": conf.get("publisher_name")}
    r["baslik_sorunu"] = _title_problems(baslik, conf.get("publisher_name"))
    r["klasor"] = title_to_folder(baslik) if baslik else None

    cop = [p.relative_to(src).as_posix() for p in src.rglob("*") if is_junk(p)]
    r["cop"] = len(cop)
    r["cop_ornek"] = sorted({c.split("/")[0] for c in cop})[:10]

    ren = [(p.relative_to(src).as_posix(), norm_component(p.name, p.is_dir()))
           for p in src.rglob("*") if not is_junk_path(p, src)]
    ren = [(a, b) for a, b in ren if a.split("/")[-1] != b]
    r["ad_degisecek"] = len(ren)
    r["ad_ornek"] = [f"{a} -> {b}" for a, b in ren[:10]]

    idx = build_index(src)
    toplam = kayip = onarilabilir = 0
    kayip_ornek = []
    for name in ("config.json", "games.json"):
        f = src / name
        if not f.exists():
            continue
        try:
            data = json.loads(f.read_text(encoding="utf-8"))
        except json.JSONDecodeError as exc:
            r.setdefault("json_hata", []).append(f"{name}: {exc}")
            continue
        for yol in iter_book_paths(data):
            toplam += 1
            parts = yol[len(BOOKS_PREFIX):].split("/", 1)
            if len(parts) != 2:
                continue
            rel = parts[1]
            if (src / rel).exists():
                continue
            if len(idx.get(loose(rel), [])) == 1:
                onarilabilir += 1
            else:
                kayip += 1
                if len(kayip_ornek) < 10:
                    kayip_ornek.append(rel)
    r["ref"] = toplam
    r["ref_onarilabilir"] = onarilabilir
    r["ref_kayip"] = kayip
    r["ref_kayip_ornek"] = kayip_ornek

    bozuk = []
    for name in ("config.json", "games.json"):
        f = src / name
        if f.exists():
            try:
                bozuk += _walk_corrupt(json.loads(f.read_text(encoding="utf-8")), "$", [])
            except json.JSONDecodeError:
                pass
    r["bozuk_metin"] = len(bozuk)
    r["bozuk_ornek"] = [f"{y}: {v!r}"[:100] for y, v in bozuk[:5]]

    r["bos_dizin"] = empty_dirs(src)
    r["asset_dizin"] = ("asset" if (src / "asset").is_dir()
                        else "assets" if (src / "assets").is_dir() else None)
    r["kapak"] = _peek_cover(src)

    raw = src / "raw"
    if raw.is_dir():
        pdfler = [f for f in raw.glob("*.pdf") if not f.name.startswith("._")]
        r["pdf"] = sorted(f.name for f in pdfler)
        _, r["pdf_kopya"] = dedupe_pdfs(pdfler) if pdfler else ([], [])
    else:
        r["pdf"] = []
        r["pdf_kopya"] = []

    aday = unreferenced_images(src)
    r["referanssiz_gorsel"] = None if aday is None else len(aday)
    r["referanssiz_ornek"] = [f.relative_to(src).as_posix() for f in (aday or [])[:10]]

    g = src / "games.json"
    if g.exists():
        try:
            r["games_bos"] = not has_games(json.loads(g.read_text(encoding="utf-8")))
        except json.JSONDecodeError:
            r["games_bos"] = None
    return r


def _peek_cover(src: Path):
    images = src / "images"
    if not images.is_dir():
        return None
    c = [f.name for f in sorted(images.iterdir())
         if f.is_file() and "cover" in f.name.lower() and not f.name.startswith("._")]
    return c[0] if c else None


def _title_problems(baslik: str, yayinevi) -> list[str]:
    """Elle girilen baslikta gozle gorulur sorunlar (editorde uyari gostermek icin)."""
    p = []
    if not baslik:
        p.append("book_title bos")
        return p
    if baslik != baslik.strip():
        p.append("bastan/sondan bosluk var")
    if yayinevi and baslik.strip() == str(yayinevi).strip():
        p.append("book_title yayinevi adiyla ayni -- yanlislikla yapistirilmis olabilir")
    if re.fullmatch(r"[A-Za-z0-9]+", baslik) and re.search(r"[a-z][A-Z]|[A-Za-z]\d", baslik):
        p.append("bosluk yok, camelCase gorunuyor -- okunakli baslik bekleniyor")
    if baslik.isupper() and len(baslik) > 4:
        p.append("tamami buyuk harf")
    return p


def normalize_book(src: Path | str, out_root: Path | str, *,
                   title: str | None = None,
                   publisher: str | None = None,
                   shrink_max_edge: int = 500,
                   remove_empty: bool = True,
                   remove_unreferenced: bool = True,
                   overwrite: bool = True) -> dict:
    """Bir kitabi normalize edip out_root/<Baslik_Klasoru>/ altina yaz.

    title / publisher verilmezse config.json'dan okunur (editorde elle dogru
    girildigi varsayilir). KAYNAGA DOKUNULMAZ -- once kopyalanir.

    Doner: asama asama rapor. Hicbir asama sessizce basarisiz olmaz.
    Raises: FlowbookError
    """
    src, out_root = Path(src), Path(out_root)
    if not src.is_dir():
        raise FlowbookError(f"kaynak dizin yok: {src}")
    conf = _read_config(src)

    baslik = (title if title is not None else conf.get("book_title") or "").strip()
    if not baslik:
        raise FlowbookError(
            f"{src.name}: baslik yok. config.json'da 'book_title' dolu olmali "
            f"ya da title argumani verilmeli.")
    yayinevi = (publisher if publisher is not None
                else conf.get("publisher_name") or "").strip()

    folder = title_to_folder(baslik)
    rapor: dict = {"kaynak": str(src), "book_title": baslik,
                   "publisher_name": yayinevi, "klasor": folder,
                   "baslik_uyari": _title_problems(baslik, yayinevi)}

    dest = out_root / folder
    if dest.exists():
        if not overwrite:
            raise FlowbookError(f"hedef zaten var: {dest}")
        safe_rmtree(dest)
    copy_tree_data_only(src, dest)

    rapor["cop"] = clean_junk(dest)
    rapor["ad"] = rename_tree(dest)

    kapak = standardize_cover(dest)
    rapor["kapak"] = kapak

    sayac = {"yol": 0}
    for name in ("config.json", "games.json"):
        cfg = dest / name
        if not cfg.exists():
            continue
        data = json.loads(cfg.read_text(encoding="utf-8"))
        data = walk_json(data, folder, sayac)
        if name == "config.json":
            data["book_title"] = baslik
            if yayinevi:
                data["publisher_name"] = yayinevi
            if kapak:
                data["book_cover"] = f"{BOOKS_PREFIX}{folder}/{kapak}"
        elif not has_games(data):
            # Icinde hic oyun yoksa games.json hic yazilmaz.
            safe_remove(cfg)
            rapor["games_bos_silindi"] = True
            continue
        cfg.write_text(json.dumps(data, ensure_ascii=False, indent=4), encoding="utf-8")
    rapor["yol_yeniden_yazildi"] = sayac["yol"]
    # ses dosyalari yeniden adlandirildi; karaoke anahtarlari da ayni fonksiyonla
    rapor["audio_json"] = remap_audio_json(dest)

    rapor["referans"] = repair_refs(dest, folder)
    rapor["bozuk_metin"] = repair_config_text(dest)

    asset_yeniden = fix_asset_dir(dest)
    rapor["gorsel"] = {"asset_dizini_yeniden_adlandirildi": asset_yeniden,
                       **shrink_assets(dest, shrink_max_edge)}

    rapor["pdf"] = place_pdfs(dest)

    # config/games yazimi ve referans onarimindan SONRA: yollar son adlari gosterir.
    # Yanlislikla referansli bir gorsel silinirse asagidaki dogrulama yakalar.
    if remove_unreferenced:
        rapor["referanssiz_gorsel"] = remove_unreferenced_images(dest)

    rapor["appledouble_silindi"] = sweep_appledouble(dest)
    rapor["bos_dizin"] = (remove_empty_dirs(dest) if remove_empty else empty_dirs(dest))

    # --- son dogrulama: config'deki her yol diskte var mi
    kalan = []
    for name in ("config.json", "games.json"):
        cfg = dest / name
        if not cfg.exists():
            continue
        for yol in iter_book_paths(json.loads(cfg.read_text(encoding="utf-8"))):
            parts = yol[len(BOOKS_PREFIX):].split("/", 1)
            if len(parts) != 2 or parts[0] != folder or not (dest / parts[1]).exists():
                kalan.append(yol)
    rapor["dogrulama"] = {"kirik_referans": len(kalan), "ornek": kalan[:10]}
    rapor["hedef"] = str(dest)
    rapor["mb"] = round(sum(f.stat().st_size for f in dest.rglob("*") if f.is_file())
                        / 1048576, 1)
    return rapor


# =====================================================================
# CLI
# =====================================================================

def main(argv=None) -> int:
    import argparse
    ap = argparse.ArgumentParser(
        description="FlowBook kitap normalizasyonu (tek dosya, AI yok).")
    ap.add_argument("kaynak", type=Path, help="ham kitap dizini")
    ap.add_argument("--cikti", type=Path, help="hedef kok dizin (--kontrol disinda zorunlu)")
    ap.add_argument("--kontrol", action="store_true", help="hicbir seye dokunma, teshis bas")
    ap.add_argument("--baslik", help="config.json'daki book_title'i ez")
    ap.add_argument("--yayinevi", help="config.json'daki publisher_name'i ez")
    ap.add_argument("--max-kenar", type=int, default=500, help="assets gorsel uzun kenari")
    ap.add_argument("--bos-dizin-birak", action="store_true", help="bos dizinleri silme")
    ap.add_argument("--referanssiz-birak", action="store_true",
                    help="images/ altindaki referanssiz gorselleri silme")
    ap.add_argument("--json", action="store_true", help="raporu JSON olarak bas")
    a = ap.parse_args(argv)

    try:
        if a.kontrol:
            rapor = check_book(a.kaynak)
        else:
            if not a.cikti:
                ap.error("--cikti zorunlu (ya da --kontrol kullan)")
            rapor = normalize_book(a.kaynak, a.cikti, title=a.baslik,
                                   publisher=a.yayinevi,
                                   shrink_max_edge=a.max_kenar,
                                   remove_empty=not a.bos_dizin_birak,
                                   remove_unreferenced=not a.referanssiz_birak)
    except FlowbookError as exc:
        print(f"HATA: {exc}")
        return 2

    if a.json:
        print(json.dumps(rapor, ensure_ascii=False, indent=1))
    else:
        for k, v in rapor.items():
            print(f"{k:>24}: {v}")
    kirik = rapor.get("dogrulama", {}).get("kirik_referans", rapor.get("ref_kayip", 0))
    return 1 if kirik else 0


if __name__ == "__main__":
    raise SystemExit(main())
