import AppKit
import Observation
import ServiceManagement

@MainActor
@Observable
final class LaunchAtLogin {
    private let service = SMAppService.mainApp
    private let promptKey = "hasAskedToLaunchAtLogin"
    private(set) var isEnabled = false

    init() {
        refresh()
    }

    func refresh() {
        isEnabled = service.status == .enabled || service.status == .requiresApproval
    }

    func promptIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: promptKey) else { return }
        let alert = NSAlert()
        alert.messageText = "Launch MacTranslate at login?"
        alert.informativeText = "MacTranslate can start automatically when you log in. You can change this later from its menu bar icon."
        alert.addButton(withTitle: "Enable")
        alert.addButton(withTitle: "Not Now")
        NSApp.activate(ignoringOtherApps: true)
        let response = alert.runModal()
        UserDefaults.standard.set(true, forKey: promptKey)
        if response == .alertFirstButtonReturn {
            setEnabled(true)
        }
    }

    func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try service.register()
            } else {
                try service.unregister()
            }
            if service.status == .requiresApproval {
                let alert = NSAlert()
                alert.messageText = "Allow MacTranslate to open at login"
                alert.informativeText = "Enable MacTranslate in Login Items in System Settings."
                alert.addButton(withTitle: "Open System Settings")
                alert.addButton(withTitle: "Later")
                if alert.runModal() == .alertFirstButtonReturn {
                    SMAppService.openSystemSettingsLoginItems()
                }
            }
            refresh()
        } catch {
            refresh()
            let alert = NSAlert(error: error)
            alert.messageText = "Could not change launch at login"
            alert.runModal()
        }
    }
}
