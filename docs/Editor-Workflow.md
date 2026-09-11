# Editing large mappings

These features are available in the editor-feedback preview.

## Replace text in comments

Select the mappings to edit, then choose **Edit Selection → Replace in Comments…** (also available by right-clicking). Enter the text to find and its replacement. The preview shows only comments that will change. **Match case** limits matches to the same capitalization. Leave the replacement empty to remove the matching text. Apply performs one undoable change. The regular search box already searches mapping and device comments.

## Change Hotcue Type commands

Select one or more Hotcue Type OUT mappings, then choose **Edit Selection → Change Command…**. Pick Hotcue 1–8 Type and review the changes. MIDI, conditions, comments and LED settings remain intact. This first version supports the compatible Hotcue Type output family; other command families are not enabled.

## Arrange rows

Enable **Manual Order** to display saved document order. Clear search and category/I/O filters before moving rows. Drag rows to their new position, or use **Move Up / Move Down** from Edit Selection or the context menu. Keyboard shortcuts are Option-Command-Up and Option-Command-Down. Multiple selected rows retain their relative order and move within one device. Sorting a column switches off Manual Order. Undo restores the previous order.

Mod 1 and Mod 2 start compact and can shrink to their former 50-point width. Drag their column boundaries wider for longer conditions.

## Shared MIDI highlights

Select a mapping to see every row sharing its MIDI assignment in red, including the selected row. The same highlighting appears immediately after assigning an already-used control. Matching includes device, IN/OUT direction, MIDI channel, and Note or CC number. Notes and CCs with the same number are distinct. Unassigned rows are excluded. The link icon and count explain the relationship; sharing does not prevent editing or saving.

## Clone FX mappings

Select FX mappings and choose **Edit Selection → Clone FX Unit…**. Choose the source and destination explicitly. MIDI, conditions, comments and settings remain intact. Exact duplicates in the same device are skipped. Deck cloning still translates Deck A and Remix Deck A slots; its help explains why FX, Global, Device Target and other deck rows are excluded.

## Loop values and MIDI Learn

Loop Size Selector now has labelled choices from 1/32 to 32 and writes Traktor's integer selectors. Unfamiliar imported selectors remain visible and retain their original bytes until edited. MIDI Learn keeps an existing interaction mode when it is valid for the detected controller type; output mappings retain LED/Output behavior.

## Saving native Traktor exports

For supported native exports, changing comments or rearranging existing rows now preserves the original file structure, including unused MIDI definitions and extra Traktor metadata. Save and Save As can use this path without a converted export. Adding/removing rows or changing commands, MIDI assignments, device information, or other settings still uses the existing preservation checks and may require a converted copy.

In the macOS Save As sheet, review **Keep changes in original document** if you want the source export to remain unchanged.
