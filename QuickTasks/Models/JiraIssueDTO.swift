import Foundation

// MARK: - Jira REST API v2 Data Transfer Objects

/// Request payload for creating a Jira issue via `POST /rest/api/2/issue`.
///
/// Jira REST API v2 uses plain text for summary and description fields,
/// avoiding the complexity of Atlassian Document Format (ADF).
struct CreateIssueRequest: Codable {
    let fields: IssueFields

    struct IssueFields: Codable {
        let project: ProjectRef
        let summary: String
        let issuetype: IssueTypeRef
        let assignee: AssigneeRef?
        let description: String?
    }

    struct ProjectRef: Codable {
        let key: String
    }

    struct IssueTypeRef: Codable {
        let name: String
    }

    struct AssigneeRef: Codable {
        let name: String
    }
}

/// Response from Jira after successfully creating an issue (HTTP 201).
struct CreateIssueResponse: Codable {
    /// The internal Jira issue ID.
    let id: String
    /// The issue key (e.g., "PROJ-123").
    let key: String
    /// The self-referencing URL of the created issue.
    let `self`: String
}

/// Response from `GET /rest/api/2/myself` — the authenticated user's profile.
struct JiraMyselfResponse: Codable {
    /// The username (Active Directory login name, e.g., "john.doe").
    let name: String
    /// The display name (e.g., "John Doe").
    let displayName: String
    /// The user's email address.
    let emailAddress: String?
}

/// Jira API error response structure.
struct JiraErrorResponse: Codable {
    let errorMessages: [String]?
    let errors: [String: String]?

    /// Returns a combined human-readable error message.
    var combinedMessage: String {
        let messages = (errorMessages ?? []) + (errors?.values.map { $0 } ?? [])
        return messages.isEmpty ? "Unknown Jira error" : messages.joined(separator: "; ")
    }
}
