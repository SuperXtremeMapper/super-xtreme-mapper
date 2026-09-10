# LED output mapping

Select an **OUT** row to find **LED Output** in the settings panel. Set Controller Min/Max, MIDI Min/Max, Blend and Output Invert, then choose **Apply LED**. Draft text does not change the mapping until applied. Undo restores the previous settings.

Controller Range is the Traktor value to match or scale. MIDI Range is the value sent to the controller, from 0 to 127 for Note/CC feedback. Equal endpoints are valid. Blend scales continuous feedback between the endpoints; leave it off when a controller uses separate MIDI values as colour codes. Output Invert is independent of an input mapping's Invert setting.

The MIDI section shows the device's output port and lets you set channel, Note/CC and number. Check these against the controller's MIDI documentation: a pad's input address and LED output address may differ. Learn captures an address but does not establish which colours the hardware supports. Traktor sends feedback when it runs the exported mapping; SXM does not send live LED feedback.

## Hotcue example

For the reported S7 configuration:

1. Add OUT → Hotcue 1 Type and assign the appropriate deck and pad output address.
2. Set Controller Min **0**, Controller Max **0**.
3. Set MIDI Min **0**, MIDI Max **1**; set Blend and Output Invert to the settings used in your working Traktor mapping.
4. Apply LED, export, and inspect the result in Traktor.

The recipient tested the exported mapping on a DJM-S7 and confirmed **1 = blue**, **12 = cyan / light blue**, and LED off after cue deletion, with no flickering or stuck LEDs. Supplied photos support the two colour observations. The pad briefly turns white when pressed and returns to the mapped colour on release; the cause of that flash is unconfirmed. These results are specific to the tested S7 setup: **1 is not a universal blue code**.

## Different colours for cue types

The condition menus include **Hotcue 1 State** through **Hotcue 8 State**, with a deck or Device Target. The values are:

| State | Controller Range for an individual state |
| --- | --- |
| No Hotcue | −1 to −1 |
| Cue | 0 to 0 |
| Fade-In | 1 to 1 |
| Fade-Out | 2 to 2 |
| Load | 3 to 3 |
| Grid | 4 to 4 |
| Loop | 5 to 5 |

Duplicate the OUT row for each state you want to represent. Set its matching Hotcue State condition and equal Controller Range endpoints, turn Blend off, and enter the hardware's MIDI colour value. Add an explicit No Hotcue rule using your hardware's off value. State conditions prevent competing colour rows from all driving the pad. Keep the deck and Hotcue number consistent across each group of rules.

Colour codes, alternative Note/CC addresses and off/brightness behaviour depend on hardware. Consult the controller's MIDI documentation and test transitions, cue deletion, track changes and modifier layers in Traktor. Numeric mapping remains available without a device colour profile.

## Playback and loop conditions

Both IN and OUT rows can use **Deck Play** (the Play/Pause state) and **Is In Active Loop** in either condition slot. Choose the condition, its deck or Device Target, then its value: **Off/On** for Deck Play, or **0/1** for Is In Active Loop (0 = off, 1 = on). These match Traktor's choices and work with any controller's supported MIDI mappings. For example, Deck Play → Deck A → On makes a row depend on Deck A playing.

Changing a condition's target retains its value. Switching to either of these condition types starts at 0 (Off). Imported conditions that SXM does not recognise keep their original identifier, target and value.

## Multiple selections and compatibility

Mixed fields show **Mixed**. Apply changes only fields you actually edit; it preserves the other values on every selected mapping. Batch Controller Range editing requires a matching known value domain and encoding. MIDI endpoints and flags can be edited across other compatible OUT selections. Select only OUT rows to edit LED settings.

Known Boolean, Hotcue, Modifier and supported continuous command families have range hints and creation defaults. Other imported outputs retain their numeric encoding without guessed command limits. Unknown encodings have read-only Controller Range fields; independently supported MIDI/flag fields remain editable. Incomplete native LED records stay read-only to avoid inventing missing data. Opening a mapping does not normalize its settings.

Copy/paste, duplication and deck cloning retain LED settings. Cloning Deck A to another deck updates Deck A conditions while preserving Device Target conditions.

This editor handles feedback exposed through SXM's supported Traktor MIDI mappings. It does not add arbitrary HID, NHL, SysEx, automatic RGB conversion, live LED previews or a controller palette library.
