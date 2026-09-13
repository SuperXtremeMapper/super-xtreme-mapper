# Stage 1: manufacturer MIDI evidence

Subsequent runtime integration is recorded in the [profile v2 integration report](../INTEGRATION.md). This directory remains the original evidence dataset, independent of runtime support.

This directory contains the first 26 documentation candidates, selected by `source_grade: ready-for-extraction` in the [catalogue](../catalogue.json). It is an intermediate evidence library, separate from SXM's bundled runtime profiles.

Use the [extraction report](REPORT.md) for coverage and unresolved entries, or [index.json](index.json) for the machine-readable model list. Each model dataset includes normalized MIDI bindings, original source URLs and hashes, page/section references, and explicit issues. Complete protocol text is retained beside the data; the original PDF or manufacturer HTML remains authoritative, especially for diagrams and merged table cells.

A binding represents one documented event in a particular mode, channel and direction. Counts are not physical-control counts: shifted actions, banks, feedback and multiple channels can produce many bindings for one control.

## What the states mean

- **Documented extraction:** manufacturer evidence has been transcribed into this reviewable format. This does not assert complete normalization, working app integration, or hardware testing.
- **Existing profile:** a binding was carried over from an existing bundled K-series profile. Its original evidence remains attached.
- **Requires adapter:** evidence is available, but SXM must represent and validate its modes, channels and encoding before installing it as a profile.
- **Unsupported:** the documented behavior cannot currently be used by SXM, such as certain compound messages or lighting protocols.
- **Conflict:** a contradictory source entry is excluded from usable bindings and retained in the issue record. No corrective value is guessed.
- **Scope:** remaining interpretation or normalization work is named explicitly. Refer to the raw evidence before expanding coverage.

No device is marked hardware-tested. User-created mappings and community corrections are planned separately; they must not overwrite manufacturer evidence.

## Verification and regeneration

From the repository root, run:

```sh
python3 -m unittest discover -s scripts/manufacturer-library -p 'test_*.py'
python3 scripts/manufacturer-library/validate_extractions.py --output docs/manufacturer-library/2026-09-12/extracted/validation.json
```

Validation checks candidate coverage, source hashes, references, binding identity, MIDI ranges and explicit limitations. Selected regression tests check known chart facts and quarantined contradictions; passing validation does not establish exhaustive transcription accuracy. The supplied extraction helpers document the process. They use locally archived sources and may require PDF extraction libraries. See the [format contract](CONTRACT.md).

## Next integration step

Extend the runtime profile representation for per-binding channels, device modes, ports, paired values and lighting semantics. Then adapt the documented subsets with focused tests and a clear coverage display. Resolve excluded entries from stronger evidence or user capture before enabling them. The 21 partial and 21 documentation-only candidates remain deferred.
