# Changelog

## 1.1

**Examining**
- PDFs are prepared on your Mac before examination: text extraction and the hidden-text scan run locally.
- **Adaptive** thoroughness is the new default. It maps the front matter at Light effort, examines at Standard, and requests a focused Thorough second opinion only where marking passes disagree by more than 15% of a criterion’s maximum, or cite conflicting evidence.
- Cropped views of isolated figures and tables for closer inspection.
- Revisions reuse the existing report and evidence, reopening only the source pages the change needs.

**Reviewing**
- **Evidence ledger** above the marks: review each strength and concern by criterion, open its cited page with the passage or figure/table label highlighted, then confirm, correct or dismiss it. Decisions stay with the finding they were made on; a reworded finding returns to To review. Decisions guide later revisions of the same examination.
- **Page references highlight what they cite.** Any page reference in the report, including weaknesses and viva questions, opens the PDF with a quoted passage or figure/table label highlighted. If neither appears, Laurea lightly highlights the sentence that best matches the comment, but only when one sentence clearly stands out.
- **Internal notes**: the three examiner scores and the chair’s marks before calibration, with a one-line view from each examiner and the chair. They stay in Laurea; the exported report shows only the agreed findings and marks.

**Exporting**
- The declaration is dated when you export the Word report, not when the draft is written. Turn the date off under Declaration to sign and date by hand.
- Export always uses a Word file produced from the current report, and never another examination’s file.
- Saving is safe while you keep editing: newer edits are never cleared or overwritten.

**Calibration**
- Learned offsets need at least three examinations where you changed the mark in the same direction. Marks accepted unchanged can strengthen an offset but cannot create or reverse one. Recent decisions carry more weight.

**Installation**
- Improvements to Laurea’s tools now reach existing installations automatically; your examining standards and teaching history are preserved.

**Development**
- `dev/check.sh`: fast offline checks (Swift type-check, Python, skill validation, report checker, Word writer, engine logic) with an optional `--build`. No PDFs, network or assistant sessions.
