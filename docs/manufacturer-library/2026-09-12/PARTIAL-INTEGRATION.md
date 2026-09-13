# Second-batch runtime integration

All 21 partial-evidence candidates are now bundled, bringing the catalogue to 47 entries: the original 26, eight Partial MIDI coverage profiles, and thirteen Documentation only entries. The new batch retains 18,381 source records: 17,246 available scalar address lookups and 1,135 documented-only protocol records. These are variants, not physical-control counts.

Documentation-only entries expose setup, gaps and source links without invented controls. The Assistant receives explicit coverage limitations. The existing Controller panel remains the inspection entry point; the broader UI pass is deferred. See [workflow](UI-WORKFLOW.md), [per-model results](partial-extracted/REPORT.md), and [community mapping candidates](COMMUNITY-MAPPING-CANDIDATES.md).

Verification completed:

- 931 app unit tests passed (869 XCTest plus 62 Swift Testing).
- 33 Python validation/generation tests passed.
- Both extraction stages validate, including exact candidate coverage and source hashes.
- Regeneration matches bundled resources; all original 26 resource hashes remain unchanged.
- Bounded independent review of performance data found no blockers; SLAB and coverage-state integration also reviewed. PX5 now correctly uses its configurable global channel with documented default 16.
- App compilation passed. No new visual or hardware validation was performed for this batch.

Resources remain bounded at 12,000,000 bytes per file and 64,000,000 bytes per catalogue. The larger per-file bound accommodates EC4 and Neon without removing original semantics. Changes are local on main; no commit or push performed. Claude's Assistant presentation files are untouched.
