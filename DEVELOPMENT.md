# Developing Laurea

## Build from source

Install Apple’s Command Line Tools, then run:

```bash
git clone https://github.com/andreademarco86/laurea.git
cd laurea
bash mac/build.sh
```

The build produces a universal app at `mac/build/Laurea.app` and a DMG in `dist/`. It bundles the tracked examiner skill, precompiled PDFKit helpers and a unique `build-id`. The version is set in `mac/build.sh`. Python’s standard library is sufficient. If `pypdf` or PyMuPDF is installed, the extraction script can also use it.

### Release checklist

1. On `development`, run `bash dev/check.sh --build`. All checks must pass.
2. Smoke-test the built app with a fresh data directory (see below): set up an engine, examine one short PDF, check the internal notes and a highlighted page reference, edit and save, try exporting before adding the viva mark (it should ask for it), export an undated report, export with the date turned off, and switch examinations during an export.
3. Update `CHANGELOG.md` and the version in `mac/build.sh`.
4. Merge `development` into `main`, tag the merge `vX.Y` and push the tag.
5. Create the GitHub Release from the tag, using the changelog entry as the notes. Upload `dist/Laurea X.Y.dmg` **renamed to `Laurea.dmg`**: the README download link uses that filename to serve the latest release.

## Repository layout

| Path | Purpose |
|---|---|
| `mac/Sources/` | SwiftUI interface, setup, settings, report and review editors, PDF viewer, calibration and teaching |
| `mac/build.sh` | Universal build, ad hoc signing and DMG packaging |
| `engine/server.py` | Loopback service that runs the selected engine (Claude Code, Codex or Gemini CLI) and manages reports and reviews, grading scales, venues, calibration and taught standards |
| `skill/SKILL.md` | Examiner workflow: three independent readings, the chair, report content and writing style |
| `skill/references/` | Marking rubric and default grading scale, field checklists and house preferences |
| `skill/templates/` | Report template (owned by the app: the editor, checker and Word export depend on its sections) |
| `skill/paper/` | Paper review workflow (`SKILL.md`), its rubric, the review template, and `venues.json`, the venue database |
| `skill/scripts/` | PDF extraction and rendering, integrity, report and review checks, Word generation and benchmarking |
| `dev/` | Offline checks (`check.sh`, `engine_checks.py`) and the sample report fixture |

## Local development

- **Check before committing or merging** with `bash dev/check.sh` (about 15 seconds). It type-checks the Swift with the Command Line Tools (catching APIs such as `@State` that need Xcode's macro plugin), compiles the engine and skill scripts, checks shell syntax, validates the bundled skill, runs the report checker and Word writer on `dev/fixtures/sample-report.md`, and runs offline engine logic checks in a temporary data folder. It uses no PDFs, network or assistant sessions. Add `--build` to also build the DMG.
- **The standards live in the app.** Laurea reads `skill/` from the app bundle (or the repository when the engine runs from source). The data directory holds only examinations, settings, signature, calibration and taught revisions. When a build with a new `build-id` first runs, it clears taught revisions, the teaching chat and copies left by older versions. From source, the `build-id` is a hash of the standards, so editing them has the same effect.
- **Test with a fresh data directory** to see a first run:
  ```bash
  LAUREA_DATA_DIR=/path/to/laurea-test-data mac/build/Laurea.app/Contents/MacOS/Laurea
  ```
- **Gemini CLI** is installed from the official npm package into `bin/gemini-cli` with a launcher, using Node.js 20+ (Laurea downloads the LTS release when none is found). Its sign-in lives in `engine-accounts/gemini/.gemini`. Each run gets a private `GEMINI_CLI_HOME` holding Laurea's settings for that run (allowed tools and scripts, sandboxed shell, no telemetry, extensions or MCP servers) and a copy of the sign-in; a refreshed sign-in is copied back and the folder is deleted. Runs decline Google's consent prompt, so an expired sign-in fails at once instead of waiting.
- **Add a field** by following the template in [the field guide](skill/references/domains.md).
- **Add or update a venue** in [`skill/paper/venues.json`](skill/paper/venues.json). Each venue has a stable `id` (never change one: reviews refer to it), its kind, its recommendation scale best first with a `tone` per option (`accept`, `borderline`, `revise` or `reject`), its scores and confidence scale, `form_fields` that map the review's parts onto the venue's own form, and its reviewer `policy` (`permitted`, `disclose`, `restricted`, `prohibited` or `unknown`, with a plain-language summary). The policy is reference data: the app shows one general note on refereeing instead of each venue's policy. Set `form` to `published` only when the scale and fields come from the venue's own public pages, `partial` when the form is not public, and list the `sources`. Journals that share a publisher's process can refer to a shared form with `{"$ref": "ieee"}`. Update `checked` at the top, then run `bash dev/check.sh`: it validates every venue.
- **Run the engine on its own** with `DE_PORT=8765 python3 engine/server.py`. It listens on `127.0.0.1`. Send the `X-DE-App` header with the value of `DE_APP_TOKEN`, which defaults to `1` for a standalone engine.
- **Capture screenshots** with `DE_SNAPSHOT_DIR=/path/to/screenshots mac/build/Laurea.app/Contents/MacOS/Laurea`. Add `DE_SNAPSHOT_DARK=1` for dark mode.
- **Paper reviews** share the extraction, rendering and checking scripts with examinations. A review's folder has `kind: review` in `status.json`, a `venue.json` snapshot of its venue, `<stem>_paper_review.md` and `<stem>_review_work/`. Paper calibration is one tendency across venues, stored as a share of each scale's span in `paper-calibration-history.json`.
- **Run the skill in Claude Code** by linking `skill/` to `~/.claude/skills/dissertation-examiner`, then `/dissertation-examiner path/to/thesis.pdf --level msc`. Without Laurea's run instructions it uses the defaults: the University of Malta scale, the default weights and a 350-word summary. Standalone runs can enable external research for citation verification and repository checks.

## Benchmark draft marks

After saving final reports, run:

```bash
python3 skill/scripts/benchmark.py "$HOME/Library/Application Support/Laurea/examinations"
```

The script compares draft and final marks and writes `benchmark.md` with error, bias, grade agreement (on each examination's grading scale) and rank agreement by criterion and degree level. To measure a change to the standards, repeat the benchmark after re-examining the same dissertations.
