import Foundation
import Observation

/// Centralized application settings backed by `UserDefaults` via `@AppStorage`.
///
/// This class provides the single source of truth for all user-configurable
/// settings: Jira connection details, default project/issue type/assignee,
/// and the list of available project keys.
///
/// ## Architecture Role
/// In the MVVM pattern, this is part of the **Model** layer. Both ViewModels
/// and Services read from this class to resolve default values.
@Observable
final class AppSettings {

    // MARK: - Storage Keys

    private enum Keys {
        static let baseURL = "jira_base_url"
        static let defaultProjectKey = "default_project_key"
        static let defaultIssueType = "default_issue_type"
        static let resolvedUsername = "resolved_username"
        static let resolvedDisplayName = "resolved_display_name"
        static let defaultAssignee = "default_assignee"
        static let projectKeys = "project_keys_json"
        static let useCustomAssignee = "use_custom_assignee"
    }

    // MARK: - Properties

    /// The Jira Data Center base URL (e.g., "https://jira.company.com").
    var baseURL: String {
        get { UserDefaults.standard.string(forKey: Keys.baseURL) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: Keys.baseURL) }
    }

    /// The default project key for new tasks (e.g., "PROJ").
    var defaultProjectKey: String {
        get { UserDefaults.standard.string(forKey: Keys.defaultProjectKey) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: Keys.defaultProjectKey) }
    }

    /// The default issue type name (e.g., "Task", "Story", "Bug").
    var defaultIssueType: String {
        get { UserDefaults.standard.string(forKey: Keys.defaultIssueType) ?? "Task" }
        set { UserDefaults.standard.set(newValue, forKey: Keys.defaultIssueType) }
    }

    /// The username resolved from Jira's `/myself` endpoint (e.g., "john.doe").
    /// This is the Active Directory login name used as the default assignee.
    var resolvedUsername: String {
        get { UserDefaults.standard.string(forKey: Keys.resolvedUsername) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: Keys.resolvedUsername) }
    }

    /// The display name resolved from Jira's `/myself` endpoint (e.g., "John Doe").
    var resolvedDisplayName: String {
        get { UserDefaults.standard.string(forKey: Keys.resolvedDisplayName) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: Keys.resolvedDisplayName) }
    }

    /// Whether to use a custom assignee instead of the resolved username.
    var useCustomAssignee: Bool {
        get { UserDefaults.standard.bool(forKey: Keys.useCustomAssignee) }
        set { UserDefaults.standard.set(newValue, forKey: Keys.useCustomAssignee) }
    }

    /// The custom assignee username (used when `useCustomAssignee` is true).
    var defaultAssignee: String {
        get { UserDefaults.standard.string(forKey: Keys.defaultAssignee) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: Keys.defaultAssignee) }
    }

    /// The list of project keys the user has added (e.g., ["PROJ", "INFRA", "MOBILE"]).
    var projectKeys: [String] {
        get {
            guard let data = UserDefaults.standard.data(forKey: Keys.projectKeys),
                  let keys = try? JSONDecoder().decode([String].self, from: data) else {
                return []
            }
            return keys
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(data, forKey: Keys.projectKeys)
            }
        }
    }

    // MARK: - Computed Properties

    /// The effective assignee username based on current settings.
    /// Returns the custom assignee if enabled, otherwise the resolved username from Jira.
    var effectiveAssignee: String {
        useCustomAssignee ? defaultAssignee : resolvedUsername
    }

    /// Whether the app has been configured with Jira credentials.
    var isConfigured: Bool {
        !baseURL.isEmpty && !resolvedUsername.isEmpty
    }

    /// Whether there is at least one project key configured.
    var hasProjects: Bool {
        !projectKeys.isEmpty && !defaultProjectKey.isEmpty
    }
}
