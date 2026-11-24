import AppKit

@MainActor
final class GlobalHotKeyMonitor {
    var onDoubleCommandC: (() -> Void)?

    var onHyperT: (() -> Void)?

    private var globalMonitor: Any?
    private var localMonitor: Any?
    private let hyperModifiers: NSEvent.ModifierFlags = [.control, .option, .shift, .command]
    private var lastCommandCAt: ContinuousClock.Instant?
    private let clock = ContinuousClock()
    private let maximumInterval: Duration = .milliseconds(550)

    func start() {
        guard globalMonitor == nil, localMonitor == nil else { return }

        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            // AppKit delivers monitor callbacks on the main thread.
            MainActor.assumeIsolated {
                self?.handle(event, detectsDoubleCopy: true)
            }
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handle(event, detectsDoubleCopy: false)
            return event
        }
    }

    func stop() {
        if let globalMonitor { NSEvent.removeMonitor(globalMonitor) }
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
        globalMonitor = nil
        localMonitor = nil
    }

    private func handle(_ event: NSEvent, detectsDoubleCopy: Bool) {
        guard !event.isARepeat else { return }

        let modifiers = event.modifierFlags
        let key = event.charactersIgnoringModifiers?.lowercased()
        if modifiers.contains(hyperModifiers), key == "t" {
            lastCommandCAt = nil
            onHyperT?()
        } else if detectsDoubleCopy, key == "c" {
            handleCopyKey(modifiers: modifiers)
        }
    }

    private func handleCopyKey(modifiers: NSEvent.ModifierFlags) {
        guard modifiers.contains(.command),
              !modifiers.contains(.option),
              !modifiers.contains(.control) else {
            return
        }

        let now = clock.now
        if let previous = lastCommandCAt,
           previous.duration(to: now) <= maximumInterval {
            lastCommandCAt = nil
            onDoubleCommandC?()
        } else {
            lastCommandCAt = now
        }
    }
}
