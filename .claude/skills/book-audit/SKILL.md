---
name: book-audit
description: AI verification pass over an analyzed FlowBook book — deterministic lints, blind multi-agent page audit (independent layout segmentation + overlay verification), triage, fixes, report. Use after the editor's Analyze, e.g. "/book-audit original" or "/book-audit Goals_2 --deep".
---

# Book Audit

Audit the Analyze output of a book under
`build/Qt_6_5_3_for_macOS-Release/build/release/books/<name>/`.
Arguments: book name; `--deep` enables independent layout segmentation
(default is overlay verification only); `--pages 5,7,12` limits scope.

## Pipeline

1. **State check** — config.json mtime, section type counts,
   needs_review list. If review renders are older than the config,
   regenerate: `python3 scripts/proto_annotate.py books/<name>
   books/<name>/review` (run from the release dir). This produces per
   page BOTH `page_NNN_review.png` (annotated + activity panels) and
   `page_NNN_answered.png` (clean answered-page render).

2. **Deterministic lints first** — `python3 scripts/proto_audit.py
   books/<name>` → button alignment/clash, zones outside crops, empty
   texts, tiny boxes. Never ask agents about things numbers already
   answer.

3. **Blind agent audit** — spawn fresh-context general-purpose agents
   in parallel, ~8 pages each, with the prompt template below. Agents
   know NOTHING about this session.

4. **Triage** — verify every finding against geometry/config before
   acting (agents see, they don't measure). Apply fixes through two
   channels:
   - root cause in a detector → fix the script in `scripts/`, sync to
     the release `scripts/` dir, re-run detection for affected pages;
   - one-off → surgical config.json edit (backup first).
   Missed-section proposals: convert the agent's %-region to PDF
   points and feed the matching deterministic builder
   (`build_dragdrop_sections`, `detect_circle_exercises` with
   `bands_override`, `detect_markwithx_exercises`, `detect_match`,
   `detect_puzzle`) — never hand-write coordinates.
   Audio/video ICONS are AI-located (deterministic icon detection was
   removed — it over-fired on illustrated pages). For every headphone/
   speaker icon (audio) or play/film icon (video) an agent reports,
   convert its `region_pct` to a PDF-point bbox and write it into
   `books/<name>/ai_overrides.json`:
   `{"audio_icons": {"10": [[x0,y0,x1,y1], ...]}, "video_icons": {...}}`
   (page number as string key, bboxes top-to-bottom = file order). On
   re-analysis `build_audio_sections`/`build_video_section` snap these
   to exact coords and pair them with the page's audio/video files. A
   fresh Analyze before any AI pass shows audio only as file-anchored
   buttons parked top-left (`needs_review`); positioning them IS the
   audio audit's job.

5. **Re-verify** — regenerate renders for changed pages; on `--deep`
   send them back to one agent until findings stop.

6. **Feedback log** — append every finding + verdict to
   `books/<name>/audit_log.jsonl`:
   `{"page", "source": "agent|lint", "finding", "verdict":
   "fixed-pipeline|fixed-config|false-alarm|by-design|flagged",
   "note"}`. This is the future training/few-shot corpus — never skip.

7. **Report** — counts before/after, fixes by root cause, remaining
   items grouped as: editor-fixable via smart crop / detector backlog /
   needs Alper's decision.

## Agent prompt template

Replace `<FILES>` with pairs of (answered, review) image paths for the
agent's pages. Keep the prompt in English regardless of the book's
language; findings come back in English and are reported to Alper in
Turkish.

```
You are auditing pages of a school workbook against the output of an
automated exercise-detection system. The book may be in ANY language —
do not keyword-match instructions; read what the instruction asks the
student to DO and classify semantically.

Per page you get TWO images:
- page_NNN_answered.png — the CLEAN answered page: the printed
  exercises plus the answer key's marks (rings, ticks, written words,
  connector lines). No system overlays.
- page_NNN_review.png — LEFT: the page with the system's overlays
  (RED box = detected fill answer, text inside; BLUE "audio" = audio
  button; PURPLE square = activity button). RIGHT: one panel per
  detected activity (crop + GREEN correct/drop boxes, BLUE non-correct
  options, type, instruction, word pool / match pairs).

STEP 1 — INDEPENDENT SEGMENTATION (use ONLY the answered image):
List every exercise/section top-to-bottom: label, one-line instruction
gist, the interaction it needs (write-in / choose-one / mark-many /
drag-words-to-blanks / sort-into-groups / match-pairs / word-search /
listen / watch / free-writing), and its approximate region as PAGE
PERCENTAGES {x%, y%, w%, h%}. Note where the key made marks.

STEP 2 — COMPARISON (now open the review image):
For each STEP-1 section: covered? type matches the interaction?
Report: missed sections (with your region + suggested type), wrong
types, key-marks with no corresponding detection.

STEP 2b — AUDIO / VIDEO ICONS (use the answered image):
The audio/video buttons are placed from the ICONS you see, not from
keywords. Find every small headphone or speaker icon (= audio) and
every play-triangle / film / camera icon (= video). For EACH icon
report a finding with stage "audio" or "video" and its `region_pct`
(tight box around the icon glyph only). List them top-to-bottom — that
is the order they pair with the page's media files. A "Listen ..." /
"Watch ..." instruction with NO icon is NOT an audio/video button here
(report it as a normal miss if it clearly needs one).

STEP 3 — QUALITY:
- Activity crops: content cut at an edge (which edge?), or unrelated
  neighbour content included?
- Fills: one answer wrapped over two lines but boxed as TWO fills
  (texts continue each other) → merge candidate; one box covering two
  separate answers → split candidate; boxes far from any blank.
- Word pools: entries that are fragments of a phrase, or foreign junk.

Known by design — do NOT report: free-writing skipped; an exercise
appearing both as fills AND as an activity panel; correct answers come
from the key — never solve the exercise yourself; activity button
positions (linted numerically elsewhere).

<FILES>

Final reply, JSON only:
[{"page": N,
  "sections_expected": [{"label": "...", "interaction": "...",
                         "region_pct": {"x":0,"y":0,"w":0,"h":0},
                         "covered": true|false,
                         "covered_type_ok": true|false|null}],
  "findings": [{"stage": "miss|type|crop|fill|pool|audio|video",
                "severity": "high|low", "confidence": "high|low",
                "finding": "<one specific sentence>",
                "region_pct": {...}|null,
                "suggested_type": "<editor type>"|null}]}]
Pages with no problems: "findings": []. Report only what you can SEE.
```

In quick mode (default) drop STEP 1 and the `sections_expected` field;
agents then only verify overlays + obvious misses.

## Triage rules learned so far

- Re-typeset echoes (key reprints text in colour) over printed text =
  phantom; real answers sit on blanks. Glossary/cover pages → add to
  `ai_overrides.json` `skip_fill_pages`.
- Agents judging "the key's answer is wrong" = false alarm (we
  reproduce the key).
- "Free-writing lines have no boxes" = by design.
- Band merges on test pages (two questions in one circle activity) =
  real, fixable in editor via smart crop; only fix in pipeline if a
  pattern repeats across books.
- Type mismatches on pool pages (dragdrop vs fillpicture vs match) =
  decision findings; collect and ask Alper once, then store in
  `ai_overrides.json`.
