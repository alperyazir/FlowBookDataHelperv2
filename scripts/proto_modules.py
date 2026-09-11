#!/usr/bin/env python3
"""Module (unit) boundary detection — multi-source.

Sources, each yielding {unit_no: start_page} candidates:
  A. running header/footer label per page ("Unit 3", "Kapitel 2", "Theme 5")
  B. unit opener pages (big lone number in the header zone next to a big
     title / "UNIT" word)
  C. contents page(s): unit labels paired with printed page numbers
     (printed page no == PDF index in every sampled book)
  D. PDF outline entries carrying a unit number
The source with the longest monotonic unit chain wins; ties go to
A > D > C > B. Front matter = "Intro", units named by the printed word
(book-wide majority; language fallback), back matter after the last unit
split by its own printed headings (Alper's rule, 2026-09-06).

Usage: python3 proto_modules.py <book_dir> [--gt gt.json] [--de] [--debug]
"""
import json, os, re, sys, collections, unicodedata

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from _bootstrap import ensure_runtime_deps
ensure_runtime_deps()

import fitz

UNIT_WORDS = r"(unit|module|kapitel|lektion|theme|chapter|[üu]nite|practice\s+test|einheit|bölüm|teil|topic)"
NUM = r"(\d{1,2}|[ivx]{1,5}|one|two|three|four|five|six|seven|eight|nine|ten|eleven|twelve|eins|zwei|drei|vier|fünf|sechs)"
UNIT_RE = re.compile(rf"\b{UNIT_WORDS}\s*[-:]?\s*{NUM}\b", re.I)
WORDNUM = {w: i for i, w in enumerate("one two three four five six seven eight nine ten eleven twelve".split(), 1)}
WORDNUM.update({w: i for i, w in enumerate("eins zwei drei vier fünf sechs".split(), 1)})
ROMAN = {"i": 1, "ii": 2, "iii": 3, "iv": 4, "v": 5, "vi": 6, "vii": 7, "viii": 8, "ix": 9, "x": 10, "xi": 11, "xii": 12}
BACK_WORDS = re.compile(r"^(unit\s*\d+\s+)?(general\s+)?(review|revision|revision\s+test|answer\s*key|wordlist|word\s*list|glossary|worksheets?|picture\s+dictionary|further\s+gramm[ae]r|irregular\s+verbs|self[- ]check|exit\s+test|book\s+review|strategy\s+training|analytic\s+rubric|rubric|checklist|contents|inhalt|anhang|lösungen|endrevision|notizen|letzte\s+runde|projects|appendix|transcripts?|audio\s*scripts?|exam\s+preparation|practice\s+tests|mixed\s+tests?|notes|vocabulary\s+revision|additional\s+materials?(\s+for\s+teachers)?)(\s*[-–:]?\s*\d+)?$", re.I)
EXERCISE_LABEL = re.compile(r"^([A-Za-z]|[IVXivx]{1,4}|\d{1,2})[.)]\s")
PURE_NUM = re.compile(r"^\d{1,3}$")
PAGE_TOKEN = re.compile(r"^(?:page|seite|s\.|p\.)?\s*(\d{1,3})(?:\s*[-–]\s*\d{1,3})?$", re.I)
CONTENTS_SCAN = 8
LANG_WORD = {"de": "Kapitel", "en": "Unit"}


def norm_num(s):
    s = s.lower()
    if s.isdigit():
        return int(s)
    return WORDNUM.get(s) or ROMAN.get(s)


def unit_label(text):
    m = UNIT_RE.search(text)
    if not m:
        return None
    n = norm_num(m.group(2))
    if n is None:
        return None
    w = m.group(1).strip().lower()
    w = {"ünite": "Ünite", "unite": "Ünite"}.get(w, w.title())
    if w.lower().startswith("practice"):
        w = "Practice Test"
    return w, n


def page_lines(page):
    out = []
    for b in page.get_text("dict").get("blocks", []):
        if b.get("type") != 0:
            continue
        for l in b["lines"]:
            txt = "".join(s["text"] for s in l["spans"]).strip()
            if txt:
                out.append((max(s["size"] for s in l["spans"]), l["bbox"][0], l["bbox"][1], txt))
    return out


def stem(name):
    """Comparison key for a back-matter heading, ignoring the trailing number.

    Folded to bare ASCII letters because publishers are not consistent about
    Turkish diacritics inside English headings: The Chase 6 Practice Tests
    prints "Mıxed Tests" on pages 67-70 and "Mixed Tests" from 71 on, which
    otherwise split one section into two modules (2026-09-11).
    """
    name = re.sub(r"[\s\-–:]*\d+\s*$", "", name).strip().lower()
    name = unicodedata.normalize("NFKD", name)
    name = "".join(c for c in name if not unicodedata.combining(c))
    # NFKD leaves the dotless i and a few other Turkish letters alone
    return name.translate(str.maketrans("ıİşğçöü", "iisgcou"))


def source_header(sig, n):
    starts, words = {}, collections.Counter()
    for i in range(2, n + 1):
        lab = sig[i]["edge_label"]
        if lab and sig[i]["review_head"]:
            lab = None
        if lab and sig[i]["kind"] != "contents":
            w, num = lab
            words[w] += 1
            starts.setdefault(num, i)
    return starts, words


def source_opener(sig, n):
    starts, words = {}, collections.Counter()
    for i in range(2, n + 1):
        if sig[i]["kind"] == "contents":
            continue
        op = sig[i]["opener"]
        if op:
            w, num = op
            if w:
                words[w] += 1
            starts.setdefault(num, i)
    return starts, words


def source_contents(doc, sig, n):
    starts, words = {}, collections.Counter()
    for i in range(2, min(n, CONTENTS_SCAN) + 1):
        if sig[i]["kind"] != "contents":
            continue
        lines = page_lines(doc[i - 1])
        nums = []
        for size, x, y, t in lines:
            m = PAGE_TOKEN.match(t)
            if m and int(m.group(1)) <= n:
                nums.append((x, y, int(m.group(1))))
            else:
                m2 = re.search(r"\s(\d{1,3})(?:\s*[-–]\s*\d{1,3})?\s*$", t)
                if m2 and len(t) > 6 and int(m2.group(1)) <= n:
                    nums.append((x + 400, y, int(m2.group(1))))
        labels = [(x, y, unit_label(t)) for size, x, y, t in lines if unit_label(t)]
        # column of lone big numbers under a "UNIT"-style column header
        med = sorted(s for s, _, _, _ in lines)[len(lines) // 2] if lines else 10
        heads = [(x, y, t) for s, x, y, t in lines if re.fullmatch(UNIT_WORDS, t.strip(), re.I)]
        for hx, hy, ht in heads:
            for s, x, y, t in lines:
                if PURE_NUM.match(t) and int(t) <= 30 and s >= 1.4 * med \
                        and abs(x - hx) < 40 and y > hy:
                    labels.append((x, y, (ht.strip().title(), int(t))))
        for x, y, lab in labels:
            w, num = lab
            best, bd = None, 1e9
            for nx, ny, pg in nums:
                if abs(ny - y) < 8 and nx > x:
                    d = nx - x
                elif nx > x + 100 and -8 <= ny - y < 60:      # right, next row (Koko)
                    d = 50 + abs(ny - y)
                elif abs(nx - x) < 60 and 0 < ny - y < 140:
                    d = 100 + (ny - y)
                elif abs(nx - x) < 60 and 0 < y - ny < 60:
                    d = 200 + (y - ny)
                else:
                    continue
                if d < bd:
                    best, bd = pg, d
            if best is not None and best >= 2:
                words[w] += 1
                starts.setdefault(num, best)
    return starts, words


# The unit badge is drawn glyph by glyph ("T H E M E") with its number
# doubled by the outline layer ("88" = unit 8). It is the only reliable
# statement of which unit a page belongs to: The Chase 6 p102 also carries a
# stale template string "Theme 1" plus the words "Worksheet 1", which made
# the back-matter rule cut Theme 8 off at its second page (2026-09-10).
# A range badge ("THEMES 1-8") names no single unit and is left alone.
# Spaces BETWEEN the letters are what identify the badge: matching "Theme"
# as a plain word picked up the stale template string first.
BADGE_RE = re.compile(r"(?:T\s+H\s+E\s+M\s+E|U\s+N\s+I\s+T)\s*(\d{1,4})\b", re.I)


def badge_unit(edge_text):
    """The unit number printed in the page's badge, or None."""
    m = BADGE_RE.search(edge_text)
    if not m:
        return None
    d = m.group(1)
    if len(d) % 2 == 0 and d[:len(d) // 2] == d[len(d) // 2:]:
        d = d[:len(d) // 2]        # the badge prints its number twice
    return int(d) if len(d) <= 2 else None


def source_outline(doc, n):
    starts, words = {}, collections.Counter()
    for lvl, title, pg in doc.get_toc():
        if not (1 <= pg <= n):
            continue
        lab = unit_label(title)
        num = None
        if lab:
            w, num = lab
            words[w] += 1
        else:
            m = re.match(r"^\s*(\d{1,2})\b", title) or re.search(r"\b(\d{1,2})\s*\.?\s*(unite|ünite|unit)\b", title, re.I)
            if m:
                num = int(m.group(1))
        if num and pg >= 2:
            starts.setdefault(num, pg)
    return starts, words


def monotonic_run(starts):
    seq = sorted(starts.items())
    best, cur, last = [], [], -1
    for num, pg in seq:
        if pg > last and (not cur or num == cur[-1][0] + 1):
            cur.append((num, pg))
            last = pg
        else:
            if len(cur) > len(best):
                best = cur
            cur, last = [(num, pg)], pg
    return best if len(best) >= len(cur) else cur


def detect(book_dir, pdf_name="original.pdf", lang="en", debug=False,
           pdf_path=None):
    doc = fitz.open(pdf_path or os.path.join(book_dir, "raw", pdf_name))
    n = doc.page_count
    sig = {}
    for i in range(1, n + 1):
        page = doc[i - 1]
        h = page.rect.height
        lines = page_lines(page)
        edge = [t for s, x, y, t in lines if y < 0.17 * h or y > 0.90 * h]
        edge_label = unit_label(" ".join(edge)) or unit_label(" | ".join(edge))
        review_head = bool(re.search(rf"\b{UNIT_WORDS}\s*\d+\s*(review|revision|test|wiederholung)\b", " ".join(edge), re.I))
        distinct = {unit_label(t)[1] for s, x, y, t in lines if unit_label(t)}
        # Next Level style contents: a "UNIT" column header with big lone
        # numbers below it (no "Unit N" text anywhere)
        if i <= CONTENTS_SCAN and len(distinct) < 3 and lines:
            med = sorted(s for s, _, _, _ in lines)[len(lines) // 2]
            for s_, hx, hy, ht in lines:
                if re.fullmatch(UNIT_WORDS, ht.strip(), re.I):
                    col = {int(t) for s2, x2, y2, t in lines if PURE_NUM.match(t)
                           and int(t) <= 30 and s2 >= 1.4 * med and abs(x2 - hx) < 40 and y2 > hy}
                    distinct |= col
        kind = "contents" if i <= CONTENTS_SCAN and len(distinct) >= 3 else "page"
        big = sorted(lines, key=lambda t: -t[0])[:4]
        edge_back = None
        for size, x, y, t in big:
            if y < 0.12 * h and len(t) < 40 and BACK_WORDS.search(t) \
                    and not EXERCISE_LABEL.match(t):
                edge_back = t.strip()
                break
        opener = None
        if not edge_label and kind == "page":
            for size, x, y, t in big:
                lab = unit_label(t)
                if lab and size >= 16 and y < 0.2 * h:
                    opener = lab
                    break
            if opener is None:
                top = [(s, x, y, t) for s, x, y, t in lines if y < 0.2 * h and s >= 20]
                mx = max((s for s, x, y, t in lines), default=0)
                nums = [t for s, x, y, t in top if PURE_NUM.match(t) and int(t) <= 30 and s >= 0.85 * mx]
                titles = [t for s, x, y, t in top if not PURE_NUM.match(t) and s >= min(30, 0.6 * mx)]
                if len(nums) == 1 and titles:
                    w = next((t.title() for t in titles if re.fullmatch(UNIT_WORDS, t.strip(), re.I)), None)
                    opener = (w, int(nums[0]))
        sig[i] = {"badge": badge_unit(" ".join(edge)),
                  "edge_label": edge_label, "edge_back": edge_back, "opener": opener, "kind": kind,
                  "review_head": review_head}

    srcs = {"header": source_header(sig, n), "outline": source_outline(doc, n),
            "contents": source_contents(doc, sig, n), "opener": source_opener(sig, n)}
    runs = {k: monotonic_run(v[0]) for k, v in srcs.items()}
    order = ["header", "outline", "contents", "opener"]
    best_src = max(order, key=lambda k: (len(runs[k]), -order.index(k)))
    run = runs[best_src]
    if debug:
        for k in order:
            print(f"   src {k:8} units={len(runs[k])} {runs[k][:12]} words={dict(srcs[k][1])}")
        print("   chosen:", best_src)

    words = collections.Counter()
    for k in order:
        words.update(srcs[k][1])
    word = words.most_common(1)[0][0] if words else LANG_WORD.get(lang, "Unit")

    modules = []
    if not run:
        modules.append({"kind": "intro", "name": "Intro", "pages": list(range(2, n + 1))})
    else:
        first = run[0][1]
        if first > 2:
            modules.append({"kind": "intro", "name": "Intro", "pages": list(range(2, first))})
        for idx, (num, pg) in enumerate(run):
            end = run[idx + 1][1] - 1 if idx + 1 < len(run) else n
            modules.append({"kind": "unit", "name": f"{word} {num}", "num": num,
                            "pages": list(range(pg, end + 1))})
        last = modules[-1]
        tail_start = None
        for p in last["pages"][1:]:
            el = sig[p]["edge_label"]
            # a running "Unit 1" inside a picture dictionary / wordlist is a
            # backward reference, not this unit's header
            if sig[p]["edge_back"] and (not el or el[1] < last["num"]) \
                    and sig[p].get("badge") != last["num"]:
                tail_start = p
                break
        if tail_start:
            tail = [p for p in last["pages"] if p >= tail_start]
            last["pages"] = [p for p in last["pages"] if p < tail_start]
            cur = None
            for p in tail:
                hb = sig[p]["edge_back"]
                if hb and (cur is None or stem(hb) != stem(cur["name"])):
                    nm = re.sub(r"(?i)^unit\s*\d+\s+", "", hb)
                    cur = {"kind": "back", "name": re.sub(r"[\s\-–:]*\d+\s*$", "", nm).strip(), "pages": [p]}
                    modules.append(cur)
                elif cur:
                    cur["pages"].append(p)
    modules = [m for m in modules if m["pages"]]
    for m in modules:
        m["start"], m["end"] = m["pages"][0], m["pages"][-1]
    return modules, best_src


def gt_modules(gt_path):
    g = json.load(open(gt_path, encoding="utf-8"))
    out = []
    for bk in g["books"]:
        for m in bk["modules"]:
            pg = [p["page_number"] for p in m["pages"]]
            if pg:
                out.append({"name": m["name"], "start": pg[0], "end": pg[-1]})
    return out


def score(ours, gt):
    os_ = {m["start"] for m in ours if m["start"] > 2}
    gs = {m["start"] for m in gt if m["start"] > 2}
    hit = len(os_ & gs)
    return {"ours": len(ours), "gt": len(gt), "boundary_hit": hit,
            "prec": round(hit / max(1, len(os_)), 2), "rec": round(hit / max(1, len(gs)), 2)}


if __name__ == "__main__":
    book = sys.argv[1]
    lang = "de" if "--de" in sys.argv else "en"
    mods, src = detect(book, lang=lang, debug="--debug" in sys.argv)
    print(f"{os.path.basename(book)}: {len(mods)} modules via {src}")
    print("  ", "; ".join(f"{m['name']} [{m['start']}-{m['end']}]" for m in mods))
    if "--gt" in sys.argv:
        gt = gt_modules(sys.argv[sys.argv.index("--gt") + 1])
        print("  GT:", "; ".join(f"{m['name']} [{m['start']}-{m['end']}]" for m in gt))
        print("  score:", score(mods, gt))
