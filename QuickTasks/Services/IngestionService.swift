import Foundation
import SwiftData
import OSLog

/// Orchestrates the task submission pipeline.
///
/// ## Pipeline
/// 1. Resolves final values (use overrides or fall back to AppSettings defaults)
/// 2. Constructs the `CreateIssueRequest` DTO
/// 3. Enqueues to SwiftData (`QueuedTask`) as a safety buffer
/// 4. Attempts `JiraClient.createIssue()`
/// 5. On success (HTTP 201): marks queue item as `.sent`, fires macOS notification
/// 6. On retryable failure: leaves as `.pending` for `QueueProcessor` to retry
/// 7. On permanent failure: marks as `.failed` with error message
@MainActor
final class IngestionService {

    // MARK: - Dependencies

    private let appSettings: AppSettings
    private let keychainService: KeychainService
    private let notificationService: NotificationService
    private let modelContainer: ModelContainer

    // MARK: - Init

    init(
        appSettings: AppSettings,
        keychainService: KeychainService = KeychainService(),
        notificationService: NotificationService = NotificationService(),
        modelContainer: ModelContainer
    ) {
        self.appSettings = appSettings
        self.keychainService = keychainService
        self.notificationService = notificationService
        self.modelContainer = modelContainer
    }

    // MARK: - Public API

    /// Submits a parsed task for creation in Jira.
    ///
    /// The window has already been dismissed by the time this is called.
    /// This method enqueues the task locally first, then attempts the network call.
    ///
    /// - Parameter parsed: The parsed input from the Quick Entry field.
    func submit(_ parsed: ParsedInput) async {
        // 1. Resolve final values
        let projectKey = parsed.projectOverride ?? appSettings.defaultProjectKey
        let issueType = parsed.issueTypeOverride ?? appSettings.defaultIssueType
        let assignee = parsed.assigneeOverride ?? appSettings.effectiveAssignee

        Logger.pipeline.info("🔧 Resolved — project: '\(projectKey)', type: '\(issueType)', assignee: '\(assignee)'")

        // 2. Construct the request DTO
        let request = CreateIssueRequest(
            fields: .init(
                project: .init(key: projectKey),
                summary: parsed.cleanTitle,
                issuetype: .init(name: issueType),
                assignee: assignee.isEmpty ? nil : .init(name: assignee),
                description: nil
            )
        )

        // 3. Serialize payload
        guard let payloadData = try? JSONEncoder().encode(request) else {
            Logger.pipeline.error("❌ Failed to encode task payload")
            await notificationService.notifyTaskFailed(
                title: parsed.cleanTitle,
                error: "Failed to encode task payload"
            )
            return
        }

        // Log the actual JSON payload for debugging
        if let jsonString = String(data: payloadData, encoding: .utf8) {
            Logger.pipeline.info("📦 Payload JSON: \(jsonString)")
        }

        // 4. Enqueue to SwiftData
        let queuedTask = QueuedTask(
            payload: payloadData,
            title: parsed.cleanTitle,
            projectKey: projectKey
        )

        let context = modelContainer.mainContext
        context.insert(queuedTask)
        try? context.save()
        Logger.pipeline.info("💾 Task enqueued to SwiftData (id: \(queuedTask.id))")

        // 5. Attempt network request
        await dispatchTask(queuedTask, request: request, context: context)
    }

    // MARK: - Private

    /// Attempts to send the task to Jira and updates the queue status.
    private func dispatchTask(
        _ queuedTask: QueuedTask,
        request: CreateIssueRequest,
        context: ModelContext
    ) async {
        Logger.network.info("🌐 Dispatching to Jira API...")

        let client = JiraClient(
            keychainService: keychainService,
            appSettings: appSettings
        )

        do {
            let response = try await client.createIssue(request)

            // Success — update queue and notify
            Logger.network.info("✅ Jira issue created: \(response.key) (id: \(response.id))")
            queuedTask.status = .sent
            queuedTask.resultIssueKey = response.key
            try? context.save()

            await notificationService.notifyTaskCreated(key: response.key)

        } catch let error as JiraClientError where error.isRetryable {
            // Retryable — leave as pending for QueueProcessor
            Logger.network.warning("⚠️ Retryable error: \(error.localizedDescription)")
            queuedTask.lastError = error.localizedDescription
            try? context.save()

        } catch {
            // Non-retryable — mark as failed
            Logger.network.error("❌ Task creation failed: \(error.localizedDescription)")
            queuedTask.status = .failed
            queuedTask.lastError = error.localizedDescription
            try? context.save()

            await notificationService.notifyTaskFailed(
                title: queuedTask.title,
                error: error.localizedDescription
            )
        }
    }
}
