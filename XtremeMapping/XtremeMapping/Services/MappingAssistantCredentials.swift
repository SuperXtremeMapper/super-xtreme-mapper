import Foundation
import Combine

/// Keychain access is deferred until an explicit AI action. Local guides never read credentials.
@MainActor
final class MappingAssistantCredentials: ObservableObject {
    @Published private(set) var hasKey = false
    let store = KeySnapshotStore()
    private let provider: @MainActor () -> String?

    init(provider: @escaping @MainActor () -> String? = { APIKeyManager.shared.activeKey }) {
        self.provider = provider
    }

    func refresh() {
        let key = provider()
        store.write(key)
        hasKey = !(key?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
    }

    func clear() {
        store.write(nil)
        hasKey = false
    }
}
