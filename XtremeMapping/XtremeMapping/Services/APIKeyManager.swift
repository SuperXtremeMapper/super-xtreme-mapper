//
//  APIKeyManager.swift
//  XtremeMapping
//
//  Manages API key storage and retrieval using macOS Keychain.
//

import Foundation
import Security
import Combine

/// Manages API key storage using macOS Keychain for secure credential handling.
///
/// The APIKeyManager provides a secure way to store, retrieve, and manage
/// the user's Anthropic API key. Keys are stored in the macOS Keychain,
/// which provides encryption at rest and integration with system security.
///
/// Usage:
/// ```swift
/// // Save a key
/// APIKeyManager.shared.saveAPIKey("sk-ant-...")
///
/// // Get the active key
/// if let key = APIKeyManager.shared.activeKey {
///     // Use the key
/// }
///
/// // Delete the key
/// APIKeyManager.shared.deleteAPIKey()
/// ```
final class APIKeyManager: ObservableObject {

    // MARK: - Singleton

    /// Shared instance for app-wide access
    static let shared = APIKeyManager()

    // MARK: - Keychain Configuration

    /// Service identifier for Keychain storage
    private static let serviceName = "com.xtrememapping.apikey"

    /// Account name for the API key entry
    private static let accountName = "anthropic"

    // MARK: - Published Properties

    /// The user's stored API key, loaded from Keychain
    @Published private(set) var userAPIKey: String?

    // MARK: - Computed Properties

    /// Returns the active API key to use for requests.
    ///
    /// Currently returns only the user's own key. This design allows
    /// for future expansion (e.g., built-in keys, team keys).
    var activeKey: String? {
        userAPIKey
    }

    /// Returns whether a valid API key is configured.
    var hasAPIKey: Bool {
        guard let key = activeKey else { return false }
        return !key.isEmpty
    }

    /// Validates that an API key has the expected format.
    ///
    /// Anthropic API keys typically start with "sk-ant-" and are
    /// at least 40 characters long. This is a basic format check,
    /// not a verification that the key is actually valid.
    ///
    /// - Parameter key: The API key to validate
    /// - Returns: `true` if the key appears to be valid format
    static func isValidKeyFormat(_ key: String) -> Bool {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        // Anthropic keys start with "sk-ant-" and are typically 100+ chars
        return trimmed.hasPrefix("sk-ant-") && trimmed.count >= 40
    }

    // MARK: - Initialization

    private init() {
        // Load any existing key from Keychain on initialization
        userAPIKey = loadAPIKey()
    }

    // MARK: - Public API

    /// Saves an API key to the Keychain.
    ///
    /// If a key already exists, it will be updated. The key is stored
    /// securely in the macOS Keychain.
    ///
    /// - Parameter key: The API key to save
    /// - Returns: `true` if the save was successful
    @discardableResult
    func saveAPIKey(_ key: String) -> Bool {
        let trimmedKey = key.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedKey.isEmpty else {
            return false
        }

        // Try to update existing key first
        if userAPIKey != nil {
            if updateKeychainItem(trimmedKey) {
                userAPIKey = trimmedKey
                return true
            }
        }

        // Add new key if update failed or no existing key
        if addKeychainItem(trimmedKey) {
            userAPIKey = trimmedKey
            return true
        }

        return false
    }

    /// Loads the API key from the Keychain.
    ///
    /// - Returns: The stored API key, or nil if not found
    func loadAPIKey() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.serviceName,
            kSecAttrAccount as String: Self.accountName,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let key = String(data: data, encoding: .utf8) else {
            return nil
        }

        return key
    }

    /// Deletes the API key from the Keychain.
    ///
    /// After deletion, `userAPIKey` and `activeKey` will return nil.
    ///
    /// - Returns: `true` if deletion was successful or key didn't exist
    @discardableResult
    func deleteAPIKey() -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.serviceName,
            kSecAttrAccount as String: Self.accountName
        ]

        let status = SecItemDelete(query as CFDictionary)

        // Success if deleted or didn't exist
        if status == errSecSuccess || status == errSecItemNotFound {
            userAPIKey = nil
            return true
        }

        return false
    }

    // MARK: - Private Keychain Methods

    /// Adds a new API key to the Keychain.
    private func addKeychainItem(_ key: String) -> Bool {
        guard let data = key.data(using: .utf8) else { return false }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.serviceName,
            kSecAttrAccount as String: Self.accountName,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
        ]

        // Delete any existing item first to avoid duplicates
        SecItemDelete(query as CFDictionary)

        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }

    /// Updates an existing API key in the Keychain.
    private func updateKeychainItem(_ key: String) -> Bool {
        guard let data = key.data(using: .utf8) else { return false }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.serviceName,
            kSecAttrAccount as String: Self.accountName
        ]

        let attributes: [String: Any] = [
            kSecValueData as String: data
        ]

        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        return status == errSecSuccess
    }
}
