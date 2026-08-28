# TSI Regression Fixture Provenance

The fixtures in `XtremeMappingTests/Fixtures/TSI` are integrity-checked before use. `manifest.json` is the authority for each fixture's SHA-256, origin classification, completeness, evidenced Traktor version, controller description, source/license, sanitization, expected preservation disposition, total risk count, and ordered risk categories.

Tests load the manifest and fixtures from the checked-out source tree, validate every hash, and only then exercise the parser and document save boundary. A fixture change therefore requires an intentional manifest update and review.

## Fixture inventory

| Fixture | Classification | Complete | Version evidence | Expected behavior |
|---|---|---:|---|---|
| `traktor-4.4.x-sanitized-complete.tsi` | Sanitized real export | Yes | Traktor Pro 4.4.1 user export set | Opens 112 mappings; unchanged document write is byte-identical; edits require converted export |
| `generated-safe-minimal.tsi` | Deterministically generated | Yes | None claimed | Opens as ordinary-save safe; a semantic edit regenerates and reparses |
| `generated-unsafe-native.tsi` | Deterministically generated | Yes | None claimed | Opens and no-op saves exactly; edited ordinary save refuses; converted output reparses |

## Sanitized Traktor 4.4.1 export

The real fixture was selected as the smallest non-empty controller-only export in the repository owner's Traktor 4.4.1 user export set. Its source XML was 17,734 bytes and its decoded controller payload was 13,176 bytes. It contains one `DeviceIO.Config.Controller` entry, one Generic MIDI device, 60 bindings, and 112 mappings.

Sanitization was deliberately minimal:

1. The personal source filename was not retained; the repository uses a neutral fixture name.
2. Every candidate decoded UTF-16 string was audited. The payload contains only `Generic MIDI` and MIDI control names—no personal comments, controller labels, filesystem paths, account identifiers, or private repository references.
3. One trailing LF was added to follow the repository's text-file convention. XML elements and the decoded controller payload are unchanged.

The committed sanitized fixture has SHA-256 `1572b47eeb8cae604b56f0695b722956f1eda808fc00f8c5b700d53b765cc647`. It is a user-owned test-fixture contribution whose redistribution was authorized by the repository owner. Private source identifiers and checksums remain in the ignored development report, not in public artifacts.

This export uses a compact real-world layout not produced by the canonical writer: uncounted DCBM binding frames directly inside DDCI, uncounted CMAI rows inside CMAS, DIOI value 0, short CMAD records, omitted metadata/definition frames, and some non-zero-padded CC names. The importer accepts and preserves these forms. Its typed risks make an edited ordinary overwrite unsafe; unchanged save remains exact.

## Generated fixtures

The generated files contain no user-derived values and are covered by the repository's MIT License.

- `generated-safe-minimal.tsi` contains one canonical Generic MIDI device with zero mappings.
- `generated-unsafe-native.tsi` contains one generated native-style `Kontrol X1 MK3` device, one `Ch02.PitchBend` input binding, and a CMAD with proprietary DeviceType 3. This proves opaque native assignment preservation and deliberate lossy conversion without implying that the file came from Traktor or Native Instruments hardware.

Their generation is deterministic: big-endian four-byte frame lengths, UTF-16BE length-prefixed strings, fixed scalar values, RFC 4648 Base64, and a fixed UTF-8 XML wrapper. The manifest hashes are the reproducibility check.

## Evidence boundaries

No complete local Traktor 4.5.2 export was found during the 2026-08-28 fixture audit. The local Native Instruments user-export directories contained Traktor versions through 4.4.1, and a `.tsi` filename search found no 4.5 or 4.5.2 candidate. This is an explicit evidence gap, not permission to relabel generated data.

The existing 4.5.2 compatibility test constructs a document with a synthetic version label and captured opaque control-name forms (`PitchBend` and paired CC). It is generated compatibility coverage, not a real export or complete 4.5.2 specimen. Existing 4.4.1 literal DCDT tests are captured payloads reduced into constructed documents, not complete exports.

When a redistributable complete 4.5.2 export becomes available, add it as a new fixture. Do not replace or relabel the current generated evidence. Audit all decoded strings, document every transformation, record the license and provenance, add its SHA-256 and expected ordered risks to the manifest, and prove document-layer exact no-op behavior.
