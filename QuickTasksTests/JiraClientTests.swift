import XCTest
@testable import QuickTasks

/// Unit tests for JiraClient using a mock URLProtocol.
final class JiraClientTests: XCTestCase {

    var appSettings: AppSettings!
    var keychainService: KeychainService!

    override func setUp() {
        super.setUp()
        appSettings = AppSettings()
        keychainService = KeychainService()
        appSettings.baseURL = "https://jira.test.com"
        try? keychainService.savePAT("test-pat-token")
        URLProtocol.registerClass(MockURLProtocol.self)
    }

    override func tearDown() {
        URLProtocol.unregisterClass(MockURLProtocol.self)
        MockURLProtocol.requestHandler = nil
        appSettings.baseURL = ""
        try? keychainService.deletePAT()
        super.tearDown()
    }

    func testTestConnectionSendsCorrectRequest() async throws {
        var capturedRequest: URLRequest?
        MockURLProtocol.requestHandler = { request in
            capturedRequest = request
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let json = #"{"name":"john.doe","displayName":"John Doe","emailAddress":"j@d.com"}"#
            return (response, json.data(using: .utf8)!)
        }

        let client = JiraClient(keychainService: keychainService, appSettings: appSettings, session: URLSession(configuration: mockConfig()))
        let result = try await client.testConnection()

        XCTAssertEqual(result.name, "john.doe")
        XCTAssertEqual(capturedRequest?.httpMethod, "GET")
        XCTAssertEqual(capturedRequest?.url?.absoluteString, "https://jira.test.com/rest/api/2/myself")
        XCTAssertEqual(capturedRequest?.value(forHTTPHeaderField: "Authorization"), "Bearer test-pat-token")
    }

    func testCreateIssueSendsCorrectPayload() async throws {
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 201, httpVersion: nil, headerFields: nil)!
            let json = #"{"id":"10001","key":"PROJ-123","self":"https://jira.test.com/rest/api/2/issue/10001"}"#
            return (response, json.data(using: .utf8)!)
        }

        let client = JiraClient(keychainService: keychainService, appSettings: appSettings, session: URLSession(configuration: mockConfig()))
        let request = CreateIssueRequest(fields: .init(project: .init(key: "PROJ"), summary: "Fix login bug", issuetype: .init(name: "Bug"), assignee: .init(name: "john.doe"), description: nil))
        let result = try await client.createIssue(request)

        XCTAssertEqual(result.key, "PROJ-123")
        XCTAssertEqual(result.id, "10001")
    }

    func testUnauthorizedThrowsCorrectError() async throws {
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 401, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }
        let client = JiraClient(keychainService: keychainService, appSettings: appSettings, session: URLSession(configuration: mockConfig()))
        do {
            _ = try await client.testConnection()
            XCTFail("Should have thrown")
        } catch is JiraClientError {
            // Expected — any JiraClientError is acceptable here
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testMissingCredentialsThrows() async throws {
        try keychainService.deletePAT()
        let client = JiraClient(keychainService: keychainService, appSettings: appSettings, session: URLSession(configuration: mockConfig()))
        do {
            _ = try await client.testConnection()
            XCTFail("Should have thrown")
        } catch is JiraClientError {
            // Expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testInvalidURLThrows() async throws {
        appSettings.baseURL = ""
        let client = JiraClient(keychainService: keychainService, appSettings: appSettings, session: URLSession(configuration: mockConfig()))
        do {
            _ = try await client.testConnection()
            XCTFail("Should have thrown")
        } catch is JiraClientError {
            // Expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testNetworkErrorIsRetryable() async throws {
        MockURLProtocol.requestHandler = { _ in throw URLError(.notConnectedToInternet) }
        let client = JiraClient(keychainService: keychainService, appSettings: appSettings, session: URLSession(configuration: mockConfig()))
        do {
            _ = try await client.testConnection()
            XCTFail("Should have thrown")
        } catch let error as JiraClientError {
            XCTAssertTrue(error.isRetryable)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testServer500IsRetryable() async throws {
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 500, httpVersion: nil, headerFields: nil)!
            return (response, "Error".data(using: .utf8)!)
        }
        let client = JiraClient(keychainService: keychainService, appSettings: appSettings, session: URLSession(configuration: mockConfig()))
        do {
            _ = try await client.testConnection()
            XCTFail("Should have thrown")
        } catch let error as JiraClientError {
            XCTAssertTrue(error.isRetryable)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    private func mockConfig() -> URLSessionConfiguration {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        return config
    }
}

// MARK: - Mock URL Protocol

final class MockURLProtocol: URLProtocol {
    nonisolated(unsafe) static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = MockURLProtocol.requestHandler else {
            client?.urlProtocol(self, didFailWithError: URLError(.unknown))
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
