import XCTest
@testable import XtremeMapping

final class FXCloneServiceTests: XCTestCase {
    @MainActor
    func testDefaultControllerFXButtonsRemainOrdinarilySaveableAfterClone() throws {
        for command in 369...372 {
            let source = MappingEntry(commandID: command, assignment: .fxUnit1, interactionMode: .direct, midiChannel: 1, midiCC: 70)
            let parser = TSIParser()
            let generated = MappingFile(devices: [Device(name: "FX", mappings: [source])])
            let imported = try parser.parseDocument(TSIWriter().writeConverted(generated))
            let original = try XCTUnwrap(imported.allMappings.first)
            var edited = imported
            edited.devices[0].mappings[0].comment = "Edited"
            XCTAssertNoThrow(try TSIWriter().write(edited), "Ordinary edit of FX command \(command)")
            let document = TraktorMappingDocument(mappingFile: imported)
            let plan = FXCloneService.plan(selectedMappingIDs: [original.id], source: .unit1, destination: .unit4, in: imported)
            _ = try FXCloneService.execute(plan, in: document, isLocked: false, undoManager: nil)
            let saved = try parser.parseDocument(TSIWriter().write(document.mappingFile))
            XCTAssertEqual(saved.allMappings.map(\.assignment), [.fxUnit1, .fxUnit4])
            XCTAssertEqual(saved.allMappings.map(\.commandID), [command, command])
            XCTAssertEqual(saved.allMappings.last?.midiAssignment, original.midiAssignment)
        }
    }

    func testClonePreservesEveryFieldExceptIdentityAndExplicitTarget() throws {
        var source = MappingEntry(commandID: 365, assignment: .fxUnit1, midiChannel: 3, midiCC: 19, comment: "FX 1 / Deck A")
        source.modifier1Condition = ModifierCondition(modifier: 1, value: 2)
        let file = MappingFile(devices: [Device(name: "FX", mappings: [source])])
        let plan = FXCloneService.plan(selectedMappingIDs: [source.id], source: .unit1, destination: .unit4, in: file)
        let clone = try XCTUnwrap(plan.inserts.first?.mapping)
        var expected = source.copy(withID: clone.id)
        expected.assignment = .fxUnit4
        XCTAssertEqual(clone, expected)
        XCTAssertNotEqual(clone.id, source.id)
    }

    func testNativeRoundtripPreservesExplicitFXTargetAndImportedProvenance() throws {
        let source = MappingEntry(commandID: 365, assignment: .fxUnit1, midiChannel: 2, midiCC: 11, comment: "FX source")
        let parser = TSIParser()
        func reimport(_ file: MappingFile) throws -> MappingFile {
            let data = try TSIWriter().writeConverted(file)
            let binary = try parser.decodeBase64(TSIParser.extractControllerData(from: data))
            return try TSIInterpreter.interpret(frames: parser.parseFrames(from: binary))
        }
        let imported = try reimport(MappingFile(devices: [Device(name: "FX", mappings: [source])]))
        let original = try XCTUnwrap(imported.allMappings.first)
        let plan = FXCloneService.plan(selectedMappingIDs: [original.id], source: .unit1, destination: .unit3, in: imported)
        let clone = try XCTUnwrap(plan.inserts.first?.mapping)
        XCTAssertEqual(clone.importedCMAD, original.importedCMAD)
        XCTAssertNotNil(clone.importedCMAD)
        let saved = try reimport(MappingFile(devices: [Device(name: "FX", mappings: [clone])]))
        XCTAssertEqual(saved.allMappings.first?.assignment, .fxUnit3)
        XCTAssertEqual(saved.allMappings.first?.midiAssignment, original.midiAssignment)
        XCTAssertEqual(saved.allMappings.first?.comment, original.comment)
    }

    @MainActor
    func testCloneIsAtomicUndoableAndRejectsStaleAndLockedPlans() throws {
        let source = MappingEntry(commandID: 365, assignment: .fxUnit1, midiChannel: 1, midiCC: 9)
        let file = MappingFile(devices: [Device(name: "FX", mappings: [source])])
        let document = TraktorMappingDocument(mappingFile: file)
        let plan = FXCloneService.plan(selectedMappingIDs: [source.id], source: .unit1, destination: .unit2, in: file)
        let undo = UndoManager()
        XCTAssertThrowsError(try FXCloneService.execute(plan, in: document, isLocked: true, undoManager: undo))
        XCTAssertEqual(document.mappingFile, file)
        undo.beginUndoGrouping()
        let result = try FXCloneService.execute(plan, in: document, isLocked: false, undoManager: undo)
        undo.endUndoGrouping()
        XCTAssertEqual(result.createdCount, 1)
        XCTAssertThrowsError(try FXCloneService.execute(plan, in: document, isLocked: false, undoManager: undo))
        undo.undo()
        XCTAssertEqual(document.mappingFile, file)
        undo.redo()
        XCTAssertEqual(document.mappingFile.allMappings.count, 2)
    }

    func testDuplicatesAreSkippedWithinTheirDeviceAndOtherAssignmentsExcluded() {
        let source = MappingEntry(commandID: 365, assignment: .fxUnit1, midiChannel: 1, midiCC: 9)
        var existing = source.copyWithNewID()
        existing.assignment = .fxUnit2
        let deck = MappingEntry(commandID: 100, assignment: .deckA)
        let file = MappingFile(devices: [Device(name: "FX", mappings: [source, existing, deck])])
        let plan = FXCloneService.plan(selectedMappingIDs: [source.id, deck.id], source: .unit1, destination: .unit2, in: file)
        XCTAssertTrue(plan.inserts.isEmpty)
        XCTAssertEqual(plan.duplicateSkipCount, 1)
        XCTAssertEqual(plan.ignoredCount, 1)
    }
}
