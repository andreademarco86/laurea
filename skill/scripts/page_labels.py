"""Repair printed page numbers guessed from page text.

A number read from a page can be wrong: a table row ("2 Mastery drops ...") or a contents entry can look like
a page number. Printed numbers run in sequence, so a guess that breaks the sequence around it is replaced by
the value its neighbours imply. Arabic and roman numbering are repaired separately.
"""
import re

ROMAN = {"i": 1, "v": 5, "x": 10, "l": 50, "c": 100, "d": 500, "m": 1000}


def _roman_value(s):
    if not s or not re.fullmatch(r"[ivxlcdm]+", s):
        return None
    total, prev = 0, 0
    for ch in reversed(s):
        v = ROMAN[ch]
        total = total - v if v < prev else total + v
        prev = max(prev, v)
    return total if total > 0 else None


def _to_roman(n):
    out = ""
    for v, r in ((1000, "m"), (900, "cm"), (500, "d"), (400, "cd"), (100, "c"), (90, "xc"), (50, "l"),
                 (40, "xl"), (10, "x"), (9, "ix"), (5, "v"), (4, "iv"), (1, "i")):
        while n >= v:
            out, n = out + r, n - v
    return out


def _parse(label):
    s = (label or "").strip().lower()
    if s.isdigit():
        return "arabic", int(s)
    v = _roman_value(s)
    return ("roman", v) if v else (None, None)


def repair_labels(labels, reach=5):
    """Labels (one per PDF page) with sequence-breaking guesses replaced; consistent ones are kept."""
    parsed = [_parse(l) for l in labels]
    out = list(labels)
    for i in range(len(labels)):
        best = None
        for p in range(i - 1, max(-1, i - reach - 1), -1):
            for n in range(i + 1, min(len(labels), i + reach + 1)):
                (k1, v1), (k2, v2) = parsed[p], parsed[n]
                if k1 and k1 == k2 and v2 - v1 == n - p:
                    if best is None or (n - p) < best[0]:
                        best = (n - p, k1, v1 + (i - p))
        if best:
            kind, value = best[1], best[2]
            expected = str(value) if kind == "arabic" else _to_roman(value)
            if value > 0 and parsed[i] != (kind, value):
                out[i] = expected
                parsed[i] = (kind, value)
    return out
