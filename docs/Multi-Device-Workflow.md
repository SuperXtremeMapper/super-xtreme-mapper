# Multi-device workflow and UX direction

## Functional foundation

A document contains mapping devices, each with its own rows, ports and controller profile. Physical MIDI sources are assigned separately, so mapping can happen offline and several mapping devices can deliberately share hardware.

The existing editor now has a device picker and **Manage devices…** entry. Selecting a device filters the table and establishes where new mappings go. **All devices** keeps the combined view. Add and paste use the explicit device, a single selected owner, or the sole device; ambiguous destinations produce an error instead of choosing the first device.

Management exposes add, label/port editing, duplicate, delete, copy/move selected rows, and separate-device TSI export. Document mutations use Undo. Transfer displays address overlap before the user chooses Copy or Move; existing destination mappings are retained. Controller profile selection, assistant capture and wizard launching use explicit device context.

Traktor's device type and user label are different fields. The editable label is stored in the device comment (DDIC). The device type remains a Traktor registry name, such as Generic MIDI. Arbitrary labels must not replace the registry name.

MIDI learning selects a physical source by saved port name or by an explicitly chosen endpoint for the current session. A selected endpoint is pinned for capture and reconnect; an unavailable or ambiguous route does not switch to another controller. Endpoint choices are session state; exported TSI files use port names, so identical hardware names still require checking port assignments in Traktor. Only one learning workflow owns MIDI capture at a time.

## Recommended next UI iteration

Keep the current dense table and inspector. Add a collapsible device list to the left, approximately 180–220 points wide, with **All devices** first and each mapping device below it. Each row shows its label and mapping count. A secondary line shows the assigned input or an explicit Offline / Input not set state. Connection status needs an icon and text, not color alone.

Selecting a device should update the table, inspector context, creation destination and assistant destination together. In All devices, add a compact Device column so every mapping's ownership is visible. Existing MIDI and command columns should retain their widths where possible. Device labels may repeat; include a distinguishable instance label in navigation.

The inspector should have a device settings section for label, profile and input/output assignments. Keep it collapsed while editing mappings. Add device should create a valid Generic MIDI group immediately and focus its label. Profile selection is optional and should not block manual mapping.

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

The functional controls are a baseline for this exploration. The sidebar, persistent Device column, richer connection status and contextual transfer menus are proposed UI work, not implemented visual redesigns.
