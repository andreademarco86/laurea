// macOS PDFKit helper for the examiner skill.
//
//   pdftext <file.pdf>          per-page text, page labels, outline and metadata as JSON
//   pdftext --scan <file.pdf>   integrity scan as JSON: text a reader cannot see
//
// The scan renders every page and checks each line of text against the pixels under it.
// A line whose area is visually uniform (white-on-white, same colour as the background,
// covered by an image), a line in a tiny font, or a line placed outside the page is
// reported as hidden. Invisible Unicode characters are reported too.
import AppKit
import Foundation
import PDFKit

func fail(_ msg: String) -> Never {
    FileHandle.standardError.write((msg + "\n").data(using: .utf8)!)
    exit(1)
}

func emit(_ obj: Any) {
    guard let data = try? JSONSerialization.data(withJSONObject: obj, options: []) else { fail("JSON encoding failed") }
    FileHandle.standardOutput.write(data)
}

var args = Array(CommandLine.arguments.dropFirst())
let scanMode = args.first == "--scan"
if scanMode { args.removeFirst() }
guard let path = args.first else { fail("usage: pdftext [--scan] <file.pdf>") }
guard let doc = PDFDocument(url: URL(fileURLWithPath: path)) else { fail("cannot open PDF: \(path)") }
if doc.isLocked { fail("PDF is encrypted/locked") }

// MARK: - Integrity scan

/// Luminance range (0-255) inside a rectangle of an RGBA bitmap.
func luminanceRange(_ rep: NSBitmapImageRep, _ r: CGRect) -> (min: Int, max: Int, pixels: Int) {
    guard let data = rep.bitmapData else { return (0, 255, 0) }
    let w = rep.pixelsWide, h = rep.pixelsHigh, bpr = rep.bytesPerRow, spp = rep.samplesPerPixel
    let x0 = max(0, Int(r.minX.rounded(.down))), x1 = min(w, Int(r.maxX.rounded(.up)))
    let y0 = max(0, Int(r.minY.rounded(.down))), y1 = min(h, Int(r.maxY.rounded(.up)))
    guard x1 > x0, y1 > y0 else { return (0, 0, 0) }
    var lo = 255, hi = 0
    for y in y0..<y1 {
        let row = data + y * bpr
        for x in x0..<x1 {
            let p = row + x * spp
            let lum = (299 * Int(p[0]) + 587 * Int(p[1]) + 114 * Int(p[2])) / 1000
            if lum < lo { lo = lum }
            if lum > hi { hi = lum }
        }
    }
    return (lo, hi, (x1 - x0) * (y1 - y0))
}

func render(_ page: PDFPage, _ box: CGRect, scale: CGFloat) -> NSBitmapImageRep? {
    let w = Int(box.width * scale), h = Int(box.height * scale)
    guard w > 0, h > 0,
          let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: w, pixelsHigh: h, bitsPerSample: 8,
                                     samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                     colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
          let ctx = NSGraphicsContext(bitmapImageRep: rep) else { return nil }
    let cg = ctx.cgContext
    cg.setFillColor(NSColor.white.cgColor)
    cg.fill(CGRect(x: 0, y: 0, width: w, height: h))
    cg.scaleBy(x: scale, y: scale)
    cg.translateBy(x: -box.origin.x, y: -box.origin.y)
    page.draw(with: .cropBox, to: cg)
    return rep
}

let invisibleScalars: Set<UInt32> = [0x200B, 0x200C, 0x200D, 0x200E, 0x200F, 0x2060, 0x2061, 0x2062, 0x2063, 0x2064, 0xFEFF]

var wordsChecked = 0
func scan() -> [[String: Any]] {
    var findings: [[String: Any]] = []
    let scale: CGFloat = 2
    for i in 0..<doc.pageCount {
        guard let page = doc.page(at: i) else { continue }
        let label = page.label ?? ""
        let box = page.bounds(for: .cropBox)
        func add(_ kind: String, _ text: String, _ b: CGRect?) {
            var f: [String: Any] = ["page": i + 1, "label": label, "kind": kind, "text": String(text.prefix(400))]
            if let b { f["bbox"] = [b.minX, b.minY, b.width, b.height].map { Double($0) } }
            findings.append(f)
        }
        // invisible Unicode characters anywhere in the page text
        if let s = page.string {
            let n = s.unicodeScalars.filter { invisibleScalars.contains($0.value) || (0xE0000...0xE007F).contains($0.value) }.count
            if n > 0 { add("invisible characters", "\(n) zero-width or tag characters in the page text", nil) }
        }
        // Word by word: hidden words can share a line with visible ones.
        guard let text = page.string, !text.isEmpty else { continue }
        let rep = render(page, box, scale: scale)
        let ns = text as NSString
        var span: [String] = [], spanKind = "", spanBox = CGRect.null
        func flush() {
            let joined = span.joined(separator: " ")
            if joined.filter({ $0.isLetter }).count >= 6 && span.count >= 2 { add(spanKind, joined, spanBox) }
            span = []; spanKind = ""; spanBox = .null
        }
        ns.enumerateSubstrings(in: NSRange(location: 0, length: ns.length), options: .byWords) { word, range, _, _ in
            guard let word else { return }
            if word.count <= 1 && !span.isEmpty { span.append(word); return }  // short words don't break a hidden span
            guard let sel = page.selection(for: range) else { return }
            let b = sel.bounds(for: page)
            wordsChecked += 1
            var kind = ""
            if b.isEmpty {
                kind = ""
            } else if !b.intersects(box) {
                kind = "outside the page"
            } else if b.height < 2.6 && word.count > 1 {
                kind = "tiny text"
            } else if let rep, word.contains(where: { $0.isLetter || $0.isNumber }) {
                let px = CGRect(x: (b.minX - box.minX) * scale, y: (box.maxY - b.maxY) * scale,
                                width: b.width * scale, height: b.height * scale)
                let r = luminanceRange(rep, px)
                if r.pixels > 0 && r.max - r.min < 24 { kind = "invisible (no visible ink)" }
            }
            if kind.isEmpty {
                flush()
            } else {
                if !spanKind.isEmpty && spanKind != kind { flush() }
                spanKind = kind
                span.append(word)
                spanBox = spanBox.union(b)
            }
        }
        flush()
    }
    return findings
}

if scanMode {
    let found = scan()
    emit(["backend": "pdfkit", "pages": doc.pageCount, "words_checked": wordsChecked, "findings": found])
    exit(0)
}

// MARK: - Text extraction

var pages: [[String: Any]] = []
for i in 0..<doc.pageCount {
    guard let p = doc.page(at: i) else { continue }
    pages.append(["index": i + 1, "label": p.label ?? "", "text": p.string ?? ""])
}

var outline: [[String: Any]] = []
func pageNumber(_ node: PDFOutline) -> Int {
    if let d = node.destination, let pg = d.page { return doc.index(for: pg) + 1 }
    if let a = node.action as? PDFActionGoTo, let pg = a.destination.page { return doc.index(for: pg) + 1 }
    return -1
}
func walk(_ node: PDFOutline, _ level: Int) {
    for i in 0..<node.numberOfChildren {
        guard let c = node.child(at: i) else { continue }
        outline.append(["title": c.label ?? "", "level": level, "page": pageNumber(c)])
        walk(c, level + 1)
    }
}
if let root = doc.outlineRoot { walk(root, 1) }

var meta: [String: String] = [:]
if let attrs = doc.documentAttributes {
    for (k, v) in attrs { meta["\(k)"] = "\(v)" }
}

emit(["backend": "pdfkit", "pages": pages, "outline": outline, "meta": meta])
