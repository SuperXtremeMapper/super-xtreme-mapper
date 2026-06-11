//
//  KeySnapshotStore.swift
//  XtremeMapping
//
//  Lock-backed snapshot of the API key, readable synchronously from any
//  thread. No Keychain dependency — APIKeyManager composes this so its
//  synchronous `activeKey` provider closure works from nonisolated code
//  while the @Published mirror stays on the main actor.
//

import Foundation

/// Thread-safe snapshot store for the active API key.
///
/// `write(_:)` makes the new value immediately visible to subsequent
/// `read()` calls on any thread — callers never race a main-queue hop.
final class KeySnapshotStore: @unchecked Sendable {

    private let lock = NSLock()
    private var value: String?

    /// Replaces the stored value. Visible to `read()` immediately.
    func write(_ newValue: String?) {
        lock.lock()
        defer { lock.unlock() }
        value = newValue
    }

    /// Returns the current value. Safe from any thread.
    func read() -> String? {
        lock.lock()
        defer { lock.unlock() }
        return value
    }
}
