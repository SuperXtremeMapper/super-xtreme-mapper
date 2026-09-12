import XCTest
@testable import XtremeMapping

final class SXMJSONCodecTests: XCTestCase {
    func testEmptyDocumentHasStableRoundTrip() throws {
        let file = MappingFile()
        let bytes = try SXMJSONCodec.encode(file)
        XCTAssertEqual(try SXMJSONCodec.decode(bytes), file)
        XCTAssertEqual(try SXMJSONCodec.encode(file), bytes)
    }

    func testSourceFreeEditableFieldsRoundTrip() throws {
        let row = MappingEntry(commandID: 100, ioType: .input, assignment: .deckB,
            interactionMode: .toggle, midiChannel: 16, midiCC: 127,
            modifier1Condition: ModifierCondition(modifier: 2, value: 7, target: .deckC),
            comment: "🎛 café 日本語", controllerType: .button, invert: true,
            softTakeover: true, setToValue: 0.75, rotarySensitivity: 2.5,
            rotaryAcceleration: 0.5, encoderMode: .mode7Fh01h, autoRepeat: true,
            ledMinRangeType: 2, ledMinRangeData: 3, ledMaxRangeType: 4,
            ledMaxRangeData: 5, ledMinMidi: 1, ledMaxMidi: 126,
            ledInvert: true, ledBlend: true, resolution: 2)
        let file = MappingFile(devices: [Device(name: "Test", comment: "Device", inPort: "In", outPort: "Out", mappings: [row])])
        XCTAssertEqual(try SXMJSONCodec.decode(SXMJSONCodec.encode(file)), file)
    }

    func testResourceLimitsAndNestedTyposAreRejected() throws {
        let row = MappingEntry(commandID: 100, comment: String(repeating: "x", count: SXMJSONCodec.maximumTextBytes + 1))
        XCTAssertThrowsError(try SXMJSONCodec.encode(MappingFile(devices: [Device(name: "Large text", mappings: [row])])) )
        XCTAssertThrowsError(try SXMJSONCodec.encode(MappingFile(devices: (0..<257).map { Device(name: "Device \($0)") })))
        var document = try XCTUnwrap(JSONSerialization.jsonObject(with: SXMJSONCodec.encode(MappingFile(devices: [Device(name: "Test", mappings: [MappingEntry(commandID: 100)])]))) as? [String: Any])
        var devices = document["devices"] as! [[String: Any]]
        var mappings = devices[0]["mappings"] as! [[String: Any]]
        mappings[0]["commment"] = "typo"; devices[0]["mappings"] = mappings; document["devices"] = devices
        XCTAssertThrowsError(try SXMJSONCodec.decode(JSONSerialization.data(withJSONObject: document))) { error in
            XCTAssertEqual((error as? SXMJSONIssue)?.path, "$.devices[0].mappings[0].commment")
        }
    }

    func testLargestFiniteFloatAndNegativeZeroRoundTrip() throws {
        let file = MappingFile(devices: [Device(name: "Floats", mappings: [MappingEntry(commandID: 100,
            setToValue: -Float.zero, rotarySensitivity: .greatestFiniteMagnitude)])])
        let data = try SXMJSONCodec.encode(file)
        XCTAssertEqual(try SXMJSONCodec.decode(data), file)
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("sxm-json-demonstration")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try data.write(to: directory.appendingPathComponent("float-limits.sxm.json"))
    }

    func testUnsupportedVersionMissingFieldAndUnknownKeyAreRejected() throws {
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: SXMJSONCodec.encode(MappingFile())) as? [String: Any])
        object["schemaVersion"] = 2
        XCTAssertThrowsError(try SXMJSONCodec.decode(JSONSerialization.data(withJSONObject: object)))
        object["schemaVersion"] = 1
        object["devicez"] = []
        XCTAssertThrowsError(try SXMJSONCodec.decode(JSONSerialization.data(withJSONObject: object)))
        object.removeValue(forKey: "devicez")
        object.removeValue(forKey: "devices")
        XCTAssertThrowsError(try SXMJSONCodec.decode(JSONSerialization.data(withJSONObject: object)))
    }
}
