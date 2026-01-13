# Known Issues

## Document Save Prompt Not Appearing (UNRESOLVED)

**Status:** Not working - needs further investigation

**Problem:** When the user modifies a document (e.g., adds a mapping) and closes the window, the app returns to the welcome wizard without prompting to save changes.

### What Was Tried

1. **Converted from FileDocument to ReferenceFileDocument**
   - Changed `TraktorMappingDocument` from a struct conforming to `FileDocument` to a class conforming to `ReferenceFileDocument`
   - Updated all views from `@Binding var document` to `@ObservedObject var document`
   - Updated `FocusedValues` to pass document reference instead of binding
   - **Result:** Still no save prompt

2. **Added UndoManager integration**
   - Added `@Environment(\.undoManager) var undoManager` to ContentView, ActionBar, SettingsPanel
   - Created `registerChange()` function that calls `undoManager?.registerUndo(withTarget:handler:)`
   - Called `registerChange()` in all document-modifying functions:
     - `deleteSelectedMappings()`
     - `duplicateSelected()`
     - `pasteSelectedMappings()`
     - `updateSelectedMappings()`
     - `handleDroppedMappings()`
     - `addMapping()` (ActionBar)
     - `addInOutPair()` (ActionBar)
     - `updateEntry()` (SettingsPanel)
     - `updateSelectedEntries()` (SettingsPanel)
   - **Result:** Still no save prompt

### Files Modified

- `XtremeMappingDocument.swift` - ReferenceFileDocument class
- `ContentView.swift` - @ObservedObject + undoManager
- `ActionBar.swift` - @ObservedObject + undoManager
- `SettingsPanel.swift` - @ObservedObject + undoManager
- `EditCommands.swift` - FocusedValue instead of FocusedBinding

### Possible Next Steps to Try

1. **Access NSDocument directly**
   - SwiftUI's DocumentGroup wraps an NSDocument underneath
   - Could try to access it via `NSDocumentController.shared.documents` and call `updateChangeCount(.changeDone)`
   - Challenge: mapping between SwiftUI ReferenceFileDocument and NSDocument

2. **Use Combine to track changes**
   - Subscribe to `mappingFile` changes via `$mappingFile` publisher
   - Trigger change notification when mappingFile changes
   - But need a way to communicate this to the document system

3. **Custom NSDocumentController**
   - Already have `XtremeMappingDocumentController` subclass
   - Could override methods to handle dirty state

4. **Check if snapshot comparison is working**
   - ReferenceFileDocument should compare snapshots to detect changes
   - Verify MappingFile and all nested types properly support comparison
   - May need to make all types conform to Equatable

5. **Debug the undo manager**
   - Add print statements to verify undoManager is not nil
   - Check if undo actions are actually being registered
   - The undoManager might not be connected to the document system properly

### References

- Apple docs on ReferenceFileDocument: https://developer.apple.com/documentation/swiftui/referencefiledocument
- The document uses snapshot comparison to detect changes
- UndoManager is supposed to mark document as edited when undo actions are registered
