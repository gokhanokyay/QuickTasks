import SwiftUI
import SwiftData

/// QuickTasks — A macOS menu bar application for instant Jira DC task creation.
///
/// The app lives entirely in the menu bar (LSUIElement). It provides:
/// - A global keyboard shortcut to summon a floating quick-entry panel
/// - Inline slash commands and mentions for project/type/assignee overrides
/// - Asynchronous task creation with offline queue support
@main
struct QuickTasksApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var appSettings = AppSettings()

    var body: some Scene {
        // MARK: - Menu Bar
        MenuBarExtra {
            MenuBarView()
                .environment(appDelegate)
                .environment(appSettings)
        } label: {
            Label(
                String(localized: "QuickTasks", comment: "Menu bar label"),
                systemImage: "bolt.fill"
            )
        }

        // MARK: - Settings Window
        Settings {
            SettingsView(appSettings: appSettings)
        }
    }
}

// MARK: - Menu Bar Dropdown View

/// The dropdown menu that appears when clicking the menu bar icon.
struct MenuBarView: View {
    @Environment(AppDelegate.self) private var appDelegate
    @Environment(AppSettings.self) private var appSettings

    var body: some View {
        Button {
            appDelegate.summonQuickEntry()
        } label: {
            Text("quick_entry_open", comment: "Open Quick Entry menu item")
        }
        .keyboardShortcut("j", modifiers: [.option, .command])

        Divider()

        SettingsLink {
            Text("settings_open", comment: "Open Settings menu item")
        }
        .keyboardShortcut("k", modifiers: [.option, .command])

        Divider()

        // Show onboarding hint if not configured
        if !appSettings.isConfigured {
            Label {
                Text("menu_setup_hint", comment: "Setup hint in menu bar")
            } icon: {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.yellow)
            }

            Divider()
        }

        Button {
            NSApplication.shared.terminate(nil)
        } label: {
            Text("app_quit", comment: "Quit application menu item")
        }
        .keyboardShortcut("q", modifiers: .command)
    }
}
