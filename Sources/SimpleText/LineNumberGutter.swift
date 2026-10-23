import AppKit
import SimpleTextCore

/// Line numbers beside the text, drawn from TextKit 2's layout fragments of the visible rows.
/// A sibling of the scroll view, not an `NSRulerView`: a ruler shifts the clip view's bounds and
/// leaves the text view undrawn (seen on macOS 15 with TextKit 2).
final class LineNumberGutter: NSView {
    weak var textView: EditorTextView?
    var lineIndexProvider: () -> LineIndex = { LineIndex("") }
    /// Called when the digit count changes the width this view needs.
    var onThicknessChange: ((CGFloat) -> Void)?
    var font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular) {
        didSet { invalidate() }
    }

    private(set) var thickness: CGFloat = 44
    private let padding: CGFloat = 10

    override var isFlipped: Bool { true }

    /// After every edit: the digit count may grow, and every row may have moved.
    func invalidate() {
        let count = lineIndexProvider().lineCount
        let digits = max(2, String(count).count)
        let width = ("0" as NSString).size(withAttributes: [.font: font]).width
        let needed = ceil(CGFloat(digits) * width + padding * 2)
        if abs(thickness - needed) > 0.5 {
            thickness = needed
            onThicknessChange?(needed)
        }
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        Theme.background.setFill()
        dirtyRect.fill()
        guard let textView,
              let layoutManager = textView.textLayoutManager,
              let contentStorage = layoutManager.textContentManager as? NSTextContentStorage else { return }
        let index = lineIndexProvider()
        let selection = textView.selectedRange()
        let selectedLine = index.line(containing: selection.location)
        let visible = textView.visibleRect
        let origin = textView.textContainerOrigin
        let normal: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: Theme.gutterText]
        let current: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: Theme.gutterCurrentText]
        let right = bounds.width - padding
        let ascender = font.ascender

        let topPoint = CGPoint(x: 0, y: max(0, visible.minY - origin.y))
        let start = layoutManager.textLayoutFragment(for: topPoint)?.rangeInElement.location
            ?? contentStorage.documentRange.location
        layoutManager.enumerateTextLayoutFragments(from: start, options: [.ensuresLayout]) { fragment in
            let frame = fragment.layoutFragmentFrame
            let top = frame.minY + origin.y
            if top > visible.maxY { return false }
            let offset = contentStorage.offset(from: contentStorage.documentRange.location, to: fragment.rangeInElement.location)
            let line = index.line(containing: offset)
            let firstLine = fragment.textLineFragments.first
            let baseline = top + (firstLine.map { $0.typographicBounds.minY + $0.glyphOrigin.y } ?? frame.height * 0.8)
            let rowTop = convert(NSPoint(x: 0, y: top), from: textView).y
            if line == selectedLine, textView.highlightCurrentLine, selection.length == 0 {
                let height = firstLine?.typographicBounds.height ?? frame.height
                Theme.currentLine.setFill()
                NSRect(x: 0, y: rowTop, width: bounds.width, height: height).fill()
            }
            let label = NSAttributedString(string: String(line + 1), attributes: line == selectedLine ? current : normal)
            let size = label.size()
            let y = convert(NSPoint(x: 0, y: baseline), from: textView).y - ascender
            label.draw(at: NSPoint(x: right - size.width, y: y))
            return true
        }
    }
}
