import Foundation
import FoundationModels
import Translation

enum TranslationMode: String, CaseIterable, Identifiable, Sendable {
    case lowLatency
    case highFidelity
    case foundationModelsStreaming

    var id: String { rawValue }

    var title: String {
        switch self {
        case .lowLatency:
            "Translation LowLatency"
        case .highFidelity:
            "Translation"
        case .foundationModelsStreaming:
            "Foundation Models Streaming"
        }
    }

    @available(macOS 26.4, *)
    var translationStrategy: TranslationSession.Strategy? {
        switch self {
        case .lowLatency:
            .lowLatency
        case .highFidelity:
            .highFidelity
        case .foundationModelsStreaming:
            nil
        }
    }
}

@MainActor
struct TranslationModeAvailability {
    private let foundationModel: SystemLanguageModel

    init(foundationModel: SystemLanguageModel = .default) {
        self.foundationModel = foundationModel
    }

    func availableModes(
        from sourceLanguage: TranslationLanguage,
        to targetLanguage: TranslationLanguage
    ) async -> [TranslationMode] {
        var modes: [TranslationMode] = []

        if #available(macOS 26.4, *) {
            let lowLatencyAvailability = LanguageAvailability(preferredStrategy: .lowLatency)
            let highFidelityAvailability = LanguageAvailability(preferredStrategy: .highFidelity)

            let lowLatencyStatus = await lowLatencyAvailability.status(
                from: sourceLanguage.locale,
                to: targetLanguage.locale
            )
            let highFidelityStatus = await highFidelityAvailability.status(
                from: sourceLanguage.locale,
                to: targetLanguage.locale
            )

            if lowLatencyStatus != .unsupported {
                modes.append(.lowLatency)
            }
            if highFidelityStatus != .unsupported {
                modes.append(.highFidelity)
            }
        } else {
            // Explicit Translation strategies were added in macOS 26.4. Earlier
            // macOS 26 releases still support Translation with its default model.
            let availability = LanguageAvailability()
            let status = await availability.status(
                from: sourceLanguage.locale,
                to: targetLanguage.locale
            )
            if status != .unsupported {
                modes.append(.highFidelity)
            }
        }

        if case .available = foundationModel.availability,
           foundationModel.supportsLocale(Locale(identifier: sourceLanguage.localeIdentifier)),
           foundationModel.supportsLocale(Locale(identifier: targetLanguage.localeIdentifier)) {
            modes.append(.foundationModelsStreaming)
        }

        return modes
    }
}
