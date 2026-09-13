# Akai / AlphaTheta partial evidence extraction

These three catalogue models are manufacturer evidence datasets, not runnable profiles. No hardware validation or runtime integration is claimed.

| Model | Coverage | Normalized bindings | Issues |
| --- | --- | ---: | ---: |
| APC64 | documentation-only | 0 | 2 |
| MPD218 | documentation-only | 0 | 2 |
| SLAB | partial | 765 | 4 |

SLAB contains 461 device-to-host and 304 host-to-device bindings: 623 Note, 128 poly-aftertouch (unsupported), 10 source-specific relative CC, and 4 ordered strip CC pairs. Its 16 pads across eight pages account for 640 bindings: unshifted Note input/output, pressure input, and shifted Note input/output. Every explicit table row is processed except E1's two contradictory rows, which quarantine four potential direction-specific bindings. E1 decimal channel 1 disagrees with status 96/channel 7 for both note 16 and note 17.

SLAB direction codes are clockwise 01 and counterclockwise 41, not two’s-complement. Color-number feedback preserves the source range, without inventing RGB mappings or unspecified zero-value behavior. Blank touch/pressure detail cells remain explicitly undocumented. The first strip pair has only its MSB in the decimal reference but both 0E and 2E in the hexadecimal source column.

APC64's editor capabilities and MPD218's program/bank capabilities do not establish actual preset note/CC addresses. Both retain full page-marked owner manuals and specific setup notes and missing information. SLAB retains all four complete protocol pages, all 43 owner-manual pages, and original/resolved tables. Paths, URLs and SHA-256 hashes match the catalogue sources.

## Reproduction

Run `python3 docs/manufacturer-library/2026-09-12/partial-extracted/akai-alphatheta/extract.py` from the repository root with pdfplumber installed. It only writes this folder. The table helper is adapted from the existing Pioneer extraction helper; original sources and helpers are unmodified. SHIFT is recovered from the center positions of words on each row, avoiding merged-cell spillover into adjacent rows. Merged trigger labels supply only the underlying action, never an inferred modifier.
