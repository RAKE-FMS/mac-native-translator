import AppKit
import ApplicationServices
import Foundation
import FoundationModels

@main
struct MacTranslateMain {
    @MainActor
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let hotKeyMonitor = DoubleCopyMonitor()
    private let panelController = TranslationPanelController()
    private let translator = FoundationTranslator()
    private var appUpdater: AppUpdater?
    private var updateStatusItemController: UpdateStatusItemController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let updater = AppUpdater()
        appUpdater = updater
        updateStatusItemController = UpdateStatusItemController(updater: updater)

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

        panelController.show(
            title: "Accessibility permission required",
            text: "Enable MacTranslate in System Settings → Privacy & Security → Accessibility, then relaunch the app."
        )
    }

    private func translateClipboard() async {
        // Give the foreground app a moment to finish handling the second copy.
        try? await Task.sleep(for: .milliseconds(80))

        guard let text = NSPasteboard.general.string(forType: .string)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !text.isEmpty else {
            panelController.show(title: "MacTranslate", text: "No text found on the clipboard.")
            return
        }

        panelController.show(title: "Translating…", text: text)

        do {
            let result = try await translator.translate(text)
            panelController.show(title: "Translation", text: result)
        } catch {
            panelController.show(title: "Translation failed", text: error.localizedDescription)
        }
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

@MainActor
final class FoundationTranslator {
    private let model = SystemLanguageModel.default

    func translate(_ text: String) async throws -> String {
        switch model.availability {
        case .available:
            break
        case .unavailable(let reason):
            throw TranslatorError.modelUnavailable(reason)
        }

        let targetLanguage = containsJapanese(text) ? "English" : "Japanese"
        let session = LanguageModelSession(
            model: model,
            instructions: """
            You are a translation engine. Translate faithfully while preserving meaning, tone, names, technical terms, numbers, code, and formatting. Do not add explanations, notes, headings, or quotation marks. Return only the translated text.
            """
        )

        let response = try await session.respond(
            to: "Translate the following text into \(targetLanguage):\n\n\(text)"
        )
        return response.content.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func containsJapanese(_ text: String) -> Bool {
        text.unicodeScalars.contains { scalar in
            switch scalar.value {
            case 0x3040...0x30FF, // Hiragana + Katakana
                 0x31F0...0x31FF, // Katakana phonetic extensions
                 0x3400...0x4DBF, // CJK Extension A
                 0x4E00...0x9FFF: // CJK Unified Ideographs
                return true
            default:
                return false
            }
        }
    }
}

enum TranslatorError: LocalizedError {
    case modelUnavailable(SystemLanguageModel.Availability.UnavailableReason)

    var errorDescription: String? {
        switch self {
        case .modelUnavailable(.appleIntelligenceNotEnabled):
            return "Apple Intelligence is disabled. Enable it in System Settings and try again."
        case .modelUnavailable(.deviceNotEligible):
            return "This Mac does not support Apple Intelligence / the on-device Foundation Model."
        case .modelUnavailable(.modelNotReady):
            return "The on-device Foundation Model is not ready yet. macOS may still be downloading model assets."
        @unknown default:
            return "The on-device Foundation Model is currently unavailable."
        }
    }
}

@MainActor
final class TranslationPanelController: NSObject {
    private let panel: NSPanel
    private let titleLabel = NSTextField(labelWithString: "MacTranslate")
    private let textView = NSTextView()
    private let copyButton = NSButton(title: "Copy", target: nil, action: nil)
    private let closeButton = NSButton(title: "Close", target: nil, action: nil)

    override init() {
        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 300),
            styleMask: [.titled, .closable, .utilityWindow, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        super.init()
        configurePanel()
    }

    func show(title: String, text: String) {
        titleLabel.stringValue = title
        textView.string = text
        positionNearPointer()
        panel.orderFrontRegardless()
    }

    private func configurePanel() {
        panel.level = .floating
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.title = "MacTranslate"
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        guard let contentView = panel.contentView else { return }

        titleLabel.font = .boldSystemFont(ofSize: 14)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        textView.isEditable = false
        textView.isSelectable = true
        textView.font = .systemFont(ofSize: 14)
        textView.textContainerInset = NSSize(width: 8, height: 8)

        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .bezelBorder
        scrollView.documentView = textView

        copyButton.target = self
        copyButton.action = #selector(copyText)
        copyButton.bezelStyle = .rounded

        closeButton.target = self
        closeButton.action = #selector(closePanel)
        closeButton.bezelStyle = .rounded

        let buttonRow = NSStackView(views: [copyButton, closeButton])
        buttonRow.orientation = .horizontal
        buttonRow.alignment = .centerY
        buttonRow.spacing = 8
        buttonRow.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(titleLabel)
        contentView.addSubview(scrollView)
        contentView.addSubview(buttonRow)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 14),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),

            scrollView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 10),
            scrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            scrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            scrollView.bottomAnchor.constraint(equalTo: buttonRow.topAnchor, constant: -12),

            buttonRow.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            buttonRow.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -14)
        ])
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

    @objc private func copyText() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(textView.string, forType: .string)
    }

    @objc private func closePanel() {
        panel.orderOut(nil)
    }
}
