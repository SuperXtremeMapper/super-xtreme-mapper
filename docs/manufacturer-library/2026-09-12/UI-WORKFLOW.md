# Controller library: intended user workflow

The library supplies physical-control identity and MIDI protocol evidence. The open TSI supplies the Traktor commands, decks, modifiers and behavior. Selecting a profile never installs a ready-made Traktor mapping or reconfigures hardware.

## Current implementation

Open Controller… above the mapping table, choose the mapping device and a profile, and confirm the applicable channel/mode/port. Search a known control and preview its matching mapping rows. Apply the profile as an undoable metadata change. Sources and coverage are available in the same panel. This is currently a detailed inspection surface; it is not the intended everyday destination for browsing thousands of protocol records.

The new batch has explicit Partial MIDI coverage and Documentation only labels. Documentation-only profiles show manual links and explain the missing addresses instead of presenting an empty control editor. The existing row MIDI Learn can capture an address; a row comment can identify the control locally. This does not add a manufacturer fact to the shared library. The Assistant snapshot carries the coverage limitation so it cannot reasonably treat missing controls as established.

## Proposed later UI pass

1. Choose the physical controller once in device setup.
2. Work normally in the mapping table or Assistant, with controller identity available as context.
3. Open optional Controller details only for setup, evidence, gaps and corrections.

For example, ask what a controller's Play button currently does. Where the profile identifies its MIDI address, SXM can find matching TSI rows and explain their commands and conditions. Ask to change that action and use the existing edit review and Undo. Where the address is missing or the hardware uses a custom template, SXM should say what is unknown and offer learning or verified template selection.

Moving selection into device setup, improving inline physical-control names, and a graphical controller surface remain later UI work. The Assistant layout is unchanged by this evidence batch.

## Community mappings

A future community-template source should retain author, mapping version, source URL and required controller configuration separately from manufacturer evidence. A hardware editor template plus labeled diagram can identify controls; a TSI alone identifies MIDI-to-software assignments and may not identify the physical surface. Coverage and provenance are separate: a community template may be comprehensive for one setup while still not representing the factory map.
