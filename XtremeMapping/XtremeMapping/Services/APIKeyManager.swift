//
//  APIKeyManager.swift
//  XtremeMapping
//
//  Manages API key storage and retrieval using macOS Keychain.
//

import Foundation
import Security
import Combine
import os

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

    /// Logger for Keychain status reporting
    private static let logger = Logger(subsystem: "com.sxm.app", category: "APIKeyManager")

    // MARK: - Key Storage

    /// Lock-backed snapshot of the current key, readable synchronously from
    /// any thread. This is the source of truth for `activeKey`; the
    /// @Published property below is a main-thread mirror for UI observation.
    private let snapshot = KeySnapshotStore()

    // MARK: - Published Properties

    /// The user's stored API key — main-thread mirror of the snapshot,
    /// for SwiftUI observation only. Reads from background contexts must
    /// go through `activeKey`.
    @Published private(set) var userAPIKey: String?

    // MARK: - Computed Properties

    /// Returns the active API key to use for requests.
    ///
    /// Reads the lock-backed snapshot, so it is safe to call synchronously
    /// from any thread (e.g. ClaudeAPIService's nonisolated key provider).
    var activeKey: String? {
        snapshot.read()
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
        let key = loadAPIKey()
        snapshot.write(key)
        userAPIKey = key
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
        if snapshot.read() != nil {
            if updateKeychainItem(trimmedKey) {
                storeKey(trimmedKey)
                return true
            }
        }

        // Add new key if update failed or no existing key
        if addKeychainItem(trimmedKey) {
            storeKey(trimmedKey)
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
            if status != errSecSuccess && status != errSecItemNotFound {
                Self.logger.error("Keychain load failed: OSStatus \(status)")
            }
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
            storeKey(nil)
            return true
        }

        Self.logger.error("Keychain delete failed: OSStatus \(status)")
        return false
    }

    // MARK: - Private Storage Helpers

    /// Writes the key to the lock-backed snapshot (immediately visible to
    /// `activeKey` on any thread), then mirrors it to the @Published
    /// property on the main thread for UI observation.
    private func storeKey(_ key: String?) {
        snapshot.write(key)
        if Thread.isMainThread {
            userAPIKey = key
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.userAPIKey = key
            }
        }
    }

    // MARK: - Private Keychain Methods

    /// Adds a new API key to the Keychain.
    private func addKeychainItem(_ key: String) -> Bool {
        guard let data = key.data(using: .utf8) else { return false }

        // Delete any existing item first to avoid duplicates. The delete
        // query must be search-only (class/service/account) — passing the
        // add query (with kSecValueData/kSecAttrAccessible) can errSecParam,
        // leaving a stale item that makes SecItemAdd errSecDuplicateItem.
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.serviceName,
            kSecAttrAccount as String: Self.accountName
        ]
        let deleteStatus = SecItemDelete(deleteQuery as CFDictionary)
        if deleteStatus != errSecSuccess && deleteStatus != errSecItemNotFound {
            Self.logger.error("Keychain pre-add delete failed: OSStatus \(deleteStatus)")
        }

        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.serviceName,
            kSecAttrAccount as String: Self.accountName,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
        ]

        let status = SecItemAdd(addQuery as CFDictionary, nil)
        if status != errSecSuccess {
            Self.logger.error("Keychain add failed: OSStatus \(status)")
        }
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
        if status != errSecSuccess && status != errSecItemNotFound {
            Self.logger.error("Keychain update failed: OSStatus \(status)")
        }
        return status == errSecSuccess
    }
}
