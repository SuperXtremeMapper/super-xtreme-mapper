# What's new

## 1.1.2 — September 11, 2026

A small compatibility update for more detailed Traktor mappings. Thank you to [@skymakai](https://github.com/skymakai) for reporting [issue #9](https://github.com/SuperXtremeMapper/super-xtreme-mapper/issues/9) and privately sharing a mapping that helped us track this down.

- Imported MIDI Button, Knob and Fader commands now have readable names and the correct Global assignment.
- Track End Warning, Flux Reverse Playback On and Load Selected (loading alternative) are now recognised by name.
- Remix Deck cell states and Deck Flavor conditions have readable names, values and deck choices. Find cell conditions in the new Remix Cell State submenu.
- Original MIDI references remain preserved. If a mapping refers to a MIDI assignment missing from its file, SXM keeps showing a compatibility warning rather than guessing a replacement.

## 1.1.1 — September 11, 2026

A small update to make your mappings easier to read and edit. Thanks for the helpful feedback!

- Resize both Mod 1 and Mod 2 columns to see longer conditions.
- See and edit Slot State conditions for every Remix Deck slot, using Empty, Loaded and Playing. Deck cloning keeps the correct slot.
- The About window now fits properly, with scrolling content and an easy-to-reach Done button.
- Version details are up to date in the welcome screen, About and Settings.

## 1.1 — September 10, 2026

More control over your LEDs, and more of Traktor's mapping settings at your fingertips. Thank you to everyone who sent reports and tested mappings on their controllers.

- **Set your LED colours and behaviour.** OUT mappings now let you edit Controller Range, MIDI Range, Blend and Output Invert. Apply changes to one row or a compatible selection, with undo if you need it.
- **Give different hotcue types different colours.** Hotcue State conditions let you create separate rules for cues, loops and empty pads. A DJM-S7 user confirmed blue and cyan colours, LEDs turning off after cue deletion, and no flickering or stuck LEDs. Colour values depend on your controller.
- **Choose when a mapping is active — [#1](https://github.com/SuperXtremeMapper/super-xtreme-mapper/issues/1).** Deck Play and Is In Active Loop are now available alongside modifiers and Hotcue State conditions, with Deck A–D or Device Target choices.
- **Recognise more OUT commands — [#9](https://github.com/SuperXtremeMapper/super-xtreme-mapper/issues/9).** Modifier outputs use the correct global target, and Generate Stems is recognised for both IN and OUT mappings.
- **Keep the details when you edit.** Condition values, deck targets and LED settings are preserved through the tested save, export and cloning workflows. Unrecognised settings keep their original data.

Checked with 692 automated tests, native Traktor 4.5.1 import/export comparisons, and visual editing and undo checks in SXM.

The fixes cover the entries we could identify in #1 and #9. We did not have the complete original mapping from #9 or the full numeric identifier shown in #1. If anything still appears unknown, please open a follow-up with the exact identifier or a small example TSI.

[Download version 1.1](https://github.com/SuperXtremeMapper/super-xtreme-mapper/releases/download/v1.1/SuperXtremeMapper_1.1.dmg). Requires macOS 14 or later; supports Apple Silicon and Intel. As with 1.0.1, the app is signed with Apple Development and is not notarized. See the [installation guide](https://superxtrememapper.github.io/super-xtreme-mapper/download.html) if macOS asks you to allow it to open.

## Earlier releases

See the [website changelog](https://superxtrememapper.github.io/super-xtreme-mapper/whatsnew.html) or [GitHub releases](https://github.com/SuperXtremeMapper/super-xtreme-mapper/releases) for earlier changes.
