# Reviewed AI import repair

Choose **File → Import JSON…**. Local validation runs first. A rejected file may offer **Optional AI repair** when its contents can be safely prepared for the service.

Expand the option, read the disclosure, and explicitly agree before choosing **Send JSON for AI Repair**. This uses the stored Anthropic API key and Sonnet. Mapping text, including names and comments, is sent to Anthropic; retained TSI preservation data remains on your Mac. Opening an import never sends an AI request.

A successful proposal shows the exact **Before** and **After** text for each edit. These changes are computed against the original file locally. All proposed edits must pass the normal JSON schema, command catalogue and TSI preservation checks before they appear as an acceptable repair.

Choose **Accept Repair** to update the import review, then inspect any warnings and choose **Import** to open a new untitled mapping. These are separate actions. **Discard Repair** restores the original review. **Stop Repair** rejects a pending response. The original file is never overwritten.

## Initial scope

Repair supports unambiguous scalar/schema corrections and source-free punctuation mistakes that can be safely isolated, such as trailing commas or missing commas before object keys. It does not infer missing MIDI controls or invent commands. Ambiguous syntax, unfamiliar nested structures, damaged preservation sections and oversized files keep local diagnostics and require a local correction or fresh export first.

Requests are bounded to 8 MiB of original input and 96 KiB of visible JSON after redaction. A proposal contains at most 16 non-overlapping exact edits, with at most 4096 UTF-8 bytes per before/after value and 32 KiB in total. Repeated text must be disambiguated by sufficient surrounding context. Invalid, ambiguous, cancelled or stale proposals cannot become imported documents.

A Keychain authorization prompt may need your attention on your Mac. Assistant and API-key settings remain responsive while waiting; closing or cancelling the session prevents a late lookup from restoring its credentials.
