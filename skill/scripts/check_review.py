#!/usr/bin/env python3
"""Structural checks for a paper review written from paper/templates/paper-review.md.

Usage: python3 check_review.py <review.md> [--venue <venue.json>] [--meta <work_dir>/meta.json]
The venue defaults to venue.json next to the review. Exit code 1 if any ERROR is found; WARNINGs should be
reviewed but do not fail.
"""
import json
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from page_labels import repair_labels  # noqa: E402
from scheme import load_summary_limit  # noqa: E402
from writing_checks import VAGUE, filler, long_sentences, process_mentions  # noqa: E402

errors, warnings = [], []
PAGE_REF = re.compile(r"(?<![A-Za-z])pp?\.[ \t]?((?:\d{1,4}|[ivxlc]{1,7})(?:[ \t]?[-–][ \t]?(?:\d{1,4}|[ivxlc]{1,7}))?)(?![\w])", re.I)
LOCATION = re.compile(r"§\s?\d|(?<![A-Za-z])pp?\.\s?\d|\b(?:Table|Tab\.|Fig(?:ure)?\.?|Eq(?:uation)?\.?|Algorithm|Alg\.|Appendix|Section|Sec\.)\s?[A-Z]?\d"
                      r"|\bL{1,2}\.\s?\d|\blines?\s\d", re.I)
SECTIONS = ["Summary", "Scores", "Strengths", "Weaknesses", "Questions for the authors", "Required changes",
            "Limitations and broader impact", "Ethical concerns", "Confidential comments to the area chair or editor"]


def section(text, title):
    m = re.search(rf"^## \d+\.\s*{re.escape(title)}\s*$", text, re.M | re.I)
    if not m:
        return None
    rest = text[m.end():]
    e = re.search(r"^## ", rest, re.M)
    return rest[: e.start()] if e else rest


def subsection(block, title):
    m = re.search(rf"^### {re.escape(title)}\s*$", block or "", re.M | re.I)
    if not m:
        return None
    rest = block[m.end():]
    e = re.search(r"^##", rest, re.M)
    return rest[: e.start()] if e else rest


def numbered(block):
    return re.findall(r"^\s*\d+\.\s+(\S.*)$", block or "", re.M)


def header(text, field):
    m = re.search(rf"^\|\s*\*\*{re.escape(field)}\*\*\s*\|\s*(.*?)\s*\|\s*$", text, re.M)
    return m.group(1).strip() if m else None


def option_matches(entry, options):
    """The option an entry like '4: Borderline accept' names, or None."""
    value, _, label = (entry or "").partition(":")
    value, label = value.strip().strip("*"), label.strip().strip("*").lower()
    for i, o in enumerate(options):
        if value == str(o["value"]) and (not label or label == str(o["label"]).lower()):
            return i
    for i, o in enumerate(options):  # the label alone, e.g. 'Major revision'
        if (entry or "").strip().strip("*").lower() == str(o["label"]).lower():
            return i
    return None


def named_options(paragraph, options):
    """Indices of the options a paragraph names in words, longest labels first so 'weak accept' is not read as 'accept'."""
    text, found = paragraph.lower(), []
    for i in sorted(range(len(options)), key=lambda i: -len(str(options[i]["label"]))):
        words = str(options[i]["label"]).lower()
        variants = [words] + {"accept": ["acceptance"], "reject": ["rejection"]}.get(words, [])
        for v in variants:
            pattern = rf"(?<![\w-]){re.escape(v)}(?![\w-])"
            if re.search(pattern, text):
                found.append(i)
                text = re.sub(pattern, " ", text)
    return found


def main():
    args = sys.argv[1:]
    if not args:
        sys.exit(__doc__)
    path = args[0]
    venue_path = args[args.index("--venue") + 1] if "--venue" in args else os.path.join(os.path.dirname(os.path.abspath(path)), "venue.json")
    try:
        with open(venue_path, encoding="utf-8") as f:
            venue = json.load(f)
    except Exception:
        venue = None
        errors.append(f"venue file not found or unreadable: {venue_path}")
    meta = None
    if "--meta" in args:
        with open(args[args.index("--meta") + 1], encoding="utf-8") as f:
            meta = json.load(f)
    text = open(path, encoding="utf-8").read()
    if venue:
        print(f"venue: {venue.get('name')} ({venue.get('kind')})")

    left = re.findall(r"\{\{[^}]*\}\}", text)
    if left:
        errors.append(f"{len(left)} unfilled template placeholder(s), e.g. {left[0][:60]}")

    # Header
    if not header(text, "Paper"):
        errors.append("header field 'Paper' missing or empty")
    tone = None
    if venue:
        rec = header(text, "Recommendation")
        options = venue["recommendation"]["options"]
        i = option_matches(rec, options)
        if i is None:
            errors.append(f"recommendation '{rec}' is not an option on the venue's scale; use one of: "
                          + "; ".join(f"{o['value']}: {o['label']}" for o in options))
        else:
            tone = options[i].get("tone")
            print(f"recommendation: {options[i]['value']}: {options[i]['label']}")
        conf = venue.get("confidence")
        entry = header(text, "Confidence")
        if conf and option_matches(entry, conf["options"]) is None:
            errors.append(f"confidence '{entry}' is not an option on the venue's scale; use one of: "
                          + "; ".join(f"{o['value']}: {o['label']}" for o in conf["options"]))

    for title in SECTIONS:
        if section(text, title) is None:
            errors.append(f"section '## N. {title}' missing")

    # Summary
    summ = section(text, "Summary")
    if summ is not None:
        n = len(re.findall(r"[A-Za-z0-9][\w'’.%/-]*", re.sub(r"[*_`#>]", " ", summ)))
        limit = load_summary_limit(path)
        if n > limit:
            errors.append(f"summary has {n} words (> {limit})")
        elif n < int(limit * 0.85):
            warnings.append(f"summary has only {n} words; use close to the limit ({int(limit * 0.9)}-{limit})")
        else:
            print(f"summary: {n} words")
        paragraphs = [p for p in re.split(r"\n\s*\n", summ.strip()) if p.strip()]
        if len(paragraphs) < 3:
            warnings.append(f"summary has {len(paragraphs)} paragraph(s); end with a separate overall assessment")
        elif len(re.findall(r"[.?](?:\s|$)", paragraphs[-1].strip())) < 4:
            warnings.append("the summary's closing assessment is too short; write four to six plain sentences")
        if venue and tone is not None and paragraphs:
            named = named_options(paragraphs[-1], venue["recommendation"]["options"])
            current = option_matches(header(text, "Recommendation"), venue["recommendation"]["options"])
            label = venue["recommendation"]["options"][current]["label"]
            others = [venue["recommendation"]["options"][i]["label"] for i in named if i != current]
            if others and current not in named:
                warnings.append(f"the summary's closing assessment recommends '{others[0]}', but the recommendation is '{label}'")
            elif current not in named:
                warnings.append(f"the summary's closing assessment does not state the recommendation; end it with, e.g., 'I recommend {label.lower()}.'")
        if PAGE_REF.search(summ) or "§" in summ or re.search(r"\bL\.\s?\d|\blines?\s\d", summ):
            errors.append("the summary contains page, section or line references; remove them (they belong in the points below)")

    # Scores
    scores = section(text, "Scores")
    if venue and scores is not None:
        if venue.get("scores"):
            for s in venue["scores"]:
                m = re.search(rf"^\|\s*{re.escape(s['name'])}\s*\|\s*(.*?)\s*\|\s*$", scores, re.M | re.I)
                if not m:
                    errors.append(f"score '{s['name']}' missing from the Scores table")
                elif option_matches(m.group(1), s["options"]) is None:
                    errors.append(f"score '{s['name']}' is '{m.group(1)}'; use one of: "
                                  + "; ".join(f"{o['value']}: {o['label']}" for o in s["options"]))
        elif not re.search(r"no separate scores", scores, re.I):
            warnings.append("this venue has no separate scores; write 'No separate scores for this venue.'")

    # Strengths and weaknesses
    strengths, weaknesses = numbered(section(text, "Strengths")), numbered(section(text, "Weaknesses"))
    if len(strengths) < 2:
        errors.append(f"{len(strengths)} strength(s); list at least two, most important first")
    if len(weaknesses) < 2:
        errors.append(f"{len(weaknesses)} weakness(es); list at least two, most important first")
    for name, items in (("strength", strengths), ("weakness", weaknesses)):
        for it in items:
            if not LOCATION.search(it):
                warnings.append(f"{name} without a location (§, page, table, figure or line): {it[:70]}...")

    # Questions
    questions = numbered(section(text, "Questions for the authors"))
    if not questions:
        errors.append("no questions for the authors; ask three to six whose answers could change your assessment")
    elif not 3 <= len(questions) <= 6:
        warnings.append(f"{len(questions)} questions for the authors; three to six is usual")

    # Required changes
    changes = section(text, "Required changes")
    cited = set()
    for tier in ("Major", "Moderate", "Minor"):
        block = subsection(changes, tier)
        if block is None:
            errors.append(f"required changes: '### {tier}' missing")
            continue
        items = numbered(block)
        if not items and not re.search(r"\bnone\b", block, re.I):
            errors.append(f"{tier.lower()} changes are empty; list them or write 'None required.'")
        for it in items:
            refs = [int(x) for x in re.findall(r"\(W(\d+)\)", it)]
            cited.update(refs)
            if tier != "Minor" and not refs:
                warnings.append(f"{tier.lower()} change does not say which weakness it addresses, e.g. (W1): {it[:60]}...")
            for r in refs:
                if not 1 <= r <= len(weaknesses):
                    errors.append(f"{tier.lower()} change cites W{r}, but there are {len(weaknesses)} weaknesses")
            v = VAGUE.search(it)
            if v:
                warnings.append(f"{tier.lower()} change is vague ('{v.group(0)}'); say exactly what to do: {it[:60]}...")
        if tier == "Minor" and items and len(items) < 3:
            warnings.append(f"{len(items)} minor change(s); list the quick fixes you found (typically 5-15)")
        if tier == "Major" and venue:
            if tone == "accept" and len(items) >= 3:
                warnings.append(f"{len(items)} major changes with an accepting recommendation; check that the recommendation and the changes agree")
            if tone == "reject" and not items and len(weaknesses) < 3:
                warnings.append("a rejecting recommendation with no major changes and few weaknesses; check that they agree")
    for q in questions:
        refs = [int(x) for x in re.findall(r"\(W(\d+)\)", q)]
        cited.update(refs)
        for r in refs:
            if not 1 <= r <= len(weaknesses):
                errors.append(f"a question cites W{r}, but there are {len(weaknesses)} weaknesses")
    unaddressed = [f"W{i}" for i in range(1, len(weaknesses) + 1) if i not in cited]
    if unaddressed and len(unaddressed) == len(weaknesses):
        warnings.append("no change or question refers to a weakness; tie each major and moderate change to the weakness it fixes, e.g. (W1)")
    elif unaddressed:
        print("weaknesses without a change or question (fine if they cannot be fixed): " + ", ".join(unaddressed))

    for title in ("Limitations and broader impact", "Ethical concerns", "Confidential comments to the area chair or editor"):
        block = section(text, title)
        if block is not None and not block.strip():
            errors.append(f"section '{title}' is empty; write what applies or 'None.'")

    # Style, voice and anonymity
    confidential = section(text, "Confidential comments to the area chair or editor") or ""
    body = re.sub(r"^(?:\||#).*$", "", text.replace(confidential, ""), flags=re.M)  # skip the header table and headings
    hits = filler(body)
    if hits:
        warnings.append("filler/AI-sounding phrasing, rewrite plainly: " + ", ".join(f"'{k}' x{v}" for k, v in hits.items()))
    process = process_mentions(body, ["panel", "area chair", "chair", "reviewers", "other reviewers", "meta-reviewer",
                                      "expert review", "three reviewers"])
    if process:
        warnings.append("the review refers to a process behind it (" + ", ".join(process) + "); write as the reviewer, in the first person")
    identity = sorted({m.group(0).lower() for m in re.finditer(
        r"\b(?:my|our) (?:own )?(?:previous|earlier|prior|recent) (?:work|paper|papers|study)\b|\bI (?:published|proposed) (?:in|a)\b", body, re.I)})
    if identity:
        warnings.append("the review may reveal who you are (" + ", ".join(identity) + "); reviews are anonymous")
    long_s = long_sentences(body)
    if long_s:
        warnings.append(f"{len(long_s)} sentence(s) over 40 words, e.g. '{long_s[0][:80]}...'")

    # Page references exist in the PDF
    if meta:
        labels = meta.get("page_labels", [])
        if meta.get("label_source") == "heuristic-from-text":
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
