import XCTest
@testable import QuickTasks

/// Tests for Jira DTO Codable models.
final class JiraDTOTests: XCTestCase {

    func testCreateIssueRequestEncodesCorrectly() throws {
        let request = CreateIssueRequest(
            fields: .init(
                project: .init(key: "PROJ"),
                summary: "Fix login bug",
                issuetype: .init(name: "Bug"),
                assignee: .init(name: "john.doe"),
                description: nil
            )
        )
        let data = try JSONEncoder().encode(request)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        let fields = json["fields"] as! [String: Any]

        XCTAssertEqual((fields["project"] as! [String: String])["key"], "PROJ")
        XCTAssertEqual(fields["summary"] as! String, "Fix login bug")
        XCTAssertEqual((fields["issuetype"] as! [String: String])["name"], "Bug")
        XCTAssertEqual((fields["assignee"] as! [String: String])["name"], "john.doe")
    }

    func testNilAssigneeNotInJSON() throws {
        let request = CreateIssueRequest(
            fields: .init(project: .init(key: "P"), summary: "T", issuetype: .init(name: "Task"), assignee: nil, description: nil)
        )
        let data = try JSONEncoder().encode(request)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        let fields = json["fields"] as! [String: Any]
        XCTAssertNil(fields["assignee"])
    }

    func testCreateIssueResponseDecodes() throws {
        let json = #"{"id":"10001","key":"PROJ-123","self":"https://jira.test.com/rest/api/2/issue/10001"}"#
        let response = try JSONDecoder().decode(CreateIssueResponse.self, from: json.data(using: .utf8)!)
        XCTAssertEqual(response.key, "PROJ-123")
    }

    func testMyselfResponseDecodes() throws {
        let json = #"{"name":"john.doe","displayName":"John Doe","emailAddress":"j@d.com"}"#
        let response = try JSONDecoder().decode(JiraMyselfResponse.self, from: json.data(using: .utf8)!)
        XCTAssertEqual(response.name, "john.doe")
    }

    func testErrorResponseCombinesMessages() throws {
        let json = #"{"errorMessages":["Field required"],"errors":{"summary":"empty"}}"#
        let response = try JSONDecoder().decode(JiraErrorResponse.self, from: json.data(using: .utf8)!)
        XCTAssertTrue(response.combinedMessage.contains("Field required"))
    }
}
