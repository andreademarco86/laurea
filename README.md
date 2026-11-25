# Laurea

**Laurea** is a native macOS app that drafts examiner's reports for **BSc, MSc and PhD** dissertations. You review, calibrate, sign and export the report as a Word document.

Its common thread is AI/ML and computational work in numerate sciences. Primary fields:

- AI, machine learning and data science, with particular depth in computer vision
- computing and ICT: computer science, software and computer engineering, information systems, cybersecurity
- speech, language and audio processing: speech recognition and synthesis, speaker recognition, phonetics, computational linguistics, NLP, signal processing
- physics and computational physics, including physics degrees with a computational component
- astronomy and astrophysics

Related fields in the same direction are covered too, using the closest checklists plus field-specific checks: for example robotics, embedded and edge AI, bioinformatics, medical imaging, remote sensing, computational chemistry and HCI. The full list, and how to add a field, is in [skill/references/domains.md](skill/references/domains.md).

In **Settings → Examination Engine**, choose **Claude** (Claude Code) or **ChatGPT** (Codex) and sign in with your existing subscription. Laurea starts each provider's own browser sign-in and runs the examination, report revisions, and teaching in the app. Usage draws from your signed-in plan and follows the provider's allowance and any extra-usage settings. [Claude plan usage](https://support.claude.com/en/articles/15036540-use-the-claude-agent-sdk-with-your-claude-plan) · [Codex sign-in](https://learn.chatgpt.com/docs/auth?surface=cli)

## What a report contains

Every report has the same structure:

- Student name, dissertation title, degree, institution and examiner.
- A recommended mark for each of five criteria, and the dissertation total.
- A viva mark, added after the oral, and the final mark out of 100.
- A summary within a word limit you set (250 words by default).
- For each criterion, 2–3 strengths and 2–3 weaknesses, each pointing to a section and printed page.
- 3–5 viva questions, each with what a good answer should cover and what a weak one looks like.
- 5–10 minor corrections, with page references.
- Your signature and, optionally, the date.

## How it examines

Laurea aims for the standard of an external examiner of international standing.

1. **Checks integrity first.** It renders every page and checks every word against the pixels beneath it. Text a reader cannot see (white on white, the background's colour, tiny fonts, invisible characters) and text addressed to an AI or a grader are removed from what the engine reads and reported to you first. They never affect a mark.
2. **Reads everything.** The engine reads the full text and looks at figures and tables as page images. Tables lose their layout when the text is extracted, so they are judged from the page images.
3. **Maps the work and its claims.** It records the stated aims and research questions, and builds a claims-and-evidence table: each headline claim from the abstract, contributions and conclusions, the table, figure or page that supports it, and a verdict.
4. **Checks the method against field checklists:**
   - **ML and computer vision:** data leakage, baselines, ablations, metrics and statistical robustness.
   - **Computing and ICT:** requirements, design, testing, measured performance, user studies, embedded hardware.
   - **Speech and language:** speaker-independent splits, signal processing, field metrics, listening tests.
   - **Physics:** the physical model and when it holds, the numerical method, convergence studies, validation and error analysis.
   - **Astronomy:** selection effects, the gap between simulations and real data, calibrated uncertainties.
   - **Related fields:** the field-specific checks listed in `skill/references/domains.md`.
5. **Checks the numbers.** Every percentage and decimal quoted in the abstract and conclusions is looked up in the results chapters. Any figure the results don't contain is listed for a check against the tables.
6. **Reviews the literature and checks for internal originality signals.** It assesses how the dissertation uses its sources and flags issues visible in the submitted work. Independent citation verification and online phrase searches are unavailable during app runs. In standalone Claude Code runs with external research enabled, the skill also verifies references against Crossref, OpenAlex and arXiv (sending only titles and identifiers) and inspects linked code repositories without running them.
7. **Marks with a panel and a chair.** A methods examiner, a field examiner and a sceptical examiner mark each criterion independently, each quoting the rubric descriptor it matches. A chair reconciles their marks. Where the examiners differ by more than 15% of a criterion's maximum, the chair re-reads the decisive pages, and the criterion is reported to you as lower confidence.
8. **Guards against inflation.** Automated assessors tend to bunch marks in the middle and over-mark weak work, so:
   - each mark must survive a devil's-advocate case for one band lower;
   - the whole scale is used;
   - totals are sanity-checked against typical ranges for the level;
   - nothing is credited without evidence.
9. **Follows your standards.** Marks also reflect your house rules and your learned calibration. Strengths and weaknesses are written in plain, specific prose.
10. **Verifies itself.** Every page reference is checked against the dissertation, and a checker validates the report's structure and arithmetic.

## Marking scheme

Each criterion has a weight, and that weight is its maximum mark. The five criteria plus the viva always add up to 100. The defaults are:

| Criterion | Default weight |
|---|---|
| (a) Introduction and overall document | 10 |
| (b) Literature review | 20 |
| (c) Method and solution | 25 |
| (d) Testing, results, analysis and evaluation | 25 |
| (e) Discussion, conclusion and future work | 10 |
| Viva | 10 |

With the defaults, the dissertation is marked out of 90 and the final mark is out of 100. You can change the weights in **Settings → Marking Scheme**.

- Each examination keeps the weights it started with, so changing them never alters a finished report.
- Your calibration is stored relative to each criterion's maximum, so it carries over when you change the weights.

## Requirements

| What | Why | How to get it |
|---|---|---|
| macOS 14 Sonoma or later | The app | |
| Apple Command Line Tools | Provide Python 3, git and Swift | `xcode-select --install` |
| **At least one** signed-in examination engine | Drafts and revises reports | **Settings → Examination Engine** |

| Engine | Installed by Laurea from | Sign-in |
|---|---|---|
| Claude (Claude Code 2.x) | Anthropic’s installer | Your Claude account with Claude Code access |
| ChatGPT (Codex CLI) | OpenAI’s official releases | Your ChatGPT account with Codex access |

Choose **Install** if the engine is missing, then choose **Sign In…** and complete the provider’s sign-in in your browser. Return to Laurea to choose the model and thoroughness. You can sign in to both and switch between them.

No Python packages, pandoc or Homebrew are needed. The engine and all skill scripts use only Python's standard library, and the Word document is generated in Python. If `pypdf` happens to be installed, PDF text extraction uses it; otherwise it uses macOS's built-in PDFKit.

## Installing

1. Open `Laurea 1.3.dmg` and drag **Laurea** to **Applications**. The app is signed for local use only, so on another Mac, right-click it and choose **Open** the first time.
2. Open Laurea. The **Setup Assistant** guides you through the rest:
   - choose Claude or ChatGPT, install the engine and sign in to your subscription.
   - your name, institution and default degree;
   - your signature: drop an image or choose a file;
   - the marking weights.

On first launch, Laurea installs examining standards into `~/Library/Application Support/Laurea/examiner`. For upgrades, the app copies compatible standards, examiner settings, signature and calibration from the previous installation, including an old skill linked to a checkout. The previous files and history remain at their original locations.

## Building from source (developers)

```bash
git clone https://github.com/andreademarco86/laurea.git ~/Work/Laurea
```

```bash
cd ~/Work/Laurea
```

Build the app and DMG:

```bash
bash mac/build.sh
```

This produces `dist/Laurea 1.3.dmg`, a universal app for Apple silicon and Intel Macs. The build bundles only files tracked in git, plus the PDF helper programs, so your personal files (`skill/config.json`, `skill/templates/signature.png` and the calibration files, all git-ignored) never end up in the app.

## Using the app

On first launch the **Setup Assistant** guides you through choosing an engine (with Install and Sign In buttons), your name, institution and signature, and the marking weights. Run it again any time from **Laurea → Setup Assistant…**.

1. **Add a dissertation:** press **⌘N**, or drag PDFs onto the window.
2. **Examine:** choose **BSc**, **MSc** or **PhD** and click **Examine**. This usually takes 20–60 minutes. A progress bar and checklist show which stage the examination is at, and you get a notification and a Dock badge when the report is ready.
3. **Review:** every field can be edited. Page references such as `p. 38` open the dissertation at that printed page in the side panel (**⌥⌘P**).
4. **Calibrate:** the **Overall** slider moves the whole mark up or down, spread over the criteria by weight; you can also adjust each criterion and note why. Each save teaches Laurea your standard for that level. The **Calibration** view (**⇧⌘K**) shows what it has learned, kept separately for BSc, MSc and PhD.
5. **After the viva:** enter the viva mark, and the final mark fills in. Turn the date on.
6. **Save and export:** **⌘S** saves and updates the Word file. **⇧⌘E** exports it. **⇧⌘R** revises the report from your description.
7. **Teach the examiner:** in **Examining Standards** (**⇧⌘L**), describe in plain words how you want dissertations examined. For example: "Be stricter about reproducibility" or "Always ask one viva question on ethics".
   - Laurea validates each draft and saves changes in a local version you can review and undo from **History**.
8. **Choose the engine:** in **Settings → Examination Engine**, pick Claude or ChatGPT, the model and the thoroughness. New examinations use the current choice.
9. **Delete an examination:** right-click it in the sidebar and choose **Move to Trash…**, press **Delete** in the sidebar, or use the trash button in the toolbar (**⌘⌫**). Laurea asks for confirmation first; the files go to the Trash, so they can be restored, and the examination is removed from your calibration. A running examination must be stopped first.

## Where things are stored

| What | Where | In git? |
|---|---|---|
| Examinations: PDFs, reports (.md and .docx), working notes and logs | `~/Library/Application Support/Laurea/examinations/` | No |
| App settings, engine log, skill-chat history | `~/Library/Application Support/Laurea/` | No |
| Your name, institution, default degree and marking weights | `examiner/config.json` under Laurea’s Application Support folder | No |
| Your signature | `examiner/templates/signature.png` | No |
| Taught standards and undo history | `examiner/standards/` | No |
| Calibration notes and history | `examiner/references/` | No |
| Subscription login | Provider-managed storage isolated to Laurea’s client configuration under `engine-accounts/` | No |
| Default skill bundled with the app | Repository `skill/` | Yes |

## Privacy

Laurea sends the material needed for a run to the provider you selected. The signed-in account’s model-training and retention settings apply. Each run starts a fresh session with local provider transcript persistence and external searches disabled. Revisions use the saved report and local examination files. Laurea supplies numerical calibration offsets for the current level and keeps the underlying student history and examiner signature on the Mac. [Claude Code data usage](https://code.claude.com/docs/en/data-usage) · [Codex data controls](https://help.openai.com/en/articles/7730893-data-controls-in-chatgpt)

## Repository layout

```
engine/server.py        Examination engine: a localhost JSON API started by the app. It runs the
                        assistant without supervision and manages reports, marking weights,
                        calibration and skill versioning.
mac/Sources/            SwiftUI app: welcome screen, sidebar, report editor, PDF panel,
                        calibration, skill chat and settings.
mac/build.sh            Builds the universal app and the DMG; also generates the icon.
mac/icon/               Draws the app icon.
skill/                  The examiner skill bundled with the app.
  SKILL.md                workflow, standards and writing style
  references/             domains.md (fields covered, which checklists apply, how to add one),
                          marking rubric (BSc/MSc/PhD), checklists for ML/vision, computing/ICT,
                          speech and language, physics and astronomy, external research and
                          originality rules, house preferences
  templates/              report template (plus your signature, not committed)
  scripts/                extract_pdf.py      PDF text with printed page numbers
                          render_pages.py     page images for figures and tables
                          check_report.py     validates structure, arithmetic and page references
                          md_to_docx.py       Word writer (standard library only)
                          scheme.py           marking weights
                          add_viva_mark.py    fills in the viva and final marks
                          numbers_check.py    claimed numbers missing from the results
                          verify_refs.py      reference verification (Crossref, OpenAlex, arXiv)
                          repo_probe.py       inspects linked code and data repositories
                          benchmark.py        agreement between drafts and your final marks
                          pdftext.swift       PDFKit text extraction and the hidden-text scan
                          pdfrender.swift     PDFKit page images
```

## Development

- **Examining Standards** changes apply to the next examination. To work on the bundled defaults, edit `skill/`, rebuild, and test with an isolated `LAUREA_DATA_DIR`.
- **Adding a field:** follow the template at the end of `skill/references/domains.md`, or ask for it in Examining Standards.
- **App or engine changes:** run `bash mac/build.sh`, then reinstall from the DMG.
- **Run the engine on its own:** `DE_PORT=8765 python3 engine/server.py`. It serves a JSON API on `127.0.0.1`. Requests require the `X-DE-App` header matching `DE_APP_TOKEN` (defaults to `1` for a standalone engine).
- **Screenshots without Screen Recording permission:** run `DE_SNAPSHOT_DIR=/some/folder mac/build/Laurea.app/Contents/MacOS/Laurea`. The app captures its own main screens to that folder, then quits. Add `DE_SNAPSHOT_DARK=1` for dark mode.
- **Using the skill without the app:** in Claude Code, run `/dissertation-examiner path/to/thesis.pdf --level msc`. Standalone runs can enable external research for reference verification and repository checks.
- **Measuring agreement with your marks:** after saving final reports, run
  ```bash
  python3 skill/scripts/benchmark.py "$HOME/Library/Application Support/Laurea/examinations"
  ```
  It compares each examination's original draft with your final report. It writes `benchmark.md` next to the examinations, with error, bias, band agreement and rank agreement per criterion and level, plus the change since the previous run. To test a change to your standards, re-examine a few dissertations you've already marked and run it again.
- **Bundled standards and existing installations:** the app copies the bundled `skill/` into its own examiner folder on first launch, and your Examining Standards teaching builds on that copy. Improvements to `skill/` reach new installations. Existing installations keep the standards they started with, plus your local teaching, until an upgrade step that merges the two is added.

## Troubleshooting

- **"The examination engine could not start":** check that the Command Line Tools are installed (`xcode-select -p`), then read `~/Library/Application Support/Laurea/engine.log`.
- **An examination stops at once with "not set up":** open **Settings → Examination Engine** to install the engine, sign in to your subscription, or select the other provider.
- **ChatGPT fails with "code-mode host was not found":** Codex is missing its companion program. Click **Install** again in Settings; it fetches both parts.
- **The signature is missing from the Word file:** add one in **Settings → Signature** (or the Setup Assistant) and save the report again. Without a signature, the report leaves a line to sign by hand.
- **The report checker reports wrong maxima:** the report was written for different weights from the examination's `scheme.json`. Revise the report, or run the examination again.
