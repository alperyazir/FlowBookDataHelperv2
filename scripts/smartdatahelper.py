import os
import json
import shutil
import argparse
import subprocess
import sys
import string

import os

os.environ["PYTHONUNBUFFERED"] = "1"

sys.stdout.reconfigure(line_buffering=True)  # Python 3.7+
from pathlib import Path

try:
    import fitz
except ImportError:
    print("PyMuPDF yükleniyor...", flush=True)
    subprocess.check_call([sys.executable, "-m", "pip", "install", "PyMuPDF"])
    import fitz

# Türkçe karakterler için dönüşüm tablosu
tr_chars = str.maketrans("ıİüÜöÖğĞşŞçÇ", "iIuUoOgGsSçC")


def normalize_filename(filename):
    """
    Dosya adını normalize eder:
    - Türkçe karakterleri İngilizce karşılıklarına çevirir
    - Tüm karakterleri küçük harfe çevirir
    - Boşlukları alt çizgi ile değiştirir
    """
    # Uzantıyı ayır
    name, ext = os.path.splitext(filename)

    # Türkçe karakterleri değiştir
    name = name.translate(tr_chars)

    # Küçük harfe çevir
    name = name.lower()

    # Boşlukları alt çizgi yap
    name = name.replace(" ", "_")

    # Uzantıyı geri ekle
    return name + ext


def save_pdf_as_images(pdf_path, output_dir, dpi=150):
    """PDF sayfalarını PNG formatında kaydeder."""
    print(f"PDF açılıyor: {pdf_path}", flush=True)
    doc = fitz.open(pdf_path)
    zoom = dpi / 72
    mat = fitz.Matrix(zoom, zoom)

    total_pages = len(doc)
    print(f"PDF toplam {total_pages} sayfa içeriyor.", flush=True)
    print(f"PROGRESS:5%", flush=True)  # İşlemin başında %5 ilerleme

    for page_num in range(total_pages):
        # Her sayfa için ilerleme yüzdesi hesapla (5% başlangıç, 70% hedef)
        progress_percentage = 5 + int((page_num / total_pages) * 65)
        print(f"PROGRESS:{progress_percentage}%", flush=True)

        print(f"  Sayfa {page_num+1}/{total_pages} işleniyor...", flush=True)
        page = doc.load_page(page_num)
        pix = page.get_pixmap(matrix=mat)
        output_path = os.path.join(output_dir, f"{page_num+1}.png")
        pix.save(output_path)
        print(f"  Sayfa {page_num+1} kaydedildi: {output_path}", flush=True)

        # Çıktıyı hemen göndermek için stdout'u flush et
        sys.stdout.flush()

    print(f"PROGRESS:70%", flush=True)  # PNG dönüştürme işlemi tamamlandı
    print(f"Tüm sayfalar PNG olarak kaydedildi: {output_dir}", flush=True)
    return total_pages


def process_pdf_with_config(config_file, dpi=150):
    """JSON yapılandırma dosyasına göre PDF işleme."""

    print(f"PROGRESS:0%", flush=True)  # İşlemin başlangıcı
    print(f"Yapılandırma dosyası okunuyor: {config_file}", flush=True)
    # JSON yapılandırma dosyasını oku
    with open(config_file, "r", encoding="utf-8") as f:
        config = json.load(f)

    # Yapılandırma parametrelerini çıkar
    publisher_name = config.get("publisher_name", "")
    book_pdf_path = config.get("book_pdf_path", "")
    book_cover_path = config.get("book_cover_path", "")
    audio_path = config.get("audio_path", "")
    video_path = config.get("video_path", "")
    modules = config.get("modules", [])
    output_path = config.get("output_path", "")
    book_title = config.get("book_title", "")
    language = config.get("language", "en")

    print(f"Yapılandırma parametreleri:", flush=True)
    print(f"  Publisher: {publisher_name}", flush=True)
    print(f"  PDF: {book_pdf_path}", flush=True)
    print(f"  Cover: {book_cover_path}", flush=True)
    print(f"  Audio: {audio_path}", flush=True)
    print(f"  Video: {video_path}", flush=True)
    print(f"  Çıktı: {output_path}", flush=True)
    print(f"  Book Title: {book_title}", flush=True)
    print(f"  Language: {language}", flush=True)
    print(f"  Modül sayısı: {len(modules)}", flush=True)

    # PDF dosya adını çıkart
    pdf_filename = os.path.basename(book_pdf_path)
    pdf_name = os.path.splitext(pdf_filename)[0]
    pdf_name = normalize_filename(pdf_name)

    print(f"İşleniyor: {pdf_filename} -> {pdf_name}", flush=True)

    # 1. Ana klasörü oluştur
    pdf_folder = os.path.join(output_path, pdf_name)
    print(f"Ana klasör oluşturuluyor: {pdf_folder}", flush=True)
    os.makedirs(pdf_folder, exist_ok=True)

    # 2. Alt klasörleri oluştur
    images_folder = os.path.join(pdf_folder, "images")
    audio_folder = os.path.join(pdf_folder, "audio")
    video_folder = os.path.join(pdf_folder, "video")
    raw_folder = os.path.join(pdf_folder, "raw")

    print(f"PROGRESS:2%", flush=True)  # Klasörler oluşturuldu
    print(f"Alt klasörler oluşturuluyor:", flush=True)
    print(f"  images: {images_folder}", flush=True)
    print(f"  audio: {audio_folder}", flush=True)
    print(f"  video: {video_folder}", flush=True)
    print(f"  raw: {raw_folder}", flush=True)

    os.makedirs(images_folder, exist_ok=True)
    os.makedirs(audio_folder, exist_ok=True)
    os.makedirs(video_folder, exist_ok=True)
    os.makedirs(raw_folder, exist_ok=True)

    # 3. PDF'i raw klasörüne kopyala
    if os.path.exists(book_pdf_path):
        print(f"PROGRESS:3%", flush=True)  # PDF kopyalamaya başlandı
        print(f"PDF kopyalanıyor: {book_pdf_path} -> {raw_folder}", flush=True)
        shutil.copy2(book_pdf_path, os.path.join(raw_folder, pdf_filename))
        print(f"PDF kopyalandı.", flush=True)
    else:
        print(f"Hata: {book_pdf_path} bulunamadı!", flush=True)
        return

    # 4. Modül klasörlerini oluştur
    print(f"PROGRESS:4%", flush=True)  # Modül klasörleri oluşturuluyor
    print(f"Modül klasörleri oluşturuluyor:", flush=True)
    for module in modules:
        module_name = module.get("module_name", "")
        # Modül ismindeki boşlukları _ ile değiştir
        module_folder_name = module_name.replace(" ", "_")
        module_folder = os.path.join(images_folder, module_folder_name)
        print(f"  Modül klasörü: {module_folder}", flush=True)
        os.makedirs(module_folder, exist_ok=True)

    # 5. PDF sayfalarını PNG olarak dışa aktar
    temp_images_folder = os.path.join(pdf_folder, "temp_images")
    print(f"Geçici klasör oluşturuluyor: {temp_images_folder}", flush=True)
    os.makedirs(temp_images_folder, exist_ok=True)

    # Önce tüm sayfaları geçici klasöre çıkar
    print(f"PDF sayfaları PNG'ye dönüştürülüyor (DPI: {dpi}, ...", flush=True)
    page_count = save_pdf_as_images(book_pdf_path, temp_images_folder, dpi)
    print(f"Toplam {page_count} sayfa dönüştürüldü.", flush=True)

    # Modül bilgilerine göre sayfaları ilgili klasörlere taşı
    print(f"PROGRESS:72%", flush=True)  # Modüllere kopyalama başlıyor
    print(f"Modüllere göre sayfalar kopyalanıyor:", flush=True)

    # Toplam işlenecek sayfa sayısını hesapla
    total_pages_to_copy = 0
    for module in modules:
        start_page = (
            module.get("start", 1) - 1
        )  # 1'den başlayan sayfa numarasını 0'dan başlayan indekse çevir
        end_page = (
            module.get("end", 1) - 1
        )  # 1'den başlayan sayfa numarasını 0'dan başlayan indekse çevir
        if start_page <= end_page and start_page >= 0 and end_page < page_count:
            total_pages_to_copy += end_page - start_page + 1

    pages_copied_so_far = 0
    for i, module in enumerate(modules, 1):
        module_name = module.get("module_name", "")
        # Modül ismindeki boşlukları _ ile değiştir
        module_folder_name = module_name.replace(" ", "_")
        start_page = (
            module.get("start", 1) - 1
        )  # 1'den başlayan sayfa numarasını 0'dan başlayan indekse çevir
        end_page = (
            module.get("end", 1) - 1
        )  # 1'den başlayan sayfa numarasını 0'dan başlayan indekse çevir

        module_folder = os.path.join(images_folder, module_folder_name)
        print(
            f"Modül {i}/{len(modules)}: '{module_name}' için sayfalar kopyalanıyor (Sayfa {start_page+1}-{end_page+1})...",
            flush=True,
        )

        pages_copied = 0
        # Sayfaları modül klasörüne kopyala, hedef dosya adı olarak orijinal sayfa numarasını kullan
        for page_num in range(start_page, end_page + 1):
            if page_num < 0 or page_num >= page_count:
                print(f"  Uyarı: Sayfa {page_num} mevcut değil, atlanıyor.", flush=True)
                continue

            # Sayfa numarasını 1'den başlat
            source_file = os.path.join(temp_images_folder, f"{page_num+1}.png")
            target_file = os.path.join(module_folder, f"{page_num+1}.png")

            if os.path.exists(source_file):
                print(
                    f"  Kopyalanıyor: {page_num+1}.png -> {module_folder_name}/{page_num+1}.png",
                    flush=True,
                )
                shutil.copy2(source_file, target_file)
                pages_copied += 1
                pages_copied_so_far += 1

                # Her sayfa kopyalandığında ilerleme yüzdesini güncelle (72% - 80%)
                if total_pages_to_copy > 0:
                    progress_percentage = 72 + int(
                        (pages_copied_so_far / total_pages_to_copy) * 8
                    )
                    print(f"PROGRESS:{progress_percentage}%", flush=True)
                    sys.stdout.flush()

        print(
            f"  Modül '{module_name}' için toplam {pages_copied} sayfa kopyalandı.",
            flush=True,
        )

    # Kapak sayfasını kopyala
    print(f"PROGRESS:80%", flush=True)  # Kapak sayfası işlemi
    if os.path.exists(book_cover_path):
        print(
            f"Kapak resmi kopyalanıyor: {book_cover_path} -> {images_folder}/book_cover.png"
        )
        # Kapak resmini book_cover.png olarak kaydet
        shutil.copy2(book_cover_path, os.path.join(images_folder, "book_cover.png"))
        print(f"Kapak resmi kopyalandı.", flush=True)
    else:
        print(f"Uyarı: Kapak resmi belirtilmemiş!", flush=True)

    # Geçici klasörü temizle
    print(f"PROGRESS:82%", flush=True)  # Temizlik işlemi
    print("Geçici dosyalar temizleniyor...", flush=True)
    shutil.rmtree(temp_images_folder)
    print(f"Geçici klasör silindi: {temp_images_folder}", flush=True)

    # 6. Ses ve video dosyalarını kopyala
    print(f"PROGRESS:85%", flush=True)  # Ses dosyaları işlemi
    if os.path.exists(audio_path) and os.path.isdir(audio_path):
        print(f"Ses dosyaları kopyalanıyor: {audio_path} -> {audio_folder}", flush=True)
        audio_files = [
            f
            for f in os.listdir(audio_path)
            if os.path.isfile(os.path.join(audio_path, f))
        ]
        audio_files_count = 0

        for i, audio_file in enumerate(audio_files):
            source_audio = os.path.join(audio_path, audio_file)
            if os.path.isfile(source_audio):
                print(f"  Ses dosyası kopyalanıyor: {audio_file}", flush=True)
                shutil.copy2(source_audio, os.path.join(audio_folder, audio_file))
                audio_files_count += 1

                # Her ses dosyası için ilerleme yüzdesini güncelle (85% - 90%)
                if len(audio_files) > 0:
                    progress_percentage = 85 + int((i + 1) / len(audio_files) * 5)
                    print(f"PROGRESS:{progress_percentage}%", flush=True)
                    sys.stdout.flush()

        print(f"Toplam {audio_files_count} ses dosyası kopyalandı.", flush=True)
    else:
        print(f"Ses dosyaları bulunamadı: {audio_path}", flush=True)

    print(f"PROGRESS:90%", flush=True)  # Video dosyaları işlemi
    if os.path.exists(video_path) and os.path.isdir(video_path):
        print(
            f"Video dosyaları kopyalanıyor: {video_path} -> {video_folder}", flush=True
        )
        video_files = [
            f
            for f in os.listdir(video_path)
            if os.path.isfile(os.path.join(video_path, f))
        ]
        video_files_count = 0

        for i, video_file in enumerate(video_files):
            source_video = os.path.join(video_path, video_file)
            if os.path.isfile(source_video):
                print(f"  Video dosyası kopyalanıyor: {video_file}", flush=True)
                shutil.copy2(source_video, os.path.join(video_folder, video_file))
                video_files_count += 1

                # Her video dosyası için ilerleme yüzdesini güncelle (90% - 95%)
                if len(video_files) > 0:
                    progress_percentage = 90 + int((i + 1) / len(video_files) * 5)
                    print(f"PROGRESS:{progress_percentage}%", flush=True)
                    sys.stdout.flush()

        print(f"Toplam {video_files_count} video dosyası kopyalandı.", flush=True)
    else:
        print(f"Video dosyaları bulunamadı: {video_path}", flush=True)

    # 7. config.json oluştur
    print(f"PROGRESS:95%", flush=True)  # JSON oluşturma işlemi
    print("config.json dosyası oluşturuluyor...", flush=True)
    # Modül sayfalarını yapılandır
    modules_config = []
    for module in modules:
        module_name = module.get("module_name", "")
        # Modül ismindeki boşlukları _ ile değiştir
        module_folder_name = module_name.replace(" ", "_")
        start_page = (
            module.get("start", 1) - 1
        )  # 1'den başlayan sayfa numarasını 0'dan başlayan indekse çevir
        end_page = (
            module.get("end", 1) - 1
        )  # 1'den başlayan sayfa numarasını 0'dan başlayan indekse çevir

        print(
            f"  Modül '{module_name}' için JSON yapılandırması hazırlanıyor...",
            flush=True,
        )

        pages_config = []
        page_idx = 1  # Modül içindeki sıralama için 1'den başlatıyoruz

        for page_num in range(start_page, end_page + 1):
            if page_num < 0 or page_num >= page_count:
                continue

            pages_config.append(
                {
                    "page_number": page_idx,
                    "image_path": f"./books/{pdf_name}/images/{module_folder_name}/{page_num+1}.png",
                    "sections": [],
                }
            )
            page_idx += 1

        print(
            f"  Modül '{module_name}' için {len(pages_config)} sayfa yapılandırıldı.",
            flush=True,
        )

        modules_config.append({"name": module_name, "pages": pages_config})

    config_json = {
        "publisher_name": publisher_name,
        "publisher_logo_path": "./publisher_logo/publisher_logo.png",
        "publisher_full_logo_path": "./rsc/images/publisher_full_logo.png",
        "book_title": book_title if book_title else pdf_name,
        "book_cover": (
            book_cover_path
            if book_cover_path
            else f"./books/{pdf_name}/images/book_cover.png"
        ),
        "language": language,
        "fullscreen": False,
        "books": [{"modules": modules_config}],
    }

    # JSON dosyasını kaydet
    json_path = os.path.join(pdf_folder, "config.json")
    print(f"JSON dosyası kaydediliyor: {json_path}", flush=True)
    with open(json_path, "w", encoding="utf-8") as json_file:
        json.dump(config_json, json_file, indent=2, ensure_ascii=False)

    print(f"config.json dosyası oluşturuldu.", flush=True)
    print(f"PROGRESS:100%", flush=True)  # İşlem tamamlandı
    print(f"İşlem tamamlandı. Çıktı klasörü: {pdf_folder}", flush=True)


def create_sample_config():
    """Örnek bir config.json dosyası oluşturur."""
    print("Örnek yapılandırma dosyası oluşturuluyor...", flush=True)
    print(f"PROGRESS:10%", flush=True)
    config = {
        "publisher_name": "publisher_name",
        "book_pdf_path": "book_pdf_path.pdf",
        "book_cover_path": "book_cover_path.png",
        "audio_path": "audio_path",
        "video_path": "video_path",
        "book_title": "Kitap Başlığı",
        "language": "tr",
        "modules": [
            {"module_name": "Module 1", "start": 0, "end": 9},
            {"module_name": "Module 2", "start": 10, "end": 19},
        ],
        "output_path": "output_path",
    }

    print(f"PROGRESS:50%", flush=True)
    with open("sample_config.json", "w", encoding="utf-8") as json_file:
        json.dump(config, json_file, indent=2, ensure_ascii=False)

    print(f"PROGRESS:100%", flush=True)
    print("Örnek yapılandırma dosyası sample_config.json oluşturuldu.", flush=True)


if __name__ == "__main__":
    print("SmartDataHelper başlatılıyor...", flush=True)
    parser = argparse.ArgumentParser(
        description="PDF işleme ve yapılandırma aracı",
        formatter_class=argparse.RawTextHelpFormatter,
    )

    parser.add_argument("config", nargs="?", help="JSON yapılandırma dosyası")
    parser.add_argument(
        "--create-sample",
        action="store_true",
        help="Örnek bir yapılandırma dosyası oluştur",
    )
    parser.add_argument(
        "--dpi",
        type=int,
        default=150,
        help="PNG dönüşümü için DPI değeri (varsayılan: 150)",
    )

    args = parser.parse_args()
    print(f"Komut satırı argümanları: {args}", flush=True)

    # Stdout buffering'i devre dışı bırak
    (
        sys.stdout.reconfigure(line_buffering=True)
        if hasattr(sys.stdout, "reconfigure")
        else None
    )

    if args.create_sample:
        create_sample_config()
    elif args.config:
        if os.path.exists(args.config):
            process_pdf_with_config(args.config, args.dpi)
        else:
            print(f"Hata: {args.config} bulunamadı!", flush=True)
    else:
        # Varsayılan olarak config.json dosyasını ara
        config_file = "config.json"
        if os.path.exists(config_file):
            process_pdf_with_config(config_file, args.dpi)
        else:
            parser.print_help()
            print("\nÖrnek config.json formatı:", flush=True)
            print(
                """{\n    \"publisher_name\": \"Universal ELT\",\n    \"book_pdf_path\": \"/Users/alperyazir/Dev/qt/FlowBookDataHelper2/test1.pdf\",\n    \"book_cover_path\": \"sad\",\n    \"audio_path\": \"asd\",\n    \"video_path\": \"asd\",\n    \"modules\": [\n        {\n            \"module_name\": \"Module1\",\n            \"start\": 1,\n            \"end\": 10\n        },\n        {\n            \"module_name\": \"Module2\",\n            \"start\": 11,\n            \"end\": 25\n        }\n    ],\n    \"output_path\": \"/Users/alperyazir/Dev/qt/FlowBookDataHelper2/build/Qt_6_5_3_for_macOS-Release/build/release/FlowBookDataHelper2.app/Contents/MacOS/../../../books\"\n}"""
            )
