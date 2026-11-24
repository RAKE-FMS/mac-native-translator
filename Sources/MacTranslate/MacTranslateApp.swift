import AppKit
import SwiftUI

@main
@MainActor
struct MacTranslateApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra(AppIdentity.displayName, systemImage: "character.bubble") {
            AppMenuView(
                updater: appDelegate.appUpdater,
                launchAtLogin: appDelegate.launchAtLogin,
                dictionaryHotKey: appDelegate.dictionaryHotKey,
                translateScreenRegion: appDelegate.startScreenTranslation,
                registerDictionaryEntry: appDelegate.startDictionaryRegistration
            )
        }
    }
}

@MainActor
private struct AppMenuView: View {
    @Bindable var updater: AppUpdater
    let launchAtLogin: LaunchAtLogin
    let dictionaryHotKey: DictionaryHotKey
    let translateScreenRegion: () -> Void
    let registerDictionaryEntry: () -> Void

    var body: some View {
        Button("Translate Screen Region…", action: translateScreenRegion)
        Button("ユーザ辞書に登録…", action: registerDictionaryEntry)
        if dictionaryHotKey.registrationError != nil {
            Text("Hyper+D を登録できませんでした")
        }

        Divider()

        Button("Check for Updates…") {
            updater.checkForUpdates()
        }
        .disabled(!updater.isConfigured)

        Toggle(
            "Automatically Check for Updates",
            isOn: Binding(
                get: { updater.automaticallyChecksForUpdates },
                set: { updater.setAutomaticallyChecksForUpdates($0) }
            )
        )
        .disabled(!updater.isConfigured)

        Divider()

        Toggle("Launch at Login", isOn: Binding(
            get: { launchAtLogin.isEnabled },
            set: { launchAtLogin.setEnabled($0) }
        ))
        .onAppear { launchAtLogin.refresh() }

        Divider()

        Button("Quit \(AppIdentity.displayName)") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}
