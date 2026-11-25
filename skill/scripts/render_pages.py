#!/usr/bin/env python3
"""Render dissertation pages to PNG so they can be viewed (figures, tables, diagrams).

Usage: python3 render_pages.py <dissertation.pdf> <work_dir> <pages> [--dpi 110] [--printed]

<pages> is a list like "41-47,52" of PDF page numbers, or of printed page numbers with
--printed (resolved through <work_dir>/meta.json from extract_pdf.py).
Writes <work_dir>/page_images/page-NNNN.png (NNNN = PDF page) and prints their paths;
open each PNG with the Read tool. Uses PyMuPDF if installed, otherwise macOS PDFKit.
"""
import json
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))


def parse_spec(spec, labels=None):
    out = []
    for part in spec.split(","):
        part = part.strip()
        if not part:
            continue
        if labels is not None:
            lo, _, hi = part.partition("-")
            lab = [str(l).lower() for l in labels]
            if lo.lower() not in lab:
                sys.exit(f"printed page {lo} not found in meta.json")
            i = lab.index(lo.lower()) + 1
            j = (lab.index(hi.lower()) + 1) if hi and hi.lower() in lab else i + (int(hi) - int(lo) if hi.isdigit() and lo.isdigit() else 0)
            out += list(range(i, j + 1))
        elif "-" in part:
            a, b = part.split("-", 1)
            out += list(range(int(a), int(b) + 1))
        else:
            out.append(int(part))
    return sorted(set(out))


def main():
    args = sys.argv[1:]
    if len(args) < 3:
        sys.exit(__doc__)
    pdf, work, spec = args[:3]
    dpi = int(args[args.index("--dpi") + 1]) if "--dpi" in args else 110
    labels = None
    if "--printed" in args:
        with open(os.path.join(work, "meta.json"), encoding="utf-8") as f:
            labels = json.load(f)["page_labels"]
    pages = parse_spec(spec, labels)
    if len(pages) > 30:
        sys.exit("render at most 30 pages per call")
    out = os.path.join(work, "page_images")
    os.makedirs(out, exist_ok=True)
    try:
        import fitz

        doc = fitz.open(pdf)
        for n in pages:
            p = doc[n - 1]
            f = os.path.join(out, f"page-{n:04d}.png")
            p.get_pixmap(dpi=dpi).save(f)
            print(f"{n}\t{p.get_label()}\t{f}")
        return
    except ImportError:
        pass
    src = os.path.join(HERE, "pdfrender.swift")
    binary = os.path.join(HERE, "bin", "pdfrender")
    if not os.path.exists(binary) or os.path.getmtime(binary) < os.path.getmtime(src):
        os.makedirs(os.path.dirname(binary), exist_ok=True)
        subprocess.run(["swiftc", "-O", src, "-o", binary], check=True)
    res = subprocess.run([binary, pdf, out, str(dpi), *map(str, pages)], capture_output=True, text=True)
    sys.stdout.write(res.stdout)
    if res.returncode != 0:
        sys.exit(res.stderr)


if __name__ == "__main__":
    main()
