import Foundation
import RegexBuilder

/// Parses raw user input from the Quick Entry field, extracting inline commands.
///
/// ## Supported Commands
/// - `/PROJECT_KEY` — overrides the target project (e.g., `/INFRA`)
/// - `/bug`, `/story`, `/task`, `/subtask` — overrides the issue type
/// - `@username` — overrides the assignee (e.g., `@mehmet.yildiz`)
///
/// ## Example
/// ```swift
/// let result = InputParser.parse("Fix login bug /INFRA /bug @mehmet.yildiz")
/// // result.cleanTitle == "Fix login bug"
/// // result.projectOverride == "INFRA"
/// // result.issueTypeOverride == "Bug"
/// // result.assigneeOverride == "mehmet.yildiz"
/// ```
enum InputParser {

    // MARK: - Regex Patterns

    /// Matches a project key override: `/` followed by 2–10 uppercase letters.
    /// Example: `/INFRA`, `/PROJ`, `/MOBILE`
    private static let projectRegex = /\/([A-Z]{2,10})\b/

    /// Matches an issue type override: `/bug`, `/story`, `/task`, `/subtask` (case-insensitive).
    private static let issueTypeRegex = /\/(bug|story|task|subtask)\b/
        .ignoresCase()

    /// Matches an assignee mention: `@` followed by alphanumeric, dots, hyphens, or underscores.
    /// Example: `@mehmet.yildiz`, `@john_doe`, `@admin`
    private static let assigneeRegex = /@([a-zA-Z0-9._-]+)\b/

    // MARK: - Public API

    /// Parses the raw input string and extracts all inline commands.
    ///
    /// - Parameter rawInput: The text entered by the user in the Quick Entry field.
    /// - Returns: A `ParsedInput` with the clean title and any overrides.
    static func parse(_ rawInput: String) -> ParsedInput {
        var text = rawInput

        // Extract issue type FIRST (before project, since `/bug` could false-match project regex)
        var issueTypeOverride: String?
        if let match = text.firstMatch(of: issueTypeRegex) {
            issueTypeOverride = normalizeIssueType(String(match.1))
            text = text.replacing(match.0, with: "")
        }

        // Extract project key
        var projectOverride: String?
        if let match = text.firstMatch(of: projectRegex) {
            projectOverride = String(match.1)
            text = text.replacing(match.0, with: "")
        }

        // Extract assignee
        var assigneeOverride: String?
        if let match = text.firstMatch(of: assigneeRegex) {
            assigneeOverride = String(match.1)
            text = text.replacing(match.0, with: "")
        }

        // Clean up: collapse multiple spaces and trim
        let cleanTitle = text
            .replacing(/\s{2,}/, with: " ")
            .trimmingCharacters(in: .whitespaces)

        return ParsedInput(
            cleanTitle: cleanTitle,
            projectOverride: projectOverride,
            issueTypeOverride: issueTypeOverride,
            assigneeOverride: assigneeOverride
        )
    }

    // MARK: - Helpers

    /// Normalizes the issue type string to the format Jira expects.
    private static func normalizeIssueType(_ raw: String) -> String {
        switch raw.lowercased() {
        case "bug": return "Bug"
        case "story": return "Story"
        case "task": return "Task"
        case "subtask": return "Sub-task"
        default: return raw.capitalized
        }
    }
}
