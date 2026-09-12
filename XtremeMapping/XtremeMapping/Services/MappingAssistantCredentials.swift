import Foundation
import Combine

/// Keychain access is deferred until an explicit AI action. Local guides never read credentials.
@MainActor
final class MappingAssistantCredentials: ObservableObject {
    @Published private(set) var hasKey = false
    @Published private(set) var isLoading = false
    let store = KeySnapshotStore()
    private let provider: @MainActor () -> String?
    private let asyncProvider: @Sendable () async -> String?
    private var generation = UUID()

    init(provider: (@MainActor () -> String?)? = nil) {
        self.provider = provider ?? { APIKeyManager.shared.activeKey }
        if let provider {
            asyncProvider = { await provider() }
        } else {
            // Keychain may wait for a macOS authorization dialog. Keep that wait
            // off the UI thread, so the user can still close/cancel the session.
            asyncProvider = { await Task.detached { APIKeyManager.loadStoredAPIKey() }.value }
        }
    }

    init(asyncProvider: @escaping @Sendable () async -> String?) {
        provider = { nil }
        self.asyncProvider = asyncProvider
    }

    func refresh() {
        generation = UUID()
        isLoading = false
        publish(provider())
    }

    func refreshAsync() async {
        generation = UUID()
        let request = generation
        isLoading = true
        let key = await asyncProvider()
        guard request == generation else { return }
        isLoading = false
        guard !Task.isCancelled else { return }
        publish(key)
    }

    func clear() {
        generation = UUID()
        isLoading = false
        store.write(nil)
        hasKey = false
    }

    private func publish(_ key: String?) {
        store.write(key)
        hasKey = !(key?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
    }
}
