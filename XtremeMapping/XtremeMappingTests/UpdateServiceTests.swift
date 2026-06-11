//
//  UpdateServiceTests.swift
//  XtremeMappingTests
//
//  Tests for UpdateService version comparison and download decision logic.
//  Pure logic only — no network, no hdiutil.
//

import XCTest
@testable import XtremeMapping

@MainActor
final class UpdateServiceTests: XCTestCase {

    // MARK: - parseVersionInfo

    func testParseStripsVPrefix() {
        let info = UpdateService.parseVersionInfo("v0.5")
        XCTAssertEqual(info.numerics, [0, 5])
        XCTAssertNil(info.prerelease)
    }

    func testParseMarksPrereleaseSuffix() {
        let info = UpdateService.parseVersionInfo("v0.5-beta")
        XCTAssertEqual(info.numerics, [0, 5])
        XCTAssertNotNil(info.prerelease)
    }

    func testParsePlainVersionWithoutPrefixOrSuffix() {
        let info = UpdateService.parseVersionInfo("1.2.3")
        XCTAssertEqual(info.numerics, [1, 2, 3])
        XCTAssertNil(info.prerelease)
    }

    func testParsePrereleaseWithoutVPrefix() {
        let info = UpdateService.parseVersionInfo("0.5-beta")
        XCTAssertEqual(info.numerics, [0, 5])
        XCTAssertNotNil(info.prerelease)
    }

    // MARK: - isNewerVersion (prerelease awareness, L10)

    func testFinalReleaseOfferedToBetaUser() {
        // Current app "0.5-beta", remote tag "v0.5" → update offered
        XCTAssertTrue(UpdateService.isNewerVersion("v0.5", than: "0.5-beta"))
    }

    func testPrereleaseNotOfferedToReleaseUser() {
        // Current app "0.5", remote tag "v0.5-beta" → NOT offered
        XCTAssertFalse(UpdateService.isNewerVersion("v0.5-beta", than: "0.5"))
    }

    func testNumericComparisonIsNotLexicographic() {
        XCTAssertTrue(UpdateService.isNewerVersion("0.10", than: "0.9"))
        XCTAssertFalse(UpdateService.isNewerVersion("0.9", than: "0.10"))
    }

    func testEqualVersionsNotOffered() {
        XCTAssertFalse(UpdateService.isNewerVersion("v0.5", than: "0.5"))
        XCTAssertFalse(UpdateService.isNewerVersion("v0.5-beta", than: "0.5-beta"))
        XCTAssertFalse(UpdateService.isNewerVersion("1.2.0", than: "1.2"))
    }

    func testBetaRespinOfferedToBetaUser() {
        // The app is distributed as a beta — a respun beta2 must be offered.
        XCTAssertTrue(UpdateService.isNewerVersion("v0.5-beta2", than: "0.5-beta"))
        XCTAssertTrue(UpdateService.isNewerVersion("v0.5-beta10", than: "0.5-beta2"))
    }

    func testOlderBetaNotOfferedToNewerBetaUser() {
        XCTAssertFalse(UpdateService.isNewerVersion("v0.5-beta", than: "0.5-beta2"))
        XCTAssertFalse(UpdateService.isNewerVersion("v0.5-beta2", than: "0.5-beta2"))
    }

    func testPrereleaseRankParsesTrailingNumber() {
        XCTAssertEqual(UpdateService.prereleaseRank("beta"), 0)
        XCTAssertEqual(UpdateService.prereleaseRank("beta2"), 2)
        XCTAssertEqual(UpdateService.prereleaseRank("beta10"), 10)
        XCTAssertEqual(UpdateService.prereleaseRank("rc1"), 1)
    }

    func testHigherNumericPrereleaseStillNewer() {
        // Numeric comparison wins before prerelease tiebreak
        XCTAssertTrue(UpdateService.isNewerVersion("v0.6-beta", than: "0.5"))
        XCTAssertFalse(UpdateService.isNewerVersion("v0.5", than: "0.6-beta"))
    }

    // MARK: - Download decision helpers (M6/L8 pure parts)

    func testResolveExpectedLengthPrefersContentLength() {
        XCTAssertEqual(UpdateService.resolveExpectedLength(contentLength: 1000, assetSize: 500), 1000)
    }

    func testResolveExpectedLengthFallsBackToAssetSize() {
        XCTAssertEqual(UpdateService.resolveExpectedLength(contentLength: -1, assetSize: 500), 500)
        XCTAssertEqual(UpdateService.resolveExpectedLength(contentLength: 0, assetSize: 500), 500)
    }

    func testResolveExpectedLengthNilWhenBothUnknown() {
        // Indeterminate — no denominator, no NaN division
        XCTAssertNil(UpdateService.resolveExpectedLength(contentLength: -1, assetSize: 0))
        XCTAssertNil(UpdateService.resolveExpectedLength(contentLength: 0, assetSize: -1))
    }

    func testProgressFractionClampsToOne() {
        XCTAssertEqual(UpdateService.progressFraction(totalWritten: 2000, expectedLength: 1000), 1.0)
        XCTAssertEqual(UpdateService.progressFraction(totalWritten: 500, expectedLength: 1000), 0.5)
    }

    func testProgressFractionNilWhenLengthUnknown() {
        XCTAssertNil(UpdateService.progressFraction(totalWritten: 500, expectedLength: nil))
        XCTAssertNil(UpdateService.progressFraction(totalWritten: 500, expectedLength: 0))
    }

    func testDownloadSizeValidationExactMatch() {
        XCTAssertTrue(UpdateService.isDownloadSizeValid(written: 1000, assetSize: 1000))
    }

    func testDownloadSizeValidationMismatchFails() {
        XCTAssertFalse(UpdateService.isDownloadSizeValid(written: 999, assetSize: 1000))
        XCTAssertFalse(UpdateService.isDownloadSizeValid(written: 1001, assetSize: 1000))
    }

    func testDownloadSizeValidationSkippedWhenSizeUnknown() {
        XCTAssertTrue(UpdateService.isDownloadSizeValid(written: 999, assetSize: 0))
        XCTAssertTrue(UpdateService.isDownloadSizeValid(written: 999, assetSize: -1))
    }
}
