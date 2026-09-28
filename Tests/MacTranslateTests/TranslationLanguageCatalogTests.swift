import XCTest
@testable import MacTranslate

final class TranslationLanguageCatalogTests: XCTestCase {
    private let japanese = TranslationLanguage(identifier: "ja", displayName: "日本語")
    private let english = TranslationLanguage(identifier: "en", displayName: "English")
    private let french = TranslationLanguage(identifier: "fr", displayName: "Français")
    private let german = TranslationLanguage(identifier: "de", displayName: "Deutsch")
    private let simplifiedChinese = TranslationLanguage(identifier: "zh-Hans", displayName: "Chinese (Simplified)")
    private let traditionalChinese = TranslationLanguage(identifier: "zh-Hant", displayName: "Chinese (Traditional)")

    func testJapaneseAndEnglishAppearBeforeOtherLanguages() {
        let result = TranslationLanguageCatalog.ordered([
            french,
            english,
            german,
            japanese
        ])

        XCTAssertEqual(result.map(\.identifier), ["ja", "en", "de", "fr"])
    }

    func testUnavailablePinnedLanguagesAreNotAdded() {
        let result = TranslationLanguageCatalog.ordered([french, german])

        XCTAssertEqual(result.map(\.identifier), ["de", "fr"])
    }

    func testKeepsDistinctLanguageScriptsSelectable() {
        let result = TranslationLanguageCatalog.ordered([traditionalChinese, simplifiedChinese])

        XCTAssertEqual(result.map(\.localeIdentifier), ["zh-Hans", "zh-Hant"])
    }

    func testDefaultTargetPreservesJapaneseEnglishDirection() {
        let languages = [japanese, english]

        XCTAssertEqual(
            TranslationLanguageCatalog.defaultTarget(for: japanese, available: languages),
            english
        )
        XCTAssertEqual(
            TranslationLanguageCatalog.defaultTarget(for: english, available: languages),
            japanese
        )
    }

    func testNonJapaneseInputDefaultsToJapaneseWhenAvailable() {
        XCTAssertEqual(
            TranslationLanguageCatalog.defaultTarget(for: french, available: [japanese, english, french]),
            japanese
        )
    }

    func testDoesNotChooseTheSourceAsItsOwnTarget() {
        XCTAssertNil(TranslationLanguageCatalog.defaultTarget(for: french, available: [french]))
    }
}

final class TranslationDirectionTests: XCTestCase {
    private let japanese = TranslationLanguage(identifier: "ja", displayName: "日本語")
    private let english = TranslationLanguage(identifier: "en", displayName: "English")
    private let french = TranslationLanguage(identifier: "fr", displayName: "Français")

    func testReverseUsesCurrentResultAndSwapsLanguages() {
        var direction = TranslationDirection(
            activeInputText: "こんにちは",
            sourceLanguage: japanese,
            targetLanguage: english
        )
        direction.setResult("Hello")

        let request = direction.reverse()

        XCTAssertEqual(request?.text, "Hello")
        XCTAssertEqual(request?.sourceLanguage, english)
        XCTAssertEqual(request?.targetLanguage, japanese)
        XCTAssertEqual(direction.activeInputText, "Hello")
        XCTAssertNil(direction.resultText)
    }

    func testChangingTargetKeepsCurrentInputText() {
        var direction = TranslationDirection(
            activeInputText: "Bonjour",
            sourceLanguage: french,
            targetLanguage: japanese
        )
        direction.setResult("こんにちは")

        let request = direction.selectTarget(english)

        XCTAssertEqual(request.text, "Bonjour")
        XCTAssertEqual(request.sourceLanguage, french)
        XCTAssertEqual(request.targetLanguage, english)
        XCTAssertNil(direction.resultText)
    }
}
