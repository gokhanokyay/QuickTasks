import Foundation
import Observation
import SwiftData
import OSLog

/// ViewModel for the Quick Entry view. Orchestrates the input → parse → submit pipeline.
///
/// ## Pipeline
/// 1. Receives raw text from QuickEntryView
/// 2. Parses it via `InputParser` to extract commands
/// 3. Fires-and-forgets the submission via `IngestionService`
///
/// The panel is dismissed **before** the network call — the user never waits.
@Observable
@MainActor
final class QuickEntryViewModel {

    // MARK: - Dependencies

    private let appSettings: AppSettings
    private let modelContainer: ModelContainer

    // MARK: - Init

    init(appSettings: AppSettings, modelContainer: ModelContainer) {
        self.appSettings = appSettings
        self.modelContainer = modelContainer
    }

    // MARK: - Public API

    /// Submits the raw input text for processing and Jira task creation.
    ///
    /// This method returns immediately. The actual network call happens
    /// asynchronously via IngestionService.
    ///
    /// - Parameter rawText: The raw text from the Quick Entry field.
    func submit(_ rawText: String) {
        Logger.pipeline.info("📝 Raw input received: '\(rawText)'")

        let parsed = InputParser.parse(rawText)

        Logger.pipeline.info("📋 Parsed — title: '\(parsed.cleanTitle)', project: \(parsed.projectOverride ?? "nil"), type: \(parsed.issueTypeOverride ?? "nil"), assignee: \(parsed.assigneeOverride ?? "nil")")

        guard !parsed.cleanTitle.isEmpty else {
            Logger.pipeline.warning("⚠️ Empty clean title after parsing, skipping submission")
            return
        }

        // Fire-and-forget: the ingestion service handles everything asynchronously
        Task {
            Logger.pipeline.info("🚀 Starting ingestion task...")
            let service = IngestionService(
                appSettings: appSettings,
                modelContainer: modelContainer
            )
            await service.submit(parsed)
            Logger.pipeline.info("✅ Ingestion task completed")
        }
    }
}
