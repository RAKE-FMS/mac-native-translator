import AppKit
import SwiftUI

@main
@MainActor
struct MacTranslateApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("MacTranslate", systemImage: "character.bubble") {
            UpdateMenuView(updater: appDelegate.appUpdater)
        }
    }
}

@MainActor
private struct UpdateMenuView: View {
    @Bindable var updater: AppUpdater

    var body: some View {
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

        Button("Quit MacTranslate") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}
