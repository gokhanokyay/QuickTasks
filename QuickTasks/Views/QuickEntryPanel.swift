import AppKit

/// A custom NSPanel configured for the Quick Entry floating input field.
///
/// This panel:
/// - Floats above all other windows
/// - Can become key window to capture keyboard input
/// - Dismisses when clicking outside
/// - Supports Esc to dismiss via the hosted SwiftUI view
final class QuickEntryPanel: NSPanel {

    /// Closure called when the user clicks outside the panel.
    var onClickOutside: (() -> Void)?

    // MARK: - Overrides

    /// Allow this panel to become the key window so it can receive keyboard input.
    override var canBecomeKey: Bool { true }

    /// Allow this panel to become the main window.
    override var canBecomeMain: Bool { true }

    // MARK: - Click Outside Detection

    override func resignKey() {
        super.resignKey()
        onClickOutside?()
    }
}
