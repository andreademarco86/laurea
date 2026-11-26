#!/usr/bin/env python3
"""Offline logic checks for the examination engine. No PDFs, no network, no assistant sessions.

Run by dev/check.sh. Uses a temporary data folder, so it never touches real examinations.
"""
import json
import os
import sys
import tempfile
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
tmp = tempfile.mkdtemp(prefix="laurea-check-")
os.environ["DE_DATA"] = tmp
sys.path.insert(0, str(REPO / "engine"))
import server as sv  # noqa: E402

failures = []


def check(name, ok, detail=""):
    print(("  ok    " if ok else "  FAIL  ") + name + (f" - {detail}" if detail and not ok else ""))
    if not ok:
        failures.append(name)


# Skill validation (what the app checks before using bundled or taught standards)
problems = sv.validate_skill(sv.standard_files(REPO / "skill"))
check("bundled skill passes the app's validation", not problems, "; ".join(problems))

# Report round trip
fixture = (REPO / "dev" / "fixtures" / "sample-report.md").read_text(encoding="utf-8")
r = sv.parse_report(fixture)
check("sample report parses with five criteria", all(r["criteria"][k]["mark"] is not None for k in "abcde"))
again = sv.parse_report(sv.write_report(r, sv.DEFAULT_SCHEME))
check("report survives a write/parse round trip", again["criteria"] == r["criteria"] and again["summary"] == r["summary"])

# Marking weights
custom = {"a": 10, "b": 15, "c": 30, "d": 25, "e": 5, "viva": 15}
check("valid custom scheme accepted", sv.valid_scheme(custom))
check("scheme not totalling 100 rejected", not sv.valid_scheme({**custom, "viva": 20}))
out = sv.write_report(r, custom)
check("custom scheme written into the report", "**62 / 85**" in out and "/ 15" in out)

# Calibration: three agreeing examiner adjustments learn an offset; accepted offsets count at half weight
today = sv.dt.date.today().isoformat()


def entry(i, raw_c, final_c, proposed_c=None):
    base = {k: 10 for k in "abde"}
    return {"exam_id": f"x{i}", "level": "msc", "include": True, "date": today, "maxima": sv.DEFAULT_SCHEME,
            "raw": {**base, "c": raw_c}, "proposed": {**base, "c": proposed_c if proposed_c is not None else raw_c},
            "final": {**base, "c": final_c}}


two = [entry(i, 15, 18) for i in range(2)]
three = two + [entry(2, 15, 18)]
check("two agreeing examinations do not yet learn an offset", sv.compute_offsets(two)["offsets"]["c"] == 0)
learned = sv.compute_offsets(three)["offsets"]["c"]
check("three agreeing examinations learn a positive offset", learned > 0, str(learned))
accepted = three + [entry(3, 15, 17, proposed_c=17)]
check("accepting an offset still counts (weak confirmation)",
      sv.compute_offsets(accepted)["support"]["c"]["examples"] == 4 and sv.compute_offsets(accepted)["offsets"]["c"] > 0)

# Evidence ledger: a decision survives rewording of its finding
d = sv.EXAMS / "20260101-000000-Sample"
work = d / "Sample_examiner_work"
work.mkdir(parents=True)
(d / "Sample.pdf").write_bytes(b"%PDF-1.4\n")
sv.write_json(d / "status.json", {"state": "done", "pdf": "Sample.pdf", "level": "msc"})
(d / "Sample_examiner_report.md").write_text(fixture, encoding="utf-8")
(work / "meta.json").write_text(json.dumps({"page_labels": [str(i) for i in range(1, 80)]}))
rows = sv.evidence_ledger(d, sv.parse_report(fixture), work / "meta.json")
check("evidence ledger lists the report's findings", len(rows) == 20, str(len(rows)))
target = rows[0]
sv.EVIDENCE_REVIEWS.mkdir(parents=True, exist_ok=True)
sv.write_json(sv.EVIDENCE_REVIEWS / f"{d.name}.json",
              {target["id"]: {"decision": "confirmed", "correction": "", "criterion": target["criterion"],
                              "kind": target["kind"], "finding": target["finding"], "source": target["source"]}})
reworded = fixture.replace(target["finding"], target["finding"].replace("Clear and well-supported", "Clear, well-supported"))
rows2 = sv.evidence_ledger(d, sv.parse_report(reworded), work / "meta.json")
match = [x for x in rows2 if x["criterion"] == target["criterion"] and x["kind"] == target["kind"] and x["decision"] == "confirmed"]
check("evidence decision survives rewording", len(match) == 1 and match[0]["id"] != target["id"])

print(f"\nengine checks: {'all passed' if not failures else str(len(failures)) + ' failed'}")
sys.exit(1 if failures else 0)
