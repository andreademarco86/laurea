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
// examiner's red tick in the margin
let tick = NSBezierPath()
tick.lineWidth = 20
tick.lineCapStyle = .round
tick.lineJoinStyle = .round
tick.move(to: CGPoint(x: -150, y: -215))
tick.line(to: CGPoint(x: -112, y: -250))
tick.line(to: CGPoint(x: -40, y: -160))
color(0xE5484D).setStroke()
tick.stroke()
cg.restoreGState()

// SF Symbols
func symbol(_ name: String, _ pt: CGFloat, _ colors: [NSColor], at p: CGPoint, weight: NSFont.Weight = .semibold) {
    let cfg = NSImage.SymbolConfiguration(pointSize: pt, weight: weight).applying(.init(paletteColors: colors))
    guard let img = NSImage(systemSymbolName: name, accessibilityDescription: nil)?.withSymbolConfiguration(cfg) else { return }
    let s = img.size
    img.draw(in: CGRect(x: p.x - s.width / 2, y: p.y - s.height / 2, width: s.width, height: s.height))
}

// Graduation cap resting on the top corner of the paper
cg.saveGState()
cg.setShadow(offset: CGSize(width: 0, height: -10), blur: 18, color: NSColor.black.withAlphaComponent(0.35).cgColor)
cg.translateBy(x: 650, y: 720)
cg.rotate(by: 12 * .pi / 180)
symbol("graduationcap.fill", 250, [color(0x14193F)], at: .zero, weight: .bold)
cg.restoreGState()

// Approval seal
cg.saveGState()
cg.setShadow(offset: CGSize(width: 0, height: -10), blur: 20, color: NSColor.black.withAlphaComponent(0.35).cgColor)
symbol("checkmark.seal.fill", 230, [NSColor.white, color(0x2FBF71)], at: CGPoint(x: 705, y: 285), weight: .bold)
cg.restoreGState()

NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
print("wrote \(out)")
