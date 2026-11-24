import XCTest
@testable import DictionaryRegistrationFeature

final class SystemDictionaryTests: XCTestCase {
    @MainActor
    func testDoesNotResubmitAnEntryAlreadyInTheDictionary() async {
        let result = await SystemDictionary.register(containsEntry: { true }) { _ in
            XCTFail("An existing entry should not be submitted again")
            return false
        }
        XCTAssertEqual(result, .added)
    }

    @MainActor
    func testAcknowledgmentRequiresTheEntryToBePresent() async {
        let result = await SystemDictionary.register(
            verificationTimeout: .zero, containsEntry: { false }
        ) { reply in
            reply(true)
            return true
        }
        XCTAssertEqual(result, .unverified)
    }

    @MainActor
    func testConfirmedEntryIsSuccessfulEvenIfTheWriteReplyWasUnclear() async {
        var isStored = false
        let result = await SystemDictionary.register(containsEntry: { isStored }) { reply in
            isStored = true
            reply(false)
            return true
        }
        XCTAssertEqual(result, .added)
    }

    @MainActor
    func testUsesManualRegistrationWhenNoWriteWasAttempted() async {
        let result = await SystemDictionary.waitForReply { _ in false }
        XCTAssertEqual(result, .manual)
    }

    @MainActor
    func testDistinguishesAcceptedAndUnconfirmedWrites() async {
        let accepted = await SystemDictionary.waitForReply { reply in
            reply(true)
            return true
        }
        let unconfirmed = await SystemDictionary.waitForReply { reply in
            reply(false)
            return true
        }
        XCTAssertEqual(accepted, .added)
        XCTAssertEqual(unconfirmed, .unverified)
    }

    @MainActor
    func testReportsAnUnansweredWriteAsUnconfirmed() async {
        var submissionCount = 0
        let result = await SystemDictionary.waitForReply(timeout: .milliseconds(5)) { _ in
            submissionCount += 1
            return true
        }
        XCTAssertEqual(result, .unverified)
        XCTAssertEqual(submissionCount, 1)
    }
}
