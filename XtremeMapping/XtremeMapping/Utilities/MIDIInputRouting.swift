import Foundation

/// Identity supplied by CoreMIDI for the source endpoint that produced a message.
/// A name is useful for selecting a route; only `uniqueID` is trusted after the
/// route has been selected.
nonisolated struct MIDIEndpointIdentity: Hashable, Sendable {
    let uniqueID: Int32?
    let name: String
    let displayName: String

    init(uniqueID: Int32?, name: String, displayName: String? = nil) {
        self.uniqueID = uniqueID
        self.name = name
        self.displayName = displayName ?? name
    }
}

/// The immutable source route owned by one MIDI listener registration.
nonisolated enum MIDIInputRoute: Equatable, Sendable {
    case allSources
    case specificSource(MIDIEndpointIdentity)

    func accepts(_ source: MIDIEndpointIdentity?) -> Bool {
        switch self {
        case .allSources:
            return true
        case .specificSource(let expected):
            guard let expectedID = expected.uniqueID,
                  let sourceID = source?.uniqueID else { return false }
            return sourceID == expectedID
        }
    }
}

nonisolated enum MIDIInputRouteResolution: Equatable, Sendable {
    case resolved(MIDIInputRoute)
    case unavailable
    case ambiguous

    var route: MIDIInputRoute? {
        guard case .resolved(let route) = self else { return nil }
        return route
    }
}

/// Resolves a saved Traktor input-port name once, then reconnects by stable
/// endpoint identity. This prevents a same-named controller from taking over a
/// capture when the originally selected controller is unplugged.
nonisolated enum MIDIInputRouteResolver {
    static func resolve(
        desiredInputPort: String?,
        requireSpecificSource: Bool,
        desiredSourceID: Int32? = nil,
        availableSources: [MIDIEndpointIdentity]
    ) -> MIDIInputRouteResolution {
        if let desiredSourceID {
            let matches = availableSources.filter { $0.uniqueID == desiredSourceID }
            guard matches.count == 1 else { return .unavailable }
            return .resolved(.specificSource(matches[0]))
        }

        let desiredName = desiredInputPort?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let requestsAllSources = desiredName == nil
            || desiredName?.isEmpty == true
            || desiredName == "All Ports"

        if requestsAllSources {
            return requireSpecificSource ? .unavailable : .resolved(.allSources)
        }

        let matches = availableSources.filter { $0.name == desiredName }
        guard matches.count <= 1 else { return .ambiguous }
        guard let match = matches.first, match.uniqueID != nil else {
            return .unavailable
        }
        return .resolved(.specificSource(match))
    }

    static func reconnect(
        pinnedRoute: MIDIInputRoute,
        availableSources: [MIDIEndpointIdentity]
    ) -> MIDIInputRouteResolution {
        switch pinnedRoute {
        case .allSources:
            return .resolved(.allSources)
        case .specificSource(let pinned):
            guard let pinnedID = pinned.uniqueID else { return .unavailable }
            let matches = availableSources.filter { $0.uniqueID == pinnedID }
            guard matches.count == 1 else { return .unavailable }
            return .resolved(.specificSource(matches[0]))
        }
    }
}

/// Drops callbacks queued by CoreMIDI before a disconnect. Reconnection gets a
/// new token even when it targets the same physical endpoint.
nonisolated struct MIDIConnectionDeliveryGate {
    private(set) var activeTokens: Set<UUID> = []

    mutating func activate(_ token: UUID) {
        activeTokens.insert(token)
    }

    mutating func disconnectAll() {
        activeTokens.removeAll()
    }

    func accepts(_ token: UUID) -> Bool {
        activeTokens.contains(token)
    }
}

/// Small session boundary used by wizard and voice workflows. The adapter owns
/// a manager lease, so routing and cleanup belong to the same capture owner.
@MainActor
protocol MIDICaptureListening: AnyObject {
    var onSetupChanged: (() -> Void)? { get set }

    func start(
        desiredInputPort: String?,
        requireSpecificSource: Bool,
        desiredSourceID: Int32?,
        onMIDIReceived: @escaping (MIDIMessage) -> Void
    ) -> Bool

    func stop()
}

@MainActor
final class MIDILeaseCaptureListener: MIDICaptureListening {
    private let manager: MIDIInputManager
    private var lease: MIDIInputManager.ListeningLease?
    private var setupChangedCallback: (() -> Void)?

    var onSetupChanged: (() -> Void)? {
        get { setupChangedCallback }
        set {
            setupChangedCallback = newValue
            if let lease, manager.ownsListeningLease(lease) {
                manager.setSetupChangedHandler(newValue, for: lease)
            }
        }
    }

    init(manager: MIDIInputManager) {
        self.manager = manager
    }

    func start(
        desiredInputPort: String?,
        requireSpecificSource: Bool,
        desiredSourceID: Int32?,
        onMIDIReceived: @escaping (MIDIMessage) -> Void
    ) -> Bool {
        stop()
        lease = manager.acquireListeningLease(
            desiredInputPort: desiredInputPort,
            requireSpecificSource: requireSpecificSource,
            desiredSourceID: desiredSourceID,
            onMIDIReceived: onMIDIReceived
        )
        if let lease {
            manager.setSetupChangedHandler(setupChangedCallback, for: lease)
        }
        return lease != nil
    }

    func stop() {
        if let lease, manager.ownsListeningLease(lease) {
            manager.releaseListeningLease(lease)
        }
        lease = nil
    }
}
