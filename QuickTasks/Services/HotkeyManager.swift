import Foundation
import KeyboardShortcuts

/// Extension to register the app's keyboard shortcut names with the KeyboardShortcuts package.
extension KeyboardShortcuts.Name {
    /// The global shortcut for summoning the Quick Entry panel.
    /// Default: ⌥⌘J (Option + Command + J)
    static let quickEntry = Self("quickEntry", default: .init(.j, modifiers: [.option, .command]))
}

/// Manages the global keyboard shortcut registration and connects it to the app's Quick Entry panel.
///
/// This class bridges the `KeyboardShortcuts` SPM package with the `AppDelegate`
/// to summon/dismiss the floating panel when the user presses the configured shortcut.
@MainActor
final class HotkeyManager {

    // MARK: - Dependencies

    private weak var appDelegate: AppDelegate?

    // MARK: - Init

    init(appDelegate: AppDelegate) {
        self.appDelegate = appDelegate
        registerShortcut()
    }

    // MARK: - Registration

    /// Registers the global shortcut handler.
    private func registerShortcut() {
        KeyboardShortcuts.onKeyUp(for: .quickEntry) { [weak self] in
            guard let appDelegate = self?.appDelegate else { return }
            if appDelegate.isQuickEntryVisible {
                appDelegate.dismissQuickEntry()
            } else {
                appDelegate.summonQuickEntry()
            }
        }
    }
}
