import Foundation
import CoreFoundation

enum JapaneseReading {
    static func estimate(for phrase: String) -> String {
        let phrase = phrase.precomposedStringWithCanonicalMapping
        guard !phrase.isEmpty, phrase.count <= DictionaryEntry.maximumPhraseLength,
              phrase.unicodeScalars.allSatisfy(isJapaneseScalar) else { return "" }

        if let kana = phrase.applyingTransform(.hiraganaToKatakana, reverse: true),
           DictionaryEntry.isHiragana(kana) {
            return kana.count <= DictionaryEntry.maximumReadingLength ? kana : ""
        }

        let range = CFRange(location: 0, length: phrase.utf16.count)
        let locale = NSLocale(localeIdentifier: "ja_JP") as CFLocale
        guard let tokenizer = CFStringTokenizerCreate(
            nil, phrase as CFString, range,
            kCFStringTokenizerUnitWord | kCFStringTokenizerAttributeLatinTranscription,
            locale
        ) else { return "" }

        var reading = ""
        var consumedLength = 0
        while !CFStringTokenizerAdvanceToNextToken(tokenizer).isEmpty {
            let tokenRange = CFStringTokenizerGetCurrentTokenRange(tokenizer)
            guard tokenRange.location == consumedLength,
                  let transcription = CFStringTokenizerCopyCurrentTokenAttribute(
                      tokenizer, kCFStringTokenizerAttributeLatinTranscription
                  ) as? String,
                  let kana = transcription.applyingTransform(.latinToHiragana, reverse: false),
                  DictionaryEntry.isHiragana(kana) else { return "" }
            reading += kana
            consumedLength += tokenRange.length
        }
        guard consumedLength == range.length, reading.count <= DictionaryEntry.maximumReadingLength else {
            return ""
        }
        return reading
    }

    private static func isJapaneseScalar(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar.value {
        case 0x3005, 0x3041...0x3096, 0x30A1...0x30FA, 0x30FC, 0x3400...0x4DBF,
             0x4E00...0x9FFF, 0xF900...0xFAFF, 0x20000...0x323AF:
            true
        default:
            false
        }
    }
}
