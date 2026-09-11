import XCTest
@testable import XtremeMapping

final class LoopValueTests: XCTestCase {
    func testLoopSelectorWritesIntegerSelectorsAndReadsThemSymmetrically() throws {
        for value in 0...10 {
            var row = MappingEntry(commandID: 2196, ioType: .input)
            row.controllerType = .button
            row.interactionMode = .direct
            row.setToValue = Float(value)
            XCTAssertEqual(TSIWriter.setValueRaw(for: row, commandId: 2196), UInt32(value))
            let data = try TSIWriter().write(MappingFile(devices: [Device(name: "Generic MIDI", mappings: [row])]))
            let parser = TSIParser()
            let binary = try parser.decodeBase64(TSIParser.extractControllerData(from: data))
            let decoded = try TSIInterpreter.interpret(frames: parser.parseFrames(from: binary))
            let imported = try XCTUnwrap(decoded.allMappings.first)
            XCTAssertEqual(imported.setToValue, Float(value))
            XCTAssertEqual(imported.importedCMAD?.setToValueBits, UInt32(value))
        }
    }
    func testImportedLoopInteractionChangesUpdateValueUIInBothDirections() throws {
        for initial in [InteractionMode.increment, .direct, .hold] {
            var row = MappingEntry(commandID: 2196, ioType: .input)
            row.controllerType = .button
            row.interactionMode = initial
            row.setToValue = 9
            let writer = TSIWriter()
            let data = try writer.write(MappingFile(devices: [Device(name: "Generic MIDI", mappings: [row])]))
            let parser = TSIParser()
            let binary = try parser.decodeBase64(TSIParser.extractControllerData(from: data))
            let decoded = try TSIInterpreter.interpret(frames: parser.parseFrames(from: binary))
            let original = try XCTUnwrap(decoded.allMappings.first)
            for destination in [InteractionMode.increment, .direct, .hold] where destination != initial {
                var edited = original
                edited.interactionMode = destination
                var expected = try writer.preservingCMADPayload(for: original)
                let wireMode: UInt8 = destination == .increment ? 5 : destination == .direct ? 3 : 2
                expected.replaceSubrange(8..<12, with: [0, 0, 0, wireMode])
                expected.replaceSubrange(36..<40, with: [0, 0, 0, destination == .increment ? 0 : 1])
                XCTAssertEqual(try writer.preservingCMADPayload(for: edited), expected,
                               "\(initial) → \(destination) must change only interaction and value UI")
            }
        }
    }

    func testPickerLabelsAndUnknownValues() {
        XCTAssertEqual(TraktorLoopValueMetadata.choices.map(\.label),
                       ["1/32", "1/16", "1/8", "1/4", "1/2", "1", "2", "4", "8", "16", "32"])
        XCTAssertEqual(TraktorLoopValueMetadata.choices.map(\.value), (0...10).map(Float.init))
        XCTAssertEqual(TraktorLoopValueMetadata.choices(including: 7).count, 11)
        let unknown = TraktorLoopValueMetadata.choices(including: -1)
        XCTAssertEqual(unknown.count, 12)
        XCTAssertEqual(unknown.first?.value, -1)
        XCTAssertTrue(unknown.first?.label.hasPrefix("Unknown (") == true)
        XCTAssertEqual(TraktorLoopValueMetadata.decode(UInt32.max), -1)
    }

    func testImportedUnknownLoopSelectorPreservesExactPayloadThroughUnrelatedEdits() throws {
        var row = MappingEntry(commandID: 2196, ioType: .input)
        row.controllerType = .button
        row.interactionMode = .direct
        let data = try TSIWriter().write(MappingFile(devices: [Device(name: "Generic MIDI", mappings: [row])]))
        let parser = TSIParser()
        var binary = try parser.decodeBase64(TSIParser.extractControllerData(from: data))
        let start = try XCTUnwrap(binary.range(of: Data("CMAD".utf8))).lowerBound + 8
        // Int32.max deliberately exceeds Float's exact integer precision.
        binary.replaceSubrange((start + 44)..<(start + 48), with: [0x7f, 0xff, 0xff, 0xff])
        let decoded = try TSIInterpreter.interpret(frames: parser.parseFrames(from: binary))
        var imported = try XCTUnwrap(decoded.allMappings.first)
        XCTAssertEqual(imported.setToValue, Float(Int32.max))
        let original = try TSIWriter().preservingCMADPayload(for: imported)
        imported.invert.toggle()
        var expected = original
        expected.replaceSubrange(20..<24, with: [0, 0, 0, 1])
        XCTAssertEqual(try TSIWriter().preservingCMADPayload(for: imported), expected)
        XCTAssertEqual(TSIWriter.setValueRaw(for: imported, commandId: 2196), 0x7fffffff)
        imported.setToValue = 9
        expected.replaceSubrange(44..<48, with: [0, 0, 0, 9])
        XCTAssertEqual(try TSIWriter().preservingCMADPayload(for: imported), expected)
    }

}
