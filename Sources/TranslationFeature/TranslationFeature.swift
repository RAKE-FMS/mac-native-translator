import AppKit
import Foundation

@MainActor
package final class TranslationFeature {
    private let appDisplayName: String
    private let screenSelection = ScreenRegionSelection()
    private var isTranslatingScreenRegion = false
    private var clipboardTask: Task<Void, Never>?
    private let translator = FoundationTranslator()
    private lazy var panelModel = TranslationPanelModel(translator: translator)
    private lazy var panelController = TranslationPanelController(model: panelModel)

    package init(appDisplayName: String) {
        self.appDisplayName = appDisplayName
    }

    package func handleDoubleCopy() {
        guard !isTranslatingScreenRegion else { return }
        clipboardTask?.cancel()
        clipboardTask = Task { await translateClipboard() }
    }

    package func cancelScreenSelection() {
        screenSelection.cancel()
    }

    package func startScreenTranslation() {
        guard !isTranslatingScreenRegion else { return }
        isTranslatingScreenRegion = true
        clipboardTask?.cancel()

        Task {
            defer { isTranslatingScreenRegion = false }

            guard CGPreflightScreenCaptureAccess() || CGRequestScreenCaptureAccess() else {
                showMessage("Allow \(appDisplayName) to record the screen in System Settings → Privacy & Security → Screen & System Audio Recording, then try again.")
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

    package func showMessage(_ message: String) {
        panelModel.showMessage(message)
        panelController.show()
    }

    private func translate(_ text: String) async {
        panelModel.prepareTranslation(text)
        panelController.show()
        await panelModel.translatePreparedText()
    }
}
