# Laurea

**Laurea** is a native macOS app that drafts examiner's reports for **BSc, MSc and PhD** dissertations in ML/AI, with particular depth in computer vision and in ML for astronomy. It uses **Claude Opus 5.5** through Claude Code. The examiner reviews, calibrates, signs and exports the report as a Word document.

Every report follows the same structure:

- Student name, dissertation title and examiner.
- A recommended dissertation mark out of 90, split over five criteria:

| Criterion | Marks |
|---|---|
| (a) Introduction and overall document | 10 |
| (b) Literature review | 20 |
| (c) Method and solution | 25 |
| (d) Testing, results, analysis and evaluation | 25 |
| (e) Discussion, conclusion and future work | 10 |

- A viva mark out of 10, which is added after the oral, and the final mark out of 100.
- A summary of at most 250 words.
- Strengths and weaknesses for each criterion, with section and page references.
- 3 to 5 viva questions, each with what a good answer should cover.
- 5 to 10 minor corrections.
- Your signature and the date.

Claude examines to an international standard:
- It reads the whole dissertation, figures and tables included.
- It checks the method against ML, computer-vision and astronomy checklists.
- It searches the literature for current and missed work and verifies that cited references exist.
- It screens for originality at a high level.
- It writes plain, specific prose that cites pages.

---

## Requirements

| What | Why | Check |
|---|---|---|
| macOS 14 Sonoma or later | The app | |
| Xcode Command Line Tools | Builds the app; provides git and Swift | `xcode-select --install` |
| Python 3.9 or later | Runs the examination engine | `python3 --version` |
| pandoc | Produces the Word report | `brew install pandoc` |
| Claude Code 2.x, signed in | Does the examining | `npm install -g @anthropic-ai/claude-code`, then run `claude` once to sign in |

Optional: `pip install pypdf`. It makes PDF text extraction slightly cleaner; without it, the app uses macOS PDFKit.

## Setup

**1. Clone the repository**

```bash
git clone https://github.com/andreademarco86/examiner_report.git ~/Work/ExaminerReport
```

```bash
cd ~/Work/ExaminerReport
```

**2. Make the skill available to Claude Code**

The `skill/` folder is the examiner's knowledge: its instructions, rubric, checklists, report template and scripts. Claude Code loads it from `~/.claude/skills`, so link it there:

```bash
mkdir -p ~/.claude/skills && ln -sfn "$PWD/skill" ~/.claude/skills/dissertation-examiner
```

**3. Add your personal files**

These files are personal and are listed in `.gitignore`, so they are never committed:

- `skill/templates/signature.png`: your signature, as a PNG with a transparent or white background. It is placed in the Declaration section of every report.
- `skill/config.json`: your name, institution and default degree. It is created from `config.example.json` the first time the app runs; you can then edit it in the app under **Settings** (⌘,).

**4. Build and install the app**

```bash
bash mac/build.sh
```

This produces `dist/Laurea 1.2.dmg`. Open it and drag **Laurea** to **Applications**. The app is ad-hoc signed, so on another Mac, right-click the app and choose **Open** the first time.

## Using the app

1. **⌘N**, or drag PDFs onto the window, to add a dissertation.
2. Choose **BSc**, **MSc** or **PhD** and click **Examine**. This usually takes 20 to 60 minutes. A progress bar and checklist show which phase Claude is in.
3. Review the draft. Every field can be edited. Page references such as `p. 38` open the dissertation at that printed page in the side panel (**⌥⌘P**).
4. **Calibrate.** The **Overall** slider moves the whole mark up or down, spread over the criteria by weight; you can also adjust each criterion and add a short reason. Each save teaches Claude your calibration for that level. The **Calibration** view (⇧⌘K) shows what it has learned.
5. After the viva, enter the viva mark; the final mark out of 100 fills in. Turn the date on.
6. **⌘S** saves and updates the Word file. **⇧⌘E** exports it. **⇧⌘R** asks Claude to revise the report from a description.
7. **Examiner Skill** (⇧⌘L): ask Claude, in plain words, to change how dissertations are examined. For example: "Be stricter about reproducibility" or "Always ask one viva question on ethics".

Each skill change is a git commit in this repository. You can review it and undo it from **History**, and a change that would break the app is rolled back automatically. Push when you want to keep the changes on GitHub.

## Privacy

- **Examinations** (the PDFs, reports and Claude's working notes) are stored in `~/Laurea/examinations/`. They are outside this repository and are never committed.
- **Calibration history and notes** name students, so they are not tracked in git either.
- **Web searches** during an examination use topics, method and dataset names, and the titles of cited papers. The originality screen adds at most 8 short phrases per dissertation. Searches never include the student's name, the supervisor, the institution or the PDF.
- **Claude's access** during an examination is limited to that examination's folder and the skill's own scripts.

## Repository layout

```
engine/server.py      Examination engine: a localhost JSON API started by the app. It runs Claude
                      Code headlessly and manages reports, calibration and skill versioning.
mac/Sources/          SwiftUI app: sidebar, report editor, PDF panel, calibration and skill chat.
mac/build.sh          Builds the universal app (Apple silicon and Intel) and the DMG.
mac/icon/             Generates the app icon.
skill/                The examiner skill, loaded by Claude Code through the symlink:
  SKILL.md              workflow, standards and writing style
  references/           marking rubric (BSc/MSc/PhD), ML/CV and astronomy checklists,
                        external research and originality rules, house preferences
  templates/            report template (plus your signature, which is not committed)
  scripts/              PDF extraction, page rendering, report checker, Word rendering
```

## Development

- **Skill changes** take effect at the next examination, with no rebuild. Make them through the app's skill chat, or edit the files and commit as usual.
- **App or engine changes:** run `bash mac/build.sh` and reinstall from the DMG.
- **Engine log:** `~/Laurea/engine.log`.
- **Using the skill without the app:** in Claude Code, run `/dissertation-examiner path/to/thesis.pdf --level msc`.

## Troubleshooting

- **"The examination engine could not start":** check that `python3` is installed and read `~/Laurea/engine.log`.
- **"Claude Code 2.x not found":** install or update Claude Code (`npm install -g @anthropic-ai/claude-code`) and run `claude` once to sign in.
- **No Word file:** install pandoc (`brew install pandoc`).
