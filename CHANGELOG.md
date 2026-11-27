# Changelog

## 1.1

**How dissertations are examined**
- **Gemini support.** Sign in with a Google account to examine with Gemini CLI; Google AI Pro and Ultra give higher daily limits. Laurea installs Gemini CLI (and Node.js if needed) from the official sources and checks every download against its published hash. Runs are locked down like the other engines: only file tools in the examination folder and Laurea’s own scripts, shell commands sandboxed without network, no web search, extensions, MCP servers or telemetry, and no local session history.
- **Your institution’s grading scale.** Each criterion is decided as a grade on your scale, then marked within that grade’s range. The case for the grade above is tested as seriously as the case for the grade below. Choose **University of Malta** (the default) or **International** in **Settings → Marking**, or edit the grades and what each means. Each examination keeps the scale it started with.
- **A more independent panel.** Three examiners each read the whole dissertation and look closely at a different part:
  - **Methods**: the method and results.
  - **Field**: the literature and the work’s place in its field.
  - **Holistic**: the argument as a whole.

  Each keeps their own evidence and gives an overall grade before marking the criteria. The chair weights each criterion towards the examiner who leads on it. Where the examiners disagree by a grade or more, the chair weighs the case for the grade above against the case for the grade below.
- **Adaptive thoroughness** is the new default. It maps the front matter at Light effort and examines at Standard. It asks for a focused Thorough second opinion only where the examiners’ marks differ by more than 15% of a criterion’s maximum, or where conflicting evidence could change a mark.
- PDFs are prepared on your Mac before the examination starts: text extraction and the hidden-text scan run locally.
- Isolated figures and tables are viewed as cropped images for closer inspection.
- Revisions reuse the existing report and evidence, reopening only the source pages the change needs.
- The examining standards were rewritten around grades and tidied to about half their former length, with the same workflow.

**The report**
- **Summary**:
  - Close to the word limit, as a readable overview with no page references.
  - Three paragraphs: what the work is, what drives the mark, and a closing assessment of four to six plain sentences on the dissertation as a whole.
  - Never names the student; it says “the candidate” where needed.
- **The examiner’s own voice**: a measured first person (“In my view”). The report never mentions a panel, chair or review behind it.
- **Strengths and weaknesses**:
  - Written as natural academic prose, with the reference at the end.
  - Most important point first.
  - Clear English that isn’t perfect costs little or nothing; awkward phrasing becomes minor corrections instead.
- **Viva questions by level**:
  - 3–5 for a BSc, 4–6 for an MSc, 8–10 for a PhD.
  - Broad, open questions about methodology, outcomes, knowledge of the field, what the dissertation leaves unclear, and limitations.
  - They may focus on a subsection, but never on a specific value or small detail.
- **Substantial corrections**: a new section, before the minor corrections, for rework that takes real effort but no new research. Each follows from a weakness in the report. It can be “None required.”
- **Plain corrections**: each says what is wrong, then what to do, starting with a verb.
- The report checker enforces these rules: it flags a named student or page references in the summary, mentions of a panel or chair, vague corrections, and the wrong number of viva questions for the level.

**Reviewing a draft**
- **Page references highlight what they cite.** Clicking any page reference opens the PDF with the quoted passage, or the figure or table label, highlighted. If neither appears, the sentence that best matches the comment is lightly highlighted, but only when one sentence clearly stands out.
- The editor shows the total’s percentage and grade, for example “72% · B”. The report itself gives marks only.
- **Internal notes** show each examiner’s marks and overall grade, the chair’s marks before calibration, a one-line view from each, and the chair’s ruling on each disputed criterion. They stay in Laurea.
- Viva questions and corrections fold away. Marks, calibration and results line up in fixed columns, and the mark rings follow the calibration slider without lag.
- Running examinations show their progress in the sidebar. Selected sidebar rows stay readable.
- Settings are arranged in **General**, **Marking** and **Engine** tabs that scroll. The unused default-degree setting has been removed.
- The report’s Markdown source stays internal; you work in the editor.
- A new app icon: a round gold laurel emblem around a checked page, on an indigo-violet background, sized to the macOS icon grid.

**Exporting**
- **Date the report** is on by default: the declaration is dated on the day you export, not when the draft is written. Pick another date, or turn the toggle off to sign and date by hand.
- Export always uses a Word file produced from the current report, and never another examination’s file. If the Word file can’t be produced, nothing is exported.
- Saving is safe while you keep editing: newer edits are never cleared or overwritten.
- The signature appears only in the exported document, not in the editor.

**Calibration**
- A learned offset needs at least three examinations in which you changed that mark in the same direction. Marks you accept unchanged can strengthen an offset but cannot create or reverse one. Recent decisions carry more weight.
- **Evidence for learned offsets** shows how many examinations support each adjustment.

**Installation and data**
- Laurea reads its examining standards and tools from the app itself. Application Support holds only your examinations, settings, signature, calibration and anything you teach.
- Installing a new version clears earlier teaching and the Examining Standards chat, and removes copies left by older versions, so the standards always match the app. Settings, signature, calibration and examinations are kept.

**Development**
- `dev/check.sh` runs fast offline checks: the Swift type-check, Python, skill validation, the report checker, the Word writer and engine logic. Add `--build` to build the DMG as well. It uses no PDFs, network or assistant sessions.
- `benchmark.py` measures grade agreement on each examination’s own grading scale.

## 1.0

The first release:
- Drafts examiner’s reports for BSc, MSc and PhD dissertations: marks for five weighted criteria, page-referenced strengths and weaknesses, a summary, viva questions with expected answers, and minor corrections.
- A Setup Assistant for the Claude or ChatGPT engine, a report editor with a PDF viewer, overall calibration, and signed Word export.
- Examining Standards for teaching standing preferences, with undoable history.
- Learned calibration for each degree level.
- Hidden-text and instruction-like-text checks.
