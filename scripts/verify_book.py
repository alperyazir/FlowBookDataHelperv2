"""Check a analysed book against the PDF it came from.

No ground truth and no AI: every check compares what we built with what the
page actually prints, so it runs on any book for free. It is the second tier
of the pipeline — deterministic build, deterministic verification, and only
then a human (or a model) on what is left.

  python3 verify_book.py <config.json> [--mark] [--quiet]

--mark sets needs_review on the sections it flags, so the editor's review
button walks the author straight through them.

Findings, worst first:
  missing_exercise    the page prints an MCQ we built nothing for
  zones_off_options   a circle's tap targets are not on its options
  phantom_zone        a tap target sits on the question number, not an option
  order               activities are not in the printed question order
  odd_option_count    a circle with an unusual number of options
  wide_crop           one crop covers more than one printed question
"""
import sys
import os

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from _bootstrap import ensure_runtime_deps
ensure_runtime_deps()

import json
import re

import fitz

DPI = 150.0
S = DPI / 72.0                      # PDF points -> page-PNG pixels
QNUM_RE = re.compile(r"^(\d{1,2})\.")
OPT_RE = re.compile(r"^([a-dA-D])[.)]")
ZONE_TOL = 34                       # px a zone may sit from its option marker
PHANTOM_TOL = 40                    # px a zone may sit from a question number

SEVERITY = {
    "missing_exercise": "high",
    "zones_off_options": "high",
    "phantom_zone": "high",
    "order": "medium",
    "odd_option_count": "medium",
    "wide_crop": "low",
}


def _pages(cfg):
    for bk in cfg.get("books", []):
        for m in bk.get("modules", []):
            for pg in m.get("pages", []):
                yield pg


def _spans_from(cache):
    for b in cache["blocks"]:
        if b["type"] != 0:
            continue
        for l in b["lines"]:
            for sp in l["spans"]:
                yield sp


def _spans(page):
    for b in page.get_text("dict")["blocks"]:
        if b["type"] != 0:
            continue
        for l in b["lines"]:
            for sp in l["spans"]:
                yield sp


def question_numbers_from(cache, x_max=200):
    """Printed exercise numbers near the left of a column, in page pixels."""
    out = []
    for sp in _spans_from(cache):
        m = QNUM_RE.match(sp["text"].strip())
        if m and sp["bbox"][0] * S <= x_max:
            out.append((int(m.group(1)), sp["bbox"][0] * S, sp["bbox"][1] * S))
    return out


def option_markers_from(cache):
    out = []
    for sp in _spans_from(cache):
        if OPT_RE.match(sp["text"].strip()):
            x0, y0, x1, y1 = [v * S for v in sp["bbox"]]
            out.append((x0, y0, x1, y1))
    return out


def option_groups_from(cache):
    """Rough count of the MCQs a page prints: a new group at every 'a.'."""
    opts = []
    for sp in _spans_from(cache):
        m = OPT_RE.match(sp["text"].strip())
        if m:
            opts.append((round(sp["bbox"][1] * S / 6), sp["bbox"][0] * S,
                         m.group(1).lower()))
    opts.sort()
    groups, cur = [], []
    for _, _, letter in opts:
        if letter == "a" and cur:
            groups.append(cur)
            cur = []
        cur.append(letter)
    if cur:
        groups.append(cur)
    return [g for g in groups if len(g) >= 3]


def question_numbers(page, x_max=200):
    out = []
    for sp in _spans(page):
        m = QNUM_RE.match(sp["text"].strip())
        if m and sp["bbox"][0] * S <= x_max:
            out.append((int(m.group(1)), sp["bbox"][0] * S, sp["bbox"][1] * S))
    return out


def option_markers(page):
    out = []
    for sp in _spans(page):
        if OPT_RE.match(sp["text"].strip()):
            x0, y0, x1, y1 = [v * S for v in sp["bbox"]]
            out.append((x0, y0, x1, y1))
    return out


def crop_question(qnums, ic):
    """The exercise number printed at a crop's top-left, or None.

    Takes the page's numbers already extracted: re-reading the page per
    section made this quadratic, and on a heavy PDF one get_text("dict")
    costs 0.6 s — 267 sections turned a 3-second check into minutes.
    """
    if not ic:
        return None
    x0, y0 = ic["x"], ic["y"]
    y1 = ic["y"] + ic["h"]
    best, bd = None, 1e9
    for num, nx, ny in qnums:
        if nx > x0 + ic["w"]:
            continue
        if not (x0 - 26 <= nx <= x0 + 40 and y0 - 26 <= ny <= y1):
            continue
        d = abs(ny - y0) + abs(nx - x0) * 0.3
        if d < bd:
            bd, best = d, num
    return best


def zones_in_page_px(book_dir, a):
    """Answer zones converted from the cropped image's pixels to page pixels."""
    from PIL import Image
    ic = a.get("image_coords")
    sp = a.get("section_path")
    if not ic or not sp or not ic.get("w") or not ic.get("h"):
        return []
    p = os.path.join(book_dir, "..", "..", sp.lstrip("./"))
    p = os.path.normpath(p)
    if not os.path.exists(p):
        return []
    try:
        iw, ih = Image.open(p).size
    except Exception:
        return []
    out = []
    for an in a.get("answer") or []:
        c = an.get("coords") or {}
        out.append((ic["x"] + c.get("x", 0) * ic["w"] / float(iw),
                    ic["y"] + c.get("y", 0) * ic["h"] / float(ih),
                    c.get("w", 0) * ic["w"] / float(iw),
                    c.get("h", 0) * ic["h"] / float(ih)))
    return out


def option_groups(page):
    """Rough count of the MCQs a page prints: a new group at every 'a.'."""
    opts = []
    for sp in _spans(page):
        m = OPT_RE.match(sp["text"].strip())
        if m:
            opts.append((round(sp["bbox"][1] * S / 6), sp["bbox"][0] * S,
                         m.group(1).lower()))
    opts.sort()
    groups, cur = [], []
    for _, _, letter in opts:
        if letter == "a" and cur:
            groups.append(cur)
            cur = []
        cur.append(letter)
    if cur:
        groups.append(cur)
    return [g for g in groups if len(g) >= 3]


def verify(config_path, mark=False):
    cfg = json.load(open(config_path, encoding="utf-8"))
    book_dir = os.path.dirname(os.path.abspath(config_path))
    raw = os.path.join(book_dir, "raw")
    pdf = ""
    if os.path.isdir(raw):
        for f in sorted(os.listdir(raw)):
            low = f.lower()
            if low.endswith(".pdf") and ("original" in low or "kitap" in low
                                         or "soru" in low):
                pdf = os.path.join(raw, f)
                break
        if not pdf:
            pdfs = [f for f in sorted(os.listdir(raw)) if f.lower().endswith(".pdf")]
            if pdfs:
                pdf = os.path.join(raw, pdfs[0])
    if not pdf:
        return {"ok": False, "error": "no original PDF under %s" % raw}

    doc = fitz.open(pdf)
    findings = []
    n_sections = 0
    marked = 0

    def flag(kind, pg, idx, detail, sec=None):
        findings.append({"kind": kind, "severity": SEVERITY[kind],
                         "page": pg, "section": idx, "detail": detail})
        if mark and sec is not None:
            a = sec.get("activity")
            if isinstance(a, dict):
                a["needs_review"] = True
                return True
        return False

    for pg in _pages(cfg):
        pn = pg.get("page_number")
        secs = pg.get("sections") or []
        n_sections += len(secs)
        if not pn or pn > doc.page_count:
            continue
        page = doc[pn - 1]
        # One text pass per page, shared by every check below.
        cache = page.get_text("dict")
        qnums = question_numbers_from(cache)
        opts = option_markers_from(cache)
        groups = option_groups_from(cache)

        seen_numbers, n_circle = [], 0
        for i, s in enumerate(secs):
            a = s.get("activity") or {}
            t = s.get("type") or a.get("type")
            if not t:
                continue
            ic = a.get("image_coords")
            q = crop_question(qnums, ic)
            if q is not None:
                seen_numbers.append(q)

            if t != "circle":
                continue
            n_circle += 1
            zones = zones_in_page_px(book_dir, a)
            n = len(a.get("answer") or [])
            if n and n not in (3, 4):
                if flag("odd_option_count", pn, i, "%d options" % n, s):
                    marked += 1

            if zones and opts:
                on_option = []
                for zx, zy, zw, zh in zones:
                    cy = zy + zh / 2.0
                    on_option.append(any(
                        abs((oy + oy1) / 2.0 - cy) <= ZONE_TOL
                        and zx - ZONE_TOL * 2 <= ox <= zx + 400
                        for ox, oy, ox1, oy1 in opts))
                hit = sum(on_option)
                if hit < len(zones) * 0.5:
                    if flag("zones_off_options", pn, i,
                            "%d of %d tap targets on an option" % (hit, len(zones)), s):
                        marked += 1
                else:
                    # A phantom is a zone that is on NO option and instead
                    # covers the printed exercise number — being merely near a
                    # numbered line is not enough, or every option row under a
                    # question header would flag.
                    for j, (zx, zy, zw, zh) in enumerate(zones):
                        if on_option[j]:
                            continue
                        cy, cx = zy + zh / 2.0, zx + zw / 2.0
                        near = next((num for num, nx, ny in qnums
                                     if abs(ny - cy) <= PHANTOM_TOL
                                     and abs(nx - cx) <= PHANTOM_TOL), None)
                        if near is not None:
                            if flag("phantom_zone", pn, i,
                                    "tap target %d sits on question number %d"
                                    % (j, near), s):
                                marked += 1
                            break

            # a crop that swallowed a second exercise header
            if ic:
                inside = [q2 for q2, nx, ny in qnums
                          if ic["x"] - 26 <= nx <= ic["x"] + 40
                          and ic["y"] + 30 <= ny <= ic["y"] + ic["h"] - 10]
                if inside:
                    if flag("wide_crop", pn, i,
                            "crop also covers question %s" % inside[0], s):
                        marked += 1

        known = [q for q in seen_numbers if q is not None]
        if len(known) >= 2 and known != sorted(known):
            findings.append({"kind": "order", "severity": SEVERITY["order"],
                             "page": pn, "section": -1,
                             "detail": "activities run %s" % known})

        printed = len(groups)
        if printed > n_circle:
            findings.append({"kind": "missing_exercise",
                             "severity": SEVERITY["missing_exercise"],
                             "page": pn, "section": -1,
                             "detail": "page prints %d MCQ groups, built %d"
                                       % (printed, n_circle)})

    if mark and marked:
        json.dump(cfg, open(config_path, "w", encoding="utf-8"),
                  indent=4, ensure_ascii=False)

    rank = {"high": 0, "medium": 1, "low": 2}
    findings.sort(key=lambda f: (rank[f["severity"]], f["page"]))
    counts = {"high": 0, "medium": 0, "low": 0}
    for f in findings:
        counts[f["severity"]] += 1
    return {"ok": True, "book": os.path.basename(book_dir),
            "pages": doc.page_count, "sections": n_sections,
            "marked": marked, "counts": counts, "findings": findings}


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    if not args:
        print(json.dumps({"ok": False, "error": "usage: verify_book.py <config.json>"}))
        return 1
    res = verify(args[0], mark="--mark" in sys.argv)
    if "--quiet" not in sys.argv and res.get("ok"):
        c = res["counts"]
        print("%s: %d pages, %d sections -> %d high, %d medium, %d low"
              % (res["book"], res["pages"], res["sections"],
                 c["high"], c["medium"], c["low"]), file=sys.stderr)
        for f in res["findings"][:40]:
            print("  [%-6s] p%-4d %-18s %s"
                  % (f["severity"], f["page"], f["kind"], f["detail"]),
                  file=sys.stderr)
    print(json.dumps(res, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    sys.exit(main())
