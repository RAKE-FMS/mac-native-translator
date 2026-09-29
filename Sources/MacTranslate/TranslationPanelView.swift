import AppKit
import SwiftUI
@preconcurrency import Translation

struct TranslationPanelView: View {
    @Bindable var model: TranslationPanelModel
    let onEscape: () -> Void

    private let cornerRadius: CGFloat = 24

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let direction = model.direction {
                languageRow(direction: direction)
            }

            translationContent
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .padding(20)
        .frame(width: 560, height: 300)
        .background(
            .regularMaterial,
            in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        )
        .gesture(WindowDragGesture())
        .allowsWindowActivationEvents()
        .onKeyPress(.escape) {
            onEscape()
            return .handled
        }
        .translationTask(model.translationConfiguration) { session in
            let sessionMode: TranslationMode
            if #available(macOS 26.4, *) {
                sessionMode = session.preferredStrategy == .lowLatency ? .lowLatency : .highFidelity
            } else {
                sessionMode = .highFidelity
            }

            guard let sourceLanguage = session.sourceLanguage,
                  let targetLanguage = session.targetLanguage else {
                return
            }

            guard let work = model.translationWork(
                from: sourceLanguage,
                to: targetLanguage,
                mode: sessionMode
            ) else {
                return
            }

            do {
                let response = try await session.translate(work.text)
                model.completeTranslation(response.targetText, operation: work.operation)
            } catch {
                model.failTranslation(error.localizedDescription, operation: work.operation)
            }
        }
    }

    @ViewBuilder
    private var translationContent: some View {
        if model.isTranslating {
            if let result = model.direction?.resultText {
                VStack(alignment: .leading, spacing: 10) {
                    translatedText(result)
                    ProgressView()
                        .controlSize(.small)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                ProgressView("Translating…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        } else if let result = model.direction?.resultText {
            translatedText(result)
        } else if let message = model.message {
            ScrollView {
                Text(message)
                    .font(.system(size: 14))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
        } else {
            Text("Select text and press Command+C twice.")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
    }

    private func languageRow(direction: TranslationDirection) -> some View {
        HStack(spacing: 12) {
            Text(direction.sourceLanguage.displayName)
                .font(.system(size: 14, weight: .semibold))
                .lineLimit(1)
                .layoutPriority(1)

            Button {
                Task { await model.reverseTranslation() }
            } label: {
                Image(systemName: "arrow.left.arrow.right")
                    .font(.system(size: 12, weight: .semibold))
                    .padding(8)
                    .background(Color.primary.opacity(0.08), in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Translate back to the input language")
            .disabled(model.isTranslating || direction.resultText == nil)

            targetLanguageMenu(direction: direction)

            Spacer(minLength: 4)

            if !model.availableModes.isEmpty || model.isCheckingModes {
                TranslationModeSlider(
                    modes: model.availableModes,
                    selectedMode: model.selectedMode,
                    isResolvingModes: model.isCheckingModes,
                    notice: model.modeNotice,
                    onSelect: model.selectMode
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func translatedText(_ text: String) -> some View {
        ScrollView {
            Text(text)
                .font(.system(size: 14))
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
        }
    }

    private func targetLanguageMenu(direction: TranslationDirection) -> some View {
        let preferred = model.languageOptions.filter { ["ja", "en"].contains($0.identifier) }
        let additional = model.languageOptions.filter { !["ja", "en"].contains($0.identifier) }

        return Menu {
            ForEach(preferred) { language in
                languageMenuItem(language, selected: direction.targetLanguage == language)
            }

            if !preferred.isEmpty && !additional.isEmpty {
                Divider()
            }

            ForEach(additional) { language in
                languageMenuItem(language, selected: direction.targetLanguage == language)
            }
        } label: {
            HStack(spacing: 5) {
                Text(direction.targetLanguage.displayName)
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
        .disabled(model.isTranslating || model.isCheckingModes)
    }

    private func languageMenuItem(_ language: TranslationLanguage, selected: Bool) -> some View {
        Button {
            Task { await model.selectTarget(language) }
        } label: {
            if selected {
                Label(language.displayName, systemImage: "checkmark")
            } else {
                Text(language.displayName)
            }
        }
    }
}
