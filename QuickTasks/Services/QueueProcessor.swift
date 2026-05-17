import Foundation
import SwiftData
import Network

/// Monitors network reachability and auto-flushes pending tasks from the offline queue
/// when the network becomes available.
///
/// ## Strategy
/// - Uses `NWPathMonitor` to detect network state changes
/// - When path becomes `.satisfied`, fetches all `.pending` `QueuedTask` items
/// - Retries each with exponential backoff (max 3 attempts)
/// - Updates status to `.sent` on success or `.failed` after max retries
@MainActor
final class QueueProcessor {

    // MARK: - Constants

    private static let maxRetries = 3

    // MARK: - Dependencies

    private let appSettings: AppSettings
    private let keychainService: KeychainService
    private let notificationService: NotificationService
    private let modelContainer: ModelContainer

    // MARK: - State

    private let monitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "com.malidyatech.QuickTasks.network-monitor")
    private var isProcessing = false

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

    /// Starts monitoring network reachability and auto-flushing on reconnect.
    func start() {
        monitor.pathUpdateHandler = { [weak self] path in
            guard path.status == .satisfied else { return }
            Task { @MainActor in
                await self?.flushPendingTasks()
            }
        }
        monitor.start(queue: monitorQueue)
    }

    /// Stops the network monitor.
    func stop() {
        monitor.cancel()
    }

    /// Manually triggers a flush of all pending tasks.
    func flushPendingTasks() async {
        guard !isProcessing else { return }
        isProcessing = true
        defer { isProcessing = false }

        let context = modelContainer.mainContext
        let pendingStatus = QueuedTaskStatus.pending
        let descriptor = FetchDescriptor<QueuedTask>(
            predicate: #Predicate { $0.status == pendingStatus },
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )

        guard let pendingTasks = try? context.fetch(descriptor), !pendingTasks.isEmpty else {
            return
        }

        let client = JiraClient(
            keychainService: keychainService,
            appSettings: appSettings
        )

        for task in pendingTasks {
            await processTask(task, client: client, context: context)
        }
    }

    /// Returns the count of pending tasks in the queue.
    var pendingCount: Int {
        let context = modelContainer.mainContext
        let pendingStatus = QueuedTaskStatus.pending
        let descriptor = FetchDescriptor<QueuedTask>(
            predicate: #Predicate { $0.status == pendingStatus }
        )
        return (try? context.fetchCount(descriptor)) ?? 0
    }

    // MARK: - Private

    /// Processes a single queued task — attempts to send it to Jira.
    private func processTask(
        _ queuedTask: QueuedTask,
        client: JiraClient,
        context: ModelContext
    ) async {
        // Decode the stored payload
        guard let request = try? JSONDecoder().decode(CreateIssueRequest.self, from: queuedTask.payload) else {
            queuedTask.status = .failed
            queuedTask.lastError = "Failed to decode stored payload"
            try? context.save()
            return
        }

        // Exponential backoff delay
        if queuedTask.retryCount > 0 {
            let delay = pow(2.0, Double(queuedTask.retryCount)) // 2, 4, 8 seconds
            try? await Task.sleep(for: .seconds(delay))
        }

        do {
            let response = try await client.createIssue(request)

            queuedTask.status = .sent
            queuedTask.resultIssueKey = response.key
            try? context.save()

            await notificationService.notifyTaskCreated(key: response.key)

        } catch let error as JiraClientError where error.isRetryable {
            queuedTask.retryCount += 1
            queuedTask.lastError = error.localizedDescription

            if queuedTask.retryCount >= Self.maxRetries {
                queuedTask.status = .failed
                await notificationService.notifyTaskFailed(
                    title: queuedTask.title,
                    error: error.localizedDescription
                )
            }

            try? context.save()

        } catch {
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
