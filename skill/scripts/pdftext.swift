// Extract per-page text, page labels, outline and metadata from a PDF using macOS PDFKit.
// Usage: swift pdftext.swift <file.pdf>   -> JSON on stdout
import Foundation
import PDFKit

func fail(_ msg: String) -> Never {
    FileHandle.standardError.write((msg + "\n").data(using: .utf8)!)
    exit(1)
}

let args = CommandLine.arguments
guard args.count >= 2 else { fail("usage: swift pdftext.swift <file.pdf>") }
guard let doc = PDFDocument(url: URL(fileURLWithPath: args[1])) else { fail("cannot open PDF: \(args[1])") }
if doc.isLocked { fail("PDF is encrypted/locked") }

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

let out: [String: Any] = ["backend": "pdfkit", "pages": pages, "outline": outline, "meta": meta]
guard let data = try? JSONSerialization.data(withJSONObject: out, options: []) else { fail("JSON encoding failed") }
FileHandle.standardOutput.write(data)
