# Mapping Explanation Implementation Plan

> **For agentic workers:** Use superpowers:subagent-driven-development or superpowers:executing-plans to implement this plan. Steps use checkboxes for tracking.

**Goal:** Explain current mappings with traceable references and export complete Markdown/text/PDF guides.
**Architecture:** Immutable local facts feed deterministic retrieval and complete documentation; a separate bounded Anthropic service interprets retrieved context. A document-scoped native sheet owns opt-in, cancellation and export review.
**Tech Stack:** Swift, SwiftUI, Foundation, AppKit/CoreText/PDFKit, XCTest; no external runtime dependency.
**Spec:** docs/superpowers/specs/2026-09-12-mapping-explanation-design.md

## Global constraints

- Read-only milestone: no assistant mutation, no changes to TSI writer or Voice Learn.
- All rows/devices must appear in local guides; unknown portions explicitly identified.
- Exact profile pins, source provenance and generic mappings without profiles are supported.
- Only opt-in questions send bounded facts; no source XML, keys, or full manuals in payloads.
- Late/cancelled/stale answers cannot become current. References must belong to the supplied context.
- Limits: 4000 question characters, 80 context rows, 96 KiB context, 4096 output tokens, 1 MiB response body. Report every omission.
- Parent owns all xcodebuild runs; agents write tests first, notify parent for RED, then implement after confirmation. No concurrent project edits outside assigned files.

## Shared interfaces

All facts/value services are `nonisolated` and Sendable; UI/coordinator are MainActor.

```swift
struct MappingExplanationSnapshot: Codable, Sendable, Equatable {
 let title: String; let revision: String
 let devices: [ExplanationDevice]; let rows: [ExplanationRow]; let limitations: [String]
 static func build(file: MappingFile, title: String, revision: String) throws -> Self
}
struct ExplanationDevice: Codable, Sendable, Equatable, Identifiable {
 let id: UUID; let name: String; let comment: String; let profile: String
 let settings: [String]; let limitations: [String]
}
struct ExplanationRow: Codable, Sendable, Equatable, Identifiable {
 let id: UUID; let deviceID: UUID; let deviceName: String; let position: Int
 let commandID: Int; let command: String; let direction: String; let assignment: String
 let midi: String; let controllerType: String; let interaction: String
 let conditions: [String]; let modifierReads: [Int]; let modifierWrites: [Int]
 let details: [String]; let controls: [String]; let sources: [String]
 let limitations: [String]; let comment: String
}
struct ExplanationContext: Codable, Sendable, Equatable {
 let revision: String; let rows: [ExplanationRow]; let totalRows: Int
 let omittedRows: Int; let limitations: [String]
}
enum MappingExplanationQuery {
 static func retrieve(question: String, snapshot: MappingExplanationSnapshot,
                      selectedIDs: Set<UUID> = [], limit: Int = 80) -> ExplanationContext
}
struct MappingAssistantAnswer: Codable, Sendable, Equatable {
 struct Claim: Codable, Sendable, Equatable { let text: String; let rowIDs: [UUID] }
 let facts: [Claim]; let interpretations: [Claim]; let unknowns: [String]
}
enum MappingAssistantModel: String, CaseIterable, Sendable {
 case sonnet = "claude-sonnet-5", haiku = "claude-haiku-4-5-20251001"
 var label: String { self == .sonnet ? "Sonnet 5" : "Haiku 4.5" }
}
protocol MappingAnswering: Sendable {
 func answer(question: String, contextJSON: Data, allowedRowIDs: Set<UUID>,
             model: MappingAssistantModel) async throws -> MappingAssistantAnswer
}
// Coordinator receives context as encoded data to isolate networking from facts.
@MainActor final class MappingAssistantCoordinator: ObservableObject {
 @Published private(set) var answer: MappingAssistantAnswer?
 @Published private(set) var isWorking: Bool
 @Published private(set) var errorMessage: String?
 init(service: any MappingAnswering)
 @discardableResult func ask(question: String, contextJSON: Data, allowedRowIDs: Set<UUID>,
                           revision: String, model: MappingAssistantModel) -> Task<Void, Never>
 func cancel(); func invalidate(revision: String)
}
struct MappingReferenceGuide: Sendable {
 let title: String; let revision: String; let sections: [Section]
 struct Section: Sendable { let heading: String; let paragraphs: [String] }
 static func build(snapshot: MappingExplanationSnapshot) throws -> Self
 var markdown: String { get }; var plainText: String { get }
}
@MainActor enum MappingGuidePDF { static func render(_ guide: MappingReferenceGuide) throws -> Data }
```

## Task 1: Structured facts and deterministic retrieval

Files: create `XtremeMapping/XtremeMapping/Models/Explanation/MappingExplanationSnapshot.swift`, `Services/MappingExplanationQuery.swift`, tests `MappingExplanationTests.swift`.
- [x] Write coverage/retrieval tests before implementation. Example: build two devices with same M1 readers/writers and assert querying M1 in one selected device does not invent cross-device dependencies; a matching filter row after 100 unrelated rows must be retrieved.
- [x] Parent runs focused RED (`-only-testing:XtremeMappingTests/MappingExplanationTests`).
- [x] Implement the shared contracts. Extract full meaningful row settings; represent unknown MIDI/commands and missing profile/custom-map evidence explicitly. Profile matches use configured resolver. Do not invent modifier writer IDs: inspect actual catalogue.
- [x] Retrieve selected rows first, relevant rows next and device-scoped dependencies. Bound the encoded context, mark omitted/truncated strings, preserve source order for ties. No-match queries must not silently substitute unrelated rows.
- [x] Parent runs focused GREEN and review; fix material findings.

## Task 2: Bounded answer transport and lifecycle

Files: create `Services/MappingAssistantService.swift`, `Services/MappingAssistantCoordinator.swift`, tests `MappingAssistantServiceTests.swift` and `MappingAssistantCoordinatorTests.swift`.
- [x] Test missing key, request separation/data payload, limits, supported model IDs, rate limit, malformed answer, unknown citations, empty answers, truncation/refusal, cancellation and stale generation before implementation.
- [x] Parent runs focused RED for both test classes.
- [x] Implement `MappingAssistantModel`, `MappingAssistantAnswer`, `MappingAnswering`, concrete `MappingAssistantService(apiKeyProvider:session:)`. Reuse transport conventions, not Voice Learn prompts. HTTPS fixed endpoint, timeout 45 seconds, structured answer JSON, no tools that mutate or browse. Validate all claims/citations against allowed IDs; local errors must not echo credentials.
- [x] Implement coordinator generation token; replacement/cancel/invalidate suppress late results even if service ignores cancellation. `invalidate` clears prior answer when revision changes.
- [x] Parent runs focused GREEN and review.

## Task 3: Complete reference guide and PDF

Files: create `Services/MappingReferenceGuide.swift`, `Services/MappingGuidePDF.swift`, tests `MappingReferenceGuideTests.swift`.
- [x] Write coverage tests for multiple devices, long comments, every row ID, unknown commands, exact profile pin/feedback/layer limitations; Markdown escaping and multi-page PDF extraction.
- [x] Parent runs focused RED.
- [x] Build guide sections from every snapshot row, with readable identity, settings, assignments, conditions, feedback, sources and limitations. Never apply AI retrieval bounds to exports. Sanitize imported Markdown markup while retaining text. Provide text from same section model.
- [x] Render paginated selectable text PDF using native CoreText/CoreGraphics; wrap long text, repeat page footer, report render failure instead of partial success. Preserve complete text coverage across page breaks.
- [x] Parent runs GREEN and visually inspects generated PDF first/middle/last pages, including long text.

## Task 4: Document-scoped native interface

Files: modify `ContentView.swift`, `XtremeMappingDocument.swift`; create `Views/MappingExplanationSheet.swift`, tests `MappingExplanationLifecycleTests.swift`.
- [x] Test revision advances for row edits, metadata-only edits and Undo; opening/building guide leaves model/dirty/Undo state unchanged.
- [x] Parent runs RED, adds document identity/content revision and native sheet.
- [x] Add Explain… above the table using existing active-sheet routing. Local guide is default. Search/question presents matched rows with navigation; AI model choice persists separately from voice settings; visible consent disclosure precedes enabling. Questions disabled with missing key/empty input/no consent; existing key settings available.
- [x] Snapshot work is cancellable; changes invalidate it. Coordinator handles cancel/replacement; closing cancels. Row navigation filters/selects current referenced rows only.
- [x] Export Markdown/text/PDF of complete local guide via save panel using exclusive atomic writer and destination checks. Review preview before export; export leaves TSI/dirty/Undo state unchanged.
- [x] Inspect native layout/keyboard behavior, missing-key state, local retrieval and exports. Parent runs full suite after integration.

## Task 5: Acceptance and documentation

Files: create `XtremeMapping/docs/Mapping-Explanation.md` and `Mapping-Explanation-Verification.md`; update roadmap status.
- [x] Record baseline, test counts, model docs links and selection rationale without claiming unperformed live model benchmarking.
- [x] Review cross-subsystem cancellation, reference validity, input trust, full guide coverage and UI. Resolve material findings.
- [x] Native demonstration with synthetic multi-device data: lookup filter mappings/modifier layer, navigate row, export Markdown/text/PDF, inspect PDF. Regression includes complex TSI/JSON preservation suite.
- [x] Commit and integrate verified tree locally. Keep unrelated untracked plans/diagnostics untouched.
