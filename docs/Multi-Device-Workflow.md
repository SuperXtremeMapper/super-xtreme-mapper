# Multi-device workflow and UX direction

## Functional foundation

A document contains mapping devices, each with its own rows, ports and controller profile. Physical MIDI sources are assigned separately, so mapping can happen offline and several mapping devices can deliberately share hardware.

The **Devices** toolbar button toggles the collapsible **XXDEVICES** pane on the left. Each compact device row shows its label and a settings gear, using the mapping editor’s background and amber selection. Controller and input status remain available in the row tooltip. **Device settings…** opens management for the selected device. Selecting a device filters the table and establishes where new mappings go. **All devices** keeps the combined view. Add and paste use the explicit device, a single selected owner, or the sole device; ambiguous destinations produce an error instead of choosing the first device.

Management exposes add, label/port editing, duplicate, delete, copy/move selected rows, and separate-device TSI export. Document mutations use Undo. Transfer displays address overlap before the user chooses Copy or Move; existing destination mappings are retained. Controller profile selection, assistant capture and wizard launching use explicit device context.

Traktor's device type and user label are different fields. The editable label is stored in the device comment (DDIC). The device type remains a Traktor registry name, such as Generic MIDI. Arbitrary labels must not replace the registry name.

MIDI learning selects a physical source by saved port name or by an explicitly chosen endpoint for the current session. A selected endpoint is pinned for capture and reconnect; an unavailable or ambiguous route does not switch to another controller. Endpoint choices are session state; exported TSI files use port names, so identical hardware names still require checking port assignments in Traktor. Only one learning workflow owns MIDI capture at a time.

## Device navigation and controller selection

The pane is 220 points wide and starts collapsed. **Devices** opens it without interrupting editing with a dialog. Selecting a device sets the mapping scope and creation destination. **All devices** restores the combined view. Collapsing the pane preserves the selected device; the scope button above the mappings table reopens it.

**Add device** creates and selects a valid Generic MIDI device with a unique default label, then opens the existing controller chooser for that device. **Keep generic MIDI** dismisses the chooser without removing the device. Each device’s gear opens **Device Settings**, where the Controller row shows the current model and a **Choose…** or **Change…** action. The pane has no separate settings or controller text actions. The chooser is pinned to the device selected when it opens; it no longer contains a second device switcher.

**Device Settings** retains label/port editing, duplication, deletion, row transfers and export. Profile choice remains optional. Keyboard navigation works in the device list, and Delete in that list does not delete selected mapping rows.

## Further UI opportunities

In All devices, add a compact Device column so every mapping's ownership is visible. Existing MIDI and command columns should retain their widths where possible. Device labels may repeat; a distinguishable instance label would improve navigation.

Learning should say **Learning from Left controller** next to the action. If disconnected, keep the route visible and offer a source picker. Do not switch automatically. For multiple identical controllers, show distinguishable endpoint instances and allow the user to identify them by moving a control before committing the route. That identification preview must not write mappings.

Copy and Move should be available in the table's context menu with a destination submenu. For address overlaps, show the source rows, destination and a count of existing matches. Keep-both is a legitimate choice; matching addresses can be intentional. Replacing existing mappings would be a separate, explicit future option.

## Alternatives and trade-offs

| Navigation | Benefit | Cost |
| --- | --- | --- |
| Collapsible device list (recommended) | Ownership, connection and empty devices remain visible | Uses horizontal space |
| Toolbar picker only | Fits the current layout with little disruption | Hides device inventory and connection state |
| Device tabs | Fast for two or three devices | Long labels and larger setups overflow; All devices is less natural |

## Scenarios to review in the UI prototype

1. Create two empty devices, label them Left and Right, then add a mapping to Right without first selecting a row.
2. Connect two controllers sending the same channel and note. Learn one on each without cross-assignment.
3. Duplicate a device for a second controller; clearly prompt for its physical input while retaining mappings/profile.
4. Work in All devices and select rows across owners. Bulk edits show their scope; creating a mapping requires a destination.
5. Disconnect a controller during Learn. The selected route remains visible and captures nothing from the other controller.
6. Move rows to another device, inspect overlap, apply, Undo, and verify both owners and labels.
7. Save and reopen a multi-device TSI, then export one device to a new file and reopen it independently.

The sidebar and combined Devices/controller workflow are implemented. A persistent Device column, richer connection controls and contextual transfer menus remain proposed UI work.
