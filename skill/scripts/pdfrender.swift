// Render selected PDF pages to PNG using macOS PDFKit (no external dependencies).
// Usage: pdfrender <file.pdf> <out_dir> <dpi> <page> [<page> ...] [--crop x,y,width,height]
// Prints one line per page: "<index>\t<label>\t<png path>"
import AppKit
import Foundation
import PDFKit

func fail(_ msg: String) -> Never {
    FileHandle.standardError.write((msg + "\n").data(using: .utf8)!)
    exit(1)
}

let a = CommandLine.arguments
guard a.count >= 5, let dpi = Double(a[3]) else { fail("usage: pdfrender <pdf> <out_dir> <dpi> <page>...") }
guard let doc = PDFDocument(url: URL(fileURLWithPath: a[1])) else { fail("cannot open PDF") }
let outDir = URL(fileURLWithPath: a[2])
try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

var pageArgs = a[4...]
var crop: CGRect?
if let flag = pageArgs.firstIndex(of: "--crop") {
    guard flag == 5, a.count == 7 else { fail("--crop requires one page") }
    let parts = a[6].split(separator: ",", omittingEmptySubsequences: false).compactMap { Double($0) }
    guard parts.count == 4, parts.allSatisfy(\.isFinite) else { fail("invalid crop") }
    let x = parts[0], y = parts[1], width = parts[2], height = parts[3]
    guard x >= 0, y >= 0, width > 0, height > 0, x + width <= 1, y + height <= 1 else { fail("crop outside page") }
    crop = CGRect(x: x, y: y, width: width, height: height)
    pageArgs = a[4..<flag]
}

for s in pageArgs {
    guard let n = Int(s), n >= 1, n <= doc.pageCount, let page = doc.page(at: n - 1) else {
        FileHandle.standardError.write("skip page \(s)\n".data(using: .utf8)!)
        continue
    }
    let box = page.bounds(for: .mediaBox)
    let scale = dpi / 72.0
    let w = Int(box.width * scale), h = Int(box.height * scale)
    guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: w, pixelsHigh: h, bitsPerSample: 8,
                                     samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                     colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
          let ctx = NSGraphicsContext(bitmapImageRep: rep) else { fail("bitmap allocation failed") }
    let cg = ctx.cgContext
    cg.setFillColor(NSColor.white.cgColor)
    cg.fill(CGRect(x: 0, y: 0, width: w, height: h))
    cg.scaleBy(x: scale, y: scale)
    cg.translateBy(x: -box.origin.x, y: -box.origin.y)
    page.draw(with: .mediaBox, to: cg)
    let output: NSBitmapImageRep
    if let crop {
        let rect = CGRect(x: crop.minX * CGFloat(w), y: crop.minY * CGFloat(h),
                          width: crop.width * CGFloat(w), height: crop.height * CGFloat(h)).integral
        guard let image = rep.cgImage?.cropping(to: rect) else { fail("cannot crop page") }
        output = NSBitmapImageRep(cgImage: image)
    } else {
        output = rep
    }
    guard let png = output.representation(using: .png, properties: [:]) else { fail("PNG encoding failed") }
    let file = outDir.appendingPathComponent(String(format: "page-%04d.png", n))
    do { try png.write(to: file) } catch { fail("write failed: \(error)") }
    print("\(n)\t\(page.label ?? "")\t\(file.path)")
}
