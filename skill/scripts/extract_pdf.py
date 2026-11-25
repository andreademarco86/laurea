#!/usr/bin/env python3
"""Extract a dissertation PDF into page-marked text for examination.

Usage: python3 extract_pdf.py <dissertation.pdf> <work_dir>

Writes into <work_dir>:
  pages.txt   - every page, prefixed "===== [PDF p.N | printed p.X] ====="
  outline.txt - PDF bookmarks (title, level, PDF page, printed page)
  meta.json   - backend, page count, page labels, word count, PDF metadata

Backends, in order: pypdf, PyMuPDF (fitz), macOS PDFKit via Swift (no install needed on macOS).
"""
import json
import os
import re
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROMAN = re.compile(r"^(?=[ivxlcdm]+$)m{0,3}(cm|cd|d?c{0,3})(xc|xl|l?x{0,3})(ix|iv|v?i{0,3})$", re.I)


def via_pypdf(path):
    from pypdf import PdfReader

    r = PdfReader(path)
    try:
        labels = list(r.page_labels)
    except Exception:
        labels = [""] * len(r.pages)
    pages = [
        {"index": i + 1, "label": labels[i] if i < len(labels) else "", "text": p.extract_text() or ""}
        for i, p in enumerate(r.pages)
    ]
    outline = []

    def walk(items, level):
        for it in items:
            if isinstance(it, list):
                walk(it, level + 1)
                continue
            try:
                pg = r.get_destination_page_number(it) + 1
            except Exception:
                pg = -1
            outline.append({"title": str(getattr(it, "title", "")), "level": level, "page": pg})

    try:
        walk(r.outline, 1)
    except Exception:
        pass
    meta = {k.lstrip("/"): str(v) for k, v in (r.metadata or {}).items()}
    return {"backend": "pypdf", "pages": pages, "outline": outline, "meta": meta}


def via_fitz(path):
    import fitz  # PyMuPDF

    doc = fitz.open(path)
    pages = [{"index": i + 1, "label": p.get_label() or "", "text": p.get_text()} for i, p in enumerate(doc)]
    outline = [{"title": t, "level": lvl, "page": pg} for lvl, t, pg in doc.get_toc()]
    meta = {k: str(v) for k, v in (doc.metadata or {}).items() if v}
    return {"backend": "pymupdf", "pages": pages, "outline": outline, "meta": meta}


def via_pdfkit(path):
    if sys.platform != "darwin":
        raise RuntimeError("PDFKit backend only available on macOS")
    src = os.path.join(HERE, "pdftext.swift")
    binary = os.path.join(HERE, "bin", "pdftext")
    cmd = ["swift", src, path]  # interpreted fallback (slow: ~30 s)
    try:  # compile once, reuse afterwards
        if not os.path.exists(binary) or os.path.getmtime(binary) < os.path.getmtime(src):
            os.makedirs(os.path.dirname(binary), exist_ok=True)
            subprocess.run(["swiftc", "-O", src, "-o", binary], check=True, capture_output=True, timeout=600)
        cmd = [binary, path]
    except Exception:
        pass
    res = subprocess.run(cmd, capture_output=True, timeout=600)
    if res.returncode != 0:
        raise RuntimeError(res.stderr.decode(errors="replace").strip())
    return json.loads(res.stdout.decode("utf-8", errors="replace"))


def guess_label(text, max_page):
    """Find a printed page number in the first/last lines of a page's text."""
    lines = [l.strip() for l in text.splitlines() if l.strip()]
    for cand in lines[-2:][::-1] + lines[:2]:
        # e.g. "12", "- 12 -", "Page 12", "12 Chapter 3. Method", "Chapter 3. Method 12"
        m = re.fullmatch(r"(?:page\s+)?[-–]?\s*(\d{1,4}|[ivxlcdm]{1,7})\s*[-–]?(?:\s+of\s+\d+)?", cand, re.I)
        if not m:
            m = re.match(r"^(\d{1,4})\s+\S", cand) or re.search(r"\S\s+(\d{1,4})$", cand)
        if m:
            tok = m.group(1)
            if (tok.isdigit() and 0 < int(tok) <= max_page) or (not tok.isdigit() and ROMAN.match(tok)):
                return tok.lower() if not tok.isdigit() else tok
    return ""


def main():
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    pdf, work = sys.argv[1], sys.argv[2]
    if not os.path.isfile(pdf):
        sys.exit(f"not a file: {pdf}")
    os.makedirs(work, exist_ok=True)

    data, errors = None, []
    for fn in (via_pypdf, via_fitz, via_pdfkit):
        try:
            data = fn(pdf)
            break
        except ImportError:
            continue
        except Exception as e:  # try the next backend
            errors.append(f"{fn.__name__}: {e}")
    if data is None:
        sys.exit("all extraction backends failed:\n" + "\n".join(errors))

    pages = data["pages"]
    explicit = any(p["label"] and p["label"] != str(p["index"]) for p in pages)
    label_source = "pdf-page-labels" if explicit else "heuristic-from-text"
    if not explicit:
        for p in pages:
            p["label"] = guess_label(p["text"], len(pages))

    total_words = 0
    with open(os.path.join(work, "pages.txt"), "w", encoding="utf-8") as f:
        for p in pages:
            total_words += len(p["text"].split())
            f.write(f"\n===== [PDF p.{p['index']} | printed p.{p['label'] or '?'}] =====\n")
            f.write(p["text"].rstrip() + "\n")

    label_of = {p["index"]: p["label"] for p in pages}
    with open(os.path.join(work, "outline.txt"), "w", encoding="utf-8") as f:
        if not data["outline"]:
            f.write("(no PDF bookmarks - build the section map from the table of contents)\n")
        for o in data["outline"]:
            pl = label_of.get(o["page"], "") or "?"
            f.write(f"{'  ' * (o['level'] - 1)}{o['title']}  [PDF p.{o['page']} | printed p.{pl}]\n")

    empty = [p["index"] for p in pages if len(p["text"].split()) < 5]
    meta = {
        "backend": data["backend"],
        "page_count": len(pages),
        "label_source": label_source,
        "page_labels": [p["label"] for p in pages],
        "total_words": total_words,
        "near_empty_pages": empty,
        "pdf_metadata": data.get("meta", {}),
    }
    with open(os.path.join(work, "meta.json"), "w", encoding="utf-8") as f:
        json.dump(meta, f, indent=2, ensure_ascii=False)

    print(f"backend={meta['backend']} pages={meta['page_count']} words~{total_words} labels={label_source}")
    if len(empty) > 0.3 * len(pages):
        print(f"WARNING: {len(empty)} pages have almost no text - PDF may be scanned; read it visually with the Read tool.")
    missing = sum(1 for p in pages if not p["label"])
    if missing:
        print(f"note: {missing} pages without a detected printed page number (cover/blank pages are normal).")
    print(f"wrote {work}/pages.txt, outline.txt, meta.json")


if __name__ == "__main__":
    main()
