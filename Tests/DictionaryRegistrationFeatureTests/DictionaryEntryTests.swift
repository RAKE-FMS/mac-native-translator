import XCTest
@testable import DictionaryRegistrationFeature

final class DictionaryEntryTests: XCTestCase {
    func testReadingEstimate() {
        XCTAssertEqual(JapaneseReading.estimate(for: "試作記録"), "しさくきろく")
        XCTAssertEqual(JapaneseReading.estimate(for: "カタカナ"), "かたかな")
        XCTAssertEqual(JapaneseReading.estimate(for: "試作ABC"), "")
        XCTAssertEqual(JapaneseReading.estimate(for: "試作 記録"), "")
        XCTAssertEqual(JapaneseReading.estimate(for: ""), "")
    }

    func testEntryValidation() {
        XCTAssertEqual(DictionaryEntry(reading: "か\u{3099}く", phrase: "学")?.reading, "がく")
        XCTAssertNotNil(DictionaryEntry(
            reading: String(repeating: "あ", count: 32), phrase: String(repeating: "語", count: 64)
        ))
        XCTAssertNil(DictionaryEntry(reading: String(repeating: "あ", count: 33), phrase: "語"))
        XCTAssertNil(DictionaryEntry(reading: "ご", phrase: String(repeating: "語", count: 65)))
        XCTAssertNil(DictionaryEntry(reading: "ゴ", phrase: "語"))
        XCTAssertNil(DictionaryEntry(reading: "", phrase: "語"))
        XCTAssertNil(DictionaryEntry(reading: "ご", phrase: "  "))
        XCTAssertNil(DictionaryEntry(reading: "ご", phrase: "語\n語"))
    }

    @MainActor
    func testDraftPreventsRepeatedRegistrationUntilThereIsAKnownOutcome() {
        let draft = DictionaryDraft()
        XCTAssertNil(draft.startRegistration())

        draft.begin(with: "試作記録")
        draft.reading = "ためしきろく"
        let entry = draft.startRegistration()
        XCTAssertEqual(entry, DictionaryEntry(reading: "ためしきろく", phrase: "試作記録"))
        XCTAssertNil(draft.startRegistration())

        draft.state = .unverified
        XCTAssertNil(draft.startRegistration())
        XCTAssertEqual(draft.reading, "ためしきろく")
        XCTAssertEqual(draft.phrase, "試作記録")
    }
}
