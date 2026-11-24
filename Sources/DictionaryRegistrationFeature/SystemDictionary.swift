import AppKit
import KeyboardServicesBridge

@MainActor
enum SystemDictionary {
    enum Result: Equatable, Sendable {
        case added
        case manual
        case unverified
    }

    private static let settingsURL = URL(
        string: "x-apple.systempreferences:com.apple.Keyboard-Settings.extension?TextReplacements"
    )!

    static func openSettings() {
        if !NSWorkspace.shared.open(settingsURL),
           let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.systempreferences") {
            NSWorkspace.shared.open(url)
        }
    }

    static func register(_ entry: DictionaryEntry) async -> Result {
        await register(containsEntry: {
            MTDictionaryContainsEntry(entry.reading, entry.phrase)
        }) { reply in
            MTAddDictionaryEntry(entry.reading, entry.phrase, reply)
        }
    }

    static func register(
        verificationTimeout: Duration = .seconds(2),
        containsEntry: () -> Bool,
        submit: (@escaping @Sendable (Bool) -> Void) -> Bool
    ) async -> Result {
        if containsEntry() { return .added }
        let reply = await waitForReply(submit: submit)
        guard reply != .manual else { return .manual }

        let deadline = ContinuousClock.now + verificationTimeout
        while !containsEntry() {
            guard reply == .added, ContinuousClock.now < deadline else { return .unverified }
            do {
                try await Task.sleep(for: .milliseconds(100))
            } catch {
                return .unverified
            }
        }
        return .added
    }

    static func waitForReply(
        timeout: Duration = .seconds(3),
        submit: (@escaping @Sendable (Bool) -> Void) -> Bool
    ) async -> Result {
        let (results, continuation) = AsyncStream<Result>.makeStream(bufferingPolicy: .bufferingOldest(1))
        guard submit({ accepted in
            continuation.yield(accepted ? .added : .unverified)
            continuation.finish()
        }) else {
            continuation.finish()
            return .manual
        }

        // A late reply may follow a successful write, so a timeout must not trigger another write.
        let expiry = Task {
            do {
                try await Task.sleep(for: timeout)
            } catch {
                return
            }
            continuation.yield(.unverified)
            continuation.finish()
        }
        defer { expiry.cancel() }

        var iterator = results.makeAsyncIterator()
        return await iterator.next() ?? .unverified
    }
}
