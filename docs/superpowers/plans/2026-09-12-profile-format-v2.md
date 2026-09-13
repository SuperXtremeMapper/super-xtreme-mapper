# Controller profile v2 integration

Approved scope: extend the runtime format, prove representative Xone96/FLX4/LaunchpadX, integrate documented subsets of all remaining stage1 candidates, show coverage. Defer second21. Work on main preserving Assistant UI. No TSI format changes or automatic hardware configuration.

## Shared implementation contract

Preserve immutable existing schema1 K profiles exactly. Add schema2 optional fields; keep existing memberwise initializer callsites compatible with defaulted var additions.

ControllerProfile:
- `var ports: [Port]? = nil`; Port {id:String, name:String}
- `var coverageNotes: [String]? = nil`
Binding existing number becomes Int? (nil required for compound/other).
Add defaulted optional fields:
- channel:Int? nil uses explicitly configured global channel, fixed channel takes precedence
- modeID:String? nil applies all modes
- portID:String? nil no port restriction
- context:String? literal manufacturer mode/condition description
- support:BindingSupport? enum available, documentedOnly; nil is legacy available
- components:[Component]?; Component {kind:Kind, number:Int, role:String}
- semantics:String? complete documented values JSON rendered as text, not executed
Extend Kind with compound, other. Extend Encoding with documented, relativeBinaryOffset, paired14Bit, palette, unsupported. Existing cases unchanged.
Only .note/.controlChange with support available (or schema1 nil) resolve to generic MIDI assignments. Compound/other and documentedOnly return actionable unresolved reasons; never flatten paired messages into scalar assignments. Value bounds remain 7-bit scalar; compound range retained in semantics.
ControllerConfiguration add `var portID:String? = nil`. Contextual override add portID optional, persisted and matched, so captured address cannot leak between ports. Metadata validation validates known port IDs while preserving unavailable/unknown references with warnings. JSON roundtrip keeps fields.
Resolver filter modeID and portID before resolving. Schema2 layer is base; distinct source contexts are named control variants rather than misusing K layer colors. Schema1 K routing remains unchanged. Fixed binding channels beat global config channel. Unsupported records are visible but blocked from generic resolution.

## Profile generation contract

Generator writes schema2 resources for exactly23 new models from evidence datasets, alongside 3 unchanged K resources. Each resource filename `<manufacturer-model-slug>-1.0.0.json`; output manifest `controller-profile-catalogue.json` {resources:[filenameWithoutExtension,...]} contains3existing+23new. Library loads manifest bounded; no automatic unpinned versions.

Profile fields unchanged with schemaVersion2; defaultChannel explicitly documented or1 used as UI starting value with coverage note asking confirmation (never claim guessed default documented). One `documented` mode and `factory` unitMap allowed; source modes/context must distinguish controls so bindings with mutuallyexclusive contexts never silently combine. Distinct physical controls/sections/decks retained in names/IDs. Port declared only from explicit evidence; else unset and explain manual device-port selection.

Convert source bindings to typed scalar Note/CC where clear, keeping all values/encoding/context in semantics. compound/other documentedOnly. Scalar addresses may resolve for lookup even when complex values cannot be generated; coverage must say address lookup only, no inferred lighting/encoder semantics or generated initialization. Unknown or ambiguous addresses remain issues/limitations; don't invent numeric zero. Original sources/evidence stable hashes/pages. Include every extracted record either as a binding or explicit coverage exclusion, and keep source raw-value text. Compact JSON to bounded resource sizes. Derived grouping deduplicates identical facts, never drops distinct mode/channel/direction/value context.

## Ownership and checks

Core agent: model, library, resolver, configuration, workflow/metadata validation and their tests.
Data agent: generator, resources/manifest and data integration tests only.
UI agent: ControllerProfileSheet and coverage helper/tests, no Assistant changes.
Coordinator: baseline, integration, report/docs, independent review and final tests.

Tests: legacy K behavior and bytes unchanged; schema2 invalid references/channels/compound validation; exact mode/port isolation; fixed channels; unsupported paired data refusal; JSON roundtrip and contextual overrides. Representative source facts and all26 bundle load. UI identifies address lookup versus unsupported documented controls. Run unit target, report any existing UI-runner environment failure separately.

## Completion

- [x] Schema2, strict validation, cached catalogue, indexed resolver and port-aware metadata/overrides.
- [x] 23 new resources plus unchanged3K, preserving all27,025 new source records.
- [x] Representative and all-binding integration checks.
- [x] Coverage UI, context selection fixes and readable names.
- [x] Independent core/data/UI reviews; findings resolved.
- [x] 927 app unit tests and25Pythonchecks passed.
- [x] Integration report and DJ-controller-first list prepared. No second-batch extraction, commit or push.
