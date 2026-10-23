import AppKit
import SwiftUI

/// Dark palette shared with SimpleAudio, Simple Recorder, Montage and OSCScore. The app has no light mode.
enum Theme {
    static let background = NSColor(hex: 0x111317)
    static let panel = NSColor(hex: 0x16191E)
    static let lane = NSColor(hex: 0x181B21)
    static let laneAlt = NSColor(hex: 0x1B1F26)
    static let separator = NSColor(hex: 0x0B0C0F)
    static let text = NSColor(hex: 0xE6E8EC)
    static let textDim = NSColor(hex: 0x8A919E)
    static let textFaint = NSColor(hex: 0x565D6A)
    static let accent = NSColor(hex: 0xFFB454)
    static let red = NSColor(hex: 0xFF5C57)
    static let cyan = NSColor(hex: 0x5CE1E6)
    static let blue = NSColor(hex: 0x7AA2F7)
    static let green = NSColor(hex: 0x9ECE6A)
    static let purple = NSColor(hex: 0xC792EA)
    static let pink = NSColor(hex: 0xFF7A90)
    static let yellow = NSColor(hex: 0xF2D96B)
    static let mint = NSColor(hex: 0x6EE7B7)

    static let selection = NSColor(hex: 0x5CE1E6, alpha: 0.22)
    static let inactiveSelection = NSColor(white: 1, alpha: 0.10)
    static let currentLine = NSColor(white: 1, alpha: 0.035)
    static let gutterText = textFaint
    static let gutterCurrentText = textDim
    static let caret = accent

    static func font(_ size: CGFloat, _ weight: NSFont.Weight = .regular) -> NSFont {
        .systemFont(ofSize: size, weight: weight)
    }

    static func mono(_ size: CGFloat, _ weight: NSFont.Weight = .regular) -> NSFont {
        .monospacedDigitSystemFont(ofSize: size, weight: weight)
    }

    /// The editor font: the user's monospaced family when it exists, SF Mono otherwise.
    static func editorFont(name: String, size: CGFloat) -> NSFont {
        if !name.isEmpty, let font = NSFont(name: name, size: size) { return font }
        return .monospacedSystemFont(ofSize: size, weight: .regular)
    }
}

extension NSColor {
    convenience init(hex: Int, alpha: CGFloat = 1) {
        self.init(
            srgbRed: CGFloat(hex >> 16 & 0xff) / 255,
            green: CGFloat(hex >> 8 & 0xff) / 255,
            blue: CGFloat(hex & 0xff) / 255,
            alpha: alpha
        )
    }

    var swiftUI: Color { Color(nsColor: self) }
}
