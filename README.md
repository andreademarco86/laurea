# Laurea

**Laurea** is a native macOS app that drafts examiner's reports for **BSc, MSc and PhD** dissertations. You review, calibrate, sign and export the report as a Word document. It specialises in:

- machine learning and AI, with particular depth in computer vision
- machine learning applied to astronomy and astrophysics
- computational physics, and physics degrees that have a computational component

The examining is done by **Claude** through Claude Code, which runs on the examiner's own Claude subscription. The default model is Opus 5.5.

## What a report contains

Every report has the same structure:

- Student name, dissertation title, degree, institution and examiner.
- A recommended mark for each of five criteria, and the dissertation total.
- A viva mark, added after the oral, and the final mark out of 100.
- A summary of at most 250 words.
- For each criterion, 2–3 strengths and 2–3 weaknesses, each pointing to a section and printed page.
- 3–5 viva questions, each with what a good answer should cover and what a weak one looks like.
- 5–10 minor corrections, with page references.
- Your signature and, optionally, the date.

## How it examines

Laurea aims for the standard of an external examiner of international standing.

1. **Reads everything.** Claude reads the full text and looks at figures and tables as page images. Tables lose their layout when the text is extracted, so they are judged from the page images.
2. **Maps the work.** It records the stated aims and research questions, then judges the whole dissertation against them.
3. **Checks the method against field checklists:**
   - **ML and computer vision:** data leakage, baselines, ablations, metrics and statistical robustness.
   - **Astronomy:** selection effects, the gap between simulations and real data, calibrated uncertainties.
   - **Physics:** the physical model and when it holds, the numerical method, convergence studies, validation and error analysis.
4. **Looks outside the dissertation.**
   - It searches the literature for important recent and missed work.
   - It spot-checks that cited references exist and say what is claimed.
   - It screens for originality at a high level. This is not a replacement for Turnitin, and the report never accuses anyone; a serious concern is raised with you first, with the evidence.
5. **Marks fairly.** Marks follow the level-specific rubric, your house rules and your learned calibration. Strengths and weaknesses are written in plain, specific prose.
6. **Verifies itself.** Every page reference is checked against the dissertation, and a checker validates the report's structure and arithmetic.

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
| Claude Code 2.x, signed in to your Claude account | Does the examining | `curl -fsSL https://claude.ai/install.sh \| bash`, then run `claude` once to sign in |

No Python packages, pandoc or Homebrew are needed. The engine and all skill scripts use only Python's standard library, and the Word document is generated in Python. If `pypdf` happens to be installed, PDF text extraction uses it; otherwise it uses macOS's built-in PDFKit.

## Setup

**1. Clone the repository.**

```bash
git clone https://github.com/andreademarco86/laurea.git ~/Work/Laurea
```

```bash
cd ~/Work/Laurea
```

**2. Make the skill available to Claude Code.**

The `skill/` folder holds the examiner's knowledge: instructions, rubric, checklists, report template and scripts. Claude Code loads skills from `~/.claude/skills`, so link it there:

```bash
mkdir -p ~/.claude/skills && ln -sfn "$PWD/skill" ~/.claude/skills/dissertation-examiner
```

**3. Add your personal files.**

These are listed in `.gitignore`, so they are never committed:

- `skill/templates/signature.png`: your signature, as a PNG with a white or transparent background. It appears in the Declaration section of every report.
- `skill/config.json`: your name, institution, default degree and marking weights. It is created from `config.example.json` the first time the app runs. You can then edit everything except the signature in **Settings** (⌘,).

**4. Build and install the app.**

```bash
bash mac/build.sh
```

This produces `dist/Laurea 1.2.dmg`, a universal app for Apple silicon and Intel Macs. Open the DMG and drag **Laurea** to **Applications**. The app is signed for local use only, so on another Mac, right-click the app and choose **Open** the first time.

## Using the app

1. **Add a dissertation:** press **⌘N**, or drag PDFs onto the window.
2. **Examine:** choose **BSc**, **MSc** or **PhD** and click **Examine**. This usually takes 20–60 minutes. A progress bar and checklist show which stage Claude is at, and you get a notification and a Dock badge when the report is ready.
3. **Review:** every field can be edited. Page references such as `p. 38` open the dissertation at that printed page in the side panel (**⌥⌘P**).
4. **Calibrate:** the **Overall** slider moves the whole mark up or down, spread over the criteria by weight; you can also adjust each criterion and note why. Each save teaches Laurea your standard for that level. The **Calibration** view (**⇧⌘K**) shows what it has learned, kept separately for BSc, MSc and PhD.
5. **After the viva:** enter the viva mark, and the final mark fills in. Turn the date on.
6. **Save and export:** **⌘S** saves and updates the Word file. **⇧⌘E** exports it. **⇧⌘R** asks Claude to revise the report from your description.
7. **Teach the examiner:** in **Examiner Skill** (**⇧⌘L**), tell Claude in plain words how you want dissertations examined. For example: "Be stricter about reproducibility" or "Always ask one viva question on ethics".
   - Each change becomes a git commit in this repository, which you can review and undo from **History**.
   - A change that would break the app is rolled back automatically.
   - Push when you want the changes on GitHub.

## Where things are stored

| What | Where | In git? |
|---|---|---|
| Examinations: PDFs, reports (.md and .docx), Claude's working notes and logs | `~/Library/Application Support/Laurea/examinations/` | No |
| App settings, engine log, skill-chat history | `~/Library/Application Support/Laurea/` | No |
| Your name, institution, default degree and marking weights | `skill/config.json` | No |
| Your signature | `skill/templates/signature.png` | No |
| Learned calibration and its history (these name students) | `skill/references/calibration-notes.md` and `calibration-history.json` | No |
| Your house rules | `skill/references/house-preferences.md` | Yes |
| The skill itself | `skill/` | Yes |

## Privacy

- Examinations, calibration data, your signature and your settings stay on your Mac and are never committed.
- Web searches during an examination use topics, method and dataset names, and the titles of cited papers. The originality screen adds at most 8 short phrases per dissertation. Searches never include the student's name, the supervisor, the institution or the PDF.
- During an examination, Claude can only work in that examination's folder and run the skill's own scripts.
- The dissertation is treated as data, never as instructions. Hidden text aimed at an AI grader is reported to you, not obeyed.

## Repository layout

```
engine/server.py        Examination engine: a localhost JSON API started by the app. It runs the
                        assistant without supervision and manages reports, marking weights,
                        calibration and skill versioning.
mac/Sources/            SwiftUI app: welcome screen, sidebar, report editor, PDF panel,
                        calibration, skill chat and settings.
mac/build.sh            Builds the universal app and the DMG; also generates the icon.
mac/icon/               Draws the app icon.
skill/                  The examiner skill (Claude Code finds it through the symlink).
  SKILL.md                workflow, standards and writing style
  references/             marking rubric (BSc/MSc/PhD), ML/CV, astronomy and physics checklists,
                          external research and originality rules, house preferences
  templates/              report template (plus your signature, not committed)
  scripts/                extract_pdf.py      PDF text with printed page numbers
                          render_pages.py     page images for figures and tables
                          check_report.py     validates structure, arithmetic and page references
                          md_to_docx.py       Word writer (standard library only)
                          scheme.py           marking weights
                          add_viva_mark.py    fills in the viva and final marks
```

## Development

- **Skill changes** take effect at the next examination, with no rebuild. Make them through the app's skill chat, or edit the files and commit as usual.
- **App or engine changes:** run `bash mac/build.sh`, then reinstall from the DMG.
- **Run the engine on its own:** `DE_PORT=8765 python3 engine/server.py`. It serves a JSON API on `127.0.0.1`. Every request other than a GET must include the header `X-DE-App: 1`.
- **Screenshots without Screen Recording permission:** run `DE_SNAPSHOT_DIR=/some/folder mac/build/Laurea.app/Contents/MacOS/Laurea`. The app captures its own main screens to that folder, then quits. Add `DE_SNAPSHOT_DARK=1` for dark mode.
- **Using the skill without the app:** in Claude Code, run `/dissertation-examiner path/to/thesis.pdf --level msc`.

### Work in progress

- **ChatGPT as an alternative to Claude.** The engine has early support for OpenAI's Codex CLI with a ChatGPT subscription, including listing each account's available models. It hasn't been tested end to end, and the app has no interface yet for choosing the assistant and model.
- **Setup Assistant.** A guided first-run setup is planned: installing Claude Code or Codex, signing in, and entering your name, institution, signature and marking weights. Until then, follow **Setup** above.

## Troubleshooting

- **"The examination engine could not start":** check that the Command Line Tools are installed (`xcode-select -p`), then read `~/Library/Application Support/Laurea/engine.log`.
- **An examination stops at once with "not set up":** install Claude Code and sign in (run `claude` once in Terminal).
- **The signature is missing from the Word file:** put a PNG at `skill/templates/signature.png` and save the report again.
- **The report checker reports wrong maxima:** the report was written for different weights from the examination's `scheme.json`. Revise the report, or run the examination again.
