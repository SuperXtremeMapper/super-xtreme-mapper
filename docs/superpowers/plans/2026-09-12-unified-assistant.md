# Unified Assistant Implementation Plan

> **For agentic workers:** Use superpowers:subagent-driven-development. Parent owns builds and integration; one implementation agent at a time with independent review after each unit. No Agency required for this task per user instruction.

**Goal:** One Assistant for voice/text questions, captured MIDI creation, and reviewed conversational edits.
**Architecture:** Pure proposal engine, bounded conversational service, input adapter and document-bound native window.
**Tech Stack:** Swift/SwiftUI/AppKit, existing speech/MIDI services, XCTest.
**Spec:** docs/superpowers/specs/2026-09-12-unified-assistant-design.md

## Global constraints

Read the acceptance contract in the spec. No automatic document mutations, no live API tests, no remote push, preserve unrelated files. Parent runs xcodebuild to avoid concurrent builds. Every unit writes tests first and notifies parent for RED before implementation. Worktree is .worktrees/unified-assistant from d930802. Sonnet uses the existing MappingAssistantModel.sonnet ID. No parallel implementation agents; independent review may overlap unrelated parent UI work.

## Task 1: Typed operations and immutable review

Own new Models/Assistant/AssistantEditOperation.swift, Services/AssistantEditPlan.swift, tests AssistantEditPlanTests.swift. Do not modify the document or JSON writer.
- [x] Write tests for multi-row update/add/delete/duplicate/reorder, invalid atomic rejection, opaque retention, no-op, stale source/metadata/revision, lock, Undo/Redo, direction/catalogue and scalar validation.
- [x] Parent observes RED, then implement.
- [x] Freeze a Codable Sendable operation model with strict unknown-field rejection, an optional-fields whitelist patch and explicit row/device IDs. Reuse SXMJSON enums/values where feasible.
- [x] Expose AssistantEditPlan.prepare(operations: [AssistantEditOperation], file: MappingFile, revision: String) throws -> Self; changes with deviceID, rowID, before/after MappingEntry?, field summaries; warnings:[String]; isEmpty:Bool. Expose apply(document: TraktorMappingDocument, isLocked:Bool, undoManager:UndoManager?) throws -> Bool. Plan keeps its original file and revision privately; stale/locked apply throws with actionable message. Expose operations for conversation refinements.
- [x] Validate whole candidate using source-aware existing JSON validation and native preservation writer contracts. Never round-trip unchanged rows through a lossy representation. Limit to 100 operations and 100 affected rows. Reject duplicate/conflicting row targets; reorder uses exact whole-device row order.
- [x] Parent GREEN and independent task review.

## Task 2: Conversation transport and state

Own new Services/AssistantConversationService.swift, Services/AssistantConversationCoordinator.swift and respective tests. Consume Task 1 operation types; do not edit them without parent coordination.
- [x] Test structured explanations/proposals/clarifications, invalid citations/operations, missing key, follow-ups, context budget, refusal/truncation, late cancellation, stale generation and replacement.
- [x] Parent RED, then implement request/response types and service using fixed Anthropic endpoint and existing model defaults. Question 4000 chars, context 96 KiB, history 24 KiB, command catalogue 48 KiB, response 1 MiB, 8192 output tokens, 45s timeout. Encode all bounds by actual bytes. Separate trusted instructions from imported facts and history. Catalogue records authoritative IDs, names and allowed directions; retrieval by question with common command aliases. Explain truncation.
- [x] Conversation request contains question, ExplanationContext, selected row IDs, current pending operations, optional captured SXMJSONMIDI + destination deviceID, available devices, bounded user/assistant history. Response: answer MappingAssistantAnswer plus operations [AssistantEditOperation]; empty operations means explanation/clarification. Every proposal target must resolve locally; service never applies.
- [x] Coordinator offers injectable protocol; published messages, pending plan, isWorking, error; send prepares context, retains follow-up referenced rows within bounds, validates response, computes plan locally, and appends one answer. cancel/revision change invalidates generation. apply delegates exact pending plan then invalidates it. Expose clear/reject and local lookup. Frozen UI contract: AssistantConversationMessage has id:UUID, role:String (user/assistant/system), text:String, answer:MappingAssistantAnswer?, revision:String. Coordinator init(service:any AssistantConversing), published messages:[AssistantConversationMessage], pendingPlan:AssistantEditPlan?, localContext:ExplanationContext?, isWorking:Bool, errorMessage:String?. send(question:document:snapshot:selectedIDs:capturedMIDI:destinationDeviceID:model:) -> Task<Void,Never>; findLocally(question:snapshot:selectedIDs:); invalidate(revision:); cancel(); discardProposal(); clear(); apply(document:isLocked:undoManager:) throws -> Bool. send takes TraktorMappingDocument and snapshot copied at dispatch; capturedMIDI:SXMJSONMIDI?, destinationDeviceID:UUID?. UI owns snapshot preparation and credential opt-in. Coordinator contains no credential lookup.
- [x] Parent GREEN and independent task review.

## Task 3: Voice and MIDI input adapter (parent)

Own Services/AssistantInputCoordinator.swift, tests AssistantInputCoordinatorTests.swift; upgrade ClaudeAPIService default to shared Sonnet. Consume existing VoiceInputManager and MIDIInputManager lease API.
- [x] Test off by default, late starts/transcripts suppressed, failed permissions surfaced, release only owned MIDI lease, capture valid Note/CC, freeze capture until re-armed.
- [x] Parent RED, then implement injectable speech and MIDI abstractions with real adapters. Voice transcript callback feeds composer only. No network calls or model interpretation in input adapter. Independent voice on/off and MIDI arm/clear, stopAll for close.
- [x] Parent GREEN and independent review.

## Task 4: Assistant window and integration (parent)

Own Views/UnifiedAssistantView.swift, Views/AssistantWindowController.swift, ContentView.swift and entry point labels, UI lifecycle tests. Reuse MappingExplanationSheet for reference guide until shared export extraction is justified.
- [x] Resizable NSWindow hosting a conversation view, bound to one document and lock state, close cleanup. Source-row navigation updates table without closing Assistant.
- [x] Chat history and composer, Voice toggle, captured MIDI panel with destination picker, separate Learn button, model/consent/key settings, local lookup and guide button.
- [x] Render exact local review before/after summaries and warnings with Apply/Discard. Old/history cards cannot apply; source edit disables stale results. No-op gets explicit feedback.
- [x] Route toolbar Assistant, old voice activation notification and Explain shortcut to same window; retain legacy coordinator tests without duplicate visible voice interface.
- [x] Run lifecycle/integration tests and native smoke walkthrough.

## Task 5: Acceptance

- [x] Full suite, final independent review and scoped fixes.
- [x] Update user guide, verification record and roadmap, including future visual controller editor and honest live-test limitations.
- [x] Commit, locally fast-forward verified tree, preserve unrelated untracked files and remove owned clean worktree.
