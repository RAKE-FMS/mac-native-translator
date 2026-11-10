import AppKit
import ApplicationServices
import Foundation

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let appUpdater = AppUpdater()
    let launchAtLogin = LaunchAtLogin()

    private let hotKeyMonitor = TranslationHotKeyMonitor()
    private let screenSelection = ScreenRegionSelection()
    private var isTranslatingScreenRegion = false
    private var clipboardTask: Task<Void, Never>?
    private let translator = FoundationTranslator()
    private lazy var panelModel = TranslationPanelModel(translator: translator)
    private lazy var panelController = TranslationPanelController(model: panelModel)

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.accessory)

        launchAtLogin.promptIfNeeded()
        requestAccessibilityPermissionIfNeeded()

        hotKeyMonitor.onDoubleCommandC = { [weak self] in
            guard let self else { return }
            guard !self.isTranslatingScreenRegion else { return }
            self.clipboardTask?.cancel()
            self.clipboardTask = Task { await self.translateClipboard() }
        }

        hotKeyMonitor.onHyperT = { [weak self] in self?.startScreenTranslation() }
        hotKeyMonitor.start()
        print("MacTranslate is running. Select text and press Command+C twice.")
        print("Press Control+C in this terminal to stop it.")
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotKeyMonitor.stop()
    }

    func applicationDidChangeScreenParameters(_ notification: Notification) {
        screenSelection.cancel()
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

    func startScreenTranslation() {
        guard !isTranslatingScreenRegion else { return }
        isTranslatingScreenRegion = true
        clipboardTask?.cancel()

        Task {
            defer { isTranslatingScreenRegion = false }

            guard CGPreflightScreenCaptureAccess() || CGRequestScreenCaptureAccess() else {
                showMessage("Allow MacTranslate to record the screen in System Settings → Privacy & Security → Screen & System Audio Recording, then try again.")
                return
            }

            let wasPanelVisible = panelController.isVisible
            panelController.close()
            guard let region = await screenSelection.select() else {
                if wasPanelVisible { panelController.restore() }
                return
            }

            do {
                let text = try await ScreenTextRecognition.capture(region)
                guard !text.isEmpty else {
                    showMessage("No text found in the selected screen region.")
                    return
                }
                await translate(text)
            } catch {
                showMessage("Could not capture or recognize the selected screen region. Try again.")
            }
        }
    }

    private func translateClipboard() async {
        // Give the foreground app a moment to finish handling the second copy.
        try? await Task.sleep(for: .milliseconds(80))

        guard !Task.isCancelled else { return }

        guard let text = NSPasteboard.general.string(forType: .string)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !text.isEmpty else {
            showMessage("No text found on the clipboard.")
            return
        }

        await translate(text)
    }

    private func showMessage(_ message: String) {
        panelModel.showMessage(message)
        panelController.show()
    }

    private func translate(_ text: String) async {
        panelModel.prepareTranslation(text)
        panelController.show()
        await panelModel.translatePreparedText()
    }
}

@MainActor
final class TranslationHotKeyMonitor {
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
