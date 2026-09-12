import XCTest
@testable import XtremeMapping

final class SXMJSONScannerTests: XCTestCase {
    func testDiagnosticPathsCannotAmplifyOversizedKeys() {
        let data = Data(("{\"" + String(repeating: "x", count: 10000) + "\":{\"a\":1,}}").utf8)
        XCTAssertThrowsError(try SXMJSONScanner.validate(data)) { error in
            XCTAssertLessThan((error as? SXMJSONIssue)?.path.utf8.count ?? Int.max, 512)
        }
    }
    func testAcceptsStrictJSONAndIndependentObjectKeys() throws {
        for source in [#"{"a":[null,true,false,-1.2e+3,{"a":"é😀\uD83D\uDE00"}],"b":{}}"#, "0", "-0", "[]", " \n{}\t\r", #"{"é":0,"e\u0301":1}"#] {
            XCTAssertNoThrow(try SXMJSONScanner.validate(Data(source.utf8)), source)
        }
    }

    func testRejectsDuplicateDecodedKeysWithLocation() {
        let source = #"{"rows":[{"a":1,"\u0061":2}]}"#
        XCTAssertThrowsError(try SXMJSONScanner.validate(Data(source.utf8))) { error in
            let issue = error as? SXMJSONIssue
            XCTAssertEqual(issue?.code, "json.duplicateKey")
            XCTAssertEqual(issue?.path, "$.rows[0].a")
            XCTAssertEqual(issue?.byteOffset, 16)
        }
        for source in [#"{"😀":0,"\ud83d\ude00":1}"#, #"{"a/b":0,"a\/b":1}"#] {
            assertRejected(Data(source.utf8), code: "json.duplicateKey")
        }
    }

    func testRejectsMalformedGrammarNumbersStringsAndTrailingData() {
        for source in ["", " ", "01", "-", "+1", "1.", "1e", "1e+", "NaN", "Infinity", "true false", "[1,]", "{\"a\":1,}", "{a:1}", "[1 2]", "{\"a\" 1}", "[", #""\q""#, #""\uZZZZ""#, #""\ud800""#, #""\udc00""#, "\"\n\""] {
            assertRejected(Data(source.utf8), code: "json.syntax")
        }
    }

    func testRejectsInvalidUTF8WithoutReplacement() {
        for bytes: [UInt8] in [[34, 0xFF, 34], [34, 0xC0, 0x80, 34], [34, 0xED, 0xA0, 0x80, 34], [34, 0xF4, 0x90, 0x80, 0x80, 34]] {
            assertRejected(Data(bytes), code: "json.syntax")
        }
    }

    func testSyntaxIssueNamesNestedPathAndByteOffset() {
        XCTAssertThrowsError(try SXMJSONScanner.validate(Data(#"{"a":[0,?]}"#.utf8))) { error in
            let issue = error as? SXMJSONIssue
            XCTAssertEqual(issue?.code, "json.syntax")
            XCTAssertEqual(issue?.path, "$.a[1]")
            XCTAssertEqual(issue?.byteOffset, 8)
        }
    }

    func testMalformedTokenSuffixRetainsItsValuePath() {
        for source in [#"{"a":[01]}"#, #"{"a":[trueX]}"#] {
            XCTAssertThrowsError(try SXMJSONScanner.validate(Data(source.utf8))) { error in
                XCTAssertEqual((error as? SXMJSONIssue)?.path, "$.a[0]")
                XCTAssertEqual((error as? SXMJSONIssue)?.code, "json.syntax")
            }
        }
    }

    func testEnforcesSizeAndDepthBeforeDecoding() throws {
        XCTAssertNoThrow(try SXMJSONScanner.validate(Data("[[]]".utf8), maximumBytes: 4, maximumDepth: 2))
        assertRejected(Data("[[]]".utf8), code: "json.resourceLimit", maximumDepth: 1)
        assertRejected(Data("null".utf8), code: "json.resourceLimit", maximumBytes: 3)
        assertRejected(Data((String(repeating: "[", count: 10000) + String(repeating: "]", count: 10000)).utf8), code: "json.resourceLimit")
    }

    private func assertRejected(_ data: Data, code: String, maximumBytes: Int = 128 * 1024 * 1024, maximumDepth: Int = 64, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertThrowsError(try SXMJSONScanner.validate(data, maximumBytes: maximumBytes, maximumDepth: maximumDepth), file: file, line: line) { error in
            XCTAssertEqual((error as? SXMJSONIssue)?.code, code, "\(error)", file: file, line: line)
        }
    }
}
