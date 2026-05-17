import Foundation

/// The result of parsing a raw user input string from the Quick Entry field.
///
/// The `InputParser` extracts inline commands (slash commands and mentions)
/// from the raw text and produces this value type with the clean title and
/// any override values.
///
/// ## Example
/// Input: `"Fix login bug /INFRA /bug @mehmet.yildiz"`
/// Result:
/// - `cleanTitle` = `"Fix login bug"`
/// - `projectOverride` = `"INFRA"`
/// - `issueTypeOverride` = `"Bug"`
/// - `assigneeOverride` = `"mehmet.yildiz"`
struct ParsedInput: Equatable, Sendable {
    /// The task title with all inline commands removed and whitespace trimmed.
    let cleanTitle: String

    /// Project key override extracted from `/PROJECT` command (e.g., "INFRA").
    /// If `nil`, the default project from AppSettings is used.
    let projectOverride: String?

    /// Issue type override extracted from `/bug`, `/story`, `/task`, `/subtask`.
    /// If `nil`, the default issue type from AppSettings is used.
    let issueTypeOverride: String?

    /// Assignee override extracted from `@username` mention (e.g., "mehmet.yildiz").
    /// If `nil`, the default assignee from AppSettings is used.
    let assigneeOverride: String?
}
