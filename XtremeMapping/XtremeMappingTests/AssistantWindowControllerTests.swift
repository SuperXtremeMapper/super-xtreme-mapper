import XCTest
import SwiftUI
@testable import XtremeMapping

@MainActor final class AssistantWindowControllerTests: XCTestCase {
    func testAssistantReadsCurrentTableSelection() {
        var selection: Set<UUID> = [UUID()]
        let session = UnifiedAssistantSession()
        defer { session.close() }
        let view = UnifiedAssistantView(document: TraktorMappingDocument(),
            selectedIDs: Binding(get: { selection }, set: { selection = $0 }),
            isLocked: .constant(false), session: session, onShowMappings: { _ in })
        let nextSelection: Set<UUID> = [UUID(), UUID()]
        selection = nextSelection
        XCTAssertEqual(view.selectedIDs, nextSelection)
        selection = []
        XCTAssertTrue(view.selectedIDs.isEmpty)
    }

    func testHostedContentDoesNotOverrideWindowSize() {
        let owner = AssistantWindowController()
        owner.present(title: "Assistant", content: {
            AnyView(Text("Long conversation").frame(idealWidth: 1000, idealHeight: 1600))
        }, onClose: {})
        owner.window?.contentView?.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        XCTAssertEqual(owner.window?.contentLayoutRect.width, 640)
        XCTAssertEqual(owner.window?.contentMinSize, NSSize(width: 520, height: 480))
        owner.window?.setContentSize(NSSize(width: 520, height: 480))
        owner.window?.contentView?.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        XCTAssertEqual(owner.window?.contentLayoutRect.size, NSSize(width: 520, height: 480))
        XCTAssertEqual(owner.window?.contentView?.subviews.first?.frame.size, NSSize(width: 520, height: 480))
        owner.close()
    }

    func testWindowUsesDocumentUndoManager() {
        let owner = AssistantWindowController()
        let manager = UndoManager()
        owner.present(title: "Assistant", content: { AnyView(Text("Test")) }, onClose: {}, undoManager: { manager })
        XCTAssertTrue(owner.window?.undoManager === manager)
        owner.close()
    }

    func testReopeningUsesOneWindowAndCloseCleansUpOnce() {
        let owner = AssistantWindowController()
        var cleanups = 0
        owner.present(title: "Assistant — Mapping A", content: { AnyView(Text("Conversation")) }, onClose: { cleanups += 1 })
        let first = owner.window
        owner.present(title: "Assistant — Mapping A", content: { AnyView(Text("Other")) }, onClose: { cleanups += 100 })
        XCTAssertTrue(owner.window === first)
        XCTAssertEqual(owner.window?.title, "Assistant — Mapping A")
        XCTAssertEqual(owner.window?.appearance?.name, .darkAqua)
        XCTAssertTrue(owner.window?.styleMask.contains(.resizable) == true)
        owner.close()
        XCTAssertEqual(cleanups, 1)
        XCTAssertNil(owner.window)
        owner.close()
        XCTAssertEqual(cleanups, 1)
    }
}
