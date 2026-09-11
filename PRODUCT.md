# Product context

## Register
Product: native macOS editor for Traktor MIDI controller mappings.

## Users and purpose
DJs and controller mapping authors maintain hundreds of input and LED output mappings. Their work depends on readable comments, dense tables, predictable selection, precise values and safe TSI roundtrips. Source: README and the existing editor.

## Design principles
Preserve mapping details; make bulk scope explicit; provide Undo; keep frequently used operations compact and discoverable. Shared controls can be intentional, so red assignment highlights identify relationships without blocking edits. Follow native macOS interaction and keyboard conventions. Avoid ornamental dashboards or large cards that reduce useful table space.
