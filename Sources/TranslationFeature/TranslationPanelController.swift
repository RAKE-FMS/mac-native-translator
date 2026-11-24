import AppKit
import SwiftUI

@MainActor
private final class TranslationPanel: NSPanel {
    var escapeHandler: (() -> Void)?

    override var canBecomeKey: Bool { true }

    override func cancelOperation(_ sender: Any?) {
        escapeHandler?()
    }
}

@MainActor
final class TranslationPanelController: NSObject {
    private let panel: TranslationPanel
    private let model: TranslationPanelModel

    init(model: TranslationPanelModel) {
        self.model = model
        panel = TranslationPanel(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 300),
            styleMask: [.titled, .utilityWindow, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        super.init()
        configurePanel()
    }

    var isVisible: Bool { panel.isVisible }

    func show() {
        positionNearPointer()
        restore()
    }

    func restore() {
        panel.makeKeyAndOrderFront(nil)
    }

    func close() {
        panel.orderOut(nil)
    }

    private func configurePanel() {
        panel.level = .floating
        panel.isFloatingPanel = true
        panel.isMovable = true
        panel.isMovableByWindowBackground = true
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.titlebarAppearsTransparent = true
        panel.titleVisibility = .hidden
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.escapeHandler = { [weak self] in self?.close() }
        panel.standardWindowButton(.closeButton)?.isHidden = true
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true

        let hostingView = NSHostingView(
            rootView: TranslationPanelView(model: model) { [weak self] in
                self?.close()
            }
        )
        hostingView.frame = NSRect(origin: .zero, size: panel.contentView?.frame.size ?? NSSize(width: 560, height: 300))
        hostingView.autoresizingMask = [.width, .height]
        panel.contentView = hostingView
    }

    private func positionNearPointer() {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first(where: { NSMouseInRect(mouse, $0.frame, false) }) ?? NSScreen.main
        guard let visibleFrame = screen?.visibleFrame else {
            panel.center()
            return
        }

        let size = panel.frame.size
        var origin = NSPoint(x: mouse.x + 18, y: mouse.y - size.height - 18)
        origin.x = min(max(origin.x, visibleFrame.minX), visibleFrame.maxX - size.width)
        origin.y = min(max(origin.y, visibleFrame.minY), visibleFrame.maxY - size.height)
        panel.setFrameOrigin(origin)
    }
}
