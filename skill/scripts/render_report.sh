#!/usr/bin/env bash
# Render the examiner's report Markdown to Word (.docx). No external tools needed (pure Python).
# Usage: render_report.sh <report.md>
set -euo pipefail
in="$1"
out="${in%.md}.docx"
here="$(cd "$(dirname "$0")" && pwd)"
templates="$(cd "$here/../templates" && pwd)"
python3 "$here/md_to_docx.py" "$in" "$out" --resource-path "$templates"
