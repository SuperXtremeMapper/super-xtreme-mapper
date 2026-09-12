import XCTest
@testable import XtremeMapping

@MainActor
final class MappingAssistantCredentialsTests: XCTestCase {
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
