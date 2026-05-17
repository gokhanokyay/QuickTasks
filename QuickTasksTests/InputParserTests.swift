import XCTest
@testable import QuickTasks

/// Unit tests for the InputParser — verifies all slash command and mention extraction patterns.
final class InputParserTests: XCTestCase {

    // MARK: - Basic Parsing

    func testPlainTextReturnsAsIs() {
        let result = InputParser.parse("Fix the login page")
        XCTAssertEqual(result.cleanTitle, "Fix the login page")
        XCTAssertNil(result.projectOverride)
        XCTAssertNil(result.issueTypeOverride)
        XCTAssertNil(result.assigneeOverride)
    }

    func testEmptyStringReturnsEmptyTitle() {
        let result = InputParser.parse("")
        XCTAssertEqual(result.cleanTitle, "")
        XCTAssertNil(result.projectOverride)
    }

    func testWhitespaceOnlyReturnsTrimmedEmpty() {
        let result = InputParser.parse("   ")
        XCTAssertEqual(result.cleanTitle, "")
    }

    // MARK: - Project Override

    func testProjectOverrideExtracted() {
        let result = InputParser.parse("Fix login bug /INFRA")
        XCTAssertEqual(result.cleanTitle, "Fix login bug")
        XCTAssertEqual(result.projectOverride, "INFRA")
    }

    func testProjectOverrideAtBeginning() {
        let result = InputParser.parse("/PROJ Fix login bug")
        XCTAssertEqual(result.cleanTitle, "Fix login bug")
        XCTAssertEqual(result.projectOverride, "PROJ")
    }

    func testProjectOverrideInMiddle() {
        let result = InputParser.parse("Fix /MOBILE login bug")
        XCTAssertEqual(result.cleanTitle, "Fix login bug")
        XCTAssertEqual(result.projectOverride, "MOBILE")
    }

    func testProjectKeyMinLength() {
        // Minimum 2 uppercase letters
        let result = InputParser.parse("Fix bug /AB")
        XCTAssertEqual(result.projectOverride, "AB")
    }

    func testProjectKeyMaxLength() {
        // Maximum 10 uppercase letters
        let result = InputParser.parse("Fix bug /ABCDEFGHIJ")
        XCTAssertEqual(result.projectOverride, "ABCDEFGHIJ")
    }

    func testLowercaseProjectNotMatched() {
        // Project keys must be uppercase
        let result = InputParser.parse("Fix bug /infra")
        XCTAssertNil(result.projectOverride)
    }

    // MARK: - Issue Type Override

    func testBugTypeExtracted() {
        let result = InputParser.parse("Login fails /bug")
        XCTAssertEqual(result.cleanTitle, "Login fails")
        XCTAssertEqual(result.issueTypeOverride, "Bug")
    }

    func testStoryTypeExtracted() {
        let result = InputParser.parse("Add dark mode /story")
        XCTAssertEqual(result.issueTypeOverride, "Story")
    }

    func testTaskTypeExtracted() {
        let result = InputParser.parse("Update docs /task")
        XCTAssertEqual(result.issueTypeOverride, "Task")
    }

    func testSubtaskTypeExtracted() {
        let result = InputParser.parse("Write unit tests /subtask")
        XCTAssertEqual(result.issueTypeOverride, "Sub-task")
    }

    func testIssueTypeCaseInsensitive() {
        let result = InputParser.parse("Login fails /BUG")
        XCTAssertEqual(result.issueTypeOverride, "Bug")
    }

    // MARK: - Assignee Override

    func testAssigneeExtracted() {
        let result = InputParser.parse("Fix login @mehmet.yildiz")
        XCTAssertEqual(result.cleanTitle, "Fix login")
        XCTAssertEqual(result.assigneeOverride, "mehmet.yildiz")
    }

    func testAssigneeWithUnderscore() {
        let result = InputParser.parse("Fix login @john_doe")
        XCTAssertEqual(result.assigneeOverride, "john_doe")
    }

    func testAssigneeWithHyphen() {
        let result = InputParser.parse("Fix login @jane-smith")
        XCTAssertEqual(result.assigneeOverride, "jane-smith")
    }

    func testAssigneeAtBeginning() {
        let result = InputParser.parse("@admin Fix login")
        XCTAssertEqual(result.cleanTitle, "Fix login")
        XCTAssertEqual(result.assigneeOverride, "admin")
    }

    // MARK: - Combined Commands

    func testAllOverridesCombined() {
        let result = InputParser.parse("Fix login bug /INFRA /bug @mehmet.yildiz")
        XCTAssertEqual(result.cleanTitle, "Fix login bug")
        XCTAssertEqual(result.projectOverride, "INFRA")
        XCTAssertEqual(result.issueTypeOverride, "Bug")
        XCTAssertEqual(result.assigneeOverride, "mehmet.yildiz")
    }

    func testProjectAndTypeOnly() {
        let result = InputParser.parse("Add dark mode /MOBILE /story")
        XCTAssertEqual(result.cleanTitle, "Add dark mode")
        XCTAssertEqual(result.projectOverride, "MOBILE")
        XCTAssertEqual(result.issueTypeOverride, "Story")
        XCTAssertNil(result.assigneeOverride)
    }

    func testTypeAndAssigneeOnly() {
        let result = InputParser.parse("Fix crash /bug @john.doe")
        XCTAssertEqual(result.cleanTitle, "Fix crash")
        XCTAssertNil(result.projectOverride)
        XCTAssertEqual(result.issueTypeOverride, "Bug")
        XCTAssertEqual(result.assigneeOverride, "john.doe")
    }

    // MARK: - Edge Cases

    func testMultipleSpacesCollapsed() {
        let result = InputParser.parse("Fix   the   bug   /PROJ")
        // After removing /PROJ and collapsing spaces
        XCTAssertFalse(result.cleanTitle.contains("  "), "Should not contain double spaces")
    }

    func testCommandsOnlyNoTitle() {
        let result = InputParser.parse("/PROJ /bug @admin")
        XCTAssertEqual(result.cleanTitle, "")
        XCTAssertEqual(result.projectOverride, "PROJ")
        XCTAssertEqual(result.issueTypeOverride, "Bug")
        XCTAssertEqual(result.assigneeOverride, "admin")
    }
}
