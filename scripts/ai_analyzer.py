import os
import json
import sys
import subprocess
import argparse
import time
import tempfile

os.environ["PYTHONUNBUFFERED"] = "1"
sys.stdout.reconfigure(line_buffering=True)

try:
    import fitz
except ImportError:
    print("PyMuPDF yukleniyor...", flush=True)
    subprocess.check_call([sys.executable, "-m", "pip", "install", "PyMuPDF"])
    import fitz

try:
    from google import genai
    from google.genai.types import GenerateContentConfig, Part
except ImportError:
    print("google-genai yukleniyor...", flush=True)
    subprocess.check_call([sys.executable, "-m", "pip", "install", "google-genai"])
    from google import genai
    from google.genai.types import GenerateContentConfig, Part


ANALYSIS_PROMPT = """You are an expert at analyzing educational workbook pages. You will receive two images:

1. FIRST IMAGE: The ORIGINAL (blank/unanswered) page of a workbook
2. SECOND IMAGE: The ANSWERED (filled-in) page of the same workbook

Your task is to find ALL differences between the two images — these differences represent the student's answers.

For each difference/answer found, determine:
1. The bounding box coordinates (x, y, w, h) in pixels relative to the image dimensions
2. The text content (if it's a written/typed answer)
3. The activity type:
   - "fill": Text written in blank spaces (fill-in-the-blank)
   - "circle": Answers that are circled
   - "markwithx": Answers marked with X, checkmark, or D/Y (Dogru/Yanlis)

Return a JSON array of sections. Each section represents one activity/exercise area on the page.

For "fill" type sections:
{
    "type": "fill",
    "activity": {
        "circleCount": 0,
        "markCount": 0
    },
    "answer": [
        {
            "coords": {"x": 100, "y": 200, "w": 150, "h": 40},
            "text": "answer text here",
            "is_text_bold": true,
            "opacity": 1
        }
    ],
    "audio_extra": {}
}

For "markwithx" type sections:
{
    "type": "markwithx",
    "activity": {
        "circleCount": 0,
        "markCount": 0,
        "answer": [
            {
                "coords": {"x": 100, "y": 200, "w": 60, "h": 50},
                "isCorrect": true,
                "opacity": 1
            },
            {
                "coords": {"x": 200, "y": 200, "w": 60, "h": 50},
                "opacity": 1
            }
        ]
    },
    "audio_extra": {}
}

For "circle" type sections:
{
    "type": "circle",
    "activity": {
        "circleCount": 1,
        "markCount": 0
    },
    "answer": [
        {
            "coords": {"x": 100, "y": 200, "w": 80, "h": 40},
            "text": "circled text",
            "opacity": 1
        }
    ],
    "audio_extra": {}
}

IMPORTANT RULES:
- Coordinates must be in pixels relative to the original image size
- Group related answers into the same section (e.g., all fill-in-the-blank answers in one exercise)
- If no differences are found, return an empty array: []
- Only return the JSON array, no other text
- Be precise with coordinates — they should tightly bound each answer area
- For markwithx type, mark "isCorrect": true for answers that are marked/checked
"""


def load_settings(settings_path):
    """Load settings.json and return the API key."""
    if not os.path.exists(settings_path):
        print(f"Error: Settings file not found: {settings_path}", flush=True)
        sys.exit(1)

    with open(settings_path, "r", encoding="utf-8") as f:
        settings = json.load(f)

    api_key = settings.get("gemini_api_key", "")
    if not api_key:
        print("Error: gemini_api_key not found in settings.json", flush=True)
        sys.exit(1)

    return api_key


def load_config(config_path):
    """Load config.json and return the config dict."""
    if not os.path.exists(config_path):
        print(f"Error: Config file not found: {config_path}", flush=True)
        sys.exit(1)

    with open(config_path, "r", encoding="utf-8") as f:
        config = json.load(f)

    return config


def find_answered_pdf(config_path):
    """Find the answered PDF in the raw/ folder (non-original PDF)."""
    config_dir = os.path.dirname(os.path.abspath(config_path))
    raw_dir = os.path.join(config_dir, "raw")

    if not os.path.exists(raw_dir):
        print(f"Error: raw/ directory not found: {raw_dir}", flush=True)
        sys.exit(1)

    pdf_files = [f for f in os.listdir(raw_dir) if f.lower().endswith(".pdf")]

    if len(pdf_files) == 0:
        print("Error: No PDF files found in raw/ directory", flush=True)
        sys.exit(1)

    if len(pdf_files) == 1:
        print(f"Only one PDF found, using it as answered PDF: {pdf_files[0]}", flush=True)
        return os.path.join(raw_dir, pdf_files[0])

    # If multiple PDFs, look for one that contains "cevap" or "answer" in name
    for pdf_file in pdf_files:
        lower_name = pdf_file.lower()
        if "cevap" in lower_name or "answer" in lower_name or "key" in lower_name:
            print(f"Found answered PDF: {pdf_file}", flush=True)
            return os.path.join(raw_dir, pdf_file)

    # If no keyword match, pick the second PDF (first is likely original)
    print(f"Using second PDF as answered: {pdf_files[1]}", flush=True)
    return os.path.join(raw_dir, pdf_files[1])


def convert_pdf_to_images(pdf_path, output_dir, dpi=150):
    """Convert PDF pages to JPEG images for AI analysis. Returns page count."""
    print(f"Converting PDF to JPEG images: {pdf_path}", flush=True)
    doc = fitz.open(pdf_path)
    zoom = dpi / 72
    mat = fitz.Matrix(zoom, zoom)
    total_pages = len(doc)

    for page_num in range(total_pages):
        page = doc.load_page(page_num)
        pix = page.get_pixmap(matrix=mat)
        output_path = os.path.join(output_dir, f"{page_num + 1}.jpg")
        pix.save(output_path, "jpeg", 85)

    print(f"Converted {total_pages} pages to JPEG", flush=True)
    doc.close()
    return total_pages


def get_all_pages(config):
    """Extract all pages from config with their module info."""
    pages = []
    books = config.get("books", [])
    if not books:
        return pages

    book = books[0]
    modules = book.get("modules", [])

    for module in modules:
        module_name = module.get("name", "")
        for page in module.get("pages", []):
            pages.append({
                "page_number": page.get("page_number"),
                "image_path": page.get("image_path", ""),
                "module_name": module_name,
                "page_ref": page,
            })

    return pages


def analyze_page(client, original_bytes, answered_bytes):
    """Send original and answered page images to Gemini for analysis."""
    response = client.models.generate_content(
        model="gemini-2.0-flash",
        contents=[
            ANALYSIS_PROMPT,
            Part.from_bytes(data=original_bytes, mime_type="image/jpeg"),
            Part.from_bytes(data=answered_bytes, mime_type="image/jpeg"),
        ],
        config=GenerateContentConfig(
            response_mime_type="application/json",
            temperature=0.2,
        ),
    )

    try:
        result = json.loads(response.text)
        if isinstance(result, list):
            return result
        elif isinstance(result, dict) and "sections" in result:
            return result["sections"]
        else:
            return [result] if result else []
    except (json.JSONDecodeError, TypeError) as e:
        print(f"  Warning: Failed to parse Gemini response: {e}", flush=True)
        print(f"  Raw response: {response.text[:500]}", flush=True)
        return []


def run_analysis(config_path, settings_path, delay=6):
    """Main analysis function."""
    print(f"PROGRESS:0%", flush=True)
    print("AI Analysis starting...", flush=True)

    # 1. Load settings and config
    api_key = load_settings(settings_path)
    config = load_config(config_path)
    config_dir = os.path.dirname(os.path.abspath(config_path))

    print(f"PROGRESS:5%", flush=True)
    print("Config loaded successfully", flush=True)

    # 2. Find answered PDF
    answered_pdf_path = find_answered_pdf(config_path)
    print(f"Answered PDF: {answered_pdf_path}", flush=True)

    # 3. Convert answered PDF to images
    print(f"PROGRESS:10%", flush=True)
    print("Converting answered PDF to images...", flush=True)
    temp_dir = tempfile.mkdtemp(prefix="ai_analyzer_")
    answered_page_count = convert_pdf_to_images(answered_pdf_path, temp_dir)
    print(f"PROGRESS:20%", flush=True)

    # 4. Initialize Gemini client
    client = genai.Client(api_key=api_key)
    print("Gemini client initialized", flush=True)

    # 5. Get all pages from config
    all_pages = get_all_pages(config)
    total_pages = len(all_pages)
    print(f"Total pages to analyze: {total_pages}", flush=True)

    if total_pages == 0:
        print("Error: No pages found in config", flush=True)
        sys.exit(1)

    # 6. Analyze each page
    analyzed_count = 0
    skipped_count = 0

    for i, page_info in enumerate(all_pages):
        page_num = page_info["page_number"]
        image_path = page_info["image_path"]
        module_name = page_info["module_name"]

        # Calculate progress (20% to 95%)
        progress = 20 + int((i / total_pages) * 75)
        print(f"PROGRESS:{progress}%", flush=True)
        print(f"Analyzing page {page_num} ({module_name}) [{i+1}/{total_pages}]...", flush=True)

        # Get original image path (resolve relative to config dir)
        # image_path is like "./books/BookName/images/Module_1/3.png"
        original_image_path = os.path.join(config_dir, os.path.basename(image_path))

        # Try to find the original image by module folder structure
        # Extract module folder and page filename from image_path
        parts = image_path.replace("\\", "/").split("/")
        # Find "images" in path and get everything after it
        try:
            images_idx = parts.index("images")
            relative_from_images = "/".join(parts[images_idx:])
            original_image_path = os.path.join(config_dir, relative_from_images)
        except ValueError:
            original_image_path = os.path.join(config_dir, image_path.lstrip("./"))

        if not os.path.exists(original_image_path):
            print(f"  Warning: Original image not found: {original_image_path}", flush=True)
            skipped_count += 1
            continue

        # Get answered image (JPEG for AI optimization)
        answered_image_path = os.path.join(temp_dir, f"{page_num}.jpg")
        if not os.path.exists(answered_image_path):
            print(f"  Warning: Answered image not found for page {page_num}", flush=True)
            skipped_count += 1
            continue

        # Read both images — convert original PNG to JPEG for AI optimization
        original_pix = fitz.Pixmap(original_image_path)
        original_bytes = original_pix.tobytes("jpeg", 85)
        original_pix = None

        with open(answered_image_path, "rb") as f:
            answered_bytes = f.read()

        # Send to Gemini
        try:
            sections = analyze_page(client, original_bytes, answered_bytes)
        except Exception as e:
            print(f"  Error analyzing page {page_num}: {e}", flush=True)
            skipped_count += 1
            if delay > 0:
                time.sleep(delay)
            continue

        # Update config
        if sections:
            page_info["page_ref"]["sections"] = sections
            analyzed_count += 1
            answer_count = sum(
                len(s.get("answer", s.get("activity", {}).get("answer", [])))
                for s in sections
            )
            print(f"  Found {len(sections)} section(s) with {answer_count} answer(s)", flush=True)
        else:
            print(f"  No differences found on this page", flush=True)

        # Rate limiting delay
        if delay > 0 and i < total_pages - 1:
            print(f"  Waiting {delay}s for rate limit...", flush=True)
            time.sleep(delay)

    # 7. Save updated config
    print(f"PROGRESS:95%", flush=True)
    print(f"Saving updated config.json...", flush=True)

    with open(config_path, "w", encoding="utf-8") as f:
        json.dump(config, f, indent=4, ensure_ascii=False)

    print(f"Config saved: {config_path}", flush=True)

    # 8. Cleanup temp directory
    import shutil
    try:
        shutil.rmtree(temp_dir)
        print("Temp directory cleaned up", flush=True)
    except Exception as e:
        print(f"Warning: Could not clean temp directory: {e}", flush=True)

    print(f"PROGRESS:100%", flush=True)
    print(f"Analysis complete! Analyzed: {analyzed_count}, Skipped: {skipped_count}", flush=True)


if __name__ == "__main__":
    print("AI Analyzer starting...", flush=True)

    parser = argparse.ArgumentParser(description="AI-powered workbook page analyzer")
    parser.add_argument("config", help="Path to config.json")
    parser.add_argument("settings", help="Path to settings.json")
    parser.add_argument(
        "--delay",
        type=int,
        default=6,
        help="Delay between API calls in seconds (default: 6 for free tier, use 0 for paid)",
    )

    args = parser.parse_args()
    print(f"Config: {args.config}", flush=True)
    print(f"Settings: {args.settings}", flush=True)
    print(f"Delay: {args.delay}s", flush=True)

    run_analysis(args.config, args.settings, args.delay)
