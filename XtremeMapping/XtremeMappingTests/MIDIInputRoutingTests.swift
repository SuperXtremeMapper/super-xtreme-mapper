import XCTest
@testable import XtremeMapping

@MainActor
final class MIDIInputRoutingTests: XCTestCase {
    private let controllerA = MIDIEndpointIdentity(uniqueID: 101, name: "XONE:K3")
    private let controllerB = MIDIEndpointIdentity(uniqueID: 202, name: "XONE:K3")

    func testSpecificLeaseDeliversSameAddressOnlyFromResolvedEndpoint() throws {
        let route = try XCTUnwrap(
            MIDIInputRouteResolver.resolve(
                desiredInputPort: "XONE:K3",
                requireSpecificSource: true,
                availableSources: [controllerA]
            ).route
        )
        var received: [MIDIMessage] = []
        var ownership = MIDIInputManager.ListenerOwnership()
        let lease = try XCTUnwrap(ownership.acquire(route: route) { received.append($0) })
        XCTAssertTrue(ownership.startLeasedListening(using: lease))

        let fromA = MIDIMessage(
            channel: 1,
            note: nil,
            cc: 16,
            value: 64,
            source: controllerA
        )
        let fromB = MIDIMessage(
            channel: 1,
            note: nil,
            cc: 16,
            value: 64,
            source: controllerB
        )
        ownership.deliver(fromB)
        ownership.deliver(fromA)

        XCTAssertEqual(received, [fromA])
        XCTAssertTrue(ownership.owns(lease))
    }

    func testRequiredSpecificRouteIsUnavailableWhenPortIsMissing() {
        let resolution = MIDIInputRouteResolver.resolve(
            desiredInputPort: "Missing Controller",
            requireSpecificSource: true,
            availableSources: [controllerA]
        )

        XCTAssertEqual(resolution, .unavailable)
    }

    func testRequiredSpecificRouteFailsClosedForDuplicateSourceNames() {
        let resolution = MIDIInputRouteResolver.resolve(
            desiredInputPort: "XONE:K3",
            requireSpecificSource: true,
            availableSources: [controllerA, controllerB]
        )

        XCTAssertEqual(resolution, .ambiguous)
    }

    func testExplicitSourceIDSelectsOneOfTwoSameNamedEndpoints() {
        let resolution = MIDIInputRouteResolver.resolve(
            desiredInputPort: "XONE:K3",
            requireSpecificSource: true,
            desiredSourceID: controllerB.uniqueID,
            availableSources: [controllerA, controllerB]
        )

        XCTAssertEqual(resolution, .resolved(.specificSource(controllerB)))
    }

    func testMissingExplicitSourceIDNeverFallsBackToMatchingName() {
        let resolution = MIDIInputRouteResolver.resolve(
            desiredInputPort: "XONE:K3",
            requireSpecificSource: true,
            desiredSourceID: 303,
            availableSources: [controllerA]
        )

        XCTAssertEqual(resolution, .unavailable)
    }

    func testRequiredSpecificRouteRejectsSourceWithoutStableIdentity() {
        let resolution = MIDIInputRouteResolver.resolve(
            desiredInputPort: "XONE:K3",
            requireSpecificSource: true,
            availableSources: [MIDIEndpointIdentity(uniqueID: nil, name: "XONE:K3")]
        )

        XCTAssertEqual(resolution, .unavailable)
    }

    func testOptionalAllPortsRouteDeliberatelyAcceptsEveryIdentifiedSource() throws {
        let route = try XCTUnwrap(
            MIDIInputRouteResolver.resolve(
                desiredInputPort: "All Ports",
                requireSpecificSource: false,
                availableSources: [controllerA, controllerB]
            ).route
        )

        XCTAssertEqual(route, .allSources)
        XCTAssertTrue(route.accepts(controllerA))
        XCTAssertTrue(route.accepts(controllerB))
    }

    func testRequiredRouteRejectsAllPortsSentinel() {
        XCTAssertEqual(
            MIDIInputRouteResolver.resolve(
                desiredInputPort: "All Ports",
                requireSpecificSource: true,
                availableSources: [controllerA]
            ),
            .unavailable
        )
    }

    func testReconnectDoesNotSubstituteSameNamedDifferentEndpoint() throws {
        let pinnedRoute = try XCTUnwrap(
            MIDIInputRouteResolver.resolve(
                desiredInputPort: "XONE:K3",
                requireSpecificSource: true,
                availableSources: [controllerA]
            ).route
        )

        XCTAssertEqual(
            MIDIInputRouteResolver.reconnect(
                pinnedRoute: pinnedRoute,
                availableSources: [controllerB]
            ),
            .unavailable
        )
    }

    func testReconnectUsesPinnedIdentityAfterTemporaryAbsence() throws {
        let pinnedRoute = try XCTUnwrap(
            MIDIInputRouteResolver.resolve(
                desiredInputPort: "XONE:K3",
                requireSpecificSource: true,
                availableSources: [controllerA]
            ).route
        )

        XCTAssertEqual(
            MIDIInputRouteResolver.reconnect(
                pinnedRoute: pinnedRoute,
                availableSources: [controllerA, controllerB]
            ),
            .resolved(.specificSource(controllerA))
        )
    }

    func testTemporaryRouteLossDoesNotReleaseLeaseOwnership() throws {
        var ownership = MIDIInputManager.ListenerOwnership()
        let route = MIDIInputRoute.specificSource(controllerA)
        let lease = try XCTUnwrap(ownership.acquire(route: route) { _ in })
        XCTAssertTrue(ownership.startLeasedListening(using: lease))

        let reconnect = MIDIInputRouteResolver.reconnect(
            pinnedRoute: route,
            availableSources: []
        )

        XCTAssertEqual(reconnect, .unavailable)
        XCTAssertTrue(ownership.owns(lease))
    }

    func testQueuedEventTokenIsRejectedAfterDisconnectAndReconnect() {
        let oldConnection = UUID()
        let newConnection = UUID()
        var gate = MIDIConnectionDeliveryGate()
        gate.activate(oldConnection)
        XCTAssertTrue(gate.accepts(oldConnection))

        gate.disconnectAll()
        gate.activate(newConnection)

        XCTAssertFalse(gate.accepts(oldConnection))
        XCTAssertTrue(gate.accepts(newConnection))
    }

    func testSetupChangeCallbackBelongsToLeaseAndStaleLeaseCannotReplaceIt() throws {
        var ownership = MIDIInputManager.ListenerOwnership()
        let activeLease = try XCTUnwrap(ownership.acquire { _ in })
        XCTAssertTrue(ownership.startLeasedListening(using: activeLease))
        var callbacks: [String] = []
        XCTAssertTrue(
            ownership.setSetupChangedCallback(
                { callbacks.append("active") },
                for: activeLease
            )
        )

        var staleOwnership = MIDIInputManager.ListenerOwnership()
        let staleLease = try XCTUnwrap(staleOwnership.acquire { _ in })
        XCTAssertFalse(
            ownership.setSetupChangedCallback(
                { callbacks.append("stale") },
                for: staleLease
            )
        )
        ownership.deliverSetupChange()

        XCTAssertEqual(callbacks, ["active"])
    }

    func testFailedContendingCaptureCannotClearActiveSetupCallback() {
        let active = MIDILeaseCaptureListener(manager: .shared)
        let contender = MIDILeaseCaptureListener(manager: .shared)
        defer { active.stop(); contender.stop() }
        var callbacks: [String] = []
        active.onSetupChanged = { callbacks.append("active") }
        XCTAssertTrue(
            active.start(
                desiredInputPort: nil,
                requireSpecificSource: false,
                desiredSourceID: nil,
                onMIDIReceived: { _ in }
            )
        )
        contender.onSetupChanged = { callbacks.append("contender") }

        XCTAssertFalse(
            contender.start(
                desiredInputPort: nil,
                requireSpecificSource: false,
                desiredSourceID: nil,
                onMIDIReceived: { _ in }
            )
        )
        MIDIInputManager.shared.onSetupChanged?()

        XCTAssertEqual(callbacks, ["active"])
    }
}
