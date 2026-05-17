import SwiftUI
import Observation

/// ViewModel for the Settings view. Orchestrates:
/// - Saving/reading Jira credentials (URL → AppSettings, PAT → Keychain)
/// - Testing the connection via JiraClient
/// - Managing the list of project keys
/// - Registering the global keyboard shortcut
@Observable
final class SettingsViewModel {

    // MARK: - Dependencies

    private let keychainService: KeychainService
    private let appSettings: AppSettings

    // MARK: - Connection State

    /// The Jira base URL entered by the user.
    var baseURL: String
    /// The PAT entered by the user (only in memory, saved to Keychain on explicit save).
    var patInput: String = ""
    /// Whether a connection test is in progress.
    var isTesting = false
    /// The result message of the last connection test.
    var connectionMessage: String?
    /// Whether the last connection test succeeded.
    var connectionSuccess = false

    // MARK: - Default Settings

    /// The list of project keys the user has added.
    var projectKeys: [String]
    /// The selected default project key.
    var defaultProjectKey: String
    /// The selected default issue type.
    var defaultIssueType: String
    /// Whether to use a custom assignee.
    var useCustomAssignee: Bool
    /// The custom assignee username.
    var customAssignee: String
    /// The resolved username from Jira (read-only display).
    var resolvedUsername: String
    /// The resolved display name from Jira (read-only display).
    var resolvedDisplayName: String

    /// Text field for adding a new project key.
    var newProjectKeyInput: String = ""

    // MARK: - Available Issue Types

    /// The list of issue types available for selection.
    let availableIssueTypes = ["Task", "Story", "Bug", "Sub-task"]

    // MARK: - Init

    init(
        keychainService: KeychainService = KeychainService(),
        appSettings: AppSettings
    ) {
        self.keychainService = keychainService
        self.appSettings = appSettings

        // Load current settings
        self.baseURL = appSettings.baseURL
        self.projectKeys = appSettings.projectKeys
        self.defaultProjectKey = appSettings.defaultProjectKey
        self.defaultIssueType = appSettings.defaultIssueType
        self.useCustomAssignee = appSettings.useCustomAssignee
        self.customAssignee = appSettings.defaultAssignee
        self.resolvedUsername = appSettings.resolvedUsername
        self.resolvedDisplayName = appSettings.resolvedDisplayName

        // Load existing PAT (masked display only)
        if keychainService.readPAT() != nil {
            self.patInput = "••••••••••••••••"
        }
    }

    // MARK: - Actions

    /// Saves the base URL to AppSettings and the PAT to Keychain.
    func saveCredentials() {
        appSettings.baseURL = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)

        // Only save PAT if user typed a new one (not the masked placeholder)
        if !patInput.isEmpty && patInput != "••••••••••••••••" {
            try? keychainService.savePAT(patInput)
        }
        
        UserDefaults.standard.synchronize()
    }

    /// Tests the Jira connection using the current credentials.
    ///
    /// On success, saves the resolved username and display name.
    func testConnection() async {
        saveCredentials()

        isTesting = true
        connectionMessage = nil

        do {
            let client = JiraClient(
                keychainService: keychainService,
                appSettings: appSettings
            )
            let myself = try await client.testConnection()

            // Save resolved identity
            appSettings.resolvedUsername = myself.name
            appSettings.resolvedDisplayName = myself.displayName
            resolvedUsername = myself.name
            resolvedDisplayName = myself.displayName

            connectionSuccess = true
            connectionMessage = String(
                localized: "settings_connection_success",
                defaultValue: "Connected as \(myself.displayName) (\(myself.name))"
            )
        } catch {
            connectionSuccess = false
            connectionMessage = error.localizedDescription
        }

        isTesting = false
    }

    /// Adds a new project key to the list.
    ///
    /// Validates that the key is a short uppercase alphanumeric code (Jira project keys
    /// never contain spaces — e.g., `EA`, `INFRA`, `PROJ`).
    func addProjectKey() {
        // Strip whitespace and force uppercase
        let key = newProjectKeyInput
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "")
            .uppercased()

        guard !key.isEmpty, !projectKeys.contains(key) else { return }

        // Validate: Jira project keys are 2-10 uppercase alphanumeric characters
        let isValid = key.count >= 2 && key.count <= 10 && key.allSatisfy { $0.isLetter || $0.isNumber }
        guard isValid else { return }

        projectKeys.append(key)
        appSettings.projectKeys = projectKeys

        // If this is the first project, make it the default
        if projectKeys.count == 1 {
            defaultProjectKey = key
            appSettings.defaultProjectKey = key
        }

        newProjectKeyInput = ""
    }

    /// Removes a project key at the given index.
    func removeProjectKey(at offsets: IndexSet) {
        let removedKeys = offsets.map { projectKeys[$0] }
        projectKeys.remove(atOffsets: offsets)
        appSettings.projectKeys = projectKeys

        // If we removed the default, pick the first remaining
        if removedKeys.contains(defaultProjectKey) {
            defaultProjectKey = projectKeys.first ?? ""
            appSettings.defaultProjectKey = defaultProjectKey
        }
    }

    /// Saves the default project/issue type/assignee settings.
    func saveDefaults() {
        appSettings.defaultProjectKey = defaultProjectKey
        appSettings.defaultIssueType = defaultIssueType
        appSettings.useCustomAssignee = useCustomAssignee
        appSettings.defaultAssignee = customAssignee
    }
}
