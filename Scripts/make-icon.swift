// Draws the SimpleText app icon and writes Resources/icon.icns and Resources/icon.png.
// Usage: swift Scripts/make-icon.swift
// Same tile as SimpleAudio and Simple Recorder (dark gradient, rim, shadow); the motif is five
// indented lines of code in amber and cyan with the red caret of the family.
import AppKit

func color(_ hex: Int, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(
        srgbRed: CGFloat((hex >> 16) & 0xff) / 255,
        green: CGFloat((hex >> 8) & 0xff) / 255,
        blue: CGFloat(hex & 0xff) / 255,
        alpha: alpha
    )
}

func drawIcon(size: Int) -> Data {
    let s = CGFloat(size) / 1024
    let space = CGColorSpace(name: CGColorSpace.sRGB)!
    let ctx = CGContext(
        data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
        space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    ctx.scaleBy(x: s, y: s)

    // macOS icon grid: 824 pt rounded square centered in 1024.
    let body = CGRect(x: 100, y: 100, width: 824, height: 824)
    let shape = CGPath(roundedRect: body, cornerWidth: 186, cornerHeight: 186, transform: nil)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -12 * s), blur: 28 * s, color: color(0x000000, 0.48))
    ctx.addPath(shape)
    ctx.setFillColor(color(0x14171C))
    ctx.fillPath()
    ctx.restoreGState()

    ctx.saveGState()
    ctx.addPath(shape)
    ctx.clip()
    let gradient = CGGradient(colorsSpace: space, colors: [color(0x222731), color(0x0E1014)] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(gradient, start: CGPoint(x: 0, y: 924), end: CGPoint(x: 0, y: 100), options: [])

    // Five lines of "code": indent, width and colour per line, top to bottom.
    let lines: [(indent: CGFloat, width: CGFloat, color: CGColor)] = [
        (0, 400, color(0xFFB454, 0.94)),
        (1, 300, color(0x5CE1E6, 0.85)),
        (2, 230, color(0xFFFFFF, 0.38)),
        (1, 340, color(0x5CE1E6, 0.85)),
        (0, 190, color(0xFFB454, 0.94)),
    ]
    let barHeight: CGFloat = 54
    let firstTop: CGFloat = 1024 - 300
    let step: CGFloat = 106
    let left: CGFloat = 212
    let indentStep: CGFloat = 88
    var caretAnchor = CGPoint.zero
    for (i, line) in lines.enumerated() {
        let x = left + line.indent * indentStep
        let y = firstTop - CGFloat(i) * step - barHeight
        let rect = CGRect(x: x, y: y, width: line.width, height: barHeight)
        ctx.addPath(CGPath(roundedRect: rect, cornerWidth: barHeight / 2, cornerHeight: barHeight / 2, transform: nil))
        ctx.setFillColor(line.color)
        ctx.fillPath()
        if i == 2 { caretAnchor = CGPoint(x: rect.maxX + 40, y: rect.midY) }
    }

    // The caret, in the family's red, with the glow of SimpleAudio's playhead.
    ctx.saveGState()
    ctx.setShadow(offset: .zero, blur: 32 * s, color: color(0xFF5C57, 0.55))
    ctx.setFillColor(color(0xFF5C57))
    let caret = CGRect(x: caretAnchor.x - 11, y: caretAnchor.y - 78, width: 22, height: 156)
    ctx.addPath(CGPath(roundedRect: caret, cornerWidth: 11, cornerHeight: 11, transform: nil))
    ctx.fillPath()
    ctx.restoreGState()
    ctx.restoreGState()

    ctx.addPath(CGPath(roundedRect: body.insetBy(dx: 2, dy: 2), cornerWidth: 184, cornerHeight: 184, transform: nil))
    ctx.setStrokeColor(color(0xFFFFFF, 0.11))
    ctx.setLineWidth(4)
    ctx.strokePath()

    return NSBitmapImageRep(cgImage: ctx.makeImage()!).representation(using: .png, properties: [:])!
}

let root = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent().deletingLastPathComponent()
let resources = root.appendingPathComponent("Resources", isDirectory: true)
let fm = FileManager.default
try fm.createDirectory(at: resources, withIntermediateDirectories: true)
let iconset = fm.temporaryDirectory.appendingPathComponent("SimpleText-\(UUID().uuidString).iconset")
try fm.createDirectory(at: iconset, withIntermediateDirectories: true)
for base in [16, 32, 128, 256, 512] {
    try drawIcon(size: base).write(to: iconset.appendingPathComponent("icon_\(base)x\(base).png"))
    try drawIcon(size: base * 2).write(to: iconset.appendingPathComponent("icon_\(base)x\(base)@2x.png"))
}
let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconset.path, "-o", resources.appendingPathComponent("icon.icns").path]
try iconutil.run()
iconutil.waitUntilExit()
try? fm.removeItem(at: iconset)
try drawIcon(size: 1024).write(to: resources.appendingPathComponent("icon.png"))
print(iconutil.terminationStatus == 0 ? "Resources/icon.icns and icon.png written" : "iconutil failed")
