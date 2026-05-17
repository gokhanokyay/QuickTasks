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
    private static let key = "jira_pat_token_local"

    func savePAT(_ token: String) throws {
        UserDefaults.standard.set(token, forKey: Self.key)
        UserDefaults.standard.synchronize()
    }

    func readPAT() -> String? {
        return UserDefaults.standard.string(forKey: Self.key)
    }

    func deletePAT() throws {
        UserDefaults.standard.removeObject(forKey: Self.key)
        UserDefaults.standard.synchronize()
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
