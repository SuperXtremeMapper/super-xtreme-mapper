import XCTest
@testable import XtremeMapping

@MainActor
final class MappingAssistantCredentialsTests: XCTestCase {
    func testClearingDuringAsyncLookupDiscardsLateKey() async {
        let gate = CredentialLookupGate()
        let started = expectation(description: "lookup started")
        let credentials = MappingAssistantCredentials(asyncProvider: {
            started.fulfill()
            await gate.wait()
            return "test-key"
        })
        let lookup = Task { await credentials.refreshAsync() }
        await fulfillment(of: [started], timeout: 2)
        XCTAssertTrue(credentials.isLoading)
        credentials.clear()
        XCTAssertFalse(credentials.isLoading)
        await gate.release()
        await lookup.value
        XCTAssertFalse(credentials.hasKey)
        XCTAssertNil(credentials.store.read())
    }

    func testLocalGuideDoesNotReadCredentialsBeforeExplicitRefresh() {
        var lookups = 0
        let credentials = MappingAssistantCredentials(provider: { lookups += 1; return "test-key" })
        XCTAssertEqual(lookups, 0)
        XCTAssertFalse(credentials.hasKey)
        XCTAssertNil(credentials.store.read())
        credentials.refresh()
        XCTAssertEqual(lookups, 1)
        XCTAssertTrue(credentials.hasKey)
        XCTAssertEqual(credentials.store.read(), "test-key")
        credentials.clear()
        XCTAssertFalse(credentials.hasKey)
        XCTAssertNil(credentials.store.read())
        XCTAssertEqual(lookups, 1)
    }
}

private actor CredentialLookupGate {
    private var continuation: CheckedContinuation<Void, Never>?
    private var released = false
    func wait() async {
        if released { return }
        await withCheckedContinuation { continuation = $0 }
    }
    func release() { released = true; continuation?.resume(); continuation = nil }
}
