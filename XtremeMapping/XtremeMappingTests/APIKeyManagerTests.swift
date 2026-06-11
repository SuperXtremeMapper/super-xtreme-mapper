//
//  APIKeyManagerTests.swift
//  XtremeMappingTests
//
//  Pure-logic tests for API key handling: the lock-backed KeySnapshotStore
//  (thread-safe synchronous visibility) and isValidKeyFormat boundaries.
//  The Keychain calls themselves are OS-bound and review-verified.
//

import XCTest
@testable import XtremeMapping

final class APIKeyManagerTests: XCTestCase {

    // MARK: - KeySnapshotStore

    func testWriteThenReadOnSameThreadIsImmediatelyVisible() {
        let store = KeySnapshotStore()
        XCTAssertNil(store.read(), "Fresh store starts empty")

        store.write("sk-ant-first")
        XCTAssertEqual(store.read(), "sk-ant-first",
                       "A write must be visible to an immediate same-thread read")

        store.write("sk-ant-second")
        XCTAssertEqual(store.read(), "sk-ant-second")
    }

    func testWriteNilClearsValue() {
        let store = KeySnapshotStore()
        store.write("sk-ant-key")
        store.write(nil)
        XCTAssertNil(store.read())
    }

    func testConcurrentReadsAndWritesDoNotCrashOrTear() {
        let store = KeySnapshotStore()
        let validValues: Set<String> = ["alpha", "beta", "gamma", "delta"]
        let values = Array(validValues)

        DispatchQueue.concurrentPerform(iterations: 2_000) { i in
            if i % 2 == 0 {
                store.write(values[i % values.count])
            } else {
                if let read = store.read() {
                    XCTAssertTrue(validValues.contains(read),
                                  "Read a torn/invalid value: \(read)")
                }
            }
        }

        // After the storm, the store still holds one of the written values.
        let final = store.read()
        XCTAssertNotNil(final)
        if let final {
            XCTAssertTrue(validValues.contains(final))
        }
    }

    // MARK: - isValidKeyFormat boundaries

    func testValidKeyAtExactMinimumLength() {
        // "sk-ant-" is 7 chars; pad to exactly 40 total.
        let key = "sk-ant-" + String(repeating: "x", count: 33)
        XCTAssertEqual(key.count, 40)
        XCTAssertTrue(APIKeyManager.isValidKeyFormat(key))
    }

    func testKeyOneCharShortOfMinimumIsInvalid() {
        let key = "sk-ant-" + String(repeating: "x", count: 32)
        XCTAssertEqual(key.count, 39)
        XCTAssertFalse(APIKeyManager.isValidKeyFormat(key))
    }

    func testWrongPrefixIsInvalidEvenWhenLongEnough() {
        let key = "sk-oth-" + String(repeating: "x", count: 100)
        XCTAssertFalse(APIKeyManager.isValidKeyFormat(key))
    }

    func testWhitespacePaddedValidKeyIsAccepted() {
        let key = "  sk-ant-" + String(repeating: "x", count: 50) + "\n"
        XCTAssertTrue(APIKeyManager.isValidKeyFormat(key),
                      "Validation must trim surrounding whitespace")
    }

    func testEmptyAndWhitespaceOnlyKeysAreInvalid() {
        XCTAssertFalse(APIKeyManager.isValidKeyFormat(""))
        XCTAssertFalse(APIKeyManager.isValidKeyFormat("   \n  "))
    }

    func testPrefixOnlyIsInvalid() {
        XCTAssertFalse(APIKeyManager.isValidKeyFormat("sk-ant-"))
    }
}
