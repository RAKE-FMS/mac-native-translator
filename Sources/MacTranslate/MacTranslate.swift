import AppKit
import ApplicationServices
import Foundation

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let appUpdater = AppUpdater()

    private let hotKeyMonitor = DoubleCopyMonitor()
    private let translator = FoundationTranslator()
    private lazy var panelModel = TranslationPanelModel(translator: translator)
    private lazy var panelController = TranslationPanelController(model: panelModel)

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.accessory)

        requestAccessibilityPermissionIfNeeded()

        hotKeyMonitor.onDoubleCommandC = { [weak self] in
            guard let self else { return }
            Task { @MainActor in
                await self.translateClipboard()
            }
        }

        hotKeyMonitor.start()
        print("MacTranslate is running. Select text and press Command+C twice.")
        print("Press Control+C in this terminal to stop it.")
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotKeyMonitor.stop()
    }

    private func requestAccessibilityPermissionIfNeeded() {
        guard !AXIsProcessTrusted() else { return }

        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)

        panelModel.showMessage(
            "Enable MacTranslate in System Settings → Privacy & Security → Accessibility, then relaunch the app."
        )
        panelController.show()
    }

    private func translateClipboard() async {
        // Give the foreground app a moment to finish handling the second copy.
        try? await Task.sleep(for: .milliseconds(80))

        guard let text = NSPasteboard.general.string(forType: .string)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !text.isEmpty else {
            panelModel.showMessage("No text found on the clipboard.")
            panelController.show()
            return
        }

        panelModel.prepareTranslation(text)
        panelController.show()
        await panelModel.translatePreparedText()
    }
}

@MainActor
final class DoubleCopyMonitor {
    var onDoubleCommandC: (() -> Void)?

    private var monitor: Any?
    private var lastCommandCAt: ContinuousClock.Instant?
    private let clock = ContinuousClock()
    private let maximumInterval: Duration = .milliseconds(550)

    func start() {
        guard monitor == nil else { return }

        monitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            Task { @MainActor in
                self?.handle(event)
            }
        }
    }

    func stop() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
    }

    private func handle(_ event: NSEvent) {
        guard !event.isARepeat else { return }

        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard modifiers.contains(.command),
              !modifiers.contains(.option),
              !modifiers.contains(.control),
              event.charactersIgnoringModifiers?.lowercased() == "c" else {
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
