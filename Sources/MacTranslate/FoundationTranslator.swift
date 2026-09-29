import Foundation
import FoundationModels

@MainActor
final class FoundationTranslator {
    private let model = SystemLanguageModel.default

    var supportedLanguages: Set<Locale.Language> {
        model.supportedLanguages
    }

    func translateStreaming(
        _ text: String,
        from sourceLanguage: TranslationLanguage,
        to targetLanguage: TranslationLanguage,
        onPartial: @escaping @MainActor (String) -> Void
    ) async throws -> String {
        switch model.availability {
        case .available:
            break
        case .unavailable(let reason):
            throw TranslatorError.modelUnavailable(reason)
        }

        guard model.supportsLocale(Locale(identifier: sourceLanguage.localeIdentifier)) else {
            throw TranslatorError.unsupportedLanguage(sourceLanguage.displayName)
        }
        guard model.supportsLocale(Locale(identifier: targetLanguage.localeIdentifier)) else {
            throw TranslatorError.unsupportedLanguage(targetLanguage.displayName)
        }

        let promptLocale = Locale(identifier: "en")
        let sourceName = promptLocale.localizedString(forIdentifier: sourceLanguage.identifier)
            ?? sourceLanguage.identifier
        let targetName = promptLocale.localizedString(forIdentifier: targetLanguage.localeIdentifier)
            ?? targetLanguage.identifier
        let session = LanguageModelSession(
            model: model,
            instructions: """
            You are a translation engine. Translate faithfully while preserving meaning, tone, names, technical terms, numbers, code, and formatting. Do not add explanations, notes, headings, or quotation marks. Return only the translated text.
            """
        )

        let stream = session.streamResponse(
            to: "Translate the following text from \(sourceName) into \(targetName):\n\n\(text)"
        )

        var finalContent = ""
        for try await response in stream {
            finalContent = response.content
            onPartial(finalContent.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        return finalContent.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

enum TranslatorError: LocalizedError {
    case modelUnavailable(SystemLanguageModel.Availability.UnavailableReason)
    case unsupportedLanguage(String)

    var errorDescription: String? {
        switch self {
        case .modelUnavailable(.appleIntelligenceNotEnabled):
            return "Apple Intelligence is disabled. Enable it in System Settings and try again."
        case .modelUnavailable(.deviceNotEligible):
            return "This Mac does not support Apple Intelligence / the on-device Foundation Model."
        case .modelUnavailable(.modelNotReady):
            return "The on-device Foundation Model is not ready yet. macOS may still be downloading model assets."
        case .unsupportedLanguage(let language):
            return "The on-device Foundation Model does not support \(language)."
        @unknown default:
            return "The on-device Foundation Model is currently unavailable."
        }
    }
}
