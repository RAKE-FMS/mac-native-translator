import Foundation
import Observation

@MainActor
@Observable
final class TranslationPanelModel {
    let languageOptions: [TranslationLanguage]

    private(set) var direction: TranslationDirection?
    private(set) var isTranslating = false
    private(set) var message: String?

    private let translator: FoundationTranslator
    private var activeOperation = UUID()

    init(translator: FoundationTranslator) {
        self.translator = translator
        languageOptions = TranslationLanguageCatalog.available(from: translator.supportedLanguages)
    }

    func prepareTranslation(_ text: String) {
        activeOperation = UUID()
        message = nil
        isTranslating = false

        let sourceLanguage = TranslationLanguageCatalog.detectSource(in: text)
        guard let targetLanguage = TranslationLanguageCatalog.defaultTarget(
            for: sourceLanguage,
            available: languageOptions
        ) else {
            direction = nil
            message = "No other supported target language is available."
            return
        }

        direction = TranslationDirection(
            activeInputText: text,
            sourceLanguage: sourceLanguage,
            targetLanguage: targetLanguage
        )
        isTranslating = true
    }

    func translatePreparedText() async {
        guard let direction else { return }
        await translate(
            TranslationRequest(
                text: direction.activeInputText,
                sourceLanguage: direction.sourceLanguage,
                targetLanguage: direction.targetLanguage
            )
        )
    }

    func showMessage(_ message: String) {
        activeOperation = UUID()
        direction = nil
        isTranslating = false
        self.message = message
    }

    func selectTarget(_ language: TranslationLanguage) async {
        guard !isTranslating, var direction else { return }
        let request = direction.selectTarget(language)
        self.direction = direction
        await translate(request)
    }

    func reverseTranslation() async {
        guard !isTranslating, var direction,
              let request = direction.reverse() else {
            return
        }
        self.direction = direction
        await translate(request)
    }

    private func translate(_ request: TranslationRequest) async {
        let operation = UUID()
        activeOperation = operation
        isTranslating = true
        message = nil

        do {
            let result = try await translator.translate(
                request.text,
                from: request.sourceLanguage,
                to: request.targetLanguage
            )
            guard activeOperation == operation else { return }

            var direction = self.direction
            direction?.setResult(result)
            self.direction = direction
        } catch {
            guard activeOperation == operation else { return }
            message = error.localizedDescription
        }

        if activeOperation == operation {
            isTranslating = false
        }
    }
}
