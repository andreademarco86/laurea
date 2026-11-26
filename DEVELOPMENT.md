# Developing Laurea

## Build from source

Install Apple’s Command Line Tools, then run:

```bash
git clone https://github.com/andreademarco86/laurea.git
cd laurea
bash mac/build.sh
```

The build produces a universal app at `mac/build/Laurea.app` and a DMG in `dist/`. It bundles the tracked examiner skill and precompiled PDFKit helpers. Python’s standard library is sufficient. If `pypdf` or PyMuPDF is installed, the extraction script can also use it.

### Release checklist

1. On `development`, run `bash dev/check.sh --build`. All checks must pass.
2. Smoke-test the built app with a fresh data directory (see below): set up an engine, examine one short PDF, edit and save, export an undated report, export with the date turned off, and switch examinations during an export.
3. Update `CHANGELOG.md` and the version in `mac/build.sh`.
4. Merge `development` into `main`, tag the merge `vX.Y` and push the tag.
5. Create the GitHub Release from the tag, using the changelog entry as the notes. Upload `dist/Laurea X.Y.dmg` **renamed to `Laurea.dmg`**: the README download link uses that filename to serve the latest release.

## Repository layout

| Path | Purpose |
|---|---|
| `mac/Sources/` | SwiftUI interface, setup, report editor, PDF viewer, calibration and teaching |
| `mac/build.sh` | Universal build, ad hoc signing and DMG packaging |
| `engine/server.py` | Loopback service that runs the selected engine and manages report files, calibration and standards |
| `skill/SKILL.md` | Examiner workflow and reporting instructions |
| `skill/references/` | Marking rubric, field checklists and house preferences |
| `skill/templates/` | Word report source template |
| `skill/scripts/` | PDF extraction and rendering, integrity and report checks, Word generation and benchmarking |

## Local development

- **Check before committing or merging** with `bash dev/check.sh` (about 15 seconds). It type-checks the Swift with the Command Line Tools (catching APIs such as `@State` that need Xcode's macro plugin), compiles the engine and skill scripts, checks shell syntax, validates the bundled skill, runs the report checker and Word writer on `dev/fixtures/sample-report.md`, and runs offline engine logic checks in a temporary data folder. It uses no PDFs, network or assistant sessions. Add `--build` to also build the DMG.
- **Scripts reach existing installations automatically.** Each examination uses the app's bundled `skill/scripts`; only the standards (SKILL.md, references, template) stay as installed and taught.
- **Test bundled standards** with a fresh data directory. Existing installations preserve their installed standards, local teaching and preferences.
  ```bash
  LAUREA_DATA_DIR=/path/to/laurea-test-data mac/build/Laurea.app/Contents/MacOS/Laurea
  ```
- **Add a field** by following the template in [the field guide](skill/references/domains.md).
- **Run the engine on its own** with `DE_PORT=8765 python3 engine/server.py`. It listens on `127.0.0.1`. Send the `X-DE-App` header with the value of `DE_APP_TOKEN`, which defaults to `1` for a standalone engine.
- **Capture screenshots** with `DE_SNAPSHOT_DIR=/path/to/screenshots mac/build/Laurea.app/Contents/MacOS/Laurea`. Add `DE_SNAPSHOT_DARK=1` for dark mode.
- **Run the installed skill in Claude Code** with `/dissertation-examiner path/to/thesis.pdf --level msc`. Standalone runs can enable external research for citation verification and repository checks.

## Benchmark draft marks

After saving final reports, run:

```bash
python3 skill/scripts/benchmark.py "$HOME/Library/Application Support/Laurea/examinations"
```

The script compares draft and final marks and writes `benchmark.md` with error, bias, band agreement and rank agreement by criterion and degree level. To measure a change to the standards, repeat the benchmark after re-examining the same dissertations.
