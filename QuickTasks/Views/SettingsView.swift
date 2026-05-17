import SwiftUI

/// The Settings window with tabbed navigation for Connection, Defaults, and Shortcut configuration.
///
/// Maps to **Epic 1**:
/// - Story 1.1: Jira Auth (Connection tab)
/// - Story 1.2: Self-Resolution (Test Connection button)
/// - Story 1.3: System Defaults (Defaults tab)
struct SettingsView: View {

    @State private var viewModel: SettingsViewModel

    init(appSettings: AppSettings) {
        _viewModel = State(initialValue: SettingsViewModel(appSettings: appSettings))
    }

    var body: some View {
        TabView {
            ConnectionTab(viewModel: viewModel)
                .tabItem {
                    Label(
                        String(localized: "settings_tab_connection", defaultValue: "Connection"),
                        systemImage: "network"
                    )
                }

            DefaultsTab(viewModel: viewModel)
                .tabItem {
                    Label(
                        String(localized: "settings_tab_defaults", defaultValue: "Defaults"),
                        systemImage: "slider.horizontal.3"
                    )
                }

            ShortcutTab()
                .tabItem {
                    Label(
                        String(localized: "settings_tab_shortcut", defaultValue: "Shortcut"),
                        systemImage: "keyboard"
                    )
                }
        }
        .frame(width: 480, height: 380)
    }
}

// MARK: - Connection Tab

/// Connection settings: Jira URL, PAT, and Test Connection.
private struct ConnectionTab: View {
    @Bindable var viewModel: SettingsViewModel

    var body: some View {
        Form {
            Section {
                TextField(
                    String(localized: "settings_jira_url_label", defaultValue: "Jira Base URL"),
                    text: $viewModel.baseURL,
                    prompt: Text(verbatim: "https://jira.company.com")
                )
                .textContentType(.URL)
                .onChange(of: viewModel.baseURL) {
                    viewModel.saveCredentials()
                }

                SecureField(
                    String(localized: "settings_pat_label", defaultValue: "Personal Access Token"),
                    text: $viewModel.patInput,
                    prompt: Text(String(
                        localized: "settings_pat_prompt",
                        defaultValue: "Paste your Jira PAT"
                    ))
                )
                .onChange(of: viewModel.patInput) {
                    viewModel.saveCredentials()
                }
            } header: {
                Text("settings_section_credentials", comment: "Credentials section header")
            }

            Section {
                HStack {
                    Button {
                        Task { await viewModel.testConnection() }
                    } label: {
                        if viewModel.isTesting {
                            ProgressView()
                                .controlSize(.small)
                                .padding(.trailing, 4)
                            Text("settings_testing_connection", comment: "Testing connection status")
                        } else {
                            Text("settings_test_connection", comment: "Test Connection button")
                        }
                    }
                    .disabled(viewModel.baseURL.isEmpty || viewModel.patInput.isEmpty || viewModel.isTesting)

                    Spacer()

                    if let message = viewModel.connectionMessage {
                        Label {
                            Text(message)
                                .font(.caption)
                        } icon: {
                            Image(systemName: viewModel.connectionSuccess ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundStyle(viewModel.connectionSuccess ? .green : .red)
                        }
                    }
                }

                if !viewModel.resolvedUsername.isEmpty {
                    LabeledContent(
                        String(localized: "settings_logged_in_as", defaultValue: "Logged in as")
                    ) {
                        Text("\(viewModel.resolvedDisplayName) (\(viewModel.resolvedUsername))")
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("settings_section_connection_test", comment: "Connection test section header")
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - Defaults Tab

/// Default project, issue type, and assignee settings.
private struct DefaultsTab: View {
    @Bindable var viewModel: SettingsViewModel

    var body: some View {
        Form {
            // Project Keys
            Section {
                ForEach(viewModel.projectKeys, id: \.self) { key in
                    HStack {
                        Text(key)
                            .font(.system(.body, design: .monospaced))
                        Spacer()
                        if key == viewModel.defaultProjectKey {
                            Text("settings_default_badge", comment: "Default badge")
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(.blue.opacity(0.15))
                                .clipShape(Capsule())
                                .foregroundStyle(.blue)
                        }
                        Button(role: .destructive) {
                            if let index = viewModel.projectKeys.firstIndex(of: key) {
                                viewModel.removeProjectKey(at: IndexSet(integer: index))
                            }
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .foregroundStyle(.red)
                        }
                        .buttonStyle(.plain)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        viewModel.defaultProjectKey = key
                        viewModel.saveDefaults()
                    }
                }

                HStack {
                    TextField(
                        String(localized: "settings_project_key_placeholder", defaultValue: "e.g. EA, INFRA"),
                        text: $viewModel.newProjectKeyInput
                    )
                    .font(.system(.body, design: .monospaced))
                    .onSubmit { viewModel.addProjectKey() }

                    Button {
                        viewModel.addProjectKey()
                    } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                    .disabled(viewModel.newProjectKeyInput.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            } header: {
                Text("settings_section_projects", comment: "Projects section header")
            } footer: {
                Text("settings_project_key_hint", comment: "Hint about project keys")
            }

            // Issue Type
            Section {
                Picker(
                    String(localized: "settings_issue_type_label", defaultValue: "Default Issue Type"),
                    selection: $viewModel.defaultIssueType
                ) {
                    ForEach(viewModel.availableIssueTypes, id: \.self) { type in
                        Text(type).tag(type)
                    }
                }
                .onChange(of: viewModel.defaultIssueType) {
                    viewModel.saveDefaults()
                }
            } header: {
                Text("settings_section_issue_type", comment: "Issue type section header")
            }

            // Assignee
            Section {
                Picker(
                    String(localized: "settings_assignee_label", defaultValue: "Default Assignee"),
                    selection: $viewModel.useCustomAssignee
                ) {
                    Text(meAssigneeLabel)
                        .tag(false)

                    Text(String(localized: "settings_assignee_other", defaultValue: "Other"))
                        .tag(true)
                }
                .onChange(of: viewModel.useCustomAssignee) {
                    viewModel.saveDefaults()
                }

                if viewModel.useCustomAssignee {
                    TextField(
                        String(localized: "settings_custom_assignee_placeholder", defaultValue: "username"),
                        text: $viewModel.customAssignee
                    )
                    .font(.system(.body, design: .monospaced))
                    .onChange(of: viewModel.customAssignee) {
                        viewModel.saveDefaults()
                    }
                }
            } header: {
                Text("settings_section_assignee", comment: "Assignee section header")
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    /// Build the "Me (username)" label as a plain string to avoid localization key mismatch.
    private var meAssigneeLabel: String {
        let me = String(localized: "settings_assignee_me", defaultValue: "Me")
        if viewModel.resolvedUsername.isEmpty {
            return me
        }
        return "\(me) (\(viewModel.resolvedUsername))"
    }
}

// MARK: - Shortcut Tab

/// Keyboard shortcut configuration.
/// Uses the KeyboardShortcuts package for the recorder widget.
private struct ShortcutTab: View {
    var body: some View {
        Form {
            Section {
                HStack {
                    Text("settings_shortcut_label", comment: "Quick Entry Shortcut label")
                    Spacer()
                    // TODO: Phase 5 — Replace with KeyboardShortcuts.Recorder
                    Text("⌥⌘J")
                        .font(.system(.body, design: .monospaced))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.quaternary)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            } header: {
                Text("settings_section_global_shortcut", comment: "Global shortcut section header")
            } footer: {
                Text("settings_shortcut_footer", comment: "Shortcut configuration instructions")
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}
