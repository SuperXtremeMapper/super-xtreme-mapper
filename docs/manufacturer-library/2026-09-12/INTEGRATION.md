# Profile format v2 integration

The current implementation bundles 26 exact-version profiles: 23 new manufacturer-derived profiles and the three existing K-series profiles, preserved byte-for-byte. Work remains on local main; the Assistant presentation files from Claude’s pass are unchanged.

## Working scope

- Select a profile for a mapping device, confirm its operating context, and search documented action variants.
- Resolve supported Note/CC addresses with fixed-channel precedence and explicit mode/port isolation.
- Find matching mapping rows and attach profile evidence to Assistant explanations.
- Save profile configuration and port-specific overrides in JSON with existing Undo/review behavior.
- Inspect advanced messages and source conflicts without converting them into incorrect scalar assignments.

Address lookup is not automatic hardware setup, MIDI output generation, palette programming, or high-resolution TSI support. Paired and other advanced messages remain documented-only. Native TSI commands and preservation behavior are unchanged.

## Bundled coverage

| Manufacturer | Model | Address lookup bindings | Documented-only bindings |
|---|---|---:|---:|
| Akai Professional | APC mini mk2 | 1,258 | 0 |
| Akai Professional | APC40 mkII | 1,179 | 0 |
| Allen & Heath | Xone:92 Mk2 | 4 | 2 |
| Allen & Heath | Xone:96 | 76 | 0 |
| AlphaTheta | CDJ-3000X | 90 | 0 |
| AlphaTheta | DDJ-GRV6 | 1,604 | 43 |
| AlphaTheta | Euphonia | 75 | 1 |
| AlphaTheta | OMNIS-DUO | 351 | 8 |
| AlphaTheta | XDJ-AZ | 1,426 | 16 |
| Denon DJ | LC6000 PRIME | 76 | 2 |
| Faderfox | UC4 | 8,244 | 0 |
| Hercules | DJControl Inpulse 500 | 724 | 62 |
| Novation | Launch Control XL 3 | 223 | 0 |
| Novation | Launchpad Mini MK3 | 566 | 0 |
| Novation | Launchpad Pro MK3 | 741 | 0 |
| Novation | Launchpad X | 566 | 0 |
| Pioneer DJ | DDJ-FLX10 | 2,934 | 78 |
| Pioneer DJ | DDJ-FLX4 | 673 | 21 |
| Pioneer DJ | DDJ-REV5 | 2,697 | 49 |
| Pioneer DJ | DDJ-REV7 | 1,123 | 41 |
| Pioneer DJ | DJM-A9 | 161 | 3 |
| Pioneer DJ | DJM-S11 | 464 | 31 |
| Pioneer DJ | XDJ-RX3 | 1,397 | 16 |
| Allen & Heath | Xone:K1 | 160 | 0 |
| Allen & Heath | Xone:K2 | 276 | 0 |
| Allen & Heath | Xone:K3 | 276 | 0 |

Total: 27,737 binding records, including 27,364 address lookups and 373 documented-only messages. Modes, ports, channels, directions and value contexts create multiple records for one physical control. These are not hardware-tested control counts.

## Format and reliability

Schema 2 adds fixed channels, explicit mode and port references, message context, support status, compound components and original source semantics. Schema 1 K profiles remain accepted unchanged. Invalid references and non-scalar flattening are rejected. The main catalogue is validated once and cached, with indexed control lookup for explanation requests.

The 23 generated profiles retain all 27,025 source binding records. Source hashes and page/section locators remain attached. The original complete extraction metadata and conflicts remain in the [evidence library](extracted/REPORT.md). Manufacturer ambiguity is not silently corrected.

UC4 has explicit factory setup selection and Launchpads expose Programmer mode. The Akai/Pioneer datasets retain descriptive contexts where a trustworthy executable mode model is not yet established. These named variants describe source conditions; they do not detect live hardware state. Per-device OS MIDI routing remains separate from a protocol’s logical port identity.

## Validation

All **927 application unit tests** passed (865 XCTest + 62 Swift Testing). All **25 Python extraction/generation checks** passed. The native development app listed all 26 models and displayed the FLX4 address-lookup and documented-only coverage.

Integration tests exercise every generated binding through the resolver, source references, fixed-channel precedence, compound refusal, operating setup and port isolation, JSON configuration roundtrips, K-series details, and the Assistant explanation path. Legacy K profile bytes and Claude’s two Assistant presentation files are unchanged. No hardware test or automated UI-suite pass is claimed.

The new resources total 36,818,678 bytes; the largest is 7,757,274 bytes. Generated resources are reproducible with `python3 scripts/manufacturer-library/generate_profiles.py --check`. Changes remain local on main; no commit or remote push was performed.

Independent reviews identified and corrected shared-Akai-mode exclusion, legacy K-series detail display inconsistent with the resolver, and initial selection outside a saved operating context. Control labels and coverage descriptions were simplified after native-app inspection.

## Next review: DJ controllers first

The current batch is integrated including its mixers, as requested. The [priority review](DJ-CONTROLLER-PRIORITIES.md) separates DJ control surfaces, standalone players, performance accessories and mixers. For the next partial-evidence work, start with the 11 Hercules/Native Instruments DJ-controller records; review the remaining categories before starting them. No next-21 extraction has begun.

See [profile documentation](../../../XtremeMapping/docs/Controller-Profiles.md) for configuration and format details.
