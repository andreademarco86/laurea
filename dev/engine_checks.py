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
check("substantial and minor corrections survive the round trip",
      len(r["substantial"]) == 1 and again["substantial"] == r["substantial"] and again["corrections"] == r["corrections"])
none = sv.parse_report(sv.write_report({**r, "substantial": []}, sv.DEFAULT_SCHEME))
check("no substantial corrections are written as 'None required.'", none["substantial"] == [] and len(none["corrections"]) == 5)

# Marking weights
custom = {"a": 10, "b": 15, "c": 30, "d": 25, "e": 5, "viva": 15}
check("valid custom scheme accepted", sv.valid_scheme(custom))
check("scheme not totalling 100 rejected", not sv.valid_scheme({**custom, "viva": 20}))
out = sv.write_report(r, custom)
check("custom scheme written into the report", "**62 / 85**" in out and "/ 15" in out)

# Standards are read from the app; only taught changes live in the data folder, and a new build clears them
sv.install_examiner()
check("untaught standards are read from the app, not copied",
      sv.current_standards() == sv.BUNDLED and not sv.STANDARDS.exists() and not (sv.SKILL / "scripts").exists())
before = sv.standard_files(sv.current_standards())
sv.save_standards(sv.STANDARDS, before, {**before, "references/house-preferences.md": "# House preferences\n\n- taught\n"},
                  "Taught rule", sv.standards_revision() or sv.BUNDLED_REVISION)
sv.write_json(sv.SKILL_CHAT, {"messages": [{"role": "user", "text": "old"}]})
check("a taught change is used and can be undone", sv.current_standards() == sv.CURRENT_STANDARDS
      and [e["message"] for e in sv.skill_history()] == ["Taught rule"])
sv.undo_standards(sv.skill_history()[0]["revision"])
check("undoing restores the app's standards", sv.standard_files(sv.current_standards()) == before)
sv.install_examiner()
check("the same build keeps teaching", sv.STANDARDS.exists() and sv.SKILL_CHAT.exists())
(sv.SKILL / "bundle-stamp").write_text("an older build")
sv.install_examiner()
check("a new build clears taught standards, history and chat",
      sv.current_standards() == sv.BUNDLED and not sv.skill_history() and not sv.SKILL_CHAT.exists())

# Grading scales
check("both grading presets are valid", all(sv.valid_grading_scale(g) for g in sv.GRADING_PRESETS))
um = next(g for g in sv.GRADING_PRESETS if g["name"] == "University of Malta")
text = sv.describe_grading_scale(um)
check("the University of Malta scale is described with its ranges", "B 70-79%" in text and "F 0-44%" in text, text[:120])
bad = {"name": "x", "bands": [{"grade": "A", "min": 50, "meaning": ""}, {"grade": "B", "min": 60, "meaning": ""}, {"grade": "C", "min": 0, "meaning": ""}]}
check("a scale with rising bounds is rejected", not sv.valid_grading_scale(bad))
check("a scale that does not reach 0% is rejected",
      not sv.valid_grading_scale({"name": "x", "bands": [{"grade": "A", "min": 50}, {"grade": "B", "min": 10}]}))

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
c = sv.compute_offsets(accepted)
check("accepted offsets shape the size but don't count as independent examples",
      c["support"]["c"]["examples"] == 3 and c["offsets"]["c"] > 0)
down = [entry(10 + i, 15, 12) for i in range(3)]
up_echo = [entry(20 + i, 15, 17, proposed_c=17) for i in range(3)]
trend = sv.compute_offsets(down + up_echo)["offsets"]["c"]
check("accepted offsets in the old direction cannot cancel a new trend", trend < 0, str(trend))
inherited_only = [entry(i, 15, 17, proposed_c=17) for i in range(3)]
check("three untouched inherited proposals do not qualify an offset", sv.compute_offsets(inherited_only)["offsets"]["c"] == 0)

# Evidence quotes: a report point logged with a quote gets that quote for PDF highlighting
d = sv.EXAMS / "20260101-000000-Sample"
work = d / "Sample_examiner_work"
work.mkdir(parents=True)
(d / "Sample.pdf").write_bytes(b"%PDF-1.4\n")
sv.write_json(d / "status.json", {"state": "done", "pdf": "Sample.pdf", "level": "msc"})
(work / "meta.json").write_text(json.dumps({"page_labels": [str(i) for i in range(1, 80)]}))
report = sv.parse_report(fixture)
logged = report["criteria"]["c"]["weaknesses"][0]
(work / "evidence.md").write_text(f"[c] §4.1 p. 31 (-) {logged} | Quote: the exact words on the page\n", encoding="utf-8")
quotes = sv.evidence_quotes(d, report, work / "meta.json")
check("a logged report point carries its quote", list(quotes.values()) == ["the exact words on the page"], str(quotes))
edited = sv.parse_report(fixture.replace(logged, logged + " Reworded."))
check("a reworded point no longer claims the quote", not sv.evidence_quotes(d, edited, work / "meta.json"))

# Panel record: three readers with overall grades, and a ruling on a disputed criterion
sv.write_json(work / "panel.json", {
    "examiners": {r: {"a": 7, "b": 14, "c": 18, "d": 15 + i, "e": 7} for i, r in enumerate(sv.PANEL_ROLES)},
    "overall": {"methods": "B", "field": "B", "holistic": "C"}, "chair": {"a": 7, "b": 14, "c": 18, "d": 16, "e": 7},
    "disputes": {"d": {"above": "x", "below": "y", "ruling": "B holds: the baselines are fair."}}, "low_confidence": ["d"],
    "notes": {"methods": "Solid build.", "field": "Well placed.", "holistic": "Claims run ahead of the results."}})
fb = sv.panel_feedback(d, work / "meta.json", sv.DEFAULT_SCHEME)
check("panel record reads all three readers, their overall grades and the ruling",
      fb and set(fb["examiners"]) == set(sv.PANEL_ROLES) and fb["overall"]["holistic"] == "C"
      and fb["decisions"].get("d", "").startswith("B holds") and fb["notes"].get("holistic"), str(fb)[:200])

# Gemini: stream events become progress items, and runs are locked down
g = sv.GeminiStream()
events = [{"type": "init", "model": "gemini-2.5-pro"}, {"type": "message", "role": "user", "content": "x"},
          {"type": "message", "role": "assistant", "content": "Reading ", "delta": True},
          {"type": "message", "role": "assistant", "content": "the thesis.", "delta": True},
          {"type": "tool_use", "tool_name": "write_file", "tool_id": "1", "parameters": {"file_path": "/w/evidence.md"}},
          {"type": "tool_result", "tool_id": "1", "status": "error", "error": {"type": "x", "message": "denied"}},
          {"type": "message", "role": "assistant", "content": "Done.", "delta": True},
          {"type": "result", "status": "success", "stats": {"duration_ms": 5}}]
items = [i for e in events for i in g(e)]
kinds = [i["kind"] for i in items]
check("Gemini stream: text is gathered, tools map to Laurea's names, the result closes the run",
      kinds == ["info", "text", "tool", "warn", "text", "result"] and items[1]["text"] == "Reading the thesis."
      and items[2]["tool"] == "Write" and sv.phase_of(items[2]) == "chair" and items[-1]["text"] is None, str(items)[:200])
failed = sv.GeminiStream()({"type": "result", "status": "error", "error": {"message": "Quota exceeded"}})
check("Gemini stream: a failed result is reported as an error", failed[-1]["is_error"] and failed[-1]["text"] == "Quota exceeded")
skill = Path(tmp) / "run-skill"
(skill / "scripts").mkdir(parents=True)
(skill / "scripts" / "check_report.py").write_text("")
(skill / "scripts" / "render_report.sh").write_text("")
cmd = sv.report_command("gemini", "/x/gemini", d, "PROMPT", skill, selection=("gemini-2.5-pro", "medium"))
run_home = Path(cmd[1].split("=", 1)[1])
settings_file = run_home / ".gemini" / "settings.json"
core = json.loads(settings_file.read_text())["tools"]["core"]
gsettings = json.loads(settings_file.read_text())
check("Gemini runs allow only file tools and Laurea's scripts, with no web tools, extensions or telemetry",
      f"run_shell_command(python3 {skill}/scripts/check_report.py)" in core
      and f"run_shell_command(bash {skill}/scripts/render_report.sh)" in core
      and not any("web" in t for t in core) and "-e" in cmd and cmd[cmd.index("-e") + 1] == "none"
      and gsettings["privacy"]["usageStatisticsEnabled"] is False and gsettings["security"]["toolSandboxing"] is True
      and gsettings["mcpServers"] == {} and cmd[-2:] == ["-p", "PROMPT"])
sv.finish_gemini_run(cmd)
check("a Gemini run's private home is removed afterwards", not run_home.exists())
sv.write_json(sv.SETTINGS_FILE, {**sv.settings(), "gemini_project": "um-examining-123"})
check("a Google Cloud project reaches Gemini runs", sv.provider_env("gemini").get("GOOGLE_CLOUD_PROJECT") == "um-examining-123")
sv.write_json(sv.SETTINGS_FILE, {**sv.settings(), "gemini_project": ""})
check("no project for personal accounts", "GOOGLE_CLOUD_PROJECT" not in sv.provider_env("gemini"))
st = sv.provider_status("gemini")
check("Gemini status without the CLI or a sign-in", st["installed"] in (True, False) and st["signed_in"] is False)

print(f"\nengine checks: {'all passed' if not failures else str(len(failures)) + ' failed'}")
sys.exit(1 if failures else 0)
