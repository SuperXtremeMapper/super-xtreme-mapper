#!/usr/bin/env python3
"""Build pinned v2 browsing/address-lookup resources from the stage-1 evidence.

Run from any directory. No network access and no edits to the immutable K profiles.
Each normalized record is a separate variant: source mode, physical section, channel,
value semantics and direction can never accidentally collapse into another record.
"""
from __future__ import annotations
import argparse
import ast
import hashlib
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
EXTRACTED = ROOT / 'docs/manufacturer-library/2026-09-12/extracted'
PARTIAL = ROOT / 'docs/manufacturer-library/2026-09-12/partial-extracted'
OUTPUT = ROOT / 'XtremeMapping/XtremeMapping/Resources/ControllerProfiles'
LEGACY = ('xone-k1', 'xone-k2', 'xone-k3')
MAX_BYTES = 12_000_000


def compact(value):
    return json.dumps(value, ensure_ascii=False, separators=(',', ':'), sort_keys=True)


def slug(value):
    return re.sub(r'[^a-z0-9]+', '-', value.lower()).strip('-')


def explicit_port(record):
    """Only accept an explicit port field or the literal label 'port N'.

    'MIDI USB interface' and 'rotary switch position USB 1' are NOT port labels.
    Their complete original meaning remains visible in context and semantics.
    """
    value = record['values'].get('port')
    if isinstance(value, (str, int)) and not isinstance(value, bool):
        return str(value)
    matches = re.findall(r'\bport\s+(\d+)\b', record['mode'], re.IGNORECASE)
    return matches[0] if len(set(matches)) == 1 else None


def is_pair(record):
    encoding = record['encoding'].lower()
    return record['message_type'] == 'compound' or 'pair' in encoding or 'msb/lsb' in encoding


def display_context(value):
    """Remove extraction separators/placeholders without changing archived context."""
    parts = [part.strip() for part in re.split(r'\s*\|\s*', value)]
    return ' · '.join(dict.fromkeys(part for part in parts if part and part != '-'))


def display_name(record, channel):
    group = re.sub(r'^\d+[.,]\s*', '', record.get('source_group', '')).strip()
    if group.isupper():
        group = group.title()
    control = record['control']
    label = f'{group} · {control}' if group else control
    context = display_context(record['mode'])
    channel_label = 'Configured channel' if channel is None else f'Channel {channel}'
    direction = 'Input' if record['direction'] == 'device-to-host' else 'Feedback'
    return ' — '.join(part for part in [label, context, channel_label, direction] if part)


def display_exclusion(value):
    # Some archived exclusions are literal extracted PDF table rows. Keep their
    # full original form in the source dataset, not in the app's coverage text.
    if value.lstrip().startswith('['):
        try:
            if isinstance(ast.literal_eval(value), list):
                return 'A chart row with uncertain addresses or conditions; see the cited source.'
        except (ValueError, SyntaxError):
            pass
    return value


def display_issue(issue):
    severity = {'conflict': 'Conflicting information', 'unsupported': 'Not supported',
                'scope': 'Coverage limit'}[issue['severity']]
    message = severity + ': ' + issue['description']
    exclusions = list(dict.fromkeys(display_exclusion(value) for value in issue['excluded_bindings']))
    if exclusions:
        message += '\nNot included: ' + '; '.join(exclusions)
    return message


def build_profile(path):
    data = json.loads(path.read_text())
    partial = data.get('status') == 'partial-extraction'
    if partial:
        assert data.get('coverage_state') in ('partial','documentation-only')
        assert bool(data['bindings']) == (data['coverage_state']=='partial')
    evidence = []
    evidence_ids = {}

    def refs(items):
        result = []
        for item in items:
            key = (item['source_id'], item['locator'])
            if key not in evidence_ids:
                identifier = f'e{len(evidence) + 1}'
                evidence_ids[key] = identifier
                evidence.append(dict(id=identifier, sourceID=key[0], locator=key[1],
                                     verification='manufacturer-documented'))
            result.append(evidence_ids[key])
        return list(dict.fromkeys(result))

    controls = []
    ports = {}
    modes = {}
    configurable_default = {'xone-96': 16, 'xone-92-mk2': 16, 'xone-px5': 16}.get(path.stem)
    for record in data['bindings']:
        reference = refs(record['evidence'])
        mode_id, mode_name = 'documented', 'Documented contexts'
        if path.stem == 'faderfox-uc4':
            match = re.match(r'Factory setup (\d+),', record['mode'])
            if match:
                mode_id, mode_name = 'setup-' + match[1], 'Factory setup ' + match[1]
        elif path.stem.startswith('launchpad-'):
            mode_id, mode_name = 'programmer', 'Programmer mode — MIDI USB interface'
        if mode_id not in modes:
            modes[mode_id] = dict(id=mode_id, name=mode_name, layeredGroups=[], softPickup=False, evidence=reference)
        port_name = explicit_port(record)
        port_id = 'port-' + slug(port_name) if port_name is not None else None
        if port_id:
            ports[port_id] = dict(id=port_id, name='Port ' + port_name)
        number = record['number']
        scalar = record['message_type'] in ('note', 'cc') and type(number) is int and 0 <= number <= 127
        pair = is_pair(record)
        kind = {'note': 'note', 'cc': 'controlChange'}.get(record['message_type'], 'other')
        if pair:
            kind = 'compound'
        elif not scalar:
            kind = 'other'
        available = scalar and not pair
        encoding = 'documented' if available else ('paired14Bit' if pair and 'slash-separated' not in record['encoding'] else 'unsupported')
        if available and record['encoding'] == 'absolute 7-bit':
            encoding = 'absolute7Bit'
        elif available and 'palette' in record['encoding'].lower():
            encoding = 'palette'
        elif available and record['encoding'] == 'relative offset binary pivot 64':
            encoding = 'relativeBinaryOffset'
        binding = dict(direction={'device-to-host': 'send', 'host-to-device': 'receive'}[record['direction']],
                       layer='base', kind=kind, number=number if scalar and not pair else None,
                       encoding=encoding, valueMin=None, valueMax=None,
                       evidence=reference, notes=record['notes'],
                       channel=None if configurable_default is not None else record['channel'],
                       modeID=mode_id, portID=port_id, context=record['mode'],
                       support='available' if available else 'documentedOnly',
                       semantics=compact(record))
        values = record['values']
        if available and type(values.get('min')) is int and type(values.get('max')) is int and 0 <= values['min'] <= values['max'] <= 127:
            binding.update(valueMin=values['min'], valueMax=values['max'])
        components = []
        for component in values.get('components', []):
            if component.get('message_type') in ('cc', 'note') and type(component.get('number')) is int and 0 <= component['number'] <= 127:
                components.append(dict(kind={'cc': 'controlChange', 'note': 'note'}[component['message_type']],
                                       number=component['number'], role=component.get('role', 'source component')))
        for key, role in [('upper_cc', 'upper'), ('lower_cc', 'lower')]:
            if type(values.get(key)) is int and 0 <= values[key] <= 127:
                components.append(dict(kind='controlChange', number=values[key], role=role))
        if components:
            binding['components'] = components
        # Keep paired scalar components as documented controls, including their exact
        # original numeric byte in semantics and as a component, never as a scalar.
        if pair and scalar and not components:
            binding['components'] = [dict(kind={'cc': 'controlChange', 'note': 'note'}[record['message_type']],
                                          number=number, role='source-documented pair component')]
        if pair and len(binding.get('components', [])) < 2:
            binding['kind'] = 'other'
            binding['encoding'] = 'unsupported'
        physical_parts = [record.get('source_group', ''), record.get('source_figure', ''), record['control']]
        physical = ' / '.join(part for part in physical_parts if part)
        name = display_name(record, binding['channel'])
        controls.append(dict(id=record['id'], physicalID='physical-' + hashlib.sha256(physical.encode()).hexdigest()[:16],
                             name=name, aliases=[record['control']], group=record.get('source_group') or 'documented',
                             reservedInModes=[], bindings=[binding], evidence=reference))

    limitations = []
    for issue in data['issues']:
        limitations.append(dict(message=display_issue(issue), evidence=refs(issue['evidence'])))
    # The complete metadata and original exclusion rows remain in the immutable
    # source dataset and extraction index. Runtime coverage stays readable.
    source_refs = [e['id'] for e in evidence]
    limitations.append(dict(message='Based on archived manufacturer documentation. The complete extraction metadata, original excluded chart rows and source files are retained in the manufacturer evidence archive. No hardware testing is claimed.', evidence=source_refs[:1]))
    notes = [
        data['scope'],
        f"Includes {len(data['bindings'])} documented control entries. See coverage limits for {len(data['issues'])} source issues or areas still to be added.",
        'Available controls let you look up Note and CC addresses. Lighting effects, encoder behavior and device setup still require the manufacturer instructions.',
        'Choose the entry matching your control and its mode or condition. Selecting a profile mode does not change the hardware. Paired messages and other complex controls are available to read but cannot be assigned here.',
        'A documented fixed channel takes priority. Otherwise the control uses your selected channel; confirm that it matches the device.',
        'Choose the correct MIDI port on your device. Port restrictions are shown only where the manufacturer explicitly labels a port.'
    ]
    if configurable_default:
        notes.append(f'The documented default channel is {configurable_default}. This device allows a different channel; enter the channel selected on your hardware.')
    else:
        notes.append('Channel 1 is only a UI starting value, not a claimed manufacturer default. Confirm the channel on your device before using entries without a fixed channel.')
    configuration_refs = list(dict.fromkeys(ref for limitation in limitations for ref in limitation['evidence']))
    if not configuration_refs:
        configuration_refs = [evidence[0]['id']]
    if partial:
        notes = [('Partial MIDI coverage: only the listed addresses are established.' if data['bindings'] else 'Documentation only: no control addresses are established from the available sources.')] + data['setup_notes'] + ['Still needed: '+n for n in data['missing_information']] + notes
        if not modes:
            modes['documented'] = dict(id='documented',name='Documented settings',layeredGroups=[],softPickup=False,evidence=configuration_refs)
    profile = dict(schemaVersion=2, id=slug(data['manufacturer']) + '.' + path.stem,
                version='1.0.0', manufacturer=data['manufacturer'], model=data['model'],
                defaultChannel=configurable_default or 1,
                sources=[dict(id=s['id'], url=s['url'], revision='Archived manufacturer source; revision not inferred', sha256=s['sha256']) for s in data['sources']],
                evidence=evidence, modes=list(modes.values()),
                unitMaps=[dict(id='factory', usesFactoryBindings=True, evidence=configuration_refs)],
                controls=controls, limitations=limitations, configurationEvidence=configuration_refs,
                ports=list(ports.values()), coverageNotes=notes)
    if partial:
        profile['coverageState'] = 'partial' if data['bindings'] else 'documentationOnly'
    return profile


def generated_resources():
    paths = [p for p in sorted(EXTRACTED.glob('*/*.json')) if p.stem not in LEGACY]
    assert len(paths) == 23, f'Expected 23 evidence datasets, got {len(paths)}'
    partial_paths = [p for p in sorted(PARTIAL.glob('*/*.json')) if isinstance((d := json.loads(p.read_text())),dict) and d.get('status') == 'partial-extraction']
    assert len(partial_paths) == 21, f'Expected 21 partial datasets, got {len(partial_paths)}'
    paths += partial_paths
    result = {}
    for path in paths:
        profile = build_profile(path)
        name = slug(profile['manufacturer']) + '-' + path.stem + '-1.0.0.json'
        payload = (compact(profile) + '\n').encode()
        assert len(payload) <= MAX_BYTES, f'{name}: {len(payload)} exceeds resource limit'
        result[name] = payload
    manifest = {'resources': sorted([s + '-1.0.0' for s in LEGACY] + [Path(name).stem for name in result])}
    result['controller-profile-catalogue.json'] = (json.dumps(manifest, indent=2) + '\n').encode()
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true', help='Verify checked-in files match regeneration without modifying them')
    args = parser.parse_args()
    resources = generated_resources()
    for name, payload in resources.items():
        destination = OUTPUT / name
        if args.check:
            assert destination.exists() and destination.read_bytes() == payload, f'Stale resource: {name}'
        else:
            destination.write_bytes(payload)
        print(f'{name}: {len(payload):,} bytes')


if __name__ == '__main__':
    main()
