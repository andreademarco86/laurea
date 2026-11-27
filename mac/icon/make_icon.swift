// Renders the 1024x1024 app icon: swift make_icon.swift out.png
//
// A gold laurel wreath around an upright page with a check badge, on an indigo-violet squircle.
// The emblem is roughly square, as the macOS icon grid expects.
// The artwork is drawn on its own layer, measured, and placed at the optical centre of the squircle,
// so it is centred by its actual pixels rather than by hand-tuned offsets.
import AppKit

let size: CGFloat = 1024
let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon_1024.png"

func color(_ hex: UInt32, _ a: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 0xff) / 255, green: CGFloat((hex >> 8) & 0xff) / 255,
            blue: CGFloat(hex & 0xff) / 255, alpha: a)
}

func bitmap() -> NSBitmapImageRep {
    NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size), bitsPerSample: 8,
                     samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                     bytesPerRow: 0, bitsPerPixel: 0)!
}

func draw(into rep: NSBitmapImageRep, _ body: (CGContext) -> Void) {
    NSGraphicsContext.saveGraphicsState()
    let ctx = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.current = ctx
    body(ctx.cgContext)
    ctx.flushGraphics()
    NSGraphicsContext.restoreGraphicsState()
}

/// A continuous-corner squircle (superellipse), like the macOS icon shape.
func squircle(in r: CGRect, exponent n: CGFloat = 4.4) -> NSBezierPath {
    let path = NSBezierPath()
    let (cx, cy, a, b) = (r.midX, r.midY, r.width / 2, r.height / 2)
    for i in 0...720 {
        let t = CGFloat(i) / 720 * 2 * .pi
        let c = cos(t), s = sin(t)
        let x = cx + a * (c < 0 ? -1 : 1) * pow(abs(c), 2 / n)
        let y = cy + b * (s < 0 ? -1 : 1) * pow(abs(s), 2 / n)
        i == 0 ? path.move(to: CGPoint(x: x, y: y)) : path.line(to: CGPoint(x: x, y: y))
    }
    path.close()
    return path
}

/// An SF Symbol filled with a vertical gradient, drawn to fit `rect` (aspect preserved, centred).
func gradientSymbol(_ name: String, in rect: CGRect, colors: [NSColor], weight: NSFont.Weight = .regular, mirrored: Bool = false) {
    let cfg = NSImage.SymbolConfiguration(pointSize: 400, weight: weight)
    guard let sym = NSImage(systemSymbolName: name, accessibilityDescription: nil)?.withSymbolConfiguration(cfg) else { return }
    let scale = min(rect.width / sym.size.width, rect.height / sym.size.height)
    let s = NSSize(width: sym.size.width * scale, height: sym.size.height * scale)
    let tile = NSImage(size: s)
    tile.lockFocus()
    // Symbol first, then the gradient only where the symbol is (sourceIn covers the whole tile, so no edge leaks).
    sym.draw(in: NSRect(origin: .zero, size: s))
    NSGraphicsContext.current?.compositingOperation = .sourceIn
    NSGradient(colors: colors)!.draw(in: NSRect(origin: .zero, size: s), angle: -90)
    tile.unlockFocus()
    let cg = NSGraphicsContext.current!.cgContext
    cg.saveGState()
    if mirrored {  // a mirror image, so the wreath is exactly symmetric
        cg.translateBy(x: rect.midX * 2, y: 0)
        cg.scaleBy(x: -1, y: 1)
    }
    tile.draw(in: CGRect(x: rect.midX - s.width / 2, y: rect.midY - s.height / 2, width: s.width, height: s.height))
    cg.restoreGState()
}

// MARK: Background

let body = CGRect(x: 100, y: 100, width: 824, height: 824)
let canvas = bitmap()
draw(into: canvas) { cg in
    let shape = squircle(in: body)
    cg.saveGState()
    cg.setShadow(offset: CGSize(width: 0, height: -14), blur: 30, color: NSColor.black.withAlphaComponent(0.32).cgColor)
    color(0x2A1F7A).setFill()
    shape.fill()
    cg.restoreGState()

    cg.saveGState()
    shape.addClip()
    // Indigo to deep violet, top-left to bottom-right
    NSGradient(colors: [color(0x7B8CFF), color(0x5B47F0), color(0x3A1C9C)], atLocations: [0, 0.5, 1], colorSpace: .sRGB)!
        .draw(in: body, angle: -55)
    // Warm glow, bottom right
    NSGradient(colors: [color(0xFF8FB1, 0.55), color(0xFF8FB1, 0)])!
        .draw(fromCenter: CGPoint(x: 860, y: 170), radius: 0, toCenter: CGPoint(x: 860, y: 170), radius: 560, options: [])
    // Soft light, top left
    NSGradient(colors: [NSColor.white.withAlphaComponent(0.28), NSColor.white.withAlphaComponent(0)])!
        .draw(fromCenter: CGPoint(x: 240, y: 900), radius: 0, toCenter: CGPoint(x: 240, y: 900), radius: 620, options: [])
    cg.restoreGState()

    // Fine inner edge
    let edge = squircle(in: body.insetBy(dx: 2, dy: 2))
    edge.lineWidth = 3
    NSColor.white.withAlphaComponent(0.16).setStroke()
    edge.stroke()
}

// MARK: Artwork, drawn on its own layer

let gold = [color(0xFFE7A3), color(0xF6C344), color(0xD9951A)]
let art = bitmap()
draw(into: art) { cg in
    let c = CGPoint(x: 512, y: 512)

    // Laurel wreath: two mirrored branches that meet below the page, forming a near-circular emblem
    // whose bounding box is about square, as the macOS icon grid expects.
    let branch = CGRect(x: c.x - 375, y: c.y - 330, width: 375, height: 660)
    gradientSymbol("laurel.leading", in: branch, colors: gold, weight: .medium)
    gradientSymbol("laurel.leading", in: branch.offsetBy(dx: 2 * (c.x - branch.midX), dy: 0), colors: gold, weight: .medium,
                   mirrored: true)

    // Upright page
    let page = CGRect(x: c.x - 126, y: c.y - 142, width: 252, height: 344)
    cg.saveGState()
    cg.setShadow(offset: CGSize(width: 0, height: -12), blur: 26, color: NSColor.black.withAlphaComponent(0.30).cgColor)
    NSColor.white.setFill()
    NSBezierPath(roundedRect: page, xRadius: 30, yRadius: 30).fill()
    cg.restoreGState()
    let line = color(0xCBC6F2)
    for (i, w) in [160, 182, 140, 170].enumerated() {
        line.setFill()
        let y = page.maxY - 70 - CGFloat(i) * 47
        NSBezierPath(roundedRect: CGRect(x: page.minX + 36, y: y, width: CGFloat(w), height: 18), xRadius: 9, yRadius: 9).fill()
    }

    // Check badge at the foot of the page
    let badge = CGRect(x: c.x - 66, y: page.minY - 56, width: 132, height: 132)
    cg.saveGState()
    cg.setShadow(offset: CGSize(width: 0, height: -8), blur: 18, color: NSColor.black.withAlphaComponent(0.30).cgColor)
    let disc = NSBezierPath(ovalIn: badge)
    color(0xF6C344).setFill()
    disc.fill()
    cg.restoreGState()
    cg.saveGState()
    NSBezierPath(ovalIn: badge).addClip()
    NSGradient(colors: gold)!.draw(in: badge, angle: -90)
    cg.restoreGState()
    let tick = NSBezierPath()
    tick.lineWidth = 16; tick.lineCapStyle = .round; tick.lineJoinStyle = .round
    tick.move(to: CGPoint(x: badge.midX - 26, y: badge.midY + 2))
    tick.line(to: CGPoint(x: badge.midX - 7, y: badge.midY - 18))
    tick.line(to: CGPoint(x: badge.midX + 27, y: badge.midY + 21))
    color(0x3A1C9C).setStroke()
    tick.stroke()
}

/// Bounding box of the layer's visible pixels, in drawing coordinates (origin bottom left).
func visibleBounds(_ rep: NSBitmapImageRep) -> CGRect {
    var (minX, minY, maxX, maxY) = (Int.max, Int.max, Int.min, Int.min)
    let w = rep.pixelsWide, h = rep.pixelsHigh
    guard let data = rep.bitmapData else { return .zero }
    for y in 0..<h {
        let row = data + y * rep.bytesPerRow
        for x in 0..<w where row[x * rep.samplesPerPixel + 3] > 24 {
            minX = min(minX, x); maxX = max(maxX, x); minY = min(minY, y); maxY = max(maxY, y)
        }
    }
    // Bitmap rows run top to bottom; flip to drawing coordinates.
    return CGRect(x: minX, y: h - 1 - maxY, width: maxX - minX + 1, height: maxY - minY + 1)
}

let box = visibleBounds(art)
// Optical centre sits a touch above the geometric one.
let target = CGPoint(x: body.midX, y: body.midY + 6)
// The artwork is symmetric about x = 512 by construction, so only the vertical position is measured.
let shift = CGPoint(x: target.x - 512, y: target.y - box.midY)

draw(into: canvas) { _ in
    NSImage(cgImage: art.cgImage!, size: NSSize(width: size, height: size))
        .draw(in: CGRect(x: shift.x, y: shift.y, width: size, height: size))
}

try! canvas.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
print("wrote \(out) (artwork \(Int(box.width))x\(Int(box.height)), shifted \(Int(shift.x)),\(Int(shift.y)))")
