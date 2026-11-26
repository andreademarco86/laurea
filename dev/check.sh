#!/usr/bin/env bash
# Fast local checks before committing or merging. No PDFs, no network, no assistant sessions, no tokens.
# Usage: bash dev/check.sh            (about a minute; add --build to also build the DMG)
set -uo pipefail
cd "$(dirname "$0")/.."
export PYTHONPYCACHEPREFIX="${TMPDIR:-/tmp}/laurea-pycache"
fail=0
step() { printf '\n› %s\n' "$1"; }
result() { if [ "$1" -eq 0 ]; then echo "  ok"; else echo "  FAILED"; fail=1; fi; }

step "Swift: type-check the app (Command Line Tools, no Xcode macros)"
out=$(swiftc -typecheck -swift-version 5 -parse-as-library -target arm64-apple-macos14.0 mac/Sources/*.swift 2>&1 | grep -E "error:" | head -5)
[ -z "$out" ]; r=$?; [ -n "$out" ] && echo "$out"; result $r

step "Swift: type-check the PDF helpers"
r=0
for f in skill/scripts/*.swift; do swiftc -typecheck "$f" 2>&1 | grep -q "error:" && { echo "  $f"; r=1; }; done
result $r

step "Python: compile the engine and skill scripts"
python3 -m py_compile engine/server.py skill/scripts/*.py dev/engine_checks.py; result $?

step "Shell: syntax of build and skill scripts"
r=0; for f in mac/build.sh skill/scripts/*.sh dev/check.sh; do bash -n "$f" || r=1; done; result $r

step "Report checker and Word writer on the sample report"
tmp=$(mktemp -d)
cp dev/fixtures/sample-report.md dev/fixtures/scheme.json "$tmp/"
python3 skill/scripts/check_report.py "$tmp/sample-report.md" | tail -1 | grep -q "^OK" ; r1=$?
python3 skill/scripts/md_to_docx.py "$tmp/sample-report.md" "$tmp/sample-report.docx" >/dev/null && textutil -convert txt -stdout "$tmp/sample-report.docx" | grep -q "Sample Student"; r2=$?
rm -rf "$tmp"; [ $r1 -eq 0 ] && [ $r2 -eq 0 ]; result $?

step "Engine logic (temporary data folder)"
python3 dev/engine_checks.py; result $?

if [ "${1:-}" = "--build" ]; then
  step "Build the app and DMG"
  bash mac/build.sh 2>&1 | grep -E "✓|error" ; result "${PIPESTATUS[0]}"
fi

echo
if [ $fail -eq 0 ]; then echo "All checks passed."; else echo "Some checks failed."; fi
exit $fail
