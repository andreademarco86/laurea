// Renders the 1024x1024 app icon: swift make_icon.swift out.png
import AppKit

let size: CGFloat = 1024
let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon_1024.png"

let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size), bitsPerSample: 8,
                           samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                           bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
let ctx = NSGraphicsContext(bitmapImageRep: rep)!
NSGraphicsContext.current = ctx
let cg = ctx.cgContext

func color(_ hex: UInt32, _ a: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 0xff) / 255, green: CGFloat((hex >> 8) & 0xff) / 255, blue: CGFloat(hex & 0xff) / 255, alpha: a)
}

// Squircle background on the macOS icon grid (824pt body, 100pt margin)
let body = CGRect(x: 100, y: 100, width: 824, height: 824)
let squircle = NSBezierPath(roundedRect: body, xRadius: 186, yRadius: 186)
cg.saveGState()
cg.setShadow(offset: CGSize(width: 0, height: -12), blur: 28, color: NSColor.black.withAlphaComponent(0.35).cgColor)
color(0x1F2A6B).setFill()
squircle.fill()
cg.restoreGState()
squircle.addClip()
NSGradient(colors: [color(0x4D6BFE), color(0x2C3C9E), color(0x1B2366)], atLocations: [0, 0.55, 1], colorSpace: .sRGB)!
    .draw(in: body, angle: -90)
// soft top highlight
NSGradient(colors: [NSColor.white.withAlphaComponent(0.18), NSColor.white.withAlphaComponent(0)])!
    .draw(in: CGRect(x: 100, y: 560, width: 824, height: 364), angle: -90)

// Paper sheet, slightly rotated
cg.saveGState()
cg.translateBy(x: 470, y: 470)
cg.rotate(by: -6 * .pi / 180)
let paper = CGRect(x: -215, y: -275, width: 430, height: 550)
cg.setShadow(offset: CGSize(width: 0, height: -14), blur: 30, color: NSColor.black.withAlphaComponent(0.35).cgColor)
NSColor.white.setFill()
NSBezierPath(roundedRect: paper, xRadius: 34, yRadius: 34).fill()
cg.setShadow(offset: .zero, blur: 0, color: nil)
// text lines
let lineColor = color(0xC9D0E3)
for (i, w) in [300, 340, 270, 330, 220, 310].enumerated() {
    lineColor.setFill()
    let y = 175 - CGFloat(i) * 62
    NSBezierPath(roundedRect: CGRect(x: -165, y: y, width: CGFloat(w), height: 22), xRadius: 11, yRadius: 11).fill()
}
// red margin rule, like a marked manuscript
color(0xE5484D, 0.55).setFill()
NSBezierPath(rect: CGRect(x: -185, y: -245, width: 6, height: 490)).fill()
cg.restoreGState()

// SF Symbols
func symbol(_ name: String, _ pt: CGFloat, _ colors: [NSColor], at p: CGPoint, weight: NSFont.Weight = .semibold) {
    let cfg = NSImage.SymbolConfiguration(pointSize: pt, weight: weight).applying(.init(paletteColors: colors))
    guard let img = NSImage(systemSymbolName: name, accessibilityDescription: nil)?.withSymbolConfiguration(cfg) else { return }
    let s = img.size
    img.draw(in: CGRect(x: p.x - s.width / 2, y: p.y - s.height / 2, width: s.width, height: s.height))
}

// Gold laurel medallion: a wreath around a check, bottom right
let gold = [color(0xFFE08A), color(0xF5B83D), color(0xC98A12)]
let medal = CGPoint(x: 690, y: 330)
cg.saveGState()
cg.setShadow(offset: CGSize(width: 0, height: -12), blur: 24, color: NSColor.black.withAlphaComponent(0.4).cgColor)
// disc
let disc = NSBezierPath(ovalIn: CGRect(x: medal.x - 150, y: medal.y - 150, width: 300, height: 300))
disc.addClip()
NSGradient(colors: [color(0x2B3A9E), color(0x18205C)])!.draw(in: disc.bounds, angle: -90)
cg.restoreGState()
cg.saveGState()
let ring = NSBezierPath(ovalIn: CGRect(x: medal.x - 150, y: medal.y - 150, width: 300, height: 300))
ring.lineWidth = 12
NSColor(patternImage: { () -> NSImage in
    let im = NSImage(size: NSSize(width: 300, height: 300)); im.lockFocus()
    NSGradient(colors: gold)!.draw(in: NSRect(x: 0, y: 0, width: 300, height: 300), angle: -90); im.unlockFocus(); return im }()).setStroke()
color(0xF2B33A).setStroke()
ring.stroke()
cg.restoreGState()
// laurels
symbol("laurel.leading", 180, [color(0xF7C548)], at: CGPoint(x: medal.x - 78, y: medal.y - 2), weight: .semibold)
symbol("laurel.trailing", 180, [color(0xF7C548)], at: CGPoint(x: medal.x + 78, y: medal.y - 2), weight: .semibold)
// check
let check = NSBezierPath()
check.lineWidth = 22; check.lineCapStyle = .round; check.lineJoinStyle = .round
check.move(to: CGPoint(x: medal.x - 30, y: medal.y + 2))
check.line(to: CGPoint(x: medal.x - 8, y: medal.y - 22))
check.line(to: CGPoint(x: medal.x + 32, y: medal.y + 28))
NSColor.white.setStroke(); check.stroke()

NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
print("wrote \(out)")
