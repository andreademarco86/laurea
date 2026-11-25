#!/usr/bin/env python3
"""Look at the code and data repositories a dissertation links to, without running anything.

Usage: python3 repo_probe.py <work_dir> [--url URL] [--max 3]

Without --url, finds repository links (GitHub, GitLab, Bitbucket, Hugging Face, Zenodo, OSF) in
<work_dir>/pages.txt. Each git repository is shallow-cloned into <work_dir>/repos/ (files over 2 MB
skipped) and checked for: README and how to reproduce, licence, dependency files, containers, tests,
notebooks, random seeds, data instructions, pretrained weights, size and last commit date.
Writes repo.md. Code is never executed. Only the public URL printed in the dissertation is used.
"""
import json
import os
import re
import subprocess
import sys

URL_RE = re.compile(r"https?://(?:www\.)?(github\.com|gitlab\.com|bitbucket\.org|huggingface\.co|zenodo\.org|osf\.io)/[^\s)\]>,;\"']+", re.I)
SEED_RE = re.compile(r"(random\.seed|np\.random\.seed|torch\.manual_seed|tf\.random\.set_seed|set_seed\(|seed_everything|PYTHONHASHSEED|rng\s*=\s*np\.random\.default_rng\(\s*\d)")


def find_urls(work):
    text = open(os.path.join(work, "pages.txt"), encoding="utf-8").read()
    text = re.sub(r"-\n", "", text)  # undo hyphenated line breaks
    urls = []
    for m in URL_RE.finditer(text):
        u = m.group(0).rstrip(".")
        if u not in urls:
            urls.append(u)
    return urls


def git_root(url):
    m = re.match(r"(https?://(?:www\.)?(?:github\.com|gitlab\.com|bitbucket\.org)/[^/]+/[^/#?]+)", url, re.I)
    if m:
        return re.sub(r"\.git$", "", m.group(1))
    m = re.match(r"(https?://huggingface\.co/(?:datasets/|spaces/)?[^/]+/[^/#?]+)", url, re.I)
    return m.group(1) if m else None


def probe(url, dest):
    r = subprocess.run(["git", "clone", "--depth", "1", "--filter=blob:limit=2m", "--quiet", url, dest],
                       capture_output=True, text=True, timeout=180, env={**os.environ, "GIT_TERMINAL_PROMPT": "0"})
    if r.returncode != 0:
        return {"url": url, "ok": False, "error": (r.stderr.strip().splitlines() or ["clone failed"])[-1]}
    files = []
    for root, dirs, fs in os.walk(dest):
        dirs[:] = [d for d in dirs if d != ".git"]
        files += [os.path.relpath(os.path.join(root, f), dest) for f in fs]
    low = [f.lower() for f in files]
    has = lambda *names: [f for f, l in zip(files, low) if any(re.search(n, l) for n in names)]
    readme = has(r"(^|/)readme(\.\w+)?$")
    readme_text = ""
    if readme:
        try:
            readme_text = open(os.path.join(dest, sorted(readme, key=len)[0]), encoding="utf-8", errors="replace").read()
        except Exception:
            pass
    seeds = 0
    for f in files:
        if f.endswith((".py", ".ipynb", ".jl", ".r", ".R")):
            try:
                if SEED_RE.search(open(os.path.join(dest, f), encoding="utf-8", errors="replace").read()):
                    seeds += 1
            except Exception:
                pass
    last = subprocess.run(["git", "-C", dest, "log", "-1", "--format=%cs"], capture_output=True, text=True).stdout.strip()
    ext = {}
    for f in files:
        e = os.path.splitext(f)[1].lower() or "(none)"
        ext[e] = ext.get(e, 0) + 1
    rt = readme_text.lower()
    return {
        "url": url, "ok": True, "files": len(files), "last_commit": last,
        "top_types": sorted(ext.items(), key=lambda kv: -kv[1])[:6],
        "readme": bool(readme), "readme_words": len(readme_text.split()),
        "readme_reproduce": any(w in rt for w in ("reproduce", "usage", "how to run", "train", "evaluate", "getting started")),
        "readme_data": any(w in rt for w in ("dataset", "download", "data/")),
        "license": has(r"(^|/)(license|licence|copying)(\.\w+)?$")
                   or (["README metadata"] if re.search(r"^\s*licen[cs]e\s*:", readme_text, re.I | re.M) else []),
        "dependencies": has(r"requirements.*\.txt$", r"environment\.ya?ml$", r"pyproject\.toml$", r"setup\.py$", r"pipfile",
                            r"package\.json$", r"cargo\.toml$", r"cmakelists\.txt$", r"\.cabal$", r"description$"),
        "container": has(r"dockerfile$", r"\.devcontainer", r"singularity", r"apptainer"),
        "tests": has(r"(^|/)tests?/", r"test_\w+\.py$", r"_test\.py$"),
        "notebooks": len(has(r"\.ipynb$")),
        "seed_files": seeds,
        "weights": has(r"\.(pt|pth|ckpt|h5|onnx|safetensors|bin)$")[:5],
    }


def main():
    args = sys.argv[1:]
    if not args:
        sys.exit(__doc__)
    work = args[0]
    mx = int(args[args.index("--max") + 1]) if "--max" in args else 3
    urls = [args[args.index("--url") + 1]] if "--url" in args else find_urls(work)
    roots = []
    for u in urls:
        r = git_root(u)
        if r and r not in roots:
            roots.append(r)
    others = [u for u in urls if not git_root(u)]
    os.makedirs(os.path.join(work, "repos"), exist_ok=True)
    results = []
    for i, r in enumerate(roots[:mx]):
        dest = os.path.join(work, "repos", re.sub(r"[^A-Za-z0-9_.-]+", "_", r.split("://", 1)[-1])[:80])
        if os.path.exists(dest):
            subprocess.run(["rm", "-rf", dest])
        try:
            results.append(probe(r, dest))
        except Exception as e:
            results.append({"url": r, "ok": False, "error": str(e)})
    json.dump({"links": urls, "probed": results}, open(os.path.join(work, "repo.json"), "w"), indent=2)

    yes = lambda v: "yes" if v else "**no**"
    with open(os.path.join(work, "repo.md"), "w", encoding="utf-8") as f:
        f.write("# Code and data repositories\n\n")
        if urls:
            f.write("Links can be the student's own code or third-party resources the work uses (pretrained models, "
                    "datasets, libraries). Decide from the dissertation which, if any, holds the student's own code, and judge "
                    "reproducibility from that one.\n\n")
        if not urls:
            f.write("No repository links found in the dissertation. If it claims code or data are available, that is a "
                    "reproducibility weakness; if it builds software, ask in the viva where the code is.\n")
        for res in results:
            f.write(f"## {res['url']}\n\n")
            if not res["ok"]:
                f.write(f"Could not be retrieved ({res['error']}). It may be private, moved or deleted; note this as a "
                        "reproducibility concern if the dissertation relies on it.\n\n")
                continue
            f.write(f"- Files: {res['files']} (mostly {', '.join(f'{e} {n}' for e, n in res['top_types'])}); last commit {res['last_commit']}\n"
                    f"- README: {yes(res['readme'])}" + (f" ({res['readme_words']} words; how to run: {yes(res['readme_reproduce'])}; data instructions: {yes(res['readme_data'])})" if res["readme"] else "") + "\n"
                    f"- Licence: {yes(res['license'])}\n"
                    f"- Dependencies pinned in: {', '.join(res['dependencies'][:4]) or '**none found**'}\n"
                    f"- Container: {', '.join(res['container'][:2]) or 'none'}\n"
                    f"- Tests: {yes(res['tests'])}; notebooks: {res['notebooks']}\n"
                    f"- Files setting random seeds: {res['seed_files']}\n"
                    f"- Model weights in the repository: {', '.join(res['weights']) or 'none (may be hosted elsewhere)'}\n\n")
        if len(roots) > mx:
            f.write("Not retrieved (limit of " + str(mx) + "): " + ", ".join(roots[mx:]) + "\n\n")
        if others:
            f.write("Other links (data or archives, not cloned): " + ", ".join(others[:10]) + "\n")
        f.write("\nThe code was not run. Judge reproducibility from this, the dissertation's own description, and the "
                "ML/computing checklists.\n")
    print(f"repositories: {len(urls)} link(s), {sum(1 for r in results if r['ok'])} retrieved - see repo.md")


if __name__ == "__main__":
    main()
