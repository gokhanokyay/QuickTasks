import Foundation
import OSLog

/// Thread-safe Jira REST API v2 client using native `URLSession`.
///
/// This actor communicates with Jira Data Center via Bearer token authentication.
/// All requests use the REST API v2 which accepts plain text for summary and
/// description fields (no ADF complexity).
///
/// ## Dependencies
/// - `KeychainService` — reads the stored PAT for Authorization headers
/// - `AppSettings` — reads the Jira base URL
actor JiraClient {

    // MARK: - Dependencies

    private let keychainService: KeychainService
    private let appSettings: AppSettings
    private let session: URLSession

    // MARK: - Init

    init(
        keychainService: KeychainService = KeychainService(),
        appSettings: AppSettings,
        session: URLSession = .shared
    ) {
        self.keychainService = keychainService
        self.appSettings = appSettings
        self.session = session
    }

    // MARK: - Public API

    /// Tests the Jira connection by calling `GET /rest/api/2/myself`.
    ///
    /// - Returns: The authenticated user's profile.
    /// - Throws: `JiraClientError` on failure.
    func testConnection() async throws -> JiraMyselfResponse {
        let request = try buildRequest(
            method: "GET",
            path: "/rest/api/2/myself"
        )
        return try await perform(request)
    }

    /// Creates a new issue in Jira via `POST /rest/api/2/issue`.
    ///
    /// - Parameter issueRequest: The issue creation payload.
    /// - Returns: The created issue's key and ID.
    /// - Throws: `JiraClientError` on failure.
    func createIssue(_ issueRequest: CreateIssueRequest) async throws -> CreateIssueResponse {
        var request = try buildRequest(
            method: "POST",
            path: "/rest/api/2/issue"
        )

        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(issueRequest)

        return try await perform(request)
    }

    // MARK: - Private Helpers

    /// Builds a URLRequest with the correct base URL, headers, and authentication.
    private func buildRequest(method: String, path: String) throws -> URLRequest {
        let baseURL = appSettings.baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard !baseURL.isEmpty, let url = URL(string: "\(baseURL)\(path)") else {
            throw JiraClientError.invalidURL
        }

        guard let pat = keychainService.readPAT(), !pat.isEmpty else {
            throw JiraClientError.missingCredentials
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(pat)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 15

        Logger.network.info("🔗 \(method) \(url.absoluteString)")

        return request
    }

    /// Performs a URL request and decodes the response.
    private func perform<T: Decodable>(_ request: URLRequest) async throws -> T {
        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await session.data(for: request)
        } catch let urlError as URLError {
            throw JiraClientError.networkUnavailable(underlying: urlError)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw JiraClientError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200...299:
            Logger.network.info("✅ HTTP \(httpResponse.statusCode) — success")
            let decoder = JSONDecoder()
            do {
                return try decoder.decode(T.self, from: data)
            } catch {
                Logger.network.error("❌ JSON decode failed: \(error.localizedDescription)")
                Logger.network.error("📄 Response body: \(String(data: data, encoding: .utf8) ?? "<binary>")")
                throw JiraClientError.decodingFailed(underlying: error)
            }

        case 401:
            Logger.network.error("❌ HTTP 401 — Unauthorized")
            throw JiraClientError.unauthorized

        case 403:
            Logger.network.error("❌ HTTP 403 — Forbidden")
            throw JiraClientError.forbidden

        case 404:
            Logger.network.error("❌ HTTP 404 — Not Found")
            throw JiraClientError.notFound

        default:
            // Try to decode Jira's error response for a meaningful message
            let errorMessage: String
            if let jiraError = try? JSONDecoder().decode(JiraErrorResponse.self, from: data) {
                errorMessage = jiraError.combinedMessage
            } else {
                errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            }
            Logger.network.error("❌ HTTP \(httpResponse.statusCode) — \(errorMessage)")
            throw JiraClientError.serverError(
                statusCode: httpResponse.statusCode,
                message: errorMessage
            )
        }
    }
}

// MARK: - Errors

/// Errors specific to the Jira API client.
enum JiraClientError: LocalizedError {
    case invalidURL
    case missingCredentials
    case networkUnavailable(underlying: URLError)
    case invalidResponse
    case unauthorized
    case forbidden
    case notFound
    case decodingFailed(underlying: Error)
    case serverError(statusCode: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return String(localized: "jira_error_invalid_url",
                         defaultValue: "Invalid Jira URL. Please check your settings.")
        case .missingCredentials:
            return String(localized: "jira_error_missing_credentials",
                         defaultValue: "No PAT found. Please configure your Jira credentials.")
        case .networkUnavailable(let error):
            return String(localized: "jira_error_network",
                         defaultValue: "Network unavailable: \(error.localizedDescription)")
        case .invalidResponse:
            return String(localized: "jira_error_invalid_response",
                         defaultValue: "Received an invalid response from Jira.")
        case .unauthorized:
            return String(localized: "jira_error_unauthorized",
                         defaultValue: "Authentication failed. Please check your PAT.")
        case .forbidden:
            return String(localized: "jira_error_forbidden",
                         defaultValue: "Access denied. You don't have permission for this operation.")
        case .notFound:
            return String(localized: "jira_error_not_found",
                         defaultValue: "The requested Jira resource was not found.")
        case .decodingFailed:
            return String(localized: "jira_error_decoding",
                         defaultValue: "Failed to parse the Jira response.")
        case .serverError(let code, let message):
            return String(localized: "jira_error_server",
                         defaultValue: "Jira server error (\(code)): \(message)")
        }
    }

    /// Whether this error is due to a network issue (eligible for retry).
    var isRetryable: Bool {
        switch self {
        case .networkUnavailable: return true
        case .serverError(let code, _): return code >= 500
        default: return false
        }
    }
}
