# Changelog

## 1.1

**Examining**
- PDFs are prepared on your Mac before examination: text extraction and the hidden-text scan run locally.
- **Adaptive** thoroughness is the new default. It maps the front matter at Light effort, examines at Standard, and requests a focused Thorough second opinion only where marking passes disagree by more than 15% of a criterion’s maximum, or cite conflicting evidence.
- Cropped views of isolated figures and tables for closer inspection.
- Revisions reuse the existing report and evidence, reopening only the source pages the change needs.

**Marking**
- **Institution grading scale** in Settings → Marking, with University of Malta (the default) and International presets, or your own grades. The examiners decide each criterion’s grade from the evidence, testing the grade above as seriously as the grade below, then give a mark within its range. The editor shows the percentage and grade beside the total.

**Reviewing**
- **Check points against the PDF**: a strength or weakness’s page reference opens the PDF at the exact passage it is based on. There is no separate review step: edit or delete points directly.
- **Substantial corrections**: a new report section, before the minor corrections, for rework that takes real effort but no new research. It can be empty ("None required."). The report layout now always comes from the app, so existing installations get the new section.
- **Collapsible viva questions and corrections** in the report editor.
- **Date the report is on by default**: an undated report is dated on the day it is exported, unless you turn the toggle off.
- **Fuller summaries with a closing assessment.** The summary is a readable overview with no page references, uses close to its word limit and ends with a paragraph of four to six plain sentences judging the dissertation as a whole: how soundly it is built and evaluated, what it adds, what the evidence does not yet support, and the overall verdict.
- **Plainer corrections.** Each says what is wrong, then what to do, starting with a verb; the report checker flags vague ones.
- **Broader viva questions** about methodology, outcomes, knowledge of the field, what the report leaves unclear, and limitations. They may focus on a subsection, but not on a specific value or small detail, which belong in the corrections.
- **The summary never names the student.** It refers to “the candidate” where needed; the report checker rejects a summary that uses the student’s name.
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
