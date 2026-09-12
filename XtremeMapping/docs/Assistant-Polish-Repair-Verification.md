# Assistant polish and repair verification — 12 September 2026

## Scope and status

The user requested Assistant UI/UX consistency, live evaluation, and AI JSON import repair, followed by a pause. UI and repair implementation are complete. Available native lifecycle checks are complete; actual model responses, speech recognition accuracy and physical MIDI capture remain unverified because Keychain authorization and live test input were unavailable. No live AI request reached Anthropic in this evaluation and no credential was printed.

## Automated checks

Baseline a675136: 890 tests passed. The first expanded full run passed 904 tests before the final privacy and geometry regressions were added. Final verification passed 908 tests (846 XCTest and 62 Swift Testing), zero failures, in `/tmp/sxm-polish-repair-accepted.log` (exit 0).

Tests cover unchanged original import bytes, malformed source-free punctuation, preserved-source scalar repair, recursive visibility validation, escaped/misspelled/unknown source containers, strict patch response decoding, ambiguous and overlapping edits, request/response size limits, sanitized transport errors, no credential access before consent, cancelled or stale repair responses, accept/discard/import separation, cancellable late key lookup, native window geometry and resizing, and existing mapping preservation/Undo behavior.

The parent ran xcodebuild with the existing XCTest target and Swift Testing suites, serially on macOS. Local test invocations disabled signing/hardened runtime/sandbox requirements for the test runner only; project security settings were not changed. Logs are under `/tmp/sxm-polish-*.log`, `/tmp/sxm-repair-*.log`, and `/tmp/sxm-window-*.log`.

## Native inspection

- Inspected the old window against the main editor, then the redesigned window at its default size.
- Resized the final Assistant to 720 × 560 content size. Header controls, conversation, composer and actions remained visible. Tested a five-line message with MIDI expanded and connection settings expanded separately. The conversation scrolls when space is limited.
- Confirmed the selection-specific example is disabled without table selection. Its action now explicitly opts into current selected-row context.
- Confirmed key lookup shows a waiting indicator while Assistant remains responsive. Cancelling asynchronous API-key settings returns to the same conversation without losing the composed message.
- Turned voice on, observed pending startup and turned it off. No transcript was received; no recognition-accuracy claim is made.
- Created a disposable MIDI destination, armed the actual MIDI listener, observed the waiting state and cancelled it. No physical MIDI event was received; no hardware-capture claim is made.
- Imported a valid two-device/four-row K-series JSON fixture through the existing local review.
- Opened a copy with a trailing comma. Local diagnostics showed the syntax error and Import was disabled. Expanded repair disclosure, verified consent gates the repair action, started the request and stopped it during Keychain waiting. The original error review returned and Import remained disabled.

The successful repair/accept/import path is exercised with injected transport responses in automated tests. It is not described as a live model demonstration.

## Issues found and corrected

1. Selection-specific prompt did not enable selection context. It now does, and is disabled without selected rows.
2. Synchronous Keychain access could freeze the UI. A nonisolated reader runs off the main actor; the observable settings manager is prepared asynchronously. Waiting and cancellation are visible.
3. An untracked settings-dismiss task could start after session cleanup. Refresh is now owned by the view lifecycle and guards late results with generations.
4. Root-only repair redaction checks allowed unfamiliar nested source containers. Every visible field and container shape must now match the known schema before transmission; protected preservation is retained and redacted in full. Unsafe input refuses locally before credentials are read.
5. Direct SwiftUI hosting could reset native window bounds after layout. A plain AppKit container separates window sizing from the hosted view. The regression checks both stable default bounds and resize propagation to the minimum size. The import panel uses the same pattern.

All independent unit and whole-change reviews passed after scoped corrections.

## Remaining live evaluation

Once the user resolves macOS Keychain authorization, run a few synthetic-fixture Sonnet requests: explanation with correct source rows, an explanation follow-up, a selected-row edit with review/Apply/Undo, an ambiguous creation request that asks for details, and a simple repair that is reviewed and revalidated. Then verify spoken input with a known phrase and capture a known physical control. Do not send personal mappings as test data unless requested.

No additional profiles or visual controller work was started. Pause after this delivery, with these live checks explicitly outstanding.
