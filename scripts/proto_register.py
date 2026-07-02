"""Diagnostic: per-page registration report for an original/answered pair.

For every page prints the measured offset (method + confidence) and the
answer-span diff size with and without registration, then a book-level
summary. Use it to verify registration on a new book before trusting
the fill stage.

Usage:
  python3 proto_register.py <book_dir | config.json> [first_page last_page]
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import fitz

from proto_inventory import diff_answer_spans, page_offset


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)
    book = sys.argv[1]
    if book.endswith(".json"):
        book = os.path.dirname(os.path.abspath(book))
    from ai_analyzer import find_answered_pdf, find_original_pdf
    cfg = os.path.join(book, "config.json")
    orig = fitz.open(find_original_pdf(cfg))
    ans = fitz.open(find_answered_pdf(cfg))
    n = min(len(orig), len(ans))
    first, last = 1, n
    if len(sys.argv) >= 4:
        first, last = int(sys.argv[2]), int(sys.argv[3])

    methods = {}
    tot_naive = tot_reg = 0
    moved = 0
    for pno in range(first, last + 1):
        po, pa = orig[pno - 1], ans[pno - 1]
        off = page_offset(po, pa)
        naive = len(diff_answer_spans(po, pa, offset=(0.0, 0.0)))
        reg = len(diff_answer_spans(po, pa))
        tot_naive += naive
        tot_reg += reg
        methods[off["method"]] = methods.get(off["method"], 0) + 1
        shifted = abs(off["dx"]) > 1.5 or abs(off["dy"]) > 1.5
        if shifted:
            moved += 1
        if shifted or naive != reg:
            print(f"  p{pno}: offset=({off['dx']:.1f},{off['dy']:.1f}) "
                  f"[{off['method']} {off['conf']:.2f}] "
                  f"spans naive={naive} registered={reg}", flush=True)
    print(f"== {os.path.basename(book)}: pages={last - first + 1} "
          f"shifted(>1.5pt)={moved} methods={methods} "
          f"spans naive={tot_naive} -> registered={tot_reg}")

    orig.close(); ans.close()


if __name__ == "__main__":
    main()
