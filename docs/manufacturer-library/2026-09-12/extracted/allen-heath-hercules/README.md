# Allen & Heath, Hercules and Euphonia extraction

Stage 1 manufacturer evidence only. Hardware has not been tested. Existing profiles and application code are unchanged.

| Model | Normalized bindings | Issues |
|---|---:|---:|
| DJControl Inpulse 500 | 786 | 13 |
| Euphonia | 76 | 1 |
| Xone:92 Mk2 | 6 | 1 |
| Xone:96 | 76 | 1 |
| XONE:K1 | 160 | 4 |
| XONE:K2 | 274 | 6 |
| XONE:K3 | 276 | 8 |

Total: 1,654 normalized bindings. Sources use original catalogue hashes. All seven datasets pass the shared model validator, including source hashes and evidence-file existence.

Complete protocol text is retained with original PDF page markers. K3 diagrams are retained in the original archive and OCR text is supplied; spatial control associations come from the existing profile with original evidence locators, not OCR position inference. K1/K2/K3 existing profile associations and mode configurations are recorded.

Remaining normalization gaps: Inpulse aggregate meter CC thresholds, malformed browser LED rows, ambiguous or conflicting source addresses listed in issues. K2 conflicting pot-switch send labels are excluded. K-series custom-map/velocity limitations remain explicit. Xone92 transport byte sequence and optional CC94 bounds are not invented. Euphonia has a transmit-only chart; channel 1 comes from status bytes 90/B0. Xone96 selectors are discrete note positions.

`extract.py` regenerates only this directory from the archived inputs.

K2 quarantine detail: the existing `pot.switch.2.3` profile has amber send note 82 and green send note 118. The send diagram on PDF page 14 prints A#2 alongside Bb5/Bb8; the existing profile resolves the intended values using the page 17 return diagram and pages 19–20 conversion table. This evidence dataset conservatively excludes those two send records instead of promoting that correction. The corresponding return records remain, with their independent original provenance. The existing runtime profile is unchanged.
