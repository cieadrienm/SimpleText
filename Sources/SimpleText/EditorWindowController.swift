import AppKit

/// One window per document; new windows join the front window as tabs.
final class EditorWindowController: NSWindowController {
    let editor: EditorViewController

    init(document: TextDocument) {
        editor = EditorViewController(document: document)
        let window = NSWindow(contentViewController: editor)
        window.setContentSize(NSSize(width: 980, height: 680))
        window.minSize = NSSize(width: 420, height: 260)
        window.appearance = NSAppearance(named: .darkAqua)
        window.backgroundColor = Theme.background
        window.tabbingMode = .preferred
        window.tabbingIdentifier = "net.cieadrienm.simpletext.editor"
        window.titlebarSeparatorStyle = .line
        super.init(window: window)
        shouldCascadeWindows = true
        windowFrameAutosaveName = "SimpleTextEditor"
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }
}
