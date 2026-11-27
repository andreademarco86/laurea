#!/usr/bin/env python3
"""How closely do the drafted marks agree with the examiner's final marks?

Usage: python3 benchmark.py <examinations_dir> [--out DIR]
       (the app's examinations live in ~/Library/Application Support/Laurea/examinations)

For every examination folder with both the original draft (report.original.md) and the saved final
report (*_examiner_report.md), compares the five criterion marks and the total. Reports, per level
and overall: mean absolute error (marks and % of the criterion maximum), bias (+ = the examiner gave
more than the draft), grade agreement on each examination's grading scale, and rank agreement across dissertations (Spearman).
Each run is saved to benchmark-history.json in --out (default: the examinations folder), and the
report shows the change since the previous run - so after changing the examining standards and
re-examining a few dissertations, you can see whether agreement improved.
Standard library only; nothing leaves the Mac.
"""
import datetime as dt
import glob
import json
import os
import re
import sys

KEYS = ["a", "b", "c", "d", "e"]
# Default grading scale (University of Malta): lower bound (% of the maximum) and grade, highest first.
# Each examination's own scale, saved in its scheme.json, takes precedence.
DEFAULT_SCALE = [(80, "A"), (70, "B"), (55, "C"), (50, "D"), (45, "E"), (0, "F")]


def marks(md):
    """{key: (mark, max)} from '### (a) ... - N/M' headings."""
    out = {}
    for k in KEYS:
        m = re.search(rf"^### \({k}\)[^\n]*?[-–—]\s*(\d+(?:\.\d+)?)\s*/\s*(\d+)\s*$", md, re.M)
        if m:
            out[k] = (float(m.group(1)), int(m.group(2)))
    return out


def grade(pct, scale):
    return next((name for lo, name in scale if int(pct) >= lo), scale[-1][1])


def exam_scale(d):
    try:
        bands = json.load(open(os.path.join(d, "scheme.json"), encoding="utf-8"))["grading_scale"]["bands"]
        scale = [(int(b["min"]), str(b["grade"])) for b in bands]
        return scale if scale and scale[-1][0] == 0 else DEFAULT_SCALE
    except Exception:
        return DEFAULT_SCALE


def spearman(xs, ys):
    n = len(xs)
    if n < 3:
        return None

    def ranks(v):
        order = sorted(range(n), key=lambda i: v[i])
        r = [0.0] * n
        i = 0
        while i < n:
            j = i
            while j + 1 < n and v[order[j + 1]] == v[order[i]]:
                j += 1
            for t in range(i, j + 1):
                r[order[t]] = (i + j) / 2 + 1
            i = j + 1
        return r
    rx, ry = ranks(xs), ranks(ys)
    mx, my = sum(rx) / n, sum(ry) / n
    num = sum((a - mx) * (b - my) for a, b in zip(rx, ry))
    den = (sum((a - mx) ** 2 for a in rx) * sum((b - my) ** 2 for b in ry)) ** 0.5
    return round(num / den, 2) if den else None


def collect(root):
    rows = []
    for d in sorted(glob.glob(os.path.join(root, "*"))):
        orig = os.path.join(d, "report.original.md")
        finals = [f for f in glob.glob(os.path.join(d, "*_examiner_report.md"))]
        if not (os.path.isfile(orig) and finals):
            continue
        a, b = marks(open(orig, encoding="utf-8").read()), marks(open(finals[0], encoding="utf-8").read())
        if set(a) != set(KEYS) or set(b) != set(KEYS):
            continue
        try:
            level = json.load(open(os.path.join(d, "status.json"))).get("level", "msc")
        except Exception:
            level = "msc"
        rows.append({"id": os.path.basename(d), "level": level, "draft": a, "final": b, "scale": exam_scale(d)})
    return rows


def summarise(rows):
    if not rows:
        return None
    s = {"n": len(rows), "criteria": {}}
    for k in KEYS:
        diffs = [r["final"][k][0] - r["draft"][k][0] for r in rows]
        pcts = [abs(r["final"][k][0] - r["draft"][k][0]) / r["final"][k][1] * 100 for r in rows]
        same = [grade(r["final"][k][0] / r["final"][k][1] * 100, r["scale"])
                == grade(r["draft"][k][0] / r["draft"][k][1] * 100, r["scale"]) for r in rows]
        s["criteria"][k] = {"mae": round(sum(map(abs, diffs)) / len(diffs), 2), "mae_pct": round(sum(pcts) / len(pcts), 1),
                            "bias": round(sum(diffs) / len(diffs), 2), "grade_agree": round(100 * sum(same) / len(same))}
    tot_d = [sum(r["draft"][k][0] for k in KEYS) for r in rows]
    tot_f = [sum(r["final"][k][0] for k in KEYS) for r in rows]
    dmax = [sum(r["final"][k][1] for k in KEYS) for r in rows]
    s["total"] = {"mae": round(sum(abs(f - d) for f, d in zip(tot_f, tot_d)) / len(rows), 2),
                  "mae_pct": round(sum(abs(f - d) / m * 100 for f, d, m in zip(tot_f, tot_d, dmax)) / len(rows), 1),
                  "bias": round(sum(f - d for f, d in zip(tot_f, tot_d)) / len(rows), 2),
                  "spearman": spearman(tot_d, tot_f)}
    return s


def main():
    args = sys.argv[1:]
    if not args:
        sys.exit(__doc__)
    root = os.path.expanduser(args[0])
    out = os.path.expanduser(args[args.index("--out") + 1]) if "--out" in args else root
    rows = collect(root)
    groups = {"all": rows}
    for lv in ("bsc", "msc", "phd"):
        if any(r["level"] == lv for r in rows):
            groups[lv] = [r for r in rows if r["level"] == lv]
    result = {"date": dt.datetime.now().isoformat(timespec="seconds"),
              "groups": {g: summarise(rs) for g, rs in groups.items()}}

    hist_path = os.path.join(out, "benchmark-history.json")
    try:
        history = json.load(open(hist_path))
    except Exception:
        history = []
    prev = history[-1] if history else None
    history.append(result)
    os.makedirs(out, exist_ok=True)
    json.dump(history, open(hist_path, "w"), indent=2)

    def delta(g, k, field):
        try:
            old = prev["groups"][g]["criteria" if k != "total" else "total"]
            old = old[k][field] if k != "total" else old[field]
            new = result["groups"][g]["criteria"][k][field] if k != "total" else result["groups"][g]["total"][field]
            d = round(new - old, 2)
            return f" ({'+' if d > 0 else ''}{d})" if d else ""
        except Exception:
            return ""

    lines = ["# Agreement between drafts and your final marks", "",
             f"{len(rows)} examination(s) with a draft and a saved final report. Bias: + means you gave more than the draft. "
             "Lower error and bias near 0 are better. Changes since the previous run are in brackets.", ""]
    if not rows:
        lines.append("Nothing to compare yet: examine dissertations and save your final reports first.")
    for g, s in result["groups"].items():
        if not s:
            continue
        lines += [f"## {g.upper() if g != 'all' else 'All levels'} ({s['n']})", "",
                  "| Criterion | Mean error (marks) | Mean error (% of max) | Bias | Same grade |", "|---|---:|---:|---:|---:|"]
        for k in KEYS:
            c = s["criteria"][k]
            lines.append(f"| ({k}) | {c['mae']}{delta(g, k, 'mae')} | {c['mae_pct']}% | {c['bias']:+}{delta(g, k, 'bias')} | {c['grade_agree']}% |")
        t = s["total"]
        lines += [f"| **Total** | **{t['mae']}**{delta(g, 'total', 'mae')} | {t['mae_pct']}% | {t['bias']:+} | |", "",
                  f"Rank agreement (Spearman, totals): {t['spearman'] if t['spearman'] is not None else 'needs 3+ examinations'}", ""]
    open(os.path.join(out, "benchmark.md"), "w", encoding="utf-8").write("\n".join(lines) + "\n")
    a = result["groups"]["all"]
    print(f"benchmark: {len(rows)} examination(s)" + (f", total mean error {a['total']['mae']} marks, bias {a['total']['bias']:+}" if a else "")
          + f" - see {os.path.join(out, 'benchmark.md')}")


if __name__ == "__main__":
    main()
