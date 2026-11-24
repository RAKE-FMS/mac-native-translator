import AppKit

struct ScreenRegion {
    let rect: CGRect

    init?(start: CGPoint, end: CGPoint, displayFrame: CGRect, primaryScreenTop: CGFloat) {
        let selection = Self.dragRect(from: start, to: end, within: displayFrame)

        guard !selection.isNull, selection.width >= 4, selection.height >= 4 else { return nil }

        rect = CGRect(
            x: selection.minX,
            y: primaryScreenTop - selection.maxY,
            width: selection.width,
            height: selection.height
        )
    }

    fileprivate static func dragRect(from start: CGPoint, to end: CGPoint, within bounds: CGRect) -> CGRect {
        CGRect(
            x: min(start.x, end.x),
            y: min(start.y, end.y),
            width: abs(end.x - start.x),
            height: abs(end.y - start.y)
        ).intersection(bounds)
    }
}

@MainActor
final class ScreenRegionSelection {
    private var panels: [SelectionPanel] = []
    private var continuation: CheckedContinuation<ScreenRegion?, Never>?

    func select() async -> ScreenRegion? {
        guard let primaryScreen = NSScreen.screens.first else { return nil }

        return await withCheckedContinuation { continuation in
            self.continuation = continuation
            let pointer = NSEvent.mouseLocation

            for screen in NSScreen.screens {
                let panel = SelectionPanel(
                    contentRect: screen.frame,
                    styleMask: [.borderless, .nonactivatingPanel],
                    backing: .buffered,
                    defer: false
                )
                panel.setFrame(screen.frame, display: false)
                panel.level = .screenSaver
                panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
                panel.isOpaque = false
                panel.backgroundColor = .clear
                panel.hasShadow = false
                panel.hidesOnDeactivate = false
                panel.onCancel = { [weak self] in self?.finish(nil) }

                let selectionView = SelectionView(frame: CGRect(origin: .zero, size: screen.frame.size))
                selectionView.onSelect = { [weak self] start, end in
                    self?.finish(ScreenRegion(
                        start: start,
                        end: end,
                        displayFrame: screen.frame,
                        primaryScreenTop: primaryScreen.frame.maxY
                    ))
                }
                panel.contentView = selectionView
                panels.append(panel)
                panel.orderFrontRegardless()
            }

            (panels.first { $0.frame.contains(pointer) } ?? panels.first)?.makeKey()
        }
    }

    func cancel() {
        finish(nil)
    }

    private func finish(_ region: ScreenRegion?) {
        let continuation = self.continuation
        self.continuation = nil
        panels.forEach { $0.orderOut(nil) }
        panels.removeAll()
        continuation?.resume(returning: region)
    }
}

private final class SelectionPanel: NSPanel {
    var onCancel: (() -> Void)?

    override var canBecomeKey: Bool { true }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {
            onCancel?()
        } else {
            super.keyDown(with: event)
        }
    }
}

private final class SelectionView: NSView {
    var onSelect: ((CGPoint, CGPoint) -> Void)?

    private var dragStart: CGPoint?
    private var dragEnd: CGPoint?

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .crosshair)
    }

    override func mouseDown(with event: NSEvent) {
        dragStart = convert(event.locationInWindow, from: nil)
        dragEnd = dragStart
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        dragEnd = convert(event.locationInWindow, from: nil)
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        guard let window, let dragStart else { return }

        onSelect?(
            window.convertPoint(toScreen: convert(dragStart, to: nil)),
            window.convertPoint(toScreen: event.locationInWindow)
        )
    }

    override func draw(_ dirtyRect: NSRect) {
        let shade = NSBezierPath(rect: bounds)
        var selection: CGRect?
        if let dragStart, let dragEnd {
            let dragRect = ScreenRegion.dragRect(from: dragStart, to: dragEnd, within: bounds)
            selection = dragRect
            shade.appendRect(dragRect)
            shade.windingRule = .evenOdd
        }
        NSColor.black.withAlphaComponent(0.28).setFill()
        shade.fill()

        if let selection {
            NSColor.white.setStroke()
            NSBezierPath(rect: selection).stroke()
        }
    }
}
