import PDFKit
import XCTest
@testable import XtremeMapping

@MainActor
final class MappingReferenceGuideTests: XCTestCase {
    func testCancelledGuideBuildThrowsInsteadOfReturningPartialContent() async {
        let deviceID = UUID()
        let row = ExplanationRow(
            id: UUID(), deviceID: deviceID, deviceName: "Large controller", position: 1,
            commandID: 1, command: "Play", direction: "Input", assignment: "Deck A",
            midi: "Note 1", controllerType: "Button", interaction: "Trigger",
            conditions: [], modifierReads: [], modifierWrites: [], details: [], controls: [],
            sources: [], limitations: [], comment: ""
        )
        let snapshot = MappingExplanationSnapshot(
            title: "Large map", revision: "cancel-build",
            devices: [ExplanationDevice(id: deviceID, name: "Large controller", comment: "", profile: "", settings: [], limitations: [])],
            rows: Array(repeating: row, count: 20_000), limitations: []
        )
        let task = Task.detached {
            try? await Task.sleep(for: .milliseconds(50))
            return try MappingReferenceGuide.build(snapshot: snapshot)
        }
        task.cancel()

        do {
            _ = try await task.value
            XCTFail("A cancelled build returned a partial or complete guide")
        } catch is CancellationError {
            // Expected.
        } catch {
            XCTFail("Expected CancellationError, got \(error)")
        }
    }

    func testCancelledPDFRenderThrowsInsteadOfReturningPartialData() async {
        let guide = MappingReferenceGuide(
            title: "Large PDF", revision: "cancel-pdf",
            sections: [.init(heading: "Rows", paragraphs: Array(repeating: String(repeating: "word ", count: 1_000), count: 200))]
        )
        let task = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(50))
            return try MappingGuidePDF.render(guide)
        }
        task.cancel()

        do {
            _ = try await task.value
            XCTFail("A cancelled render returned a partial or complete PDF")
        } catch is CancellationError {
            // Expected.
        } catch {
            XCTFail("Expected CancellationError, got \(error)")
        }
    }

    func testMemberwiseGuideExportsIdentityAndPreservesParagraphLineLayout() {
        let guide = MappingReferenceGuide(
            title: "Reviewed answer",
            revision: "answer-revision-9",
            sections: [.init(
                heading: "Facts",
                paragraphs: ["Row 1\nCommand: Play\nSource: row evidence"]
            )]
        )

        XCTAssertTrue(guide.markdown.contains("Reviewed answer"))
        XCTAssertTrue(guide.markdown.contains("answer-revision-9"))
        XCTAssertTrue(guide.markdown.contains("Row 1  \nCommand: Play  \nSource: row evidence"))
        XCTAssertTrue(guide.plainText.contains("Reviewed answer\nRevision: answer-revision-9"))
        XCTAssertTrue(guide.plainText.contains("Row 1\nCommand: Play\nSource: row evidence"))
    }

    func testGuideIncludesEveryDeviceRowAndExactEvidenceWithoutExportLimits() throws {
        let firstID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
        let secondID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
        let firstDeviceID = UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!
        let secondDeviceID = UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!
        let snapshot = MappingExplanationSnapshot(
            title: "Touring map",
            revision: "revision-42",
            devices: [
                ExplanationDevice(
                    id: firstDeviceID,
                    name: "Xone K3",
                    comment: "Main controller",
                    profile: "xone-k3@1.4.2#sha256:0123456789abcdef",
                    settings: ["In-port: K3", "Out-port: K3"],
                    limitations: ["Physical layer is not a Traktor modifier"]
                ),
                ExplanationDevice(
                    id: secondDeviceID,
                    name: "Generic MIDI",
                    comment: "Fallback device",
                    profile: "Unknown profile",
                    settings: ["In-port: All Ports"],
                    limitations: ["No configured profile match"]
                )
            ],
            rows: [
                ExplanationRow(
                    id: firstID,
                    deviceID: firstDeviceID,
                    deviceName: "Xone K3",
                    position: 1,
                    commandID: 2548,
                    command: "Modifier #1",
                    direction: "Output",
                    assignment: "Global",
                    midi: "CC ch16 #40",
                    controllerType: "LED",
                    interaction: "Output",
                    conditions: ["M2 = 3 (Global)"],
                    modifierReads: [2],
                    modifierWrites: [1],
                    details: ["Feedback controller range: 7…7", "Feedback MIDI range: 0…127", "Blend: false", "Invert: true"],
                    controls: ["K3 upper-left encoder push", "Layer: amber"],
                    sources: ["CMAD command id 2548", "Profile pin xone-k3@1.4.2#sha256:0123456789abcdef"],
                    limitations: ["Imported feedback tail contains opaque bytes"],
                    comment: "Writes M1 for the amber layer"
                ),
                ExplanationRow(
                    id: secondID,
                    deviceID: secondDeviceID,
                    deviceName: "Generic MIDI",
                    position: 97,
                    commandID: 999_999,
                    command: "Unknown command (999999)",
                    direction: "Input",
                    assignment: "Deck D",
                    midi: "Unknown MIDI assignment (status 0xFE)",
                    controllerType: "Unknown controller type 91",
                    interaction: "Unknown interaction 73",
                    conditions: ["No conditions"],
                    modifierReads: [],
                    modifierWrites: [],
                    details: ["Rotary sensitivity: 42%"],
                    controls: [],
                    sources: ["Imported CMAD row 97"],
                    limitations: ["Command catalogue has no entry for 999999", "Physical control is unknown"],
                    comment: "Keep this unknown row"
                )
            ],
            limitations: ["One source block could not be interpreted"]
        )

        let guide = try MappingReferenceGuide.build(snapshot: snapshot)

        for output in [guide.plainText] {
            XCTAssertTrue(output.contains("Touring map"))
            XCTAssertTrue(output.contains("revision-42"))
            XCTAssertTrue(output.contains(firstDeviceID.uuidString))
            XCTAssertTrue(output.contains(secondDeviceID.uuidString))
            XCTAssertTrue(output.contains(firstID.uuidString))
            XCTAssertTrue(output.contains(secondID.uuidString))
            XCTAssertTrue(output.contains("xone-k3@1.4.2#sha256:0123456789abcdef"))
            XCTAssertTrue(output.contains("Feedback controller range: 7…7"))
            XCTAssertTrue(output.contains("M2 = 3 (Global)"))
            XCTAssertTrue(output.contains("Unknown MIDI assignment (status 0xFE)"))
            XCTAssertTrue(output.contains("Command catalogue has no entry for 999999"))
            XCTAssertTrue(output.contains("Imported CMAD row 97"))
        }
        XCTAssertTrue(guide.markdown.contains("xone-k3@1.4.2\\#sha256:0123456789abcdef"))
        XCTAssertTrue(guide.markdown.contains("M2 = 3 \\(Global\\)"))
        XCTAssertTrue(guide.markdown.contains("Unknown MIDI assignment \\(status 0xFE\\)"))
        XCTAssertEqual(guide.sections.filter { $0.heading.contains("Device") }.count, 2)
    }

    func testMarkdownEscapesImportedMarkupWhilePlainTextRetainsLiteralText() throws {
        let deviceID = UUID(uuidString: "CCCCCCCC-CCCC-CCCC-CCCC-CCCCCCCCCCCC")!
        let rowID = UUID(uuidString: "33333333-3333-3333-3333-333333333333")!
        let snapshot = MappingExplanationSnapshot(
            title: "Map #1 *live*",
            revision: "rev_[unsafe]",
            devices: [ExplanationDevice(
                id: deviceID,
                name: "Pad **bank**",
                comment: "[manual](https://invalid.example) `literal`",
                profile: "profile_1",
                settings: [],
                limitations: []
            )],
            rows: [ExplanationRow(
                id: rowID, deviceID: deviceID, deviceName: "Pad **bank**", position: 1,
                commandID: 1, command: "Play | Pause", direction: "Input", assignment: "Deck A",
                midi: "Note #36", controllerType: "Button", interaction: "Toggle",
                conditions: [], modifierReads: [], modifierWrites: [], details: [], controls: [],
                sources: [], limitations: [], comment: "> user supplied _comment_"
            )],
            limitations: []
        )

        let guide = try MappingReferenceGuide.build(snapshot: snapshot)

        XCTAssertTrue(guide.markdown.contains("\\*live\\*"))
        XCTAssertTrue(guide.markdown.contains("\\[manual\\]\\(https://invalid.example\\)"))
        XCTAssertTrue(guide.markdown.contains("\\`literal\\`"))
        XCTAssertTrue(guide.markdown.contains("\\> user supplied \\_comment\\_"))
        XCTAssertTrue(guide.plainText.contains("[manual](https://invalid.example) `literal`"))
        XCTAssertTrue(guide.plainText.contains("> user supplied _comment_"))
    }

    func testPDFIsMultipageSelectableAndContainsCompleteUnicodeAndUnbrokenText() throws {
        let deviceID = UUID(uuidString: "DDDDDDDD-DDDD-DDDD-DDDD-DDDDDDDDDDDD")!
        let longToken = "BEGIN-UNBROKEN-" + String(repeating: "abcdefghij", count: 90) + "-END-UNBROKEN"
        let rows = (1...48).map { position in
            ExplanationRow(
                id: UUID(), deviceID: deviceID, deviceName: "Controller Ω", position: position,
                commandID: 2_000 + position, command: "Cue \(position) — 日本語 café 🎚️",
                direction: position.isMultiple(of: 2) ? "Output" : "Input", assignment: "Deck A",
                midi: "CC ch1 #\(position)", controllerType: "Button", interaction: "Direct",
                conditions: ["M1 = \(position % 8)"], modifierReads: [1], modifierWrites: [],
                details: position == 24 ? [longToken] : ["Complete row marker \(position)"],
                controls: ["Control \(position)"], sources: ["Synthetic source \(position)"],
                limitations: [], comment: "Unicode comment \(position): naïve façade"
            )
        }
        let snapshot = MappingExplanationSnapshot(
            title: "PDF coverage Ω", revision: "pdf-revision",
            devices: [ExplanationDevice(id: deviceID, name: "Controller Ω", comment: "", profile: "Synthetic", settings: [], limitations: [])],
            rows: rows,
            limitations: []
        )

        let data = try MappingGuidePDF.render(try MappingReferenceGuide.build(snapshot: snapshot))
        let document = try XCTUnwrap(PDFDocument(data: data))
        XCTAssertGreaterThan(document.pageCount, 1)
        let extracted = (0..<document.pageCount).compactMap { document.page(at: $0)?.string }.joined(separator: "\n")
        XCTAssertTrue(extracted.contains("PDF coverage Ω"))
        XCTAssertTrue(extracted.contains(rows.first!.id.uuidString))
        XCTAssertTrue(extracted.contains(rows.last!.id.uuidString))
        XCTAssertTrue(extracted.contains("Complete row marker 48"))
        XCTAssertTrue(extracted.contains("日本語 café"))
        XCTAssertTrue(extracted.replacingOccurrences(of: "\n", with: "").contains(longToken))
        for pageIndex in 0..<document.pageCount {
            XCTAssertTrue(document.page(at: pageIndex)?.string?.contains("Page \(pageIndex + 1)") == true)
        }

        let sampleDirectory = URL(fileURLWithPath: "/tmp/sxm-assistant-demonstration", isDirectory: true)
        try FileManager.default.createDirectory(at: sampleDirectory, withIntermediateDirectories: true)
        try data.write(to: sampleDirectory.appendingPathComponent("guide.pdf"), options: .atomic)
    }

    func testEmptyDeviceAndDocumentLimitationsRemainVisible() throws {
        let deviceID = UUID(uuidString: "EEEEEEEE-EEEE-EEEE-EEEE-EEEEEEEEEEEE")!
        let snapshot = MappingExplanationSnapshot(
            title: "Empty device example", revision: "empty-1",
            devices: [ExplanationDevice(
                id: deviceID, name: "Disconnected controller", comment: "No rows imported",
                profile: "Unknown profile", settings: ["In-port: None"],
                limitations: ["No mapping rows were present for this device"]
            )],
            rows: [],
            limitations: ["Original XML extension block is opaque"]
        )

        let guide = try MappingReferenceGuide.build(snapshot: snapshot)

        XCTAssertTrue(guide.markdown.contains(deviceID.uuidString))
        XCTAssertTrue(guide.markdown.contains("No mapping rows were present for this device"))
        XCTAssertTrue(guide.markdown.contains("Original XML extension block is opaque"))
        XCTAssertTrue(guide.plainText.contains("Disconnected controller"))
    }
}
