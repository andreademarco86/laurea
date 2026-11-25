#!/usr/bin/env python3
"""Fill in the viva mark of an existing examiner's report and compute the final mark /100.

Usage: python3 add_viva_mark.py <report.md> <viva_mark 0-10>
Updates the Viva mark and Final mark rows in place (re-running replaces earlier values),
then re-render the Word copy with render_report.sh.
"""
import re
import sys

if len(sys.argv) != 3:
    sys.exit(__doc__)
path, raw = sys.argv[1], sys.argv[2]
try:
    viva = float(raw)
except ValueError:
    sys.exit(f"viva mark must be a number, got {raw!r}")
if not 0 <= viva <= 10:
    sys.exit("viva mark must be between 0 and 10")

text = open(path, encoding="utf-8").read()
m = re.search(r"\*\*Recommended dissertation mark\*\*\s*\|\s*\*\*(\d+(?:\.\d+)?)\s*/\s*90\*\*", text)
if not m:
    sys.exit("could not find '**Recommended dissertation mark** | **N / 90**' in the report")
diss = float(m.group(1))
fmt = lambda x: f"{x:g}"
total = diss + viva

text, n1 = re.subn(r"(\*\*Viva mark\*\*\s*\|\s*)[^|\n]*?(\s*\|)", rf"\g<1>**{fmt(viva)} / 10**\g<2>", text, count=1)
text, n2 = re.subn(r"(\*\*Final mark\*\*\s*\|\s*)[^|\n]*?(\s*\|)", rf"\g<1>**{fmt(total)} / 100**\g<2>", text, count=1)
if not (n1 and n2):
    sys.exit("could not find the 'Viva mark' and 'Final mark' rows in the report header")
open(path, "w", encoding="utf-8").write(text)
print(f"dissertation {fmt(diss)}/90 + viva {fmt(viva)}/10 = final {fmt(total)}/100")
