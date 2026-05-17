import Foundation
import SwiftData

/// A locally queued task that acts as an offline buffer for Jira issue creation.
///
/// When the user submits a task, it is immediately enqueued to SwiftData
/// before attempting the network request. This ensures zero data loss
/// even if the network is unavailable or the VPN is disconnected.
///
/// ## Lifecycle
/// 1. Created with status `.pending` when user submits a task
/// 2. Updated to `.sent` when Jira returns HTTP 201
/// 3. Updated to `.failed` after max retry attempts
/// 4. The `QueueProcessor` auto-flushes `.pending` tasks when network recovers
@Model
final class QueuedTask {

    /// Unique identifier for this queued task.
    @Attribute(.unique) var id: UUID

    /// The serialized JSON payload (`CreateIssueRequest`) ready to send to Jira.
    var payload: Data

    /// The clean task title (for display in the pending tasks list).
    var title: String

    /// The target project key (for display purposes).
    var projectKey: String

    /// When this task was enqueued.
    var createdAt: Date

    /// Current processing status.
    var status: QueuedTaskStatus

    /// Number of times the network request has been retried.
    var retryCount: Int

    /// Error message from the last failed attempt, if any.
    var lastError: String?

    /// The Jira issue key returned on success (e.g., "PROJ-123").
    var resultIssueKey: String?

    init(
        payload: Data,
        title: String,
        projectKey: String
    ) {
        self.id = UUID()
        self.payload = payload
        self.title = title
        self.projectKey = projectKey
        self.createdAt = Date()
        self.status = .pending
        self.retryCount = 0
        self.lastError = nil
        self.resultIssueKey = nil
    }
}

// MARK: - Queue Status

/// The processing status of a queued task.
enum QueuedTaskStatus: String, Codable {
    /// Waiting to be sent (initial state, or network was unavailable).
    case pending
    /// Successfully created in Jira.
    case sent
    /// Failed after maximum retry attempts.
    case failed
}
