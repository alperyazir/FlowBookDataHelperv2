"""Which PDF in a book's raw/ folder is the book.

There were four copies of this rule — three Python, one C++ — and they did not
agree. compress_pdf skipped covers, crop_section and align_audio did not, and
none of the Python ones sorted the directory listing, so the answer depended on
whatever order the filesystem happened to hand back.

That is how GOALS5 broke: raw/ holds "Level 5-kitap.pdf" (the 112-page book),
"Level 5 - CEVAPLI.pdf" (the answer key) and "SDG L5 KAPAK GÜNCEL.pdf" (a
one-page cover). Packaging picked the book, because the C++ rule skips covers;
karaoke picked the cover, because this one did not — and then every page index
was out of range. One rule, in one place, applied by everyone.

Kept deliberately identical to PdfProcess::findOriginalPdf so the editor never
crops from one document and aligns against another.
"""
import os

ANSWERED_KEYS = ("cevap", "answer", "key")   # the completed/answer-key edition
COVER_KEYS = ("kapak", "cover", "kapag")     # a jacket, not the book
ORIGINAL_KEYS = ("original", "soru")         # an explicit "this is the source"


def _has(name, keys):
    low = name.lower()
    return any(k in low for k in keys)


def find_original_pdf(raw_dir):
    """The original (unanswered) book PDF in raw_dir, or None.

    Sorted, so two machines given the same folder reach the same answer — an
    arbitrary listing order is one more way for a book to behave differently on
    someone else's desk."""
    if not os.path.isdir(raw_dir):
        return None
    pdfs = sorted(f for f in os.listdir(raw_dir) if f.lower().endswith(".pdf"))
    rest = [f for f in pdfs if not _has(f, ANSWERED_KEYS)]
    if not rest:
        return None
    named = [f for f in rest if _has(f, ORIGINAL_KEYS)]
    if named:
        return os.path.join(raw_dir, named[0])
    no_cover = [f for f in rest if not _has(f, COVER_KEYS)]
    return os.path.join(raw_dir, (no_cover or rest)[0])
