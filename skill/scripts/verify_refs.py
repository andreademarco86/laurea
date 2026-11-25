#!/usr/bin/env python3
"""Verify a dissertation's references against scholarly databases.

Usage: python3 verify_refs.py <work_dir> [--limit N]

Reads <work_dir>/references.json - a list you extract from the bibliography:
  [{"id": "12", "raw": "full reference as printed", "title": "...", "authors": ["Surname, I.", ...],
    "year": 2021, "doi": "10.xxxx/...", "arxiv": "2106.01234", "type": "article|book|web|software|other"}, ...]
Only "title" is required; give DOI / arXiv id whenever the reference has one.

Checks each reference by DOI (Crossref), arXiv id (arXiv API) or title (OpenAlex, then Crossref), and
writes refcheck.json and refcheck.md: verified / mismatch (exists, but year or authors differ) /
not found / not checkable (web pages, software, datasets). Only titles, DOIs and ids are sent -
never anything else from the dissertation. Standard library only; uses the system curl.
"""
import difflib
import json
import os
import re
import subprocess
import sys
import time
import urllib.parse

UA = "Laurea-examiner-reference-check/1.0"


def fetch(url, timeout=20):
    try:
        r = subprocess.run(["/usr/bin/curl", "-fsSL", "--max-time", str(timeout), "-A", UA, url],
                           capture_output=True, timeout=timeout + 5)
        if r.returncode == 0:
            return r.stdout.decode("utf-8", errors="replace")
        if r.returncode in (6, 7, 28, 35):  # cannot resolve / connect / timeout / TLS
            raise ConnectionError("network unavailable")
        return None  # HTTP error such as 404
    except subprocess.TimeoutExpired:
        raise ConnectionError("network timeout")


def norm(s):
    s = re.sub(r"<[^>]+>", " ", s or "")
    s = re.sub(r"[^a-z0-9 ]", " ", s.lower())
    return re.sub(r"\s+", " ", s).strip()


def sim(a, b):
    a, b = norm(a), norm(b)
    if not a or not b:
        return 0.0
    if a == b:
        return 1.0
    return difflib.SequenceMatcher(None, a, b).ratio()


def surnames(authors):
    out = []
    for a in authors or []:
        a = a.strip()
        if not a:
            continue
        sn = a.split(",")[0] if "," in a else a.split()[-1]
        out.append(norm(sn))
    return [x for x in out if x]


def compare(ref, title, year, authors):
    """(similarity, problems) between the cited reference and a database record."""
    s = sim(ref.get("title"), title)
    problems = []
    try:
        if ref.get("year") and year and abs(int(ref["year"]) - int(year)) > 1:
            problems.append(f"year {ref['year']} cited, {year} in record")
    except (TypeError, ValueError):
        pass
    cited = surnames(ref.get("authors"))
    tokens = set(" ".join(norm(x) for x in authors if x).split())
    found = [x for x in authors if x]
    if cited and tokens and not any(c in tokens for c in cited[:2]):
        problems.append(f"authors differ (cited {', '.join(cited[:2])}; record {', '.join(found[:2])})")
    return s, problems


def via_crossref_doi(doi):
    j = fetch("https://api.crossref.org/works/" + urllib.parse.quote(doi.strip(), safe="/"))
    if not j:
        return None
    m = json.loads(j).get("message", {})
    year = ((m.get("issued") or {}).get("date-parts") or [[None]])[0][0]
    return {"title": (m.get("title") or [""])[0], "year": year,
            "authors": [a.get("family", "") for a in m.get("author", [])],
            "venue": (m.get("container-title") or [""])[0], "source": "Crossref (DOI)", "url": "https://doi.org/" + doi}


def via_arxiv(aid):
    aid = re.sub(r"^arxiv:", "", aid.strip(), flags=re.I)
    x = fetch("https://export.arxiv.org/api/query?id_list=" + urllib.parse.quote(aid))
    if not x or "<entry>" not in x:
        return None
    entry = x.split("<entry>", 1)[1]
    title = re.search(r"<title>(.*?)</title>", entry, re.S)
    pub = re.search(r"<published>(\d{4})", entry)
    authors = re.findall(r"<name>(.*?)</name>", entry)
    if not title or "Error" in title.group(1):
        return None
    return {"title": re.sub(r"\s+", " ", title.group(1)).strip(), "year": int(pub.group(1)) if pub else None,
            "authors": authors, "venue": "arXiv", "source": "arXiv", "url": "https://arxiv.org/abs/" + aid}


def via_openalex(title):
    j = fetch("https://api.openalex.org/works?per-page=5&search=" + urllib.parse.quote(title))
    if not j:
        return []
    out = []
    for w in json.loads(j).get("results", []):
        out.append({"title": w.get("display_name") or "", "year": w.get("publication_year"),
                    "authors": [(a.get("author") or {}).get("display_name") or "" for a in w.get("authorships", [])],
                    "venue": (((w.get("primary_location") or {}).get("source") or {}).get("display_name") or ""),
                    "source": "OpenAlex", "url": w.get("doi") or w.get("id")})
    return out


def via_crossref_title(title):
    j = fetch("https://api.crossref.org/works?rows=5&query.bibliographic=" + urllib.parse.quote(title))
    if not j:
        return []
    out = []
    for m in json.loads(j).get("message", {}).get("items", []):
        year = ((m.get("issued") or {}).get("date-parts") or [[None]])[0][0]
        out.append({"title": (m.get("title") or [""])[0], "year": year,
                    "authors": [a.get("family", "") for a in m.get("author", [])],
                    "venue": (m.get("container-title") or [""])[0], "source": "Crossref (title)",
                    "url": "https://doi.org/" + m["DOI"] if m.get("DOI") else ""})
    return out


def check(ref):
    if (ref.get("type") or "").lower() in ("web", "website", "software", "dataset", "standard", "other") and not ref.get("doi"):
        return {"status": "not checkable", "note": "web page, software or dataset; check the link by hand if it matters"}
    if not (ref.get("title") or ref.get("doi") or ref.get("arxiv")):
        return {"status": "not checkable", "note": "no title, DOI or arXiv id extracted"}
    records = []
    if ref.get("doi"):
        r = via_crossref_doi(ref["doi"])
        if r:
            records.append(r)
        elif not ref.get("title"):
            return {"status": "not found", "note": f"DOI {ref['doi']} does not resolve"}
    if ref.get("arxiv"):
        r = via_arxiv(ref["arxiv"])
        if r:
            records.append(r)
    if not records and ref.get("title"):
        records = via_openalex(ref["title"]) or via_crossref_title(ref["title"])
    if not records:
        return {"status": "not found", "note": "no matching record in Crossref, arXiv or OpenAlex"}
    best, best_sim, best_problems, best_key = None, -1.0, [], None
    for r in records:
        s, problems = compare(ref, r["title"], r["year"], r["authors"])
        if ref.get("doi") and r["source"].startswith("Crossref (DOI)") and not ref.get("title"):
            s = 1.0
        try:
            ydiff = abs(int(ref.get("year")) - int(r["year"]))
        except (TypeError, ValueError):
            ydiff = 99
        key = (round(s * 20) / 20, -len(problems), -ydiff)  # same title: prefer fewer problems, then nearest year
        if best_key is None or key > best_key:
            best, best_sim, best_problems, best_key = r, s, problems, key
    rec = {k: best[k] for k in ("title", "year", "venue", "source", "url")}
    if best_sim >= 0.9 and not best_problems:
        return {"status": "verified", "similarity": round(best_sim, 2), "record": rec}
    if best_sim >= 0.9:
        return {"status": "mismatch", "similarity": round(best_sim, 2), "record": rec, "note": "; ".join(best_problems)}
    if best_sim >= 0.7:
        return {"status": "mismatch", "similarity": round(best_sim, 2), "record": rec,
                "note": "only a close title match: " + "; ".join(["title differs"] + best_problems)}
    if ref.get("doi") and best["source"].startswith("Crossref (DOI)"):
        return {"status": "mismatch", "similarity": round(best_sim, 2), "record": rec,
                "note": "the DOI points to a different work"}
    return {"status": "not found", "similarity": round(best_sim, 2), "record": rec,
            "note": "nearest record has a different title"}


def main():
    args = sys.argv[1:]
    if not args:
        sys.exit(__doc__)
    work = args[0]
    limit = int(args[args.index("--limit") + 1]) if "--limit" in args else 10**6
    with open(os.path.join(work, "references.json"), encoding="utf-8") as f:
        refs = json.load(f)
    results, offline = [], False
    for i, ref in enumerate(refs[:limit]):
        if offline:
            res = {"status": "unchecked", "note": "no network"}
        else:
            try:
                res = check(ref)
            except ConnectionError as e:
                offline = True
                res = {"status": "unchecked", "note": str(e)}
            time.sleep(0.15)
        results.append({"id": ref.get("id", str(i + 1)), "cited": ref.get("raw") or ref.get("title"), **res})
    with open(os.path.join(work, "refcheck.json"), "w", encoding="utf-8") as f:
        json.dump(results, f, indent=2, ensure_ascii=False)
    counts = {}
    for r in results:
        counts[r["status"]] = counts.get(r["status"], 0) + 1
    order = {"not found": 0, "mismatch": 1, "unchecked": 2, "not checkable": 3, "verified": 4}
    with open(os.path.join(work, "refcheck.md"), "w", encoding="utf-8") as f:
        f.write("# Reference check\n\n" + ", ".join(f"{v} {k}" for k, v in sorted(counts.items(), key=lambda kv: order.get(kv[0], 9))) + "\n\n")
        if offline:
            f.write("The network was not available for some or all references: verify the important ones by web search "
                    "(titles only) and say so in the final message.\n\n")
        f.write("Not found or mismatched is not proof of fabrication (books, theses and local reports are often missing "
                "from databases). Read the reference, look at the nearest record, and judge.\n\n")
        f.write("| # | Status | Cited | Note | Nearest record |\n|---|---|---|---|---|\n")
        for r in sorted(results, key=lambda r: order.get(r["status"], 9)):
            rec = r.get("record") or {}
            near = f"{rec.get('title', '')} ({rec.get('year', '')}, {rec.get('source', '')})" if rec else ""
            cells = [str(r["id"]), r["status"], (r["cited"] or "")[:140], r.get("note", ""), near[:160]]
            f.write("| " + " | ".join(c.replace("|", "/").replace("\n", " ") for c in cells) + " |\n")
    print("references: " + ", ".join(f"{v} {k}" for k, v in counts.items()) + " - see refcheck.md")


if __name__ == "__main__":
    main()
