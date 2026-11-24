import AppKit
import ApplicationServices
import DictionaryRegistrationFeature
import TranslationFeature

enum AppIdentity {
    static let displayName = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
        ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String
        ?? "MacTranslate"
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let appUpdater = AppUpdater()
    let launchAtLogin = LaunchAtLogin()
    let dictionaryHotKey = DictionaryHotKey()

    private let hotKeyMonitor = GlobalHotKeyMonitor()
    private let translation = TranslationFeature(appDisplayName: AppIdentity.displayName)
    private let dictionaryRegistration = DictionaryRegistrationFeature()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.accessory)

        launchAtLogin.promptIfNeeded()
        requestAccessibilityPermissionIfNeeded()

        hotKeyMonitor.onDoubleCommandC = { [weak self] in self?.translation.handleDoubleCopy() }
        hotKeyMonitor.onHyperT = { [weak self] in self?.startScreenTranslation() }
        hotKeyMonitor.start()
        dictionaryHotKey.start { [weak self] in self?.startDictionaryRegistration() }
        print("\(AppIdentity.displayName) is running. Select text and press Command+C twice to translate.")
        print("Press Control+C in this terminal to stop it.")
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotKeyMonitor.stop()
        dictionaryHotKey.stop()
    }

    func applicationDidChangeScreenParameters(_ notification: Notification) {
        translation.cancelScreenSelection()
    }

    func startScreenTranslation() {
        translation.startScreenTranslation()
    }

    func startDictionaryRegistration() {
        dictionaryRegistration.show()
    }

    private func requestAccessibilityPermissionIfNeeded() {
        guard !AXIsProcessTrusted() else { return }

        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)

        translation.showMessage(
            "Enable \(AppIdentity.displayName) in System Settings → Privacy & Security → Accessibility, then relaunch the app."
        )
    }
}
