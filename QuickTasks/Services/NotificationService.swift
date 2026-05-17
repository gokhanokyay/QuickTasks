import Foundation
import UserNotifications

/// Wraps `UNUserNotificationCenter` to send silent macOS notifications
/// for task creation success and failure events.
final class NotificationService: Sendable {

    // MARK: - Init

    init() {
        // Request notification permission on first use
        Task {
            try? await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound])
        }
    }

    // MARK: - Public API

    /// Sends a success notification when a Jira issue is created.
    ///
    /// - Parameter key: The Jira issue key (e.g., "PROJ-123").
    func notifyTaskCreated(key: String) async {
        let content = UNMutableNotificationContent()
        content.title = "QuickTasks"
        content.body = "Task Created: \(key)"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "task-created-\(key)",
            content: content,
            trigger: nil // Deliver immediately
        )

        try? await UNUserNotificationCenter.current().add(request)
    }

    /// Sends a failure notification when a task could not be created.
    ///
    /// - Parameters:
    ///   - title: The task title that failed.
    ///   - error: A human-readable error description.
    func notifyTaskFailed(title: String, error: String) async {
        let content = UNMutableNotificationContent()
        content.title = String(
            localized: "notification_task_failed_title",
            defaultValue: "Task Failed"
        )
        content.body = "\"\(title)\" — \(error)"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "task-failed-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )

        try? await UNUserNotificationCenter.current().add(request)
    }
}
