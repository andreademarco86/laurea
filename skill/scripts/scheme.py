"""Marking scheme (criterion weights) shared by the skill's scripts.

Each weight is a criterion's maximum mark. The five criteria plus the viva total 100, so the
dissertation is marked out of 100 - viva. Lookup order for a report:
  1. scheme.json next to the report (or one folder up) - written by the app when an examination starts
  2. config.json "marking_scheme" in the skill folder - the examiner's current default
  3. DEFAULT below
"""
import json
import os

KEYS = ["a", "b", "c", "d", "e"]
NAMES = {
    "a": "Introduction and overall document",
    "b": "Literature Review",
    "c": "Method and Solution",
    "d": "Testing, Results, Analysis and Evaluation",
    "e": "Discussion, Conclusion and Future Work",
}
DEFAULT = {"a": 10, "b": 20, "c": 25, "d": 25, "e": 10, "viva": 10}


def valid(s):
    try:
        if any(int(s[k]) < 1 for k in KEYS) or int(s["viva"]) < 0:
            return False
        return sum(int(s[k]) for k in KEYS) + int(s["viva"]) == 100
    except (KeyError, TypeError, ValueError):
        return False


def normalise(s):
    return {k: int(s[k]) for k in KEYS + ["viva"]}


def load_scheme(report_path=None):
    here = os.path.dirname(os.path.abspath(__file__))
    cands = []
    if report_path:
        d = os.path.dirname(os.path.abspath(report_path))
        cands += [os.path.join(d, "scheme.json"), os.path.join(d, "..", "scheme.json")]
    cands.append(os.path.join(here, "..", "config.json"))
    for c in cands:
        try:
            with open(c, encoding="utf-8") as f:
                j = json.load(f)
        except Exception:
            continue
        j = j.get("marking_scheme", j) if isinstance(j, dict) else None
        if isinstance(j, dict) and valid(j):
            return normalise(j)
    return dict(DEFAULT)


def dissertation_max(s):
    return 100 - s["viva"]


def describe(s):
    parts = ", ".join(f"({k}) {s[k]}" for k in KEYS)
    return f"{parts}; dissertation /{dissertation_max(s)}; viva /{s['viva']}; final /100"


if __name__ == "__main__":
    import sys
    print(describe(load_scheme(sys.argv[1] if len(sys.argv) > 1 else None)))
