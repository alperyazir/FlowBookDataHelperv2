"""Prototype eval: compare a produced config.json against a human
ground-truth config (the completed books under Done/).

Per page: section types we found vs the human's, plus answer counts.
Summary: per-type precision/recall over pages and the page-level
mismatch list — the calibration loop for every new book family.

Usage:
  python3 proto_eval.py <our_config.json> <gt_config.json> [--pages]
"""

import json
import sys
import collections


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


def section_type(s):
    return s.get("type") or s.get("activity", {}).get("type") or "?"


def answers_of(s):
    return s.get("answer") or s.get("activity", {}).get("answer") or []


def inventory(cfg):
    """{page_number: Counter(type -> count)} + answer totals + per-page
    fill answer counts (humans split fill sections per exercise, so
    only the answer count is comparable)."""
    inv, ans, fillans = {}, collections.Counter(), collections.Counter()
    for p in iter_pages(cfg):
        c = collections.Counter()
        for s in p.get("sections", []):
            t = section_type(s)
            c[t] += 1
            ans[t] += len(answers_of(s))
            if t == "fill":
                fillans[p["page_number"]] += len(answers_of(s))
        inv[p["page_number"]] = c
    return inv, ans, fillans


def main():
    if len(sys.argv) < 3:
        print(__doc__)
        sys.exit(1)
    ours, oans, ofill = inventory(json.load(open(sys.argv[1], encoding="utf-8")))
    gt, gans, gfill = inventory(json.load(open(sys.argv[2], encoding="utf-8")))
    show_pages = "--pages" in sys.argv

    types = sorted({t for c in list(ours.values()) + list(gt.values())
                    for t in c})
    print(f"{'type':22s} {'gt':>4s} {'ours':>5s} {'hit':>4s}  "
          f"{'gt_ans':>6s} {'our_ans':>7s}")
    for t in types:
        gt_n = sum(c[t] for c in gt.values())
        our_n = sum(c[t] for c in ours.values())
        hit = sum(min(gt.get(pn, collections.Counter())[t], c[t])
                  for pn, c in ours.items())
        print(f"{t:22s} {gt_n:4d} {our_n:5d} {hit:4d}  "
              f"{gans[t]:6d} {oans[t]:7d}")

    print("\n--- fill cevap sayıları (sayfa, gt != ours olanlar) ---")
    bad = same = 0
    for pn in sorted(set(gfill) | set(ofill)):
        g, o = gfill[pn], ofill[pn]
        if abs(g - o) <= max(1, g * 0.1):
            same += 1
            continue
        bad += 1
        print(f"p{pn:3d}: fill cevap gt={g} ours={o}")
    print(f"({same} sayfa ±10% içinde, {bad} sayfa sapmış)")

    print("\n--- sayfa tip farkları (fill hariç) ---")
    for pn in sorted(set(gt) | set(ours)):
        g = gt.get(pn, collections.Counter())
        o = ours.get(pn, collections.Counter())
        diff = {t: (g[t], o[t]) for t in set(g) | set(o)
                if t != "fill" and g[t] != o[t]}
        if diff:
            print(f"p{pn:3d}: " + ", ".join(
                f"{t} gt={a} ours={b}" for t, (a, b) in sorted(diff.items())))


if __name__ == "__main__":
    main()
