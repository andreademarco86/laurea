#!/usr/bin/env python3
"""Structural checks for an examiner's report written from templates/examiner-report.md.

Usage: python3 check_report.py <report.md> [--meta <work_dir>/meta.json]
Exit code 1 if any ERROR is found. WARNINGs should be reviewed but do not fail.
"""
import json
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from page_labels import repair_labels  # noqa: E402
from scheme import KEYS, dissertation_max, load_scheme, load_summary_limit  # noqa: E402

MAX = {}  # filled from the marking scheme in main()
errors, warnings = [], []
PAGE_REF = re.compile(r"(?<![A-Za-z])pp?\.[ \t]?((?:\d{1,4}|[ivxlc]{1,7})(?:[ \t]?[-–][ \t]?(?:\d{1,4}|[ivxlc]{1,7}))?)(?![\w])", re.I)


def section(text, start_pat, end_pat=r"^## "):
    m = re.search(start_pat, text, re.M)
    if not m:
        return None
    rest = text[m.end():]
    e = re.search(end_pat, rest, re.M)
    return rest[: e.start()] if e else rest


VIVA_QUESTIONS = {"bsc": (3, 5), "msc": (4, 6), "phd": (8, 10)}


def report_level(path, text):
    """bsc, msc or phd: from the examination's status.json next to the report, else the report title (default msc)."""
    try:
        with open(os.path.join(os.path.dirname(os.path.abspath(path)), "status.json"), encoding="utf-8") as f:
            level = json.load(f).get("level")
        if level in VIVA_QUESTIONS:
            return level
    except Exception:
        pass
    m = re.search(r'^title:\s*"?([^"\n]*)', text[:300], re.M)
    title = (m.group(1) if m else "").lower()
    return "phd" if "phd" in title or "thesis" in title else "bsc" if "bsc" in title else "msc"


def bullets(block):
    return [l for l in block.splitlines() if re.match(r"^\s*[-*]\s+\S", l)]


def main():
    args = sys.argv[1:]
    if not args:
        sys.exit(__doc__)
    path = args[0]
    meta = None
    if "--meta" in args:
        with open(args[args.index("--meta") + 1], encoding="utf-8") as f:
            meta = json.load(f)
    text = open(path, encoding="utf-8").read()
    scheme = load_scheme(path)
    MAX.update({k: scheme[k] for k in KEYS})
    DMAX, VMAX = dissertation_max(scheme), scheme["viva"]
    print(f"scheme: " + ", ".join(f"({k}) {MAX[k]}" for k in KEYS) + f"; dissertation /{DMAX}; viva /{VMAX}")

    # Unfilled template slots
    left = re.findall(r"\{\{[^}]*\}\}", text)
    if left:
        errors.append(f"{len(left)} unfilled template placeholder(s), e.g. {left[0]}")

    # Header fields
    for field in ("Student name", "Dissertation title", "Examiner"):
        m = re.search(rf"\*\*{field}\*\*\s*\|\s*(.*?)\s*\|", text)
        if not m or not m.group(1).strip():
            errors.append(f"header field '{field}' missing or empty")
    m = re.search(rf"\*\*Recommended dissertation mark\*\*\s*\|\s*\*\*(\d+)\s*/\s*{DMAX}\*\*", text)
    header_total = int(m.group(1)) if m else None
    if header_total is None:
        errors.append(f"recommended mark '**N / {DMAX}**' not found in header")
    if not re.search(rf"\*\*Viva mark\*\*\s*\|\s*(?:_+|\*\*[\d.]+)\s*/\s*{VMAX}\b", text):
        errors.append(f"viva mark row ('______ / {VMAX}' or a filled-in mark) missing")
    if not re.search(r"\*\*Final mark\*\*\s*\|\s*(?:_+|\*\*[\d.]+)\s*/\s*100", text):
        errors.append("final mark row ('______ / 100' or a filled-in mark) missing")

    # Summary
    summ = section(text, r"^## 1\. Summary\s*$")
    if summ is None:
        errors.append("section '## 1. Summary' missing")
    else:
        words = re.findall(r"[A-Za-z0-9][\w'’.%/-]*", re.sub(r"[*_`#>]", " ", summ))
        n = len(words)
        limit = load_summary_limit(path)
        if n > limit:
            errors.append(f"summary has {n} words (> {limit})")
        elif n < int(limit * 0.85):
            warnings.append(f"summary has only {n} words; use close to the limit ({int(limit * 0.9)}-{limit})")
        else:
            print(f"summary: {n} words")
        paragraphs = [p for p in re.split(r"\n\s*\n", summ.strip()) if p.strip()]
        if len(paragraphs) < 3:
            warnings.append(f"summary has {len(paragraphs)} paragraph(s); end with a separate short summative assessment")
        elif len(re.findall(r"[.?](?:\s|$)", paragraphs[-1].strip())) < 4:
            warnings.append("the summary's final summative paragraph is too short; write four to six plain sentences")

        # The summary is a readable overview: page and section references belong in the criterion comments.
        if PAGE_REF.search(summ) or re.search(r"§", summ):
            errors.append("the summary contains page or section references; remove them (they belong in the criterion comments)")
        # The summary refers to "the candidate", never to the student by name.
        m = re.search(r"\*\*Student name\*\*\s*\|\s*(.*?)\s*\|", text)
        parts = [p for p in re.findall(r"[^\W\d_][\w'’-]*", m.group(1) if m else "") if len(p) >= 3 and p[0].isupper()]
        named = sorted({p for p in parts if re.search(rf"\b{re.escape(p)}\b", summ)})
        if named:
            errors.append(f"summary names the student ({', '.join(named)}); write 'the candidate' instead")

    # Criterion marks
    marks = {}
    for k in MAX:
        h = re.search(rf"^### \({k}\)[^\n]*?[-–—]\s*(\d+)\s*/\s*(\d+)\s*$", text, re.M)
        if not h:
            errors.append(f"criterion ({k}) heading with 'N/{MAX[k]}' not found")
            continue
        mark, mx = int(h.group(1)), int(h.group(2))
        if mx != MAX[k]:
            errors.append(f"criterion ({k}) is out of {mx}, expected {MAX[k]}")
        if not 0 <= mark <= MAX[k]:
            errors.append(f"criterion ({k}) mark {mark} outside 0-{MAX[k]}")
        marks[k] = mark
        row = re.search(rf"^\|\s*\({k}\)[^|]*\|\s*\**{MAX[k]}\**\s*\|\s*\**(\d+)\**\s*\|", text, re.M)
        if row and int(row.group(1)) != mark:
            errors.append(f"criterion ({k}): table says {row.group(1)}, heading says {mark}")
        body = section(text, rf"^### \({k}\).*$", r"^#{2,3} ")
        st = section(body or "", r"^\*\*Strengths\*\*\s*$", r"^\*\*Weaknesses\*\*")
        wk = section(body or "", r"^\*\*Weaknesses\*\*\s*$", r"^#{2,3} |\Z")
        for name, blk in (("strengths", st), ("weaknesses", wk)):
            if blk is None:
                errors.append(f"criterion ({k}): '**{name.capitalize()}**' block missing")
                continue
            bl = bullets(blk)
            if not 2 <= len(bl) <= 3:
                errors.append(f"criterion ({k}): {len(bl)} {name}, expected 2-3")
            for b in bl:
                if not PAGE_REF.search(b):
                    warnings.append(f"criterion ({k}) {name} point has no page ref: {b.strip()[:70]}...")
    if len(marks) == 5:
        total = sum(marks.values())
        print("marks: " + ", ".join(f"({k}) {v}/{MAX[k]}" for k, v in marks.items()) + f" -> {total}/{DMAX}")
        if header_total is not None and header_total != total:
            errors.append(f"header total {header_total} != sum of criteria {total}")
        trow = re.search(rf"^\|\s*\*\*Total\*\*\s*\|\s*\**{DMAX}\**\s*\|\s*\**(\d+)\**\s*\|", text, re.M)
        if not trow or int(trow.group(1)) != total:
            errors.append(f"table Total row missing or != {total}")

    # Viva questions
    qs = section(text, r"^## 3\. Viva questions\s*$")
    if qs is None:
        errors.append("section '## 3. Viva questions' missing")
    else:
        qn = re.findall(r"^\*\*Q\d+\.", qs, re.M)
        lo, hi = VIVA_QUESTIONS[report_level(path, text)]
        if not lo <= len(qn) <= hi:
            errors.append(f"{len(qn)} viva questions, expected {lo}-{hi} at {report_level(path, text).upper()} level")
        exp = len(re.findall(r"Expected / acceptable answer", qs))
        if exp < len(qn):
            errors.append(f"{len(qn) - exp} viva question(s) without an expected/acceptable answer")

    # Substantial corrections: up to 5, or "None required."
    sc = section(text, r"^## \d+\. Substantial corrections\s*$")
    if sc is None:
        errors.append("section '## 4. Substantial corrections' missing")
    else:
        items = re.findall(r"^\s*\d+\.\s+\S.*$", sc, re.M)
        if len(items) > 5:
            errors.append(f"{len(items)} substantial corrections, expected at most 5 (larger problems belong in the weaknesses)")
        elif not items and not re.search(r"\bnone\b", sc, re.I):
            errors.append("substantial corrections section is empty; list them or write 'None required.'")
        for it in items:
            if not PAGE_REF.search(it):
                warnings.append(f"substantial correction without page ref: {it.strip()[:70]}")

    # Corrections are for the student: plain and direct
    VAGUE = re.compile(r"\b(consider|may wish|might want|could benefit|would benefit|could perhaps|enhanc\w*|robustness|rigou?r)\b", re.I)
    for name, block in (("substantial", sc), ("minor", section(text, r"^## \d+\. Minor corrections\s*$"))):
        for it in re.findall(r"^\s*\d+\.\s+(\S.*)$", block or "", re.M):
            v = VAGUE.search(it)
            if v:
                warnings.append(f"{name} correction is vague ('{v.group(0)}'); say exactly what to do: {it[:60]}...")

    # Minor corrections
    mc = section(text, r"^## \d+\. Minor corrections\s*$")
    if mc is None:
        errors.append("section '## 5. Minor corrections' missing")
    else:
        items = re.findall(r"^\s*\d+\.\s+\S.*$", mc, re.M)
        if not 5 <= len(items) <= 10:
            errors.append(f"{len(items)} minor corrections, expected 5-10")
        for it in items:
            if not PAGE_REF.search(it):
                warnings.append(f"correction without page ref: {it.strip()[:70]}")

    # Filler / AI-sounding phrasing (style warnings)
    SLOP = [r"\bdelv\w*", r"\bshowcas\w*", r"\bleverag(e|es|ed|ing)\b", r"\bcomprehensive\b", r"\bholistic\b",
            r"\bmeticulous\w*", r"\bseamless\w*", r"\bpivotal\b", r"\bcrucial role\b", r"\ba testament to\b",
            r"\bin the realm of\b", r"\blandscape\b", r"\btapestry\b", r"\bunderscor\w*", r"\bit is worth noting\b",
            r"\bit is important to note\b", r"\boverall,? the dissertation\b", r"\bnot only\b.{0,80}\bbut also\b",
            r"\bcutting[- ]edge\b", r"\bstate[- ]of[- ]the[- ]art\b(?![^.]*\b(table|fig|p\.))", r"^\s*[-*]?\s*(Furthermore|Moreover|Additionally),",
            r"!(?!\[)", r"\bClaude\b", r"\bAnthropic\b", r"\b(?:AI|LLM)[- ]generated\b", r"\blanguage model\b", r"\bas an AI\b", r"\bnavigat\w* the\b", r"\bintricate\b", r"\bnuanced\b", r"\bmultifaceted\b"]
    body = re.sub(r"^\|.*$", "", text, flags=re.M)  # skip header table
    hits = {}
    for pat in SLOP:
        for m in re.finditer(pat, body, re.I | re.M):
            hits.setdefault(m.group(0).strip()[:30].lower(), 0)
            hits[m.group(0).strip()[:30].lower()] += 1
    # The report is the examiner's own: no panel, chair or review process behind it
    process = sorted({m.group(0).lower() for m in re.finditer(
        r"\b(?:the|our|this) (?:panel|chair|examiners|examining panel|reviewers|expert review|marking panel)\b|\bthe three examiners\b",
        body, re.I)})
    if process:
        warnings.append("the report refers to a process behind it (" + ", ".join(process) + "); write as the examiner, in the first person")
    if hits:
        warnings.append("filler/AI-sounding phrasing, rewrite plainly: " + ", ".join(f"'{k}' x{v}" for k, v in hits.items()))
    long_s = [s_ for s_ in re.split(r"(?<=[.?])\s+", re.sub(r"\s+", " ", body)) if len(s_.split()) > 40]
    if long_s:
        warnings.append(f"{len(long_s)} sentence(s) over 40 words, e.g. '{long_s[0][:80]}...'")

    # Declaration
    for f in ("Signature:", "Date:"):
        if f not in text:
            errors.append(f"'{f}' placeholder missing")

    # Page references exist in the PDF
    if meta:
        labels = meta.get("page_labels", [])
        if meta.get("label_source") == "heuristic-from-text":  # guessed numbers: repair sequence breaks
            labels = repair_labels([str(l) for l in labels])
        labels = {str(l).lower() for l in labels if l}
        bad = set()
        for m in PAGE_REF.finditer(text):
            for part in re.split(r"[ \t]?[-–][ \t]?", m.group(1)):
                if part.lower() not in labels:
                    bad.add(part)
        for m in re.finditer(r"PDF p\.\s?(\d+)", text):
            if int(m.group(1)) > meta.get("page_count", 0):
                bad.add("PDF p." + m.group(1))
        if bad:
            errors.append("cited pages not found among the PDF's printed page numbers: " + ", ".join(sorted(bad)))

    for w in warnings:
        print("WARNING:", w)
    for e in errors:
        print("ERROR:", e)
    print("OK" if not errors else f"{len(errors)} error(s)")
    sys.exit(1 if errors else 0)


if __name__ == "__main__":
    main()
