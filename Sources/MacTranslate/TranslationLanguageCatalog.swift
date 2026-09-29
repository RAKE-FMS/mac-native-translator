import Foundation
import NaturalLanguage

struct TranslationLanguage: Hashable, Identifiable {
    let identifier: String
    let localeIdentifier: String
    let displayName: String

    var id: String { localeIdentifier }
    var locale: Locale.Language { Locale.Language(identifier: localeIdentifier) }

    init(identifier: String, displayName: String? = nil) {
        let language = Locale.Language(identifier: identifier)
        self.identifier = language.languageCode?.identifier ?? identifier
        self.localeIdentifier = identifier
        self.displayName = displayName
            ?? Locale.current.localizedString(forIdentifier: identifier)
            ?? identifier
    }

    init(language: Locale.Language) {
        let code = language.languageCode?.identifier ?? language.minimalIdentifier
        self.identifier = code
        self.localeIdentifier = language.minimalIdentifier
        self.displayName = Locale.current.localizedString(forIdentifier: language.minimalIdentifier) ?? code
    }
}

enum TranslationLanguageCatalog {
    private static let pinnedIdentifiers = ["ja", "en"]

    static func available(from supportedLanguages: Set<Locale.Language>) -> [TranslationLanguage] {
        let languages = supportedLanguages.map(TranslationLanguage.init(language:))
        return ordered(languages)
    }

    static func ordered(_ languages: [TranslationLanguage]) -> [TranslationLanguage] {
        var languagesByLocale: [String: TranslationLanguage] = [:]
        for language in languages.sorted(by: { $0.localeIdentifier < $1.localeIdentifier }) {
            languagesByLocale[language.localeIdentifier] = languagesByLocale[language.localeIdentifier] ?? language
        }
        let uniqueLanguages = languagesByLocale.values.sorted { $0.localeIdentifier < $1.localeIdentifier }

        let pinned = pinnedIdentifiers.compactMap { identifier in
            uniqueLanguages.first(where: { $0.localeIdentifier == identifier })
                ?? uniqueLanguages.first(where: { $0.identifier == identifier })
        }
        let pinnedLocaleIdentifiers = Set(pinned.map(\.localeIdentifier))
        let others = uniqueLanguages
            .filter {
                !pinnedLocaleIdentifiers.contains($0.localeIdentifier)
                    && !pinnedIdentifiers.contains($0.identifier)
            }
            .sorted {
                let comparison = $0.displayName.localizedStandardCompare($1.displayName)
                return comparison == .orderedSame
                    ? $0.localeIdentifier < $1.localeIdentifier
                    : comparison == .orderedAscending
            }

        return pinned + others
    }

    static func detectSource(in text: String) -> TranslationLanguage {
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)

        if let rawIdentifier = recognizer.dominantLanguage?.rawValue {
            return TranslationLanguage(identifier: rawIdentifier)
        }

        let fallbackIdentifier = containsJapanese(text) ? "ja" : "en"
        return TranslationLanguage(identifier: fallbackIdentifier)
    }

    static func defaultTarget(
        for source: TranslationLanguage,
        available languages: [TranslationLanguage]
    ) -> TranslationLanguage? {
        let preferredIdentifier = source.identifier == "ja" ? "en" : "ja"
        return languages.first(where: { $0.identifier == preferredIdentifier })
            ?? languages.first(where: { $0.identifier != source.identifier })
    }

    private static func containsJapanese(_ text: String) -> Bool {
        text.unicodeScalars.contains { scalar in
            switch scalar.value {
            case 0x3040...0x30FF, 0x31F0...0x31FF, 0x3400...0x4DBF, 0x4E00...0x9FFF:
                return true
            default:
                return false
            }
        }
    }
}

struct TranslationRequest: Equatable {
    let text: String
    let sourceLanguage: TranslationLanguage
    let targetLanguage: TranslationLanguage
}

struct TranslationDirection {
    private(set) var activeInputText: String
    private(set) var sourceLanguage: TranslationLanguage
    private(set) var targetLanguage: TranslationLanguage
    private(set) var resultText: String?

    init(
        activeInputText: String,
        sourceLanguage: TranslationLanguage,
        targetLanguage: TranslationLanguage
    ) {
        self.activeInputText = activeInputText
        self.sourceLanguage = sourceLanguage
        self.targetLanguage = targetLanguage
        resultText = nil
    }

    mutating func setResult(_ text: String) {
        resultText = text
    }

    mutating func clearResult() {
        resultText = nil
    }

    mutating func selectTarget(_ language: TranslationLanguage) -> TranslationRequest {
        targetLanguage = language
        resultText = nil
        return currentRequest
    }

    mutating func reverse() -> TranslationRequest? {
        guard let resultText, !resultText.isEmpty else { return nil }

        activeInputText = resultText
        self.resultText = nil
        swap(&sourceLanguage, &targetLanguage)
        return currentRequest
    }

    private var currentRequest: TranslationRequest {
        TranslationRequest(
            text: activeInputText,
            sourceLanguage: sourceLanguage,
            targetLanguage: targetLanguage
        )
    }
}
