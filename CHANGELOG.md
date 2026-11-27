# Changelog

## 1.2 (in development)

**Paper reviews**
- **Review journal and conference papers before submission**, beside examining dissertations. Laurea reviews the paper as a careful referee at your target venue would, on that venue's own form and scale, so you can see what to fix first.
- **Venues** with their reviewer forms and recommendation scales, checked against each venue's published guidelines in November 2026:
  - **Conferences**: NeurIPS, ICML, ICLR, ACL Rolling Review (ACL, EMNLP, NAACL), CVPR, ICCV/ECCV, AAAI, IJCAI, Interspeech and ICASSP.
  - **Journals**: TMLR, JMLR, IEEE TPAMI, TNNLS and TASLP, Pattern Recognition, Computer Speech & Language, Computer Physics Communications, Astronomy and Computing, the Physical Review journals, MNRAS, ApJ/AJ, A&A and Machine Learning: Science and Technology.
  - **Other conference** and **Other journal**, with general scales.

  Where a venue does not publish its form, Laurea says so and follows its recent practice. Each review keeps the form it was written for.
- One short note where a review starts: reviews are for checking a paper before submission, and using one to referee a submission is your responsibility under the venue's rules.
- **The review**:
  - a summary close to its word limit, ending in an overall assessment;
  - numbered strengths and weaknesses (W1, W2, …), most important first, each with its location;
  - questions for the authors whose answers could change the assessment;
  - required changes in three tiers, each tied to the weakness it fixes: **major** (new experiments, baselines, statistical tests, narrowed claims or a new title, only where a claim depends on them), **moderate** (rework with existing results) and **minor** (a fuller list of quick fixes);
  - limitations, ethical concerns and confidential comments to the area chair or editor;
  - the recommendation, scores and confidence on the venue's own scale.

  Written in your voice as an anonymous reviewer, with the same writing rules as reports.
- **A panel for papers**: soundness, novelty and clarity reviewers each read the whole paper and give a recommendation before their scores; an area chair settles disagreements with an advocate and a critic. Internal notes show each reviewer's ratings and the rulings.
- **The review editor** shows the venue's scale as a strip you click to change the recommendation, with the proposal marked, and the scores and confidence beside what was proposed.
- **Copy and Export**: copy each field, or the whole review laid out as the venue's form (⇧⌘C), or export a Word copy.
- **Calibration for papers**: one learned tendency across venues, from recommendations you change consistently (at least three reviews moved the same way). It appears under **Calibration → Papers**.
- The review checker enforces the venue's options, the three tiers and their links to weaknesses, locations and the writing rules, and flags anything that could reveal who you are.

**Everywhere**
- The sidebar has **Examinations** and **Paper Reviews** sections. **New Examination** (⌘N) adds a dissertation and **New Paper Review** (⇧⌘N) adds a paper; dropped PDFs ask which they are. The welcome screen offers both.
- Your examining standards cover paper reviews too: teach preferences for either in **Examining Standards**.

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
- The editor shows the percentage and grade, for example “72% · B”: for the final mark once the viva mark is in, otherwise for the dissertation mark. The report itself gives marks only.
- **Internal notes** show each examiner’s marks and overall grade, the chair’s marks before calibration, a one-line view from each, and the chair’s ruling on each disputed criterion. They stay in Laurea.
- The summary, the strengths and weaknesses for criteria (a)–(e) (now under one heading), the viva questions and the corrections each fold away.
- **Marks are adjusted one criterion at a time.** The overall calibration slider is gone: it spread whole marks by weight, so small criteria rarely moved. Raise or lower each mark with its arrows; **Your Adjustment** shows the change from the proposed total, and calibration learns from these per-criterion changes as before.
- Typing and mark changes stay responsive: a keystroke redraws only its own field, and a mark change redraws only the marks. Marks, adjustments and results line up in fixed columns.
- Running examinations show their progress in the sidebar. Selected sidebar rows stay readable.
- Settings are arranged in **General**, **Marking** and **Engine** tabs that scroll. The unused default-degree setting has been removed.
- The report’s Markdown source stays internal; you work in the editor.
- A new app icon: a round gold laurel emblem around a checked page, on an indigo-violet background, sized to the macOS icon grid.

**Exporting**
- **The Word report comes last.** Laurea no longer writes a Word file during the examination or on save. **Export Word Report…**, at the end of the report and in the toolbar, produces it after your review and the viva: signed, with the viva and final marks, saved with the examination and shown in Finder. It asks for the viva mark and your signature if either is missing.
- **Date the report** is on by default: the declaration is dated on the day you export, not when the draft is written. Pick another date, or turn the toggle off to sign and date by hand.
- Export always produces the Word report from the current report, and never from another examination.
- Saving is safe while you keep editing: newer edits are never cleared or overwritten.
- The signature appears only in the exported document, not in the editor.
- **More reliable page numbers** for PDFs without built-in page labels: a number taken from a table row or contents entry no longer replaces the real page number, so citations and the checker agree with the PDF.

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
