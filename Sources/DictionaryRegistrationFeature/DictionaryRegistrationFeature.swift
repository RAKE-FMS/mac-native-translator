import AppKit
import SwiftUI

@MainActor
package final class DictionaryRegistrationFeature {
    private let draft = DictionaryDraft()
    private var sourceApplication: NSRunningApplication?
    private var hasOpenDraft = false
    private lazy var panel = makePanel()

    package init() {}

    package func show() {
        guard draft.state != .registering else { return }
        let opensNewDraft = !hasOpenDraft
        if opensNewDraft {
            let focused = FocusedText.capture()
            sourceApplication = focused.application
            draft.begin(with: focused.phrase)
            hasOpenDraft = true
            positionPanel(near: focused.bounds)
        }
        panel.makeKeyAndOrderFront(nil)
        if opensNewDraft {
            panel.makeFirstResponder(nil)
        }
    }

    private func makePanel() -> RegistrationPanel {
        let panel = RegistrationPanel(
            contentRect: NSRect(x: 0, y: 0, width: 390, height: 104),
            styleMask: [.titled, .utilityWindow, .nonactivatingPanel],
            backing: .buffered, defer: false
        )
        panel.title = "ユーザ辞書に登録"
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.onEscape = { [weak self] in self?.discard() }
        panel.onFocusLoss = { [weak self] in self?.discard(restoreFocus: false) }
        panel.contentView = NSHostingView(rootView: RegistrationForm(
            draft: draft,
            register: { [weak self] in self?.register() },
            cancel: { [weak self] in self?.discard() }
        ))
        return panel
    }

    private func positionPanel(near bounds: CGRect?) {
        let pointer = NSEvent.mouseLocation
        let anchor = bounds.flatMap { bounds in
            NSScreen.screens.contains { $0.frame.contains(CGPoint(x: bounds.midX, y: bounds.midY)) }
                ? bounds : nil
        } ?? CGRect(origin: pointer, size: .zero)
        let point = CGPoint(x: anchor.midX, y: anchor.midY)
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(point) }) ?? NSScreen.main else {
            panel.center()
            return
        }

        let frame = screen.visibleFrame
        let size = panel.frame.size
        let below = anchor.minY - size.height - 8
        let y = below >= frame.minY ? below : anchor.maxY + 8
        panel.setFrameOrigin(CGPoint(
            x: max(frame.minX, min(anchor.minX, frame.maxX - size.width)),
            y: max(frame.minY, min(y, frame.maxY - size.height))
        ))
    }

    private func register() {
        guard let entry = draft.startRegistration() else { return }
        Task {
            let result = await SystemDictionary.register(entry)
            guard hasOpenDraft else {
                draft.state = .editing
                return
            }
            switch result {
            case .added:
                draft.state = .editing
                discard()
            case .manual:
                draft.state = .manual
            case .unverified:
                draft.state = .unverified
            }
        }
    }

    private func discard(restoreFocus: Bool = true) {
        guard hasOpenDraft else { return }
        let previousApplication = sourceApplication
        let shouldRestoreFocus = restoreFocus && panel.isKeyWindow
        hasOpenDraft = false
        sourceApplication = nil
        panel.orderOut(nil)
        draft.clear()
        if shouldRestoreFocus {
            previousApplication?.activate()
        }
    }
}

@MainActor
private final class RegistrationPanel: NSPanel {
    var onEscape: (() -> Void)?
    var onFocusLoss: (() -> Void)?

    override var canBecomeKey: Bool { true }

    override func cancelOperation(_ sender: Any?) {
        onEscape?()
    }

    override func resignKey() {
        super.resignKey()
        onFocusLoss?()
    }
}

@MainActor
@Observable
final class DictionaryDraft {
    enum State {
        case editing
        case registering
        case manual
        case unverified
    }

    var reading = ""
    var phrase = ""
    var state = State.editing

    private var entry: DictionaryEntry? { DictionaryEntry(reading: reading, phrase: phrase) }

    var canRegister: Bool {
        (state == .editing || state == .manual) && entry != nil
    }

    func startRegistration() -> DictionaryEntry? {
        guard state == .editing || state == .manual, let entry else { return nil }
        // Lock the draft before the asynchronous work begins.
        state = .registering
        return entry
    }

    func begin(with phrase: String) {
        self.phrase = phrase
        reading = JapaneseReading.estimate(for: phrase)
        state = .editing
    }

    func clear() {
        reading = ""
        phrase = ""
        if state != .registering {
            state = .editing
        }
    }
}

private struct RegistrationForm: View {
    @Bindable var draft: DictionaryDraft
    let register: () -> Void
    let cancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 6) {
                GridRow {
                    Text("読み")
                    TextField("ひらがなで入力", text: $draft.reading)
                        .accessibilityLabel("読み")
                        .overlay {
                            if draft.reading.count > DictionaryEntry.maximumReadingLength {
                                lengthErrorBorder
                            }
                        }
                }
                GridRow {
                    Text("語句")
                    TextField("変換後の語句", text: $draft.phrase)
                        .accessibilityLabel("語句")
                        .overlay {
                            if draft.phrase.count > DictionaryEntry.maximumPhraseLength {
                                lengthErrorBorder
                            }
                        }
                }
            }
            .disabled(draft.state == .registering)

            HStack {
                if draft.state == .manual || draft.state == .unverified {
                    Button(
                        draft.state == .unverified ? "辞書で結果を確認" : "辞書設定を開く",
                        action: SystemDictionary.openSettings
                    )
                }
                Spacer()
                Button("キャンセル", action: cancel)
                    .disabled(draft.state == .registering)
                Button("登録", action: register)
                    .disabled(!draft.canRegister)
            }
        }
        .padding(12)
        .frame(minWidth: 385)
    }

    private var lengthErrorBorder: some View {
        RoundedRectangle(cornerRadius: 5)
            .strokeBorder(.red, lineWidth: 1)
            .allowsHitTesting(false)
    }
}
