# Pioneer DJ / AlphaTheta stage 1 extraction

All 11 source-ready models are represented. SLAB and Euphonia are excluded from this batch. Complete protocol PDF page text and ruled-table evidence are retained for each model. These are review datasets, not profiles; no hardware testing or application integration is claimed.

| Model | Bindings | Device → host | Host → device | Compound bindings | Conflict rows | Other excluded rows |
|---|---:|---:|---:|---:|---:|---:|
| CDJ-3000X | 90 | 90 | 0 | 0 | 0 | 0 |
| DDJ-FLX10 | 3012 | 1605 | 1407 | 57 | 0 | 0 |
| DDJ-FLX4 | 694 | 390 | 304 | 21 | 5 | 0 |
| DDJ-GRV6 | 1647 | 926 | 721 | 43 | 0 | 0 |
| DDJ-REV5 | 2746 | 1476 | 1270 | 49 | 11 | 0 |
| DDJ-REV7 | 1164 | 632 | 532 | 41 | 0 | 0 |
| DJM-A9 | 164 | 164 | 0 | 0 | 0 | 0 |
| DJM-S11 | 495 | 313 | 182 | 31 | 16 | 0 |
| OMNIS-DUO | 359 | 268 | 91 | 0 | 0 | 0 |
| XDJ-AZ | 1442 | 834 | 608 | 8 | 0 | 0 |
| XDJ-RX3 | 1413 | 786 | 627 | 8 | 0 | 0 |

Total: 13,226 bindings. Counts expand explicitly listed channels and distinguish direction, mode and modifier contexts; they do not count physical controls.

## Coverage and limitations

- Every ruled-table row containing an explicit Note/CC status is either normalized or referenced in an exclusion issue. Hardware-only controls, explanatory footnotes, channel-allocation matrices and numeric palette/level explanations remain in complete raw protocol evidence. Values preserve the manufacturer semantics as text instead of inventing standardized color or relative-encoder behavior.
- Vertically merged control names are recovered geometrically, including continuation across pages. Combined modifier/trigger cells retain literal source context; this is not a fully executable modifier state machine.
- Paired CC addresses are compound bindings with ordered MSB/LSB components and source-specific bounds. DJM-A9 separate-row TIME components retain explicit component encoding. Jog position/speed semantics remain distinct from scalar knobs.
- All five previously deferred non-conflict rows are now represented: REV5/REV7 slash-separated Note addresses use compound bindings retaining both source-listed addresses without inventing sequence or position association. XDJ-AZ MIC 2 EQ HI uses its explicitly documented decimal address 96 (hexadecimal 60); the blank extracted hexadecimal cell is noted.
- Quarantined contradictions: DDJ-FLX4 five rows; DDJ-REV5 eleven rows, including eight visually verified malformed BASS/PAD3 input rows whose independent output bytes are retained; DJM-S11 sixteen rows. Decimal/status or decimal/hex contradictions are not silently resolved.
- Input channel references are not used to reject explicitly different receive status channels. Channels not specified by a binding row remain null with a note; the channel matrix remains in raw evidence.
- Table evidence stores original and merged-cell-resolved rows. Source locators are one-based page/table/row indices in these files. Original PDFs and original hashes remain authoritative.

## Verification

All 11 datasets pass the shared stage-1 structural/source-hash validator. Source regressions checked FLX4 PLAY/PAUSE normal/Shift note addresses, both directions and channels; tempo 00/20 pairs input-only; CDJ-3000X configurable channel/input-only; DJM-A9 input-only. DDJ-REV5 malformed BASS/PAD3 chart cells were visually inspected (review crop retained). Duplicate semantic rows were consolidated while preserving evidence.

## Physical identity fields

Every binding additionally stores optional `source_group` and `source_figure` strings, preserving physical section and diagram references separately from control labels and modes. Empty strings mean no corresponding source column. Headers and non-protocol tables never update inherited group/figure context. Blank continuation cells follow the preceding protocol section, with DJM-S11 pages 8–9 explicitly identified as TOUCH MIDI SCREEN. DJM-A9 CH1–CH4 TRIM and MIC versus BOOTH MONITOR EQ identity regressions pass.
