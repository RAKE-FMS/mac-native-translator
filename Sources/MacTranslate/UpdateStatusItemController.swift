import AppKit

@MainActor
final class UpdateStatusItemController: NSObject {
    private let updater: AppUpdater
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

    init(updater: AppUpdater) {
        self.updater = updater
        super.init()
        statusItem.button?.title = "MT"
        rebuildMenu()
    }

    private func rebuildMenu() {
        let menu = NSMenu()

        let checkForUpdates = NSMenuItem(
            title: "Check for Updates…",
            action: #selector(checkForUpdates(_:)),
            keyEquivalent: ""
        )
        checkForUpdates.target = self
        checkForUpdates.isEnabled = updater.isConfigured
        menu.addItem(checkForUpdates)

        let automaticChecks = NSMenuItem(
            title: "Automatically Check for Updates",
            action: #selector(toggleAutomaticChecks(_:)),
            keyEquivalent: ""
        )
        automaticChecks.target = self
        automaticChecks.state = updater.automaticallyChecksForUpdates ? .on : .off
        automaticChecks.isEnabled = updater.isConfigured
        menu.addItem(automaticChecks)

        menu.addItem(.separator())

        let quit = NSMenuItem(
            title: "Quit MacTranslate",
            action: #selector(quit(_:)),
            keyEquivalent: "q"
        )
        quit.target = self
        menu.addItem(quit)

        statusItem.menu = menu
    }

    @objc private func checkForUpdates(_ sender: Any?) {
        updater.checkForUpdates()
    }

    @objc private func toggleAutomaticChecks(_ sender: NSMenuItem) {
        updater.setAutomaticallyChecksForUpdates(sender.state != .on)
        rebuildMenu()
    }

    @objc private func quit(_ sender: Any?) {
        NSApplication.shared.terminate(nil)
    }
}
