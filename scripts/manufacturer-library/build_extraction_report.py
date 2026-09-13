#!/usr/bin/env python3
"""Build the local stage-one evidence index after validation succeeds."""
import hashlib
import json
from collections import Counter
from pathlib import Path
from validate_extractions import validate_model, validate_catalogue_coverage

ROOT=Path(__file__).resolve().parents[2]/'docs/manufacturer-library/2026-09-12'
OUT=ROOT/'extracted'

def main():
    entries=[]
    for path in OUT.rglob('*.json'):
        data=json.loads(path.read_text())
        if isinstance(data,dict) and data.get('status')=='documented-extraction': entries.append((path,data))
    entries.sort(key=lambda pair:(pair[1]['manufacturer'],pair[1]['model']))
    errors=validate_catalogue_coverage([d for _,d in entries],json.loads((ROOT/'catalogue.json').read_text()))
    for path,data in entries: errors.extend(f'{path.name}: {e}' for e in validate_model(data,ROOT))
    if errors: raise SystemExit('\n'.join(errors))
    index=[]
    for path,data in entries:
        index.append(dict(manufacturer=data['manufacturer'],model=data['model'],file=str(path.relative_to(OUT)),sha256=hashlib.sha256(path.read_bytes()).hexdigest(),bindings=len(data['bindings']),directions=dict(Counter(b['direction'] for b in data['bindings'])),app_support=dict(Counter(b['app_support'] for b in data['bindings'])),issues=dict(Counter(i['severity'] for i in data['issues'])),scope=data['scope'],hardware_tested=False,raw_evidence=[dict(file=r['file'],sha256=hashlib.sha256((OUT/r['file']).read_bytes()).hexdigest()) for r in data['raw_evidence']]))
    total=sum(e['bindings'] for e in index)
    (OUT/'index.json').write_text(json.dumps(dict(schema_version=1,stage=1,models=len(index),normalized_bindings=total,runtime_profiles_added=0,entries=index),indent=2)+'\n')
    lines=['# Stage 1 extraction report','',f'Prepared evidence datasets for all **{len(index)} ready-for-extraction candidates**, containing **{total:,} normalized bindings** and complete protocol text. These include the three existing K-series profiles; **no new runtime profiles are installed**. A binding count includes separate modes, banks, channels and directions, not just physical controls.','',
    'Claude’s Assistant presentation changes at `67adb09` were reviewed on local `main`. They use the editor’s amber styling, shared controls, typography, notices and panel treatment. This extraction does not change the Assistant, conversation, edit-review or Undo code.','',
    '## Coverage','', '| Manufacturer | Model | Bindings | Conflict records | Dataset |','|---|---|---:|---:|---|']
    for e in index:lines.append(f"| {e['manufacturer']} | {e['model']} | {e['bindings']:,} | {e['issues'].get('conflict',0)} | [JSON]({e['file']}) |")
    lines += ['', '## How to interpret the results','',
    'Every normalized binding cites an archived source and a page or section. Original source hashes are checked against the candidate catalogue and files on disk. The index also records hashes for the extracted datasets and protocol text. Manufacturer documentation is the evidence standard for this stage; no hardware testing is claimed.','',
    'The runtime profile schema currently has a global MIDI channel and a small set of K-series layers, colors and encodings. Most new records therefore require an adapter before SXM can use them. Explicitly retained modes, ports, compound values, RGB/palette behavior and SysEx descriptions must not be flattened into that schema.','',
    'Conflict counts are issue records, not numbers of physical controls. Some record historical diagram inconsistencies with independently supported bindings retained. Other issues quarantine multiple bindings. The per-model JSON identifies the excluded entries and their evidence.','',
    '## Remaining work by model','']
    for _,d in entries:
        lines.extend([f"### {d['manufacturer']} {d['model']}",'',d['scope'],''])
        for i in d['issues']:
            evidence='; '.join(f"{e['source_id']}: {e['locator']}" for e in i['evidence'])
            lines.append(f"- **{i['severity'].capitalize()}:** {i['description']} Evidence: {evidence}.")
        lines.append('')
    lines += ['## Verification','',
    '- Exact coverage of the catalogue’s 26 candidates; no partial or documentation-only candidates promoted.',
    '- Original source hashes, candidate/source association, unique binding identities, channel and data-byte ranges, evidence references and raw artifacts validated.',
    '- 16 focused Python checks cover validation failures and selected source facts: FLX4 base/Shift and paired tempo direction, APC mini channel numbering, LC6000 scrub exclusion, and DJM-A9 channel-strip identity.',
    '- Baseline application run: 846 XCTest tests and 62 Swift Testing tests passed (908 total). The separate UI-test runner failed to initialize macOS automation before running its tests. A follow-up unit-only launch stalled and was cancelled; no additional pass is claimed.',
    '- Selected original charts were visually inspected and an independent extraction review was performed. These checks do not constitute an exhaustive audit of every binding.',
    '', '## Recommended next step','',
    'Adapt the documented subsets into the runtime library, starting with the required channel/mode/encoding representation and tests. Show coverage and exclusions explicitly. Resolve conflicting rows separately from supported controls. The second batch of 21 partial candidates and the 21 documentation-only candidates remain deferred.','',
    'See [format and use](README.md), [machine index](index.json), [validation results](validation.json), and [extraction contract](CONTRACT.md).','']
    (OUT/'REPORT.md').write_text('\n'.join(lines))
    print(f'Wrote report and index: {len(index)} models, {total:,} bindings')

if __name__=='__main__':main()
