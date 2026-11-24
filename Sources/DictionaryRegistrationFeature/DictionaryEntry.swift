import Foundation

struct DictionaryEntry: Equatable {
    static let maximumReadingLength = 32
    static let maximumPhraseLength = 64

    let reading: String
    let phrase: String

    init?(reading: String, phrase: String) {
        let reading = reading.precomposedStringWithCanonicalMapping
        guard Self.isHiragana(reading), reading.count <= Self.maximumReadingLength,
              !phrase.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !phrase.unicodeScalars.contains(where: CharacterSet.newlines.contains),
              phrase.count <= Self.maximumPhraseLength else { return nil }
        self.reading = reading
        self.phrase = phrase
    }

    static func isHiragana(_ text: String) -> Bool {
        !text.isEmpty && text.unicodeScalars.allSatisfy {
            (0x3041...0x3096).contains($0.value) || $0.value == 0x30FC
        }
    }
}
