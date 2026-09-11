# Controller export round trip and file dialogs

## Result

The rebuilt editor-feedback preview successfully opened and saved a real controller-only export from Traktor Pro 4.5.1 (21). Traktor then imported the saved copy and displayed the edited comment. A second source-preserving file also imported with the first two commands in the requested swapped order.

## Native source and fix

Controller Manager → Edit → Export produced one controller with 82 mappings. Even this controller-only file contained 8,157 unused MIDI definitions, one unknown frame, two extra XML entries, and a noncanonical DDIF value. The previous ordinary writer refused a comment edit because regenerating that file would discard source data.

The new source patcher accepts only comments and order changes to existing mappings in the same devices. It preserves original MIDI binding headers, opaque frames, unused definitions, noncanonical metadata, and XML outside the unique Controller Value attribute. It replaces comment bytes and moves whole mapping frames, adjusting ancestor lengths. Subsequent save receipts refresh the source envelope while retaining model identity, so repeated saves and undo use the latest source bytes.

Changes to commands, MIDI assignments, settings, device metadata, insertion/deletion, or unsupported/ambiguous source layouts still use the existing preservation checks. This is not general lossless editing of arbitrary TSI content.

## Validation

- Full automated result: **732 passed, 0 failed, 0 skipped**. Result bundle: `/tmp/sxm-preserve-controller-tests/Logs/Test/Test-XtremeMapping-2026.09.12_00-25-18-+0400.xcresult`; log: `/tmp/sxm-preserve-full.log`.
- Independent review of source patching, writer dispatch, document receipt rebasing, and tests found no actionable data-loss or safety issues.
- New synthetic regressions check exact expected binary/XML, opaque fake CMAS bytes, original MIDI bindings, unused definitions, DDIF, XML attribute variation, unsupported edits/topologies, repeat saves, and undo to exact original bytes.
- A temporary private native-fixture test retained all 82 rows and the same preservation risks. An independent byte audit confirmed that only the intended comment, row swap, ancestor lengths and Controller Value changed. No private fixture or fixture-specific test was committed.
- Clean preview build succeeded with signing disabled, then a separately identified ad-hoc preview was produced. Temporary diagnostic instrumentation was removed.
- GUI: opened the controller export, edited the first row comment to `SXM GUI CONTROLLER VALIDATION`, saved `K3-controller-GUI-edited.tsi` through normal Save As, and imported it through Traktor Controller Manager → Add → Import from disk. Traktor displayed that comment on Modifier #1 and its original Button/Hold, Ch15 Note C1 assignment.
- Imported `/tmp/K3-controller-sourcepatched.tsi` separately; Traktor displayed Play/Pause before Modifier #1, confirming saved order. GUI keyboard row movement was not confirmed in this session; this reorder was generated through the tested writer path.
- Native Save As also saved the synthetic 504-row document to a separate file.

## Dialog investigation

An initial Open panel showed a selected, correctly typed TSI but disabled Open. Instrumentation confirmed a recognized URL and document class, and the main thread was idle. A minimal native file chooser worked. Cancelling/reopening the preview chooser then worked, and a fresh rebuilt preview successfully opened the controller export and showed an enabled Save button.

Some automated clicks used stale accessibility state; screenshots and fresh state showed differences. Traktor itself later returned `noWindowsAvailable` for coordinate input until its test instance was restarted. These are observed automation limitations; no application root cause was established, so no speculative dialog code change was retained. The successful Open/Save As checks supersede the earlier unverified result without proving the original symptom cannot recur.

The native Save As sheet exposes **Keep changes in original document**. During validation the temporary source export also acquired the comment; it is not retained as an untouched source fixture. User Traktor settings were separately backed up before testing.

## Cleanup

Traktor, the preview, and the temporary panel probe were closed. Traktor's settings were restored byte-for-byte from this session's pre-test backup; SHA-256: `31e6ddb2479e02d3813f4682560875f1866e18078dffd7f108471040eb454484`. Temporary copies remain under ignored `build/validation-0912` and `/tmp` for local evidence. The installed application was not replaced. No release was published.
