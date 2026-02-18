import os
import json
import sys
import re
import argparse
from PIL import Image

os.environ["PYTHONUNBUFFERED"] = "1"
sys.stdout.reconfigure(line_buffering=True)

try:
    import fitz
except ImportError:
    import subprocess
    print("PyMuPDF yukleniyor...", flush=True)
    subprocess.check_call([sys.executable, "-m", "pip", "install", "PyMuPDF"])
    import fitz


# ---------------------------------------------------------------------------
# Normalize helpers — matches config.json format
# ---------------------------------------------------------------------------

def normalize_section(raw_section):
    """Convert raw detection result into the config.json section format."""
    section_type = raw_section.get("type", "fill")
    answers = raw_section.get("answers", [])

    if section_type == "fill":
        normalized_answers = []
        for ans in answers:
            normalized_answers.append({
                "coords": ans.get("coords", {"x": 0, "y": 0, "w": 0, "h": 0}),
                "text": ans.get("text", ""),
                "is_text_bold": True,
                "opacity": 1,
            })
        return {
            "type": "fill",
            "activity": {"circleCount": 0, "markCount": 0},
            "answer": normalized_answers,
            "audio_extra": {},
        }

    elif section_type in ("markwithx", "circle"):
        normalized_answers = []
        for ans in answers:
            entry = {
                "coords": ans.get("coords", {"x": 0, "y": 0, "w": 0, "h": 0}),
                "opacity": 1,
            }
            if ans.get("isCorrect"):
                entry["isCorrect"] = True
            normalized_answers.append(entry)

        circle_count = len(normalized_answers) if section_type == "circle" else 0
        mark_count = len(normalized_answers) if section_type == "markwithx" else 0

        return {
            "activity": {
                "type": section_type,
                "answer": normalized_answers,
                "circleCount": circle_count,
                "markCount": mark_count,
                "coords": raw_section.get("header_coords", {"x": 0, "y": 0, "w": 0, "h": 0}),
                "headerText": "",
                "section_path": raw_section.get("section_path", ""),
            },
            "audio_extra": {},
        }

    else:
        return normalize_section({"type": "fill", "answers": answers})


def normalize_sections(raw_sections):
    return [normalize_section(s) for s in raw_sections if s]


# ---------------------------------------------------------------------------
# Config / settings helpers
# ---------------------------------------------------------------------------

def load_settings(settings_path):
    if not os.path.exists(settings_path):
        print(f"Error: Settings file not found: {settings_path}", flush=True)
        sys.exit(1)
    with open(settings_path, "r", encoding="utf-8") as f:
        settings = json.load(f)
    answer_color = settings.get("answer_color", "")
    if not answer_color:
        print("Error: answer_color not found in settings.json", flush=True)
        sys.exit(1)
    return answer_color


def load_config(config_path):
    if not os.path.exists(config_path):
        print(f"Error: Config file not found: {config_path}", flush=True)
        sys.exit(1)
    with open(config_path, "r", encoding="utf-8") as f:
        return json.load(f)


def find_answered_pdf(config_path):
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
    for pdf_file in pdf_files:
        lower_name = pdf_file.lower()
        if "cevap" in lower_name or "answer" in lower_name or "key" in lower_name:
            print(f"Found answered PDF: {pdf_file}", flush=True)
            return os.path.join(raw_dir, pdf_file)
    print(f"Using second PDF as answered: {pdf_files[1]}", flush=True)
    return os.path.join(raw_dir, pdf_files[1])


def find_original_pdf(config_path):
    """Find the original (unanswered) PDF in raw/ directory. Returns path or None."""
    config_dir = os.path.dirname(os.path.abspath(config_path))
    raw_dir = os.path.join(config_dir, "raw")
    if not os.path.exists(raw_dir):
        return None
    pdf_files = [f for f in os.listdir(raw_dir) if f.lower().endswith(".pdf")]
    for pdf_file in pdf_files:
        lower_name = pdf_file.lower()
        if "original" in lower_name or "soru" in lower_name:
            return os.path.join(raw_dir, pdf_file)
    # If there are 2+ PDFs, the first one (not answered) is likely original
    if len(pdf_files) >= 2:
        answered_keywords = ("cevap", "answer", "key")
        for pdf_file in pdf_files:
            if not any(kw in pdf_file.lower() for kw in answered_keywords):
                return os.path.join(raw_dir, pdf_file)
    return None


def get_all_pages(config):
    pages = []
    books = config.get("books", [])
    if not books:
        return pages
    book = books[0]
    for module in book.get("modules", []):
        module_name = module.get("name", "")
        for page in module.get("pages", []):
            pages.append({
                "page_number": page.get("page_number"),
                "image_path": page.get("image_path", ""),
                "module_name": module_name,
                "page_ref": page,
            })
    return pages


# ---------------------------------------------------------------------------
# PDF text extraction with color filtering
# ---------------------------------------------------------------------------

def parse_hex_color(hex_color):
    """Parse '#2b9849' → (0x2b, 0x98, 0x49) → fitz integer color."""
    hex_color = hex_color.lstrip("#")
    r = int(hex_color[0:2], 16)
    g = int(hex_color[2:4], 16)
    b = int(hex_color[4:6], 16)
    return r, g, b


def fitz_color_to_rgb(color_int):
    """Convert PyMuPDF's integer color to (r, g, b) tuple.
    PyMuPDF stores color as an integer: 0xRRGGBB."""
    r = (color_int >> 16) & 0xFF
    g = (color_int >> 8) & 0xFF
    b = color_int & 0xFF
    return r, g, b


def color_distance(c1, c2):
    """Simple Euclidean distance between two RGB tuples."""
    return ((c1[0]-c2[0])**2 + (c1[1]-c2[1])**2 + (c1[2]-c2[2])**2) ** 0.5


def extract_answer_spans(page, answer_rgb, tolerance=60):
    """Extract text spans from a PDF page that match the answer color.
    Returns list of dicts with 'text' and 'bbox' (in PDF coordinates)."""
    text_dict = page.get_text("dict", flags=fitz.TEXT_PRESERVE_WHITESPACE)
    matching_spans = []

    for block in text_dict.get("blocks", []):
        if block.get("type") != 0:  # text block only
            continue
        for line in block.get("lines", []):
            for span in line.get("spans", []):
                span_color_int = span.get("color", 0)
                span_rgb = fitz_color_to_rgb(span_color_int)
                dist = color_distance(span_rgb, answer_rgb)
                if dist <= tolerance:
                    text = span.get("text", "").strip()
                    if text:
                        bbox = span.get("bbox", (0, 0, 0, 0))
                        matching_spans.append({
                            "text": text,
                            "bbox": bbox,  # (x0, y0, x1, y1) in PDF points
                            "color": span_rgb,
                        })

    return matching_spans


def merge_nearby_spans(spans, y_threshold=5, x_gap_factor=1.5):
    """Merge spans that are on the same line (close y) and horizontally close.
    Spans with large horizontal gaps stay separate (e.g. crossword letters).
    x_gap_factor: max gap as multiple of average span height before splitting."""
    if not spans:
        return []

    # Sort by y position first, then x
    sorted_spans = sorted(spans, key=lambda s: (s["bbox"][1], s["bbox"][0]))

    # Group by vertical proximity (same line)
    line_groups = []
    current_line = [sorted_spans[0]]

    for span in sorted_spans[1:]:
        prev_y_center = (current_line[-1]["bbox"][1] + current_line[-1]["bbox"][3]) / 2
        curr_y_center = (span["bbox"][1] + span["bbox"][3]) / 2

        if abs(curr_y_center - prev_y_center) <= y_threshold:
            current_line.append(span)
        else:
            line_groups.append(current_line)
            current_line = [span]

    line_groups.append(current_line)

    # Within each line, split into sub-groups by horizontal gap
    merged = []
    for line in line_groups:
        line.sort(key=lambda s: s["bbox"][0])  # sort left to right

        # Average span height as reference for gap threshold
        avg_height = sum(s["bbox"][3] - s["bbox"][1] for s in line) / len(line)
        max_gap = avg_height * x_gap_factor

        sub_group = [line[0]]
        for j in range(1, len(line)):
            prev_x1 = sub_group[-1]["bbox"][2]  # right edge of previous span
            curr_x0 = line[j]["bbox"][0]         # left edge of current span
            gap = curr_x0 - prev_x1

            if gap <= max_gap:
                sub_group.append(line[j])
            else:
                # Large gap — flush current sub_group, start new one
                merged.append(_merge_span_group(sub_group))
                sub_group = [line[j]]

        merged.append(_merge_span_group(sub_group))

    return merged


def _merge_span_group(group):
    """Merge a list of spans into a single answer entry."""
    text = " ".join(s["text"] for s in group)
    x0 = min(s["bbox"][0] for s in group)
    y0 = min(s["bbox"][1] for s in group)
    x1 = max(s["bbox"][2] for s in group)
    y1 = max(s["bbox"][3] for s in group)
    return {
        "text": text,
        "bbox": (x0, y0, x1, y1),
    }


def split_crossword_span(item):
    """If an item looks like a crossword word (all uppercase letters, wide spacing),
    split it into individual letter items. Otherwise return as-is."""
    text = item["text"].strip()
    x0, y0, x1, y1 = item["bbox"]
    w = x1 - x0
    h = y1 - y0

    # Extract only non-space characters
    letters = [ch for ch in text if not ch.isspace()]

    if len(letters) < 2:
        return [item]

    # Crossword detection:
    # 1. ALL characters must be uppercase letters (no digits, no symbols)
    all_upper_alpha = all(ch.isalpha() and ch.isupper() for ch in letters)
    if not all_upper_alpha:
        return [item]

    # 2. Width per character must be large (crossword cells are wide)
    #    Normal text: ~5-8 pts per char, crossword: ~15+ pts per char
    width_per_char = w / len(letters)
    if width_per_char < 12:
        return [item]

    # Split bbox evenly among letters
    cell_w = w / len(letters)
    result = []
    for idx, letter in enumerate(letters):
        lx0 = x0 + idx * cell_w
        lx1 = lx0 + cell_w
        result.append({
            "text": letter,
            "bbox": (lx0, y0, lx1, y1),
        })
    return result


def _transform_to_png(item, scale_x, scale_y):
    """Transform a single item's PDF bbox to PNG pixel coords with padding."""
    x0, y0, x1, y1 = item["bbox"]
    pad_x = (x1 - x0) * 0.15  # 15% horizontal padding
    pad_y = (y1 - y0) * 0.3   # 30% vertical padding
    px = max(0, int((x0 - pad_x) * scale_x))
    py = max(0, int((y0 - pad_y) * scale_y))
    pw = int((x1 - x0 + pad_x * 2) * scale_x)
    ph = int((y1 - y0 + pad_y * 2) * scale_y)
    return {"x": px, "y": py, "w": pw, "h": ph}


def analyze_page_pdf(page, answer_rgb, scale_x, scale_y):
    """Analyze a single PDF page: extract answer-colored text spans,
    transform coordinates to PNG pixel space.
    Returns list of raw sections."""
    spans = extract_answer_spans(page, answer_rgb)

    if not spans:
        return []

    merged = merge_nearby_spans(spans)

    # Split crossword-style spans into individual letters
    expanded = []
    for item in merged:
        expanded.extend(split_crossword_span(item))

    fills = []
    for item in expanded:
        coords = _transform_to_png(item, scale_x, scale_y)
        fills.append({
            "coords": coords,
            "text": item["text"],
        })

    sections = []
    if fills:
        sections.append({"type": "fill", "answers": fills})

    return sections


# ---------------------------------------------------------------------------
# Circle activity detection (multiple choice questions)
# ---------------------------------------------------------------------------

def find_circle_drawings(page, answer_rgb, tolerance=80):
    """Find circle/oval drawings in answer_color on the page.
    Returns list of fitz.Rect for each detected circle."""
    drawings = page.get_drawings()
    # Convert answer_rgb (0-255) to fitz float (0.0-1.0)
    target = (answer_rgb[0] / 255.0, answer_rgb[1] / 255.0, answer_rgb[2] / 255.0)

    circles = []
    for d in drawings:
        color = d.get("color")  # stroke color
        if not color or d.get("fill") is not None:
            continue
        r = d["rect"]
        w, h = r.width, r.height
        # Circle-like: roughly square, reasonable size (8-30pt), has curve items
        if w < 8 or h < 8 or w > 30 or h > 30:
            continue
        if abs(w - h) > 5:
            continue
        # Must have curve items (circles use 'c' commands)
        has_curves = any(item[0] == "c" for item in d["items"])
        if not has_curves:
            continue
        # Check color matches answer_color using Euclidean distance
        if len(color) >= 3:
            stroke_rgb = (color[0] * 255, color[1] * 255, color[2] * 255)
            dist = color_distance(stroke_rgb, answer_rgb)
            if dist <= tolerance:
                circles.append(r)

    return circles


def get_all_text_spans(page):
    """Extract ALL text spans from a page with their bboxes."""
    text_dict = page.get_text("dict", flags=fitz.TEXT_PRESERVE_WHITESPACE)
    spans = []
    for block in text_dict.get("blocks", []):
        if block.get("type") != 0:
            continue
        for line in block.get("lines", []):
            for span in line.get("spans", []):
                text = span.get("text", "").strip()
                if text:
                    spans.append({
                        "text": text,
                        "bbox": span.get("bbox", (0, 0, 0, 0)),
                    })
    return spans


def is_option_span(text):
    """Check if text is or starts with an option letter pattern like 'A)', 'B) ...'"""
    return bool(re.match(r'^[A-EÇ]\)', text))


def get_option_letter(text):
    """Extract the option letter from a span text like 'A)' or 'A) some text'."""
    m = re.match(r'^([A-EÇ])\)', text)
    return m.group(1) if m else None


def find_option_letter(circle_rect, all_spans):
    """Find which option letter (A, B, C, D) a circle is around."""
    cx = (circle_rect.x0 + circle_rect.x1) / 2
    cy = (circle_rect.y0 + circle_rect.y1) / 2

    best = None
    best_dist = 999
    for span in all_spans:
        text = span["text"].strip()
        if not is_option_span(text):
            continue
        sb = span["bbox"]
        sx = (sb[0] + sb[2]) / 2
        sy = (sb[1] + sb[3]) / 2
        dist = ((cx - sx)**2 + (cy - sy)**2) ** 0.5
        if dist < best_dist and dist < 30:
            best_dist = dist
            best = span

    # If no match within 30pt, try wider search (for inline options like "B) text...")
    if not best:
        for span in all_spans:
            text = span["text"].strip()
            if not is_option_span(text):
                continue
            sb = span["bbox"]
            # Check if circle overlaps or is very close to the left edge of the span
            if abs(cy - (sb[1] + sb[3]) / 2) < 15 and abs(cx - sb[0]) < 20:
                dist = ((cx - sb[0])**2 + (cy - (sb[1]+sb[3])/2)**2) ** 0.5
                if dist < best_dist:
                    best_dist = dist
                    best = span

    return best


def find_question_number(option_bbox, all_spans, page_rect):
    """Find the question number above/before the options."""
    ox, oy = option_bbox[0], option_bbox[1]

    best = None
    best_dist = 999
    for span in all_spans:
        text = span["text"].strip()
        # Match question numbers: "1.", "2.", "10." etc.
        if re.match(r'^\d{1,2}\.$', text):
            sb = span["bbox"]
            sy = sb[1]
            sx = sb[0]
            # Question number should be above the option
            if sy < oy + 5:
                # Same column (within 50% of page width)
                half_w = page_rect.width / 2
                same_half = (ox < half_w and sx < half_w) or (ox >= half_w and sx >= half_w)
                if same_half:
                    dist = abs(oy - sy) + abs(ox - sx) * 0.3
                    if dist < best_dist:
                        best_dist = dist
                        best = span
    return best


def find_all_options_for_question(circled_option, all_spans, page_rect):
    """Given a circled option (e.g. 'A)' or 'A) some text'), find all sibling options
    for the same question."""
    circled_bbox = circled_option["bbox"]
    cy = (circled_bbox[1] + circled_bbox[3]) / 2
    cx = circled_bbox[0]
    half_w = page_rect.width / 2

    # Collect all option spans near the same area
    options = []
    for span in all_spans:
        text = span["text"].strip()
        if not is_option_span(text):
            continue
        sb = span["bbox"]
        sy = (sb[1] + sb[3]) / 2
        sx = sb[0]
        # Same half of page
        same_half = (cx < half_w and sx < half_w) or (cx >= half_w and sx >= half_w)
        if not same_half:
            continue
        # Vertical proximity: within 80pt (options can be listed vertically)
        if abs(sy - cy) > 80:
            continue
        # Horizontal proximity: similar x-start (within 30pt) for vertical lists
        # OR similar y for horizontal layouts
        if abs(sx - cx) < 30 or abs(sy - cy) < 30:
            options.append(span)

    # Sort by y then x (top to bottom, left to right)
    options.sort(key=lambda s: (s["bbox"][1], s["bbox"][0]))
    return options


def find_all_question_numbers(page):
    """Find all question number spans (e.g. '1.', '2.') on the page.
    Returns list of {'text': '1.', 'bbox': (...), 'num': 1}."""
    text_dict = page.get_text("dict", flags=fitz.TEXT_PRESERVE_WHITESPACE)
    questions = []
    for block in text_dict.get("blocks", []):
        if block.get("type") != 0:
            continue
        for line in block.get("lines", []):
            for span in line.get("spans", []):
                text = span.get("text", "").strip()
                m = re.match(r'^(\d{1,2})\.$', text)
                if m:
                    questions.append({
                        "text": text,
                        "bbox": span["bbox"],
                        "num": int(m.group(1)),
                    })
    return questions


def get_question_bounds(q_num_span, all_questions, page_rect):
    """Determine the full question area: from this question number
    to the next question in the same column, or to the page bottom."""
    if not q_num_span:
        return None

    qb = q_num_span["bbox"]
    q_x = qb[0]
    q_y = qb[1]
    half_w = page_rect.width / 2
    is_left = q_x < half_w

    # Column boundaries
    col_x0 = 0 if is_left else half_w
    col_x1 = half_w if is_left else page_rect.width

    # Find next question in same column (by y position)
    next_q_y = page_rect.height  # default: page bottom
    for q in all_questions:
        qb2 = q["bbox"]
        q2_x = qb2[0]
        q2_is_left = q2_x < half_w
        if q2_is_left != is_left:
            continue
        if qb2[1] > q_y + 5:  # below current question
            next_q_y = min(next_q_y, qb2[1])

    # Bounds: from question top to next question top (or page bottom), full column width
    pad = 5
    return fitz.Rect(
        col_x0,
        max(0, q_y - pad),
        col_x1,
        next_q_y - pad if next_q_y < page_rect.height else page_rect.height,
    )


def calc_render_scale(clip_rect, target_size=1000.0, min_scale=2.0):
    """Calculate render scale so the longer side of the output is ~target_size px."""
    longer_side = max(clip_rect.width, clip_rect.height)
    if longer_side <= 0:
        return min_scale
    scale = target_size / longer_side
    return max(scale, min_scale)


def crop_question_from_pdf(original_doc, page_idx, clip_rect, output_path, render_scale=None):
    """Crop question area from the ORIGINAL PDF at high resolution.
    If render_scale is None, automatically calculates scale for ~1000px output."""
    page = original_doc.load_page(page_idx)
    if render_scale is None:
        render_scale = calc_render_scale(clip_rect)
    mat = fitz.Matrix(render_scale, render_scale)
    pix = page.get_pixmap(matrix=mat, clip=clip_rect)
    pix.save(output_path)
    actual_scale = render_scale  # store for caller
    pix = None
    return actual_scale


def detect_circle_activities(page, answer_rgb, scale_x, scale_y,
                             page_num, page_idx, original_doc, images_dir,
                             section_path_prefix):
    """Detect multiple-choice (circle) activities on a page.
    Returns list of raw circle sections."""
    circle_rects = find_circle_drawings(page, answer_rgb)
    if not circle_rects:
        return []

    print(f"    Found {len(circle_rects)} circle drawing(s) on page", flush=True)

    all_spans = get_all_text_spans(page)
    page_rect = page.rect
    all_questions = find_all_question_numbers(page)

    sections = []
    processed_circles = set()

    for circle_rect in circle_rects:
        # Avoid processing the same question twice
        circle_key = (round(circle_rect.x0), round(circle_rect.y0))
        if circle_key in processed_circles:
            continue

        # Find which option letter this circle is around
        circled_option = find_option_letter(circle_rect, all_spans)
        if not circled_option:
            print(f"    Circle at ({circle_rect.x0:.0f},{circle_rect.y0:.0f}) — no option letter found, skipping", flush=True)
            continue

        circled_letter = get_option_letter(circled_option["text"].strip())

        # Find all sibling options (A, B, C, D)
        all_options = find_all_options_for_question(circled_option, all_spans, page_rect)
        if len(all_options) < 2:
            print(f"    Circle for '{circled_letter}' — only {len(all_options)} option(s) found, skipping", flush=True)
            continue

        # Mark all these options' circles as processed
        for opt in all_options:
            processed_circles.add((round(opt["bbox"][0]), round(opt["bbox"][1])))
        processed_circles.add(circle_key)

        # Find question number
        q_num_span = find_question_number(circled_option["bbox"], all_spans, page_rect)

        # Use full column width and extend to next question boundary
        # This ensures question text, images, and paragraphs are fully captured
        options_bottom = max(o["bbox"][3] for o in all_options)

        if q_num_span:
            # Try get_question_bounds for full column-width crop
            full_bounds = get_question_bounds(q_num_span, all_questions, page_rect)
            if full_bounds:
                # Ensure we at least cover all options at the bottom
                q_bounds = fitz.Rect(
                    full_bounds.x0,
                    full_bounds.y0,
                    full_bounds.x1,
                    max(full_bounds.y1, options_bottom + 8),
                )
            else:
                # Fallback: use half-page column width
                half_w = page_rect.width / 2
                q_x = q_num_span["bbox"][0]
                is_left = q_x < half_w
                col_x0 = 0 if is_left else half_w
                col_x1 = half_w if is_left else page_rect.width
                pad = 8
                q_bounds = fitz.Rect(
                    col_x0,
                    max(0, q_num_span["bbox"][1] - pad),
                    col_x1,
                    options_bottom + pad,
                )
        else:
            # No question number found — use half-page column width based on options
            half_w = page_rect.width / 2
            opt_x = circled_option["bbox"][0]
            is_left = opt_x < half_w
            col_x0 = 0 if is_left else half_w
            col_x1 = half_w if is_left else page_rect.width
            q_top = min(o["bbox"][1] for o in all_options) - 40
            pad = 8
            q_bounds = fitz.Rect(
                col_x0,
                max(0, q_top - pad),
                col_x1,
                options_bottom + pad,
            )

        q_num_bbox = q_num_span["bbox"] if q_num_span else (0, 0, 0, 0)

        # Determine section index
        section_idx = len(sections) + 1

        # Crop from ORIGINAL PDF at high resolution
        section_filename = f"p{page_num}s{section_idx}.png"
        section_path_abs = os.path.join(images_dir, section_filename)

        if original_doc:
            actual_scale = crop_question_from_pdf(original_doc, page_idx, q_bounds, section_path_abs)
        else:
            # Fallback: render from answered PDF
            actual_scale = crop_question_from_pdf(answered_doc, page_idx, q_bounds, section_path_abs)

        # Build relative section_path
        section_path_rel = f"{section_path_prefix}{section_filename}"

        # Use the actual render scale for coordinate calculations
        render_scale = actual_scale if actual_scale else calc_render_scale(q_bounds)
        crop_x0 = q_bounds.x0
        crop_y0 = q_bounds.y0

        # Build answers array — coords relative to the section image
        opts_sorted = sorted(all_options, key=lambda o: (o["bbox"][1], o["bbox"][0]))

        answers = []
        for opt in opts_sorted:
            opt_letter = get_option_letter(opt["text"].strip())
            ob = opt["bbox"]
            pad_x = 3
            pad_y = 2
            coords = {
                "x": int((ob[0] - crop_x0 - pad_x) * render_scale),
                "y": int((ob[1] - crop_y0 - pad_y) * render_scale),
                "w": int((ob[2] - ob[0] + pad_x * 2) * render_scale),
                "h": int((ob[3] - ob[1] + pad_y * 2) * render_scale),
            }
            entry = {"coords": coords, "opacity": 1}
            if opt_letter == circled_letter:
                entry["isCorrect"] = True
            answers.append(entry)

        # Header coords in full page PNG space
        header_coords = {
            "x": int(q_num_bbox[0] * scale_x),
            "y": int(q_num_bbox[1] * scale_y),
            "w": int((q_num_bbox[2] - q_num_bbox[0]) * scale_x),
            "h": int((q_num_bbox[3] - q_num_bbox[1]) * scale_y),
        }

        # Sanity check: must have exactly one correct answer
        correct_count = sum(1 for a in answers if a.get("isCorrect"))
        if correct_count == 0:
            print(f"    Circle activity skipped — no correct answer found", flush=True)
            continue

        q_label = q_num_span["text"].strip() if q_num_span else "?"
        print(f"    Circle activity: Q{q_label} answer={circled_letter}, options={len(all_options)}, section={section_filename}", flush=True)

        sections.append({
            "type": "circle",
            "answers": answers,
            "header_coords": header_coords,
            "section_path": section_path_rel,
        })

    return sections


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def run_analysis(config_path, settings_path):
    """Main analysis function — PDF text extraction, no API calls."""
    print("PROGRESS:0%", flush=True)
    print("AI Analysis starting (PDF text extraction mode)...", flush=True)

    # 1. Load settings and config
    answer_color = load_settings(settings_path)
    answer_rgb = parse_hex_color(answer_color)
    print(f"Answer color: {answer_color} → RGB{answer_rgb}", flush=True)

    config = load_config(config_path)
    config_dir = os.path.dirname(os.path.abspath(config_path))

    print("PROGRESS:5%", flush=True)
    print("Config loaded successfully", flush=True)

    # 2. Find answered PDF
    answered_pdf_path = find_answered_pdf(config_path)
    print(f"Answered PDF: {answered_pdf_path}", flush=True)

    # 3. Create temp directory
    print("PROGRESS:10%", flush=True)
    temp_dir = os.path.join(config_dir, "temp")
    os.makedirs(temp_dir, exist_ok=True)
    print(f"Temp directory: {temp_dir}", flush=True)

    # 4. Open answered PDF
    answered_doc = fitz.open(answered_pdf_path)
    answered_page_count = len(answered_doc)
    print(f"Answered PDF has {answered_page_count} pages", flush=True)

    # 4b. Find and open original PDF (for high-quality section crops)
    original_pdf_path = find_original_pdf(config_path)
    original_doc = None
    if original_pdf_path:
        original_doc = fitz.open(original_pdf_path)
        print(f"Original PDF: {original_pdf_path} ({len(original_doc)} pages)", flush=True)
    else:
        print("Original PDF not found — will crop from answered PDF", flush=True)

    print("PROGRESS:15%", flush=True)

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

        progress = 15 + int((i / total_pages) * 80)
        print(f"PROGRESS:{progress}%", flush=True)
        print(f"Analyzing page {page_num} ({module_name}) [{i+1}/{total_pages}]...", flush=True)

        # Resolve original image path (need dimensions for coordinate transform)
        parts = image_path.replace("\\", "/").split("/")
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

        # Check answered PDF has this page
        pdf_page_idx = page_num - 1
        if pdf_page_idx < 0 or pdf_page_idx >= answered_page_count:
            print(f"  Warning: Answered PDF has no page {page_num}", flush=True)
            skipped_count += 1
            continue

        # Get original PNG dimensions
        original_pix = fitz.Pixmap(original_image_path)
        png_width = original_pix.width
        png_height = original_pix.height
        original_pix = None

        # Get PDF page and compute scale factors
        pdf_page = answered_doc.load_page(pdf_page_idx)
        scale_x = png_width / pdf_page.rect.width
        scale_y = png_height / pdf_page.rect.height

        print(f"  PNG: {png_width}x{png_height}, PDF page: {pdf_page.rect.width:.0f}x{pdf_page.rect.height:.0f}, Scale: {scale_x:.3f}x{scale_y:.3f}", flush=True)

        # Save images to temp for debug
        original_jpeg_path = os.path.join(temp_dir, f"original_{page_num}.jpg")
        orig_pix = fitz.Pixmap(original_image_path)
        orig_jpeg_bytes = orig_pix.tobytes("jpeg", 90)
        with open(original_jpeg_path, "wb") as f:
            f.write(orig_jpeg_bytes)
        orig_pix = None

        mat = fitz.Matrix(scale_x, scale_y)
        ans_pix = pdf_page.get_pixmap(matrix=mat)
        answered_jpeg_path = os.path.join(temp_dir, f"answered_{page_num}.jpg")
        ans_jpeg_bytes = ans_pix.tobytes("jpeg", 85)
        with open(answered_jpeg_path, "wb") as f:
            f.write(ans_jpeg_bytes)
        ans_pix = None

        print(f"  Saved to temp: original_{page_num}.jpg, answered_{page_num}.jpg", flush=True)

        # Determine images directory and section_path prefix from image_path
        # image_path like "./books/BookName/images/Module_1/8.png"
        img_parts = image_path.replace("\\", "/").split("/")
        try:
            img_idx = img_parts.index("images")
            module_dir_name = img_parts[img_idx + 1] if img_idx + 1 < len(img_parts) else "Module_1"
            # section_path prefix: everything up to and including Module dir + "/"
            # e.g. "./books/BookName/images/Module_1/"
            section_path_prefix = "/".join(img_parts[:img_idx + 2]) + "/"
            images_dir = os.path.join(config_dir, "images", module_dir_name)
        except ValueError:
            module_dir_name = "images"
            section_path_prefix = "./images/"
            images_dir = os.path.join(config_dir, "images")
        os.makedirs(images_dir, exist_ok=True)

        # Clear any existing sections from previous runs
        page_info["page_ref"]["sections"] = []

        # --- Fill detection (answer-colored text) ---
        fill_sections = analyze_page_pdf(pdf_page, answer_rgb, scale_x, scale_y)

        # --- Circle detection (multiple choice drawings) ---
        circle_sections = detect_circle_activities(
            pdf_page, answer_rgb, scale_x, scale_y,
            page_num, pdf_page_idx, original_doc, images_dir,
            section_path_prefix
        )

        # Combine all sections
        sections = fill_sections + circle_sections

        if sections:
            normalized = normalize_sections(sections)
            page_info["page_ref"]["sections"] = normalized
            analyzed_count += 1

            fill_count = len(fill_sections)
            circle_count = len(circle_sections)
            answer_count = sum(len(s.get("answers", [])) for s in sections)
            print(f"  Found {len(sections)} section(s): {fill_count} fill, {circle_count} circle, {answer_count} total answers", flush=True)
            for s in sections:
                if s.get("type") == "fill":
                    for ans in s.get("answers", []):
                        c = ans["coords"]
                        print(f"    [fill] [{c['x']},{c['y']} {c['w']}x{c['h']}] \"{ans.get('text', '')}\"", flush=True)

            # Save config after each page (incremental)
            with open(config_path, "w", encoding="utf-8") as f:
                json.dump(config, f, indent=4, ensure_ascii=False)
            print(f"  Config saved (page {page_num} done)", flush=True)
        else:
            print(f"  No answers found on this page", flush=True)

    # 7. Close PDFs
    answered_doc.close()
    if original_doc:
        original_doc.close()

    # 8. Save final config
    print("PROGRESS:95%", flush=True)
    print("Saving final config.json...", flush=True)

    with open(config_path, "w", encoding="utf-8") as f:
        json.dump(config, f, indent=4, ensure_ascii=False)

    print(f"Config saved: {config_path}", flush=True)
    print(f"Temp images kept at: {temp_dir}", flush=True)

    print("PROGRESS:100%", flush=True)
    print(f"Analysis complete! Analyzed: {analyzed_count}, Skipped: {skipped_count}", flush=True)


if __name__ == "__main__":
    print("AI Analyzer starting (PDF text extraction)...", flush=True)

    parser = argparse.ArgumentParser(description="PDF text extraction workbook page analyzer")
    parser.add_argument("config", help="Path to config.json")
    parser.add_argument("settings", help="Path to settings.json")

    args = parser.parse_args()
    print(f"Script path: {os.path.abspath(__file__)}", flush=True)
    print(f"Config: {args.config}", flush=True)
    print(f"Settings: {args.settings}", flush=True)

    run_analysis(args.config, args.settings)
