#!/usr/bin/env python3
"""Convert an examiner's report (Markdown, as written from templates/examiner-report.md) to Word .docx.

Usage: python3 md_to_docx.py <report.md> <report.docx> [--resource-path DIR[:DIR...]]

Standard library only (no pandoc). Supports what the report template uses: a YAML `title`,
headings (#, ##, ###), paragraphs, **bold** / *italic* / `code`, "- " bullets, "1. " numbered
lists, pipe tables, `&nbsp;` spacers and images `![alt](file.png){width=4.5cm}`.
"""
import html
import os
import re
import struct
import sys
import zipfile

EMU_PER_CM = 360000
FONT = "Calibri"


def esc(s):
    return html.escape(s, quote=False)


def runs(text, bold=False, italic=False):
    """Inline Markdown -> WordprocessingML runs."""
    out = []
    pos = 0
    pat = re.compile(r"(\*\*(.+?)\*\*|\*(?!\s)(.+?)(?<!\s)\*|`([^`]+)`)")
    for m in pat.finditer(text):
        if m.start() > pos:
            out.append(run(text[pos:m.start()], bold, italic))
        if m.group(2) is not None:
            out.extend(runs(m.group(2), True, italic))
        elif m.group(3) is not None:
            out.extend(runs(m.group(3), bold, True))
        else:
            out.append(run(m.group(4), bold, italic, mono=True))
        pos = m.end()
    if pos < len(text):
        out.append(run(text[pos:], bold, italic))
    return out


def run(t, bold=False, italic=False, mono=False):
    t = t.replace("&nbsp;", " ")
    props = ""
    if bold:
        props += "<w:b/>"
    if italic:
        props += "<w:i/>"
    if mono:
        props += '<w:rFonts w:ascii="Menlo" w:hAnsi="Menlo"/><w:sz w:val="19"/>'
    rpr = f"<w:rPr>{props}</w:rPr>" if props else ""
    return f'<w:r>{rpr}<w:t xml:space="preserve">{esc(t)}</w:t></w:r>'


def para(content, style=None, num=None, keep_next=False, spacing_after=None, align=None):
    ppr = ""
    if style:
        ppr += f'<w:pStyle w:val="{style}"/>'
    if keep_next:
        ppr += "<w:keepNext/>"
    if num:
        ppr += f'<w:numPr><w:ilvl w:val="0"/><w:numId w:val="{num}"/></w:numPr>'
    if spacing_after is not None:
        ppr += f'<w:spacing w:after="{spacing_after}"/>'
    if align:
        ppr += f'<w:jc w:val="{align}"/>'
    ppr = f"<w:pPr>{ppr}</w:pPr>" if ppr else ""
    return f"<w:p>{ppr}{''.join(content) if isinstance(content, list) else content}</w:p>"


def png_size(path):
    with open(path, "rb") as f:
        head = f.read(24)
    if head[:8] != b"\x89PNG\r\n\x1a\n":
        return None
    return struct.unpack(">II", head[16:24])


class Doc:
    def __init__(self, resource_dirs):
        self.body = []
        self.media = []  # (zip name, bytes)
        self.rels = []   # (rid, target)
        self.resource_dirs = resource_dirs
        self.num_lists = 0

    def image(self, src, width_cm):
        path = next((os.path.join(d, src) for d in self.resource_dirs if os.path.isfile(os.path.join(d, src))), None)
        if not path:  # no signature yet: leave a line to sign by hand
            return run("______________________________")
        size = png_size(path)
        if not size:
            return run(f"[{src} is not a PNG]", italic=True)
        w_px, h_px = size
        cx = int((width_cm or 4.5) * EMU_PER_CM)
        cy = int(cx * h_px / max(1, w_px))
        n = len(self.media) + 1
        name = f"media/image{n}.png"
        rid = f"rIdImg{n}"
        self.media.append((name, open(path, "rb").read()))
        self.rels.append((rid, name))
        return (
            f'<w:r><w:drawing><wp:inline distT="0" distB="0" distL="0" distR="0"><wp:extent cx="{cx}" cy="{cy}"/>'
            f'<wp:docPr id="{n}" name="Picture {n}"/><a:graphic><a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/picture">'
            f'<pic:pic><pic:nvPicPr><pic:cNvPr id="{n}" name="{esc(src)}"/><pic:cNvPicPr/></pic:nvPicPr>'
            f'<pic:blipFill><a:blip r:embed="{rid}"/><a:stretch><a:fillRect/></a:stretch></pic:blipFill>'
            f'<pic:spPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="{cx}" cy="{cy}"/></a:xfrm><a:prstGeom prst="rect"><a:avLst/></a:prstGeom></pic:spPr>'
            f"</pic:pic></a:graphicData></a:graphic></wp:inline></w:drawing></w:r>"
        )

    def inline_with_images(self, text):
        parts, pos = [], 0
        for m in re.finditer(r"!\[[^\]]*\]\(([^)]+)\)(\{width=([\d.]+)cm\})?", text):
            if m.start() > pos:
                parts.extend(runs(text[pos:m.start()]))
            parts.append(self.image(m.group(1), float(m.group(3)) if m.group(3) else None))
            pos = m.end()
        if pos < len(text):
            parts.extend(runs(text[pos:]))
        return parts

    def table(self, rows):
        header, body = rows[0], rows[1:]
        aligns = []
        if body and all(re.fullmatch(r":?-{3,}:?", c.strip()) for c in body[0]):
            aligns = ["center" if c.strip().startswith(":") and c.strip().endswith(":") else None for c in body[0]]
            body = body[1:]
        two_col_kv = all(not c.strip() for c in header)  # "| | |" header = key/value table
        ncols = len(header)
        width = 9360  # twips across the text block
        if two_col_kv and ncols == 2:
            widths = [3000, width - 3000]
        elif ncols == 3:
            widths = [width - 2400, 1200, 1200]
        else:
            widths = [width // ncols] * ncols
        grid = "".join(f'<w:gridCol w:w="{w}"/>' for w in widths)
        border = '<w:{0} w:val="single" w:sz="4" w:space="0" w:color="C8CCD6"/>'
        borders = "".join(border.format(b) for b in ("top", "left", "bottom", "right", "insideH", "insideV"))
        out = [f'<w:tbl><w:tblPr><w:tblW w:w="{width}" w:type="dxa"/><w:tblLayout w:type="fixed"/><w:tblBorders>{borders}</w:tblBorders>'
               f'<w:tblCellMar><w:top w:w="60" w:type="dxa"/><w:left w:w="110" w:type="dxa"/><w:bottom w:w="60" w:type="dxa"/>'
               f'<w:right w:w="110" w:type="dxa"/></w:tblCellMar><w:tblLook w:val="04A0"/></w:tblPr><w:tblGrid>{grid}</w:tblGrid>']

        def row(cells, is_header=False, is_total=False):
            tr = ["<w:tr>"]
            for i in range(ncols):
                c = cells[i].strip() if i < len(cells) else ""
                shade = '<w:shd w:val="clear" w:color="auto" w:fill="EEF1F8"/>' if (is_header or (two_col_kv and i == 0) or is_total) else ""
                al = aligns[i] if i < len(aligns) else None
                content = runs(c, bold=is_header) if c else [run("")]
                tr.append(f'<w:tc><w:tcPr><w:tcW w:w="{widths[i]}" w:type="dxa"/>{shade}</w:tcPr>'
                          f'{para(content, spacing_after=0, align=al)}</w:tc>')
            tr.append("</w:tr>")
            return "".join(tr)

        if not two_col_kv:
            out.append(row(header, is_header=True))
        for r in body:
            out.append(row(r, is_total=bool(re.match(r"\*\*Total", r[0].strip()))))
        out.append("</w:tbl>")
        self.body.append("".join(out))
        self.body.append(para("", spacing_after=0))

    def build(self, md):
        title = None
        m = re.match(r"^---\s*\n(.*?)\n---\s*\n", md, re.S)
        if m:
            t = re.search(r'^title:\s*"?(.*?)"?\s*$', m.group(1), re.M)
            title = t.group(1) if t else None
            md = md[m.end():]
        if title:
            self.body.append(para(runs(title), style="Title"))

        lines = md.splitlines()
        i, list_kind = 0, None
        while i < len(lines):
            line = lines[i]
            s = line.strip()
            if not s:
                list_kind = None
                i += 1
                continue
            if s.startswith("|"):
                rows = []
                while i < len(lines) and lines[i].strip().startswith("|"):
                    rows.append([c for c in lines[i].strip().strip("|").split("|")])
                    i += 1
                self.table(rows)
                list_kind = None
                continue
            h = re.match(r"^(#{1,3})\s+(.*)$", s)
            if h:
                lvl = len(h.group(1))
                self.body.append(para(runs(h.group(2)), style=f"Heading{lvl}", keep_next=True))
                list_kind = None
                i += 1
                continue
            b = re.match(r"^[-*]\s+(.*)$", s)
            n = re.match(r"^\d+\.\s+(.*)$", s)
            if b or n:
                text = (b or n).group(1)
                while i + 1 < len(lines) and lines[i + 1].startswith(("  ", "\t")) and lines[i + 1].strip() \
                        and not re.match(r"^\s*([-*]|\d+\.)\s", lines[i + 1]):
                    i += 1
                    text += " " + lines[i].strip()
                if n and list_kind != "num":
                    self.num_lists += 1
                kind = "num" if n else "bullet"
                list_kind = kind
                num_id = 1 if kind == "bullet" else 1 + self.num_lists
                self.body.append(para(self.inline_with_images(text), style="ListParagraph", num=num_id, spacing_after=60))
                i += 1
                continue
            # paragraph: join following plain lines
            text = s
            while i + 1 < len(lines) and lines[i + 1].strip() and not re.match(r"^(\||#{1,3}\s|[-*]\s|\d+\.\s)", lines[i + 1].strip()):
                i += 1
                text += " " + lines[i].strip()
            if text == "&nbsp;":
                self.body.append(para(""))
            else:
                self.body.append(para(self.inline_with_images(text)))
            list_kind = None
            i += 1

    def save(self, out):
        ns = ('xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" '
              'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" '
              'xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing" '
              'xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" '
              'xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture"')
        sect = ('<w:sectPr><w:pgSz w:w="11906" w:h="16838"/><w:pgMar w:top="1300" w:right="1270" w:bottom="1300" w:left="1270" '
                'w:header="708" w:footer="708" w:gutter="0"/></w:sectPr>')
        document = f'<?xml version="1.0" encoding="UTF-8" standalone="yes"?><w:document {ns}><w:body>{"".join(self.body)}{sect}</w:body></w:document>'
        rels = "".join(f'<Relationship Id="{rid}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="{t}"/>'
                       for rid, t in self.rels)
        doc_rels = ('<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
                    '<Relationship Id="rIdStyles" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>'
                    '<Relationship Id="rIdNum" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/numbering" Target="numbering.xml"/>'
                    f"{rels}</Relationships>")
        with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as z:
            z.writestr("[Content_Types].xml", CONTENT_TYPES)
            z.writestr("_rels/.rels", ROOT_RELS)
            z.writestr("word/document.xml", document)
            z.writestr("word/_rels/document.xml.rels", doc_rels)
            z.writestr("word/styles.xml", STYLES)
            z.writestr("word/numbering.xml", numbering(1 + self.num_lists))
            for name, data in self.media:
                z.writestr("word/" + name, data)


def numbering(n_lists):
    bullet = ('<w:abstractNum w:abstractNumId="0"><w:multiLevelType w:val="singleLevel"/><w:lvl w:ilvl="0"><w:start w:val="1"/>'
              '<w:numFmt w:val="bullet"/><w:lvlText w:val="•"/><w:lvlJc w:val="left"/><w:pPr><w:ind w:left="360" w:hanging="260"/></w:pPr>'
              '</w:lvl></w:abstractNum>')
    dec = ('<w:abstractNum w:abstractNumId="1"><w:multiLevelType w:val="singleLevel"/><w:lvl w:ilvl="0"><w:start w:val="1"/>'
           '<w:numFmt w:val="decimal"/><w:lvlText w:val="%1."/><w:lvlJc w:val="left"/><w:pPr><w:ind w:left="400" w:hanging="300"/></w:pPr>'
           '</w:lvl></w:abstractNum>')
    nums = '<w:num w:numId="1"><w:abstractNumId w:val="0"/></w:num>'
    for k in range(2, n_lists + 1):
        nums += (f'<w:num w:numId="{k}"><w:abstractNumId w:val="1"/><w:lvlOverride w:ilvl="0"><w:startOverride w:val="1"/>'
                 f"</w:lvlOverride></w:num>")
    return ('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
            f'<w:numbering xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">{bullet}{dec}{nums}</w:numbering>')


CONTENT_TYPES = ('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
                 '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
                 '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
                 '<Default Extension="xml" ContentType="application/xml"/><Default Extension="png" ContentType="image/png"/>'
                 '<Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>'
                 '<Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/>'
                 '<Override PartName="/word/numbering.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.numbering+xml"/>'
                 "</Types>")
ROOT_RELS = ('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
             '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
             '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>'
             "</Relationships>")


def _style(sid, name, ppr="", rpr="", based="Normal", kind="paragraph"):
    b = f'<w:basedOn w:val="{based}"/>' if based else ""
    return (f'<w:style w:type="{kind}" w:styleId="{sid}"><w:name w:val="{name}"/>{b}<w:qFormat/>'
            f"<w:pPr>{ppr}</w:pPr><w:rPr>{rpr}</w:rPr></w:style>")


STYLES = ('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
          '<w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">'
          f'<w:docDefaults><w:rPrDefault><w:rPr><w:rFonts w:ascii="{FONT}" w:hAnsi="{FONT}" w:cs="{FONT}"/><w:sz w:val="22"/>'
          '<w:lang w:val="en-GB"/></w:rPr></w:rPrDefault><w:pPrDefault><w:pPr><w:spacing w:after="120" w:line="264" w:lineRule="auto"/></w:pPr>'
          "</w:pPrDefault></w:docDefaults>"
          + _style("Normal", "Normal", based=None)
          + _style("Title", "Title", '<w:spacing w:after="240"/>', '<w:b/><w:color w:val="1F2A6B"/><w:sz w:val="40"/>')
          + _style("Heading1", "heading 1", '<w:spacing w:before="320" w:after="120"/><w:outlineLvl w:val="0"/>', '<w:b/><w:color w:val="1F2A6B"/><w:sz w:val="32"/>')
          + _style("Heading2", "heading 2", '<w:spacing w:before="300" w:after="100"/><w:outlineLvl w:val="1"/>', '<w:b/><w:color w:val="1F2A6B"/><w:sz w:val="28"/>')
          + _style("Heading3", "heading 3", '<w:spacing w:before="220" w:after="80"/><w:outlineLvl w:val="2"/>', '<w:b/><w:color w:val="2C3C9E"/><w:sz w:val="24"/>')
          + _style("ListParagraph", "List Paragraph", '<w:ind w:left="360"/>')
          + "</w:styles>")


def main():
    args = sys.argv[1:]
    if len(args) < 2:
        sys.exit(__doc__)
    src, out = args[0], args[1]
    dirs = [os.path.dirname(os.path.abspath(src)), os.getcwd()]
    if "--resource-path" in args:
        dirs += args[args.index("--resource-path") + 1].split(":")
    d = Doc(dirs)
    d.build(open(src, encoding="utf-8").read())
    d.save(out)
    print(f"wrote {out}")


if __name__ == "__main__":
    main()
