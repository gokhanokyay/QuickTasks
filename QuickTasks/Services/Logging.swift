import OSLog

/// Centralized loggers for QuickTasks subsystems.
///
/// Usage:
/// ```swift
/// Logger.pipeline.info("Task submitted: \(title)")
/// Logger.network.error("Jira request failed: \(error)")
/// ```
extension Logger {
    /// The bundle identifier used as the subsystem for all loggers.
    private static let subsystem = "com.malidyatech.QuickTasks"

    /// Logs for the task ingestion pipeline (submit → parse → enqueue → dispatch).
    static let pipeline = Logger(subsystem: subsystem, category: "Pipeline")

    /// Logs for Jira network requests and responses.
    static let network = Logger(subsystem: subsystem, category: "Network")

    /// Logs for the offline queue processor.
    static let queue = Logger(subsystem: subsystem, category: "Queue")

    /// Logs for app settings and configuration.
    static let settings = Logger(subsystem: subsystem, category: "Settings")
}
