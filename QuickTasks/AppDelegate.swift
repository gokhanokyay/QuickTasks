import AppKit
import SwiftUI
import SwiftData
import Observation

/// AppDelegate manages the floating Quick Entry panel at the AppKit level.
///
/// Responsibilities:
/// - Creates and manages the NSPanel for Quick Entry (floating, above all windows)
/// - Handles panel focus, dismiss on Esc/click-outside
/// - Initializes and owns the HotkeyManager for global shortcut registration
/// - Initializes the QueueProcessor for offline task auto-flush
/// - Provides `summonQuickEntry()` and `dismissQuickEntry()` for the rest of the app
@Observable
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    // MARK: - Properties

    private var quickEntryPanel: QuickEntryPanel?
    private(set) var isQuickEntryVisible = false
    private var hotkeyManager: HotkeyManager?
    private var queueProcessor: QueueProcessor?

    // MARK: - Shared Dependencies

    let appSettings = AppSettings()
    let modelContainer: ModelContainer = {
        let schema = Schema([QueuedTask.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        return try! ModelContainer(for: schema, configurations: [config])
    }()

    // MARK: - Application Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupQuickEntryPanel()
        setupHotkey()
        setupQueueProcessor()
    }

    func applicationWillTerminate(_ notification: Notification) {
        queueProcessor?.stop()
    }

    // MARK: - Quick Entry Panel

    /// Creates the floating NSPanel for Quick Entry input.
    private func setupQuickEntryPanel() {
        let panelWidth: CGFloat = 600
        let panelHeight: CGFloat = 56

        // Center on the main screen
        let screenFrame = NSScreen.main?.visibleFrame ?? .zero
        let panelX = screenFrame.midX - (panelWidth / 2)
        let panelY = screenFrame.midY + 100

        let contentRect = NSRect(x: panelX, y: panelY, width: panelWidth, height: panelHeight)

        let panel = QuickEntryPanel(
            contentRect: contentRect,
            styleMask: [.nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        panel.level = .floating
        panel.isMovableByWindowBackground = true
        panel.hidesOnDeactivate = false
        panel.titlebarAppearsTransparent = true
        panel.titleVisibility = .hidden
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true

        // Host the SwiftUI QuickEntryView inside the panel
        let viewModel = QuickEntryViewModel(
            appSettings: appSettings,
            modelContainer: modelContainer
        )
        let hostingView = NSHostingView(rootView: QuickEntryView(
            viewModel: viewModel,
            dismissAction: { [weak self] in
                self?.dismissQuickEntry()
            }
        ))
        panel.contentView = hostingView

        // Dismiss when clicking outside
        panel.onClickOutside = { [weak self] in
            self?.dismissQuickEntry()
        }

        self.quickEntryPanel = panel
    }

    /// Initializes the global keyboard shortcut.
    private func setupHotkey() {
        hotkeyManager = HotkeyManager(appDelegate: self)
    }

    /// Initializes the offline queue processor with network monitoring.
    private func setupQueueProcessor() {
        queueProcessor = QueueProcessor(
            appSettings: appSettings,
            modelContainer: modelContainer
        )
        queueProcessor?.start()
    }

    // MARK: - Panel Control

    /// Summons the Quick Entry panel: centers it, makes it key, and focuses the text field.
    func summonQuickEntry() {
        guard let panel = quickEntryPanel else { return }

        // Re-center on current screen
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let panelFrame = panel.frame
            let newOrigin = NSPoint(
                x: screenFrame.midX - (panelFrame.width / 2),
                y: screenFrame.midY + 100
            )
            panel.setFrameOrigin(newOrigin)
        }

        panel.makeKeyAndOrderFront(nil)
        panel.makeFirstResponder(panel.contentView)
        NSApp.activate(ignoringOtherApps: true)
        isQuickEntryVisible = true
    }

    /// Dismisses the Quick Entry panel immediately.
    func dismissQuickEntry() {
        quickEntryPanel?.orderOut(nil)
        isQuickEntryVisible = false
    }
}
