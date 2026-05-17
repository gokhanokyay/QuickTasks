import XCTest
@testable import QuickTasks

/// Unit tests for KeychainService — verifies save, read, delete, and update operations.
final class KeychainServiceTests: XCTestCase {
    let service = KeychainService()

    override func tearDown() {
        // Clean up any test data from the Keychain
        try? service.deletePAT()
        super.tearDown()
    }

    // MARK: - Save & Read

    func testSaveAndReadPAT() throws {
        try service.savePAT("test-token-12345")
        let retrieved = service.readPAT()
        XCTAssertEqual(retrieved, "test-token-12345")
    }

    func testReadReturnsNilWhenEmpty() {
        try? service.deletePAT()
        let result = service.readPAT()
        XCTAssertNil(result)
    }

    // MARK: - Update

    func testUpdateOverwritesExisting() throws {
        try service.savePAT("old-token")
        try service.savePAT("new-token")
        let retrieved = service.readPAT()
        XCTAssertEqual(retrieved, "new-token")
    }

    // MARK: - Delete

    func testDeleteRemovesPAT() throws {
        try service.savePAT("token-to-delete")
        try service.deletePAT()
        let result = service.readPAT()
        XCTAssertNil(result)
    }

    func testDeleteWhenNotExistingDoesNotThrow() {
        try? service.deletePAT() // ensure clean
        XCTAssertNoThrow(try service.deletePAT())
    }

    // MARK: - Edge Cases

    func testSaveEmptyString() throws {
        try service.savePAT("")
        let retrieved = service.readPAT()
        XCTAssertEqual(retrieved, "")
    }

    func testSaveLongToken() throws {
        let longToken = String(repeating: "a", count: 1000)
        try service.savePAT(longToken)
        let retrieved = service.readPAT()
        XCTAssertEqual(retrieved, longToken)
    }

    func testSaveSpecialCharacters() throws {
        let token = "pat_123+/=!@#$%^&*()"
        try service.savePAT(token)
        let retrieved = service.readPAT()
        XCTAssertEqual(retrieved, token)
    }
}
