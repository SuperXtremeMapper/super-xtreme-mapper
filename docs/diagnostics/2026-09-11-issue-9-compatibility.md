# Issue #9: imported command and condition compatibility

The mapping privately supplied by @skymakai exposed command identities and software conditions missing from the catalogue. Version 1.1.2 addresses those gaps without publishing the customer's mapping.

## Evidence and scope

- CMDR's `KnownCommands` identifies Track End Warning (520), Flux Reverse Playback On (874), and all eight MIDI Buttons, Knobs and Faders (850–873). Its global-target metadata establishes that target word zero means Global for the internal MIDI controls.
- A synthetic 3079 input was imported into Traktor Pro 4.5.1. Controller Manager displayed **Load Selected (loading alternative)**. A native re-export retained command ID 3079. The controller-only fixture `traktor-4.5.1-load-selected-alternative.tsi` records this result; its manifest documents provenance, hash and preservation risks. No customer rows are included.
- Newly named commands remain recognition-only catalogue entries. Naming an imported row does not claim audited creation defaults or enable new commands in the verified creation menus.
- CMDR's `KnownConditions`, `SlotCellState`, `DeckFlavor` and condition target options define Remix cell conditions 665–728 and Deck Flavor 2302. Cell identity is encoded in the condition ID; the target encodes the deck. All four slots and sixteen cells use the same state family.
- A separate synthetic import and native re-export confirmed `(665, target 2, value 3)` as Slot 1 Cell 1, Remix Deck C, Waiting, and `(2302, target 3, value 2)` as Deck Flavor, Deck D, Stem Deck. The re-export preserved both tuples.

Primary reference implementation: [CMDR TSI library](https://github.com/cmdr-editor/cmdr/tree/master/cmdr/cmdr.TsiLib).

## Compatibility boundaries

The private mapping has 1,746 rows across five devices. After the changes, the actual importer recognises every command identity and condition type in that file. An independent inspection of the original binding tables confirms that twenty referenced MIDI binding IDs are absent. SXM preserves and flags those references rather than inventing assignments or using control-definition ordering as a substitute.

The no-op parse/write remains byte-identical. All 113 newly supported condition occurrences were checked for edits that change only the intended four-byte value. Ordinary edited saves still refuse regeneration when unrelated native data cannot be safely preserved; this release does not remove that safeguard or claim hardware validation.

## Verification

Synthetic regressions cover names and reverse lookup, Global target interpretation, all cell condition identities, values and target options, unfamiliar imported values, family switching, both condition slots, precise byte edits, full document re-import and native 3079 no-op preservation. Existing unresolved-binding collision and preservation tests remain applicable. The private inspection harness and source copy were removed after use.

A fresh independent review covers the implementation, fixture privacy, release package and documentation. Detailed local build/release evidence is retained outside the public repository. The previous 1.1.1 release remains available for rollback.
