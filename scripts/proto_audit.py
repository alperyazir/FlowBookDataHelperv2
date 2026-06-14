"""Deterministic pre-lints for the AI verification pass.

Pure-number checks that need no vision: run these BEFORE spawning
audit agents so they only spend judgment on visual questions.

  - button-align : activity buttons on a page should share a column
  - button-clash : a button overlapping a fill box / another button
  - zone-bounds  : activity answer boxes outside their crop image
  - empty-text   : dragdrop zone / fill answer with empty text
  - tiny-box     : answer boxes smaller than a tappable size

Usage:
  python3 proto_audit.py <book_dir>          # prints JSON findings
"""

import json
import os
import sys

MIN_TAP_PX = 14
BTN_X_TOL = 24          # page buttons should align within this (px)


def iter_pages(cfg):
    if isinstance(cfg, dict):
        if "page_number" in cfg and "sections" in cfg:
            yield cfg
        else:
            for v in cfg.values():
                yield from iter_pages(v)
    elif isinstance(cfg, list):
        for v in cfg:
            yield from iter_pages(v)


def rects_overlap(a, b):
    return (min(a["x"] + a["w"], b["x"] + b["w"]) > max(a["x"], b["x"]) and
            min(a["y"] + a["h"], b["y"] + b["h"]) > max(a["y"], b["y"]))


def audit(book_dir):
    cfg = json.load(open(os.path.join(book_dir, "config.json"),
                         encoding="utf-8"))
    release_root = os.path.normpath(os.path.join(book_dir, "..", ".."))
    findings = []

    def add(pn, kind, severity, msg):
        findings.append({"page": pn, "lint": kind,
                         "severity": severity, "finding": msg})

    crop_sizes = {}

    def crop_size(path):
        if path not in crop_sizes:
            try:
                from PIL import Image
                p = os.path.normpath(os.path.join(release_root,
                                                  path.lstrip("./")))
                crop_sizes[path] = Image.open(p).size
            except Exception:
                crop_sizes[path] = None
        return crop_sizes[path]

    for page in iter_pages(cfg):
        pn = page["page_number"]
        buttons = []
        fills = []
        for s in page.get("sections", []):
            if s.get("type") == "fill":
                for a in s.get("answer", []):
                    fills.append(a)
                    c = a["coords"]
                    if c["w"] < MIN_TAP_PX or c["h"] < MIN_TAP_PX:
                        add(pn, "tiny-box", "low",
                            f"fill '{a.get('text', '')[:20]}' is "
                            f"{c['w']}x{c['h']}px — hard to tap")
                    if not a.get("text", "").strip():
                        add(pn, "empty-text", "low", "fill with empty text")
                continue
            a = s.get("activity")
            if not a:
                continue
            if a.get("coords"):
                buttons.append((a["type"], a["coords"]))
            size = crop_size(a["section_path"]) if a.get("section_path") else None
            for ans in a.get("answer", []):
                c = ans["coords"]
                if size:
                    if c["x"] + c["w"] < 0 or c["y"] + c["h"] < 0 or \
                            c["x"] > size[0] or c["y"] > size[1]:
                        add(pn, "zone-bounds", "high",
                            f"{a['type']} zone fully outside its crop "
                            f"({c['x']},{c['y']} vs {size[0]}x{size[1]})")
                    elif c["x"] < -8 or c["y"] < -8 or \
                            c["x"] + c["w"] > size[0] + 8 or \
                            c["y"] + c["h"] > size[1] + 8:
                        add(pn, "zone-bounds", "low",
                            f"{a['type']} zone sticks out of its crop")
                if a["type"].startswith("dragdroppicture") and \
                        "text" in ans and not ans["text"].strip() and \
                        not ans.get("group"):
                    add(pn, "empty-text", "high",
                        f"{a['type']} zone with empty word")

        # Buttons on one page should sit in one column; and never on
        # top of a fill box or each other.
        if len(buttons) >= 2:
            xs = sorted(c["x"] for _, c in buttons)
            if xs[-1] - xs[0] > BTN_X_TOL:
                add(pn, "button-align", "low",
                    f"{len(buttons)} activity buttons spread over "
                    f"{xs[-1] - xs[0]}px in x (want one column)")
        for i, (t1, c1) in enumerate(buttons):
            for t2, c2 in buttons[i + 1:]:
                if rects_overlap(c1, c2):
                    add(pn, "button-clash", "high",
                        f"{t1} and {t2} buttons overlap")
            for f in fills:
                if rects_overlap(c1, f["coords"]):
                    add(pn, "button-clash", "low",
                        f"{t1} button overlaps fill "
                        f"'{f.get('text', '')[:20]}'")
                    break
    return findings


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)
    out = audit(sys.argv[1])
    print(json.dumps(out, ensure_ascii=False, indent=1))
    counts = {}
    for f in out:
        counts[f["lint"]] = counts.get(f["lint"], 0) + 1
    print(f"-- {len(out)} finding(s): {counts}", file=sys.stderr)


if __name__ == "__main__":
    main()
