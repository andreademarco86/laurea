#!/usr/bin/env bash
# Render the examiner's report Markdown to Word (.docx) with pandoc.
# Usage: render_report.sh <report.md> [reference.docx]
# A reference.docx (fonts, margins, university header) can be placed at
# ~/.claude/skills/dissertation-examiner/templates/reference.docx and is used automatically.
set -euo pipefail
in="$1"
out="${in%.md}.docx"
ref="${2:-$HOME/.claude/skills/dissertation-examiner/templates/reference.docx}"
command -v pandoc >/dev/null || { echo "pandoc not found: install it (brew install pandoc) or submit the .md" >&2; exit 1; }
skill_templates="$HOME/.claude/skills/dissertation-examiner/templates"
args=(--from markdown --to docx -o "$out" --resource-path ".:$(dirname "$in"):$skill_templates")
[ -f "$ref" ] && args+=(--reference-doc "$ref")
pandoc "$in" "${args[@]}"
echo "wrote $out"
