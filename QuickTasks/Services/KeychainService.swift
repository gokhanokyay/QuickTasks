import Foundation
import Security

/// A service for securely storing and retrieving the Jira Personal Access Token (PAT)
/// using the native macOS Keychain.
///
/// The PAT is stored as a generic password with a fixed service identifier
/// and account name, using hardware-backed encryption provided by the Keychain.
///
/// ## Usage
/// ```swift
/// let keychain = KeychainService()
/// try keychain.savePAT("my-secret-token")
/// let token = keychain.readPAT()
/// ```
struct KeychainService: Sendable {

    // MARK: - Constants

    private static let service = "com.malidyatech.QuickTasks"
    private static let account = "jira-pat"

    // MARK: - Public API

    /// Saves the Jira PAT to the macOS Keychain.
    ///
    /// If a PAT already exists, it is updated in place.
    /// - Parameter token: The Personal Access Token to store.
    /// - Throws: `KeychainError` if the save or update operation fails.
    func savePAT(_ token: String) throws {
        guard let data = token.data(using: .utf8) else {
            throw KeychainError.encodingFailed
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.service,
            kSecAttrAccount as String: Self.account,
        ]

        // Try to update first
        let updateAttributes: [String: Any] = [
            kSecValueData as String: data,
        ]

        let updateStatus = SecItemUpdate(query as CFDictionary, updateAttributes as CFDictionary)

        if updateStatus == errSecItemNotFound {
            // Item doesn't exist yet — add it
            var addQuery = query
            addQuery[kSecValueData as String] = data
            let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw KeychainError.saveFailed(status: addStatus)
            }
        } else if updateStatus != errSecSuccess {
            throw KeychainError.saveFailed(status: updateStatus)
        }
    }

    /// Reads the Jira PAT from the macOS Keychain.
    ///
    /// - Returns: The stored PAT string, or `nil` if no PAT has been saved yet.
    func readPAT() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.service,
            kSecAttrAccount as String: Self.account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess, let data = result as? Data else {
            return nil
        }

        return String(data: data, encoding: .utf8)
    }

    /// Deletes the Jira PAT from the macOS Keychain.
    ///
    /// - Throws: `KeychainError` if the delete fails (ignores "item not found").
    func deletePAT() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.service,
            kSecAttrAccount as String: Self.account,
        ]

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.deleteFailed(status: status)
        }
    }
}

// MARK: - Errors

/// Errors that can occur during Keychain operations.
enum KeychainError: LocalizedError {
    case encodingFailed
    case saveFailed(status: OSStatus)
    case deleteFailed(status: OSStatus)

    var errorDescription: String? {
        switch self {
        case .encodingFailed:
            return "Failed to encode the token as UTF-8 data."
        case .saveFailed(let status):
            return "Keychain save failed with status: \(status)"
        case .deleteFailed(let status):
            return "Keychain delete failed with status: \(status)"
        }
    }
}
