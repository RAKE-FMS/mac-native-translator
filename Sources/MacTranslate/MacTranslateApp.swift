import AppKit
import SwiftUI

@main
@MainActor
struct MacTranslateApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("MacTranslate", systemImage: "character.bubble") {
            UpdateMenuView(
                updater: appDelegate.appUpdater,
                launchAtLogin: appDelegate.launchAtLogin,
                translateScreenRegion: appDelegate.startScreenTranslation
            )
        }
    }
}

@MainActor
private struct UpdateMenuView: View {
    @Bindable var updater: AppUpdater
    let launchAtLogin: LaunchAtLogin
    let translateScreenRegion: () -> Void

    var body: some View {
        Button("Translate Screen Region…", action: translateScreenRegion)

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

        Button("Quit MacTranslate") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}
