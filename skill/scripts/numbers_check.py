#!/usr/bin/env python3
"""Check that numbers claimed in the abstract and conclusions appear in the results.

Usage: python3 numbers_check.py <work_dir> --claims "i-iii,85-90" --results "40-80"

Page ranges are PRINTED page numbers (resolved through <work_dir>/meta.json from extract_pdf.py).
Every percentage and decimal number on the claims pages is looked up in the results pages, allowing
equivalent forms (12.3% = 0.123, 12.30 = 12.3). Writes numbers.md listing the claimed numbers that
do not appear in the results, with context, so they can be checked against the tables by eye.
Standard library only.
"""
import json
import os
import re
import sys

NUM = re.compile(r"(?<![\w.])(\d{1,3}(?:,\d{3})*(?:\.\d+)?|\d*\.\d+)\s*(%|percent|pp\b)?", re.I)


def pages_by_label(work):
    meta = json.load(open(os.path.join(work, "meta.json"), encoding="utf-8"))
    labels = [str(x).lower() for x in meta["page_labels"]]
    text = open(os.path.join(work, "pages.txt"), encoding="utf-8").read()
    chunks = re.split(r"^===== \[PDF p\.(\d+) \| printed p\.[^\]]*\] =====$", text, flags=re.M)
    by_index = {int(chunks[i]): chunks[i + 1] for i in range(1, len(chunks) - 1, 2)}
    return labels, by_index


def resolve(spec, labels):
    """'i-iii,85-90' -> list of PDF page indices (1-based)."""
    out = []
    for part in (spec or "").split(","):
        part = part.strip().lower()
        if not part:
            continue
        lo, _, hi = part.partition("-")
        if lo not in labels:
            sys.exit(f"printed page {lo} not found in meta.json")
        i = labels.index(lo)
        j = labels.index(hi) if hi and hi in labels else i
        out.extend(range(i + 1, j + 2))
    return out


def variants(value, is_pct):
    """Equivalent spellings of a number to look for in the results."""
    v = float(value.replace(",", ""))
    forms = set()
    for x in ([v, v / 100] if is_pct else [v, v * 100, v / 100]):
        for d in range(0, 5):
            forms.add(f"{x:.{d}f}")
    forms.add(value)
    return {f for f in forms if f not in ("0", "0.0", "0.00", "0.000", "0.0000")}


def main():
    args = sys.argv[1:]
    if len(args) < 5 or "--claims" not in args or "--results" not in args:
        sys.exit(__doc__)
    work = args[0]
    labels, pages = pages_by_label(work)
    claims = resolve(args[args.index("--claims") + 1], labels)
    results = resolve(args[args.index("--results") + 1], labels)
    results_text = " ".join(pages.get(i, "") for i in results)
    results_nums = {m.group(1).replace(",", "") for m in NUM.finditer(results_text)}

    missing, checked = [], 0
    for i in claims:
        t = pages.get(i, "")
        for m in NUM.finditer(t):
            value, unit = m.group(1), (m.group(2) or "")
            plain = value.replace(",", "")
            # skip years, section numbers, small integers and page/figure references
            if re.fullmatch(r"(19|20)\d\d", plain) or ("." not in plain and not unit):
                continue
            before = t[max(0, m.start() - 12):m.start()].lower()
            if re.search(r"(section|chapter|fig\.?|figure|table|eq\.?|p\.|pp\.|§)\s*$", before):
                continue
            checked += 1
            if not (variants(plain, bool(unit)) & results_nums):
                ctx = re.sub(r"\s+", " ", t[max(0, m.start() - 90):m.end() + 90]).strip()
                missing.append((labels[i - 1] or f"PDF {i}", value + (unit or ""), ctx))

    with open(os.path.join(work, "numbers.md"), "w", encoding="utf-8") as f:
        f.write("# Numbers check\n\n")
        f.write(f"{checked} percentages and decimal numbers checked on the claims pages; "
                f"{len(missing)} do not appear in the results pages.\n\n")
        if missing:
            f.write("Check each against the results tables and figures by eye (tables extract imperfectly, and some numbers "
                    "may legitimately come from the literature). A claimed result that the results do not support is a "
                    "weakness in (d) or (e).\n\n| Printed page | Number | Context |\n|---|---|---|\n")
            for p, n, c in missing:
                f.write(f"| {p} | {n} | {c.replace('|', '/')} |\n")
    print(f"numbers: {checked} checked, {len(missing)} not found in the results - see numbers.md")


if __name__ == "__main__":
    main()
