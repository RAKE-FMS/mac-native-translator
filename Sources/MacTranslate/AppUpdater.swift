import Foundation
import Observation
import Sparkle

@MainActor
@Observable
final class AppUpdater {
    private let controller: SPUStandardUpdaterController?
    private(set) var automaticallyChecksForUpdates = false

    init(bundle: Bundle = .main) {
        let feedURL = bundle.object(forInfoDictionaryKey: "SUFeedURL") as? String
        let publicKey = bundle.object(forInfoDictionaryKey: "SUPublicEDKey") as? String
        guard let feedURL, URL(string: feedURL)?.scheme == "https",
              let publicKey, !publicKey.isEmpty else {
            controller = nil
            return
        }

        controller = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        automaticallyChecksForUpdates = controller?.updater.automaticallyChecksForUpdates ?? false
    }

    var isConfigured: Bool { controller != nil }

    func checkForUpdates() {
        controller?.checkForUpdates(nil)
    }

    func setAutomaticallyChecksForUpdates(_ enabled: Bool) {
        controller?.updater.automaticallyChecksForUpdates = enabled
        automaticallyChecksForUpdates = enabled
    }
}
