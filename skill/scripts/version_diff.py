#!/usr/bin/env python3
"""What changed between two versions of a paper, from their extracted pages.txt files.

Usage: python3 version_diff.py <previous pages.txt> <revised pages.txt> <out.md>

Compares the two texts sentence by sentence and writes a Markdown summary: the page count, then the passages
added, removed and rewritten, each with the page where it sits (printed page labels, as in pages.txt). It is a map
for the reviewer, not a verdict: whether a change answers an earlier point is for the reviewer to judge.
"""
import difflib
import re
import sys

HEADER = re.compile(r"^===== \[PDF p\.(\d+) \| printed p\.([^\]]+)\] =====$", re.M)
MAX_RUNS = 120
MAX_CHARS = 600


def sentences(path):
    """(sentence, page label) pairs, whitespace-normalised."""
    text = open(path, encoding="utf-8", errors="replace").read()
    heads = list(HEADER.finditer(text))
    out = []
    for i, h in enumerate(heads):
        body = text[h.end(): heads[i + 1].start() if i + 1 < len(heads) else len(text)]
        label = h.group(2).strip()
        body = re.sub(r"-\n(?=[a-z])", "", body)  # rejoin hyphenated line breaks
        body = re.sub(r"\s+", " ", body).strip()
        for s in re.split(r"(?<=[.!?])\s+(?=[A-Z0-9(\[])", body):
            s = s.strip()
            if len(s) >= 3:
                out.append((s, label))
    return out, len(heads)


def clip(text):
    return text if len(text) <= MAX_CHARS else text[:MAX_CHARS].rsplit(" ", 1)[0] + " …"


def pages(labels):
    labels = list(dict.fromkeys(labels))
    return f"p. {labels[0]}" if len(labels) == 1 else f"pp. {labels[0]}–{labels[-1]}"


def main():
    if len(sys.argv) != 4:
        sys.exit(__doc__)
    old, old_pages = sentences(sys.argv[1])
    new, new_pages = sentences(sys.argv[2])
    norm = lambda s: re.sub(r"[^a-z0-9]+", " ", s.lower()).strip()  # noqa: E731
    matcher = difflib.SequenceMatcher(None, [norm(s) for s, _ in old], [norm(s) for s, _ in new], autojunk=False)
    runs, added, removed = [], 0, 0
    for tag, i1, i2, j1, j2 in matcher.get_opcodes():
        if tag == "equal":
            continue
        before, after = old[i1:i2], new[j1:j2]
        added += len(after)
        removed += len(before)
        if tag == "insert":
            runs.append(f"- **Added** ({pages([p for _, p in after])} of the revision): {clip(' '.join(s for s, _ in after))}")
        elif tag == "delete":
            runs.append(f"- **Removed** (was {pages([p for _, p in before])}): {clip(' '.join(s for s, _ in before))}")
        else:
            runs.append(f"- **Rewritten** (was {pages([p for _, p in before])}, now {pages([p for _, p in after])}):\n"
                        f"  - before: {clip(' '.join(s for s, _ in before))}\n"
                        f"  - after: {clip(' '.join(s for s, _ in after))}")
    similarity = matcher.ratio() if old and new else 0.0
    lines = ["# Changes between the versions", "",
             f"Previous version: {old_pages} pages, {len(old)} sentences. Revised version: {new_pages} pages, {len(new)} sentences.",
             f"About {similarity:.0%} of the text is unchanged; {removed} sentences were removed or rewritten and {added} added or rewritten.",
             "", "This is a map of where the text changed, not a judgement. Check each earlier point in the revised pages.", ""]
    if not runs:
        lines.append("No changes to the text were found. Figures, tables shown as images and equations may still have changed.")
    lines += runs[:MAX_RUNS]
    if len(runs) > MAX_RUNS:
        lines.append(f"- … and {len(runs) - MAX_RUNS} further changes, not listed.")
    with open(sys.argv[3], "w", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")
    print(f"{len(runs)} changed passages; {similarity:.0%} unchanged")


if __name__ == "__main__":
    main()
