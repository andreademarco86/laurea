# Laurea

**Laurea** is a native macOS app that drafts examiner's reports for **BSc, MSc and PhD** dissertations. You review, calibrate, sign and export the report as a Word document.

Its common thread is AI/ML and computational work in numerate sciences. Primary fields:

- AI, machine learning and data science, with particular depth in computer vision
- computing and ICT: computer science, software and computer engineering, information systems, cybersecurity
- speech, language and audio processing: speech recognition and synthesis, speaker recognition, phonetics, computational linguistics, NLP, signal processing
- physics and computational physics, including physics degrees with a computational component
- astronomy and astrophysics

Related fields in the same direction are covered too, using the closest checklists plus field-specific checks: for example robotics, embedded and edge AI, bioinformatics, medical imaging, remote sensing, computational chemistry and HCI. The full list, and how to add a field, is in [skill/references/domains.md](skill/references/domains.md).

The examining is done by an AI engine on the examiner's own subscription, chosen in **Settings → Examination Engine**: **Claude** (through Claude Code) or **ChatGPT** (through OpenAI's Codex). You can be signed in to both and switch at any time, and pick any model and thoroughness your account offers. The app's interface and the reports themselves don't mention the engine.

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

1. **Reads everything.** The engine reads the full text and looks at figures and tables as page images. Tables lose their layout when the text is extracted, so they are judged from the page images.
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
| **At least one** examination engine, signed in | Does the examining | Install and sign in from **Settings → Examination Engine** (details below) |

Examination engines (one is enough, both are fine):

| Engine | Subscription | Installed by the app from | Signs in with |
|---|---|---|---|
| Claude (Claude Code 2.x) | Claude Pro or Max | Anthropic's installer (`claude.ai/install.sh`) | `claude auth login` |
| ChatGPT (Codex CLI) | ChatGPT Plus or Pro | OpenAI's official GitHub release, into `~/Library/Application Support/Laurea/bin` | `codex login` |

In Settings, each engine shows whether it is installed and signed in, with **Install** and **Sign In…** buttons. Sign-in opens Terminal with the engine's own sign-in command, which completes in your browser. If you're already signed in to Claude Code or Codex on this Mac, Laurea uses that sign-in. The model list comes live from your account.

No Python packages, pandoc or Homebrew are needed. The engine and all skill scripts use only Python's standard library, and the Word document is generated in Python. If `pypdf` happens to be installed, PDF text extraction uses it; otherwise it uses macOS's built-in PDFKit.

## Installing

1. Open `Laurea 1.3.dmg` and drag **Laurea** to **Applications**. The app is signed for local use only, so on another Mac, right-click it and choose **Open** the first time.
2. Open Laurea. The **Setup Assistant** guides you through the rest:
   - choose Claude and/or ChatGPT, then install and sign in from the app;
   - your name, institution and default degree;
   - your signature: drop an image or choose a file;
   - the marking weights.

Laurea starts blank: the app contains no examiner details. On first run it installs its examining standards (the skill) to `~/Library/Application Support/Laurea/skill` and links them where Claude Code finds skills. Your details, signature, calibration and examinations stay on your Mac.

## Building from source (developers)

```bash
git clone https://github.com/andreademarco86/laurea.git ~/Work/Laurea
```

```bash
cd ~/Work/Laurea
```

To work on the skill in place (instead of the copy the app installs), link the repository's `skill/` folder before the first launch:

```bash
mkdir -p ~/.claude/skills && ln -sfn "$PWD/skill" ~/.claude/skills/dissertation-examiner
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
   - Each change becomes a git commit in this repository, which you can review and undo from **History**.
   - A change that would break the app is rolled back automatically.
   - Push when you want the changes on GitHub.
8. **Choose the engine:** in **Settings → Examination Engine**, pick Claude or ChatGPT, the model and the thoroughness. New examinations use the current choice.
9. **Delete an examination:** right-click it in the sidebar and choose **Move to Trash…**, press **Delete** in the sidebar, or use the trash button in the toolbar (**⌘⌫**). Laurea asks for confirmation first; the files go to the Trash, so they can be restored, and the examination is removed from your calibration. A running examination must be stopped first.

## Where things are stored

| What | Where | In git? |
|---|---|---|
| Examinations: PDFs, reports (.md and .docx), working notes and logs | `~/Library/Application Support/Laurea/examinations/` | No |
| App settings, engine log, skill-chat history | `~/Library/Application Support/Laurea/` | No |
| Your name, institution, default degree and marking weights | `config.json` in the skill folder (set in the Setup Assistant or Settings) | No |
| Your signature | `templates/signature.png` in the skill folder (set in the Setup Assistant or Settings) | No |
| The examining standards (skill) installed by the app | `~/Library/Application Support/Laurea/skill` (developers: the repository's `skill/`, via the link) | Its own git history |
| Learned calibration and its history (these name students) | `skill/references/calibration-notes.md` and `calibration-history.json` | No |
| Your house rules | `skill/references/house-preferences.md` | Yes |
| The skill itself | `skill/` | Yes |

## Privacy

- Examinations, calibration data, your signature and your settings stay on your Mac and are never committed.
- Web searches during an examination use topics, method and dataset names, and the titles of cited papers. The originality screen adds at most 8 short phrases per dissertation. Searches never include the student's name, the supervisor, the institution or the PDF.
- During an examination, the engine can only work in that examination's folder and run the skill's own scripts.
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
```

## Development

- **Skill changes** take effect at the next examination, with no rebuild. Make them in the app's Examining Standards, or edit the files and commit as usual. Before each standards change, the app commits any pending skill edits as "Skill: changes made outside the app", so each change can be undone on its own.
- **Adding a field:** follow the template at the end of `skill/references/domains.md`, or ask for it in Examining Standards.
- **App or engine changes:** run `bash mac/build.sh`, then reinstall from the DMG.
- **Run the engine on its own:** `DE_PORT=8765 python3 engine/server.py`. It serves a JSON API on `127.0.0.1`. Every request other than a GET must include the header `X-DE-App: 1`.
- **Screenshots without Screen Recording permission:** run `DE_SNAPSHOT_DIR=/some/folder mac/build/Laurea.app/Contents/MacOS/Laurea`. The app captures its own main screens to that folder, then quits. Add `DE_SNAPSHOT_DARK=1` for dark mode.
- **Using the skill without the app:** in Claude Code, run `/dissertation-examiner path/to/thesis.pdf --level msc`.

### Work in progress

- **ChatGPT engine.** Installing, signing in, listing models and short runs through ChatGPT are tested. A full examination on ChatGPT has not been run yet, and the skill was tuned on Claude, so ChatGPT reports may need some calibration at first.


## Troubleshooting

- **"The examination engine could not start":** check that the Command Line Tools are installed (`xcode-select -p`), then read `~/Library/Application Support/Laurea/engine.log`.
- **An examination stops at once with "not set up":** the chosen engine isn't installed or signed in. Open **Settings → Examination Engine** and use **Install** or **Sign In…**, or choose the other engine.
- **ChatGPT fails with "code-mode host was not found":** Codex is missing its companion program. Click **Install** again in Settings; it fetches both parts.
- **The signature is missing from the Word file:** add one in **Settings → Signature** (or the Setup Assistant) and save the report again. Without a signature, the report leaves a line to sign by hand.
- **The report checker reports wrong maxima:** the report was written for different weights from the examination's `scheme.json`. Revise the report, or run the examination again.
