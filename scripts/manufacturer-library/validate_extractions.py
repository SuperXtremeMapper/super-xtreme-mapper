#!/usr/bin/env python3
"""Validate local manufacturer evidence, without promoting it to runtime profiles."""
import argparse
from collections import Counter
import hashlib
import json
from pathlib import Path

MESSAGE_TYPES = {'note','cc','pitch-bend','poly-aftertouch','channel-aftertouch','sysex','realtime','compound'}


def validate_model(data, root, evidence_directory="extracted"):
    errors = []
    def require(condition, message):
        if not condition: errors.append(message)
    require(data.get('schema_version') == 1, 'schema_version must be 1')
    require(data.get('status') in {'documented-extraction','partial-extraction'}, 'invalid status')
    partial = data.get('status') == 'partial-extraction'
    if partial:
        require(data.get('coverage_state') in {'partial','documentation-only'}, 'invalid partial coverage_state')
        for key in ('setup_notes','missing_information'):
            require(isinstance(data.get(key),list) and bool(data[key]) and all(isinstance(v,str) and v.strip() for v in data[key]),f'missing {key}')
        require(bool(data.get('issues')), 'partial extraction needs explicit issues')
    require(data.get('hardware_tested') is False, 'hardware validation must not be claimed')
    for key in ('manufacturer','model','scope'):
        require(isinstance(data.get(key),str) and bool(data[key].strip()), f'missing {key}')
    sources = data.get('sources',[])
    source_ids = [s.get('id') for s in sources]
    require(bool(sources), 'missing sources')
    require(len(set(source_ids)) == len(source_ids), 'duplicate source id')
    for source in sources:
        path = root / source.get('local_file','')
        require(path.is_file(), f'missing source file: {path}')
        require(str(source.get('url','')).startswith('https://'), 'source URL must use https')
        if path.is_file():
            digest=hashlib.sha256(path.read_bytes()).hexdigest()
            require(digest == source.get('sha256'), f'source hash mismatch: {path}')
    def evidence(items, context):
        require(isinstance(items,list) and bool(items), f'{context}: missing evidence')
        if not isinstance(items,list): return
        for item in items:
            require(item.get('source_id') in source_ids, f'{context}: unknown evidence source')
            require(isinstance(item.get('locator'),str) and bool(item['locator'].strip()), f'{context}: missing evidence locator')
    bindings = data.get('bindings',[])
    if partial and data.get('coverage_state') == 'documentation-only':
        require(not bindings,'documentation-only must not contain normalized bindings')
    else:
        require(bool(bindings), 'empty normalized bindings; extraction incomplete')
    ids = [b.get('id') for b in bindings]
    require(len(set(ids)) == len(ids), 'duplicate binding id')
    for b in bindings:
        context = f"binding {b.get('id')}"
        for key in ('id','control','mode','encoding'):
            require(isinstance(b.get(key),str) and bool(b[key].strip()),f'{context}: missing {key}')
        require(b.get('direction') in {'device-to-host','host-to-device'}, f'{context}: invalid direction')
        require(b.get('message_type') in MESSAGE_TYPES, f'{context}: invalid message_type')
        channel=b.get('channel'); number=b.get('number')
        require(channel is None or (type(channel) is int and 1 <= channel <= 16),f'{context}: channel must be human 1..16 or null')
        require(number is None or (type(number) is int and 0 <= number <= 127),f'{context}: number must be 0..127 or null')
        if b.get('message_type') in {'note','cc','poly-aftertouch'}:
            require(type(number) is int, f'{context}: numbered message missing number')
        require(isinstance(b.get('values'),dict),f'{context}: missing values object')
        require(isinstance(b.get('notes'),list),f'{context}: missing notes array')
        if channel is None:
            require(bool(b.get('notes')),f'{context}: null channel requires explanation in notes')
        require(b.get('app_support') in {'existing-profile','requires-adapter','unsupported'},f'{context}: invalid app_support')
        evidence(b.get('evidence'),context)
    for issue in data.get('issues',[]):
        require(issue.get('severity') in {'conflict','unsupported','scope'}, 'invalid issue severity')
        require(bool(issue.get('id')) and bool(issue.get('description')), 'missing issue identity/description')
        require(isinstance(issue.get('excluded_bindings'),list),'missing excluded_bindings array')
        evidence(issue.get('evidence'),f"issue {issue.get('id')}")
    raw=data.get('raw_evidence',[])
    require(bool(raw),'missing raw_evidence')
    for item in raw:
        require(item.get('source_id') in source_ids,'raw evidence unknown source')
        path=root/evidence_directory/item.get('file','')
        require(path.is_file() and path.stat().st_size > 0, f'missing or empty raw evidence: {path}')
        require(bool(item.get('extraction_method')),'raw evidence missing extraction_method')
    return errors


def validate_catalogue_coverage(models, catalogue, source_grade="ready-for-extraction"):
    expected={(m['manufacturer'],m['model']) for m in catalogue['models'] if m['source_grade']==source_grade}
    counts=Counter((m.get('manufacturer'),m.get('model')) for m in models)
    errors=[]
    for key in sorted(expected-counts.keys()): errors.append(f'missing candidate: {key}')
    for key in sorted(counts.keys()-expected): errors.append(f'unexpected candidate: {key}')
    for key,count in counts.items():
        if count != 1: errors.append(f'duplicate candidate: {key}')
    lookup={(m['manufacturer'],m['model']):m for m in catalogue['models']}
    for model in models:
        key=(model.get('manufacturer'),model.get('model'))
        if key not in lookup: continue
        allowed={s['sha256'] for s in lookup[key].get('sources',[])}
        for source in model.get('sources',[]):
            if source.get('sha256') not in allowed:
                errors.append(f'source not in candidate catalogue: {key}, {source.get("id")}')
    return errors


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root',type=Path,default=Path(__file__).resolve().parents[2]/'docs/manufacturer-library/2026-09-12')
    parser.add_argument('--output',type=Path)
    parser.add_argument('--stage',choices=['documented','partial'],default='documented')
    args=parser.parse_args()
    evidence_directory='partial-extracted' if args.stage=='partial' else 'extracted'
    status='partial-extraction' if args.stage=='partial' else 'documented-extraction'
    models=[]; results=[]
    for path in sorted((args.root/evidence_directory).rglob('*.json')):
        data=json.loads(path.read_text())
        if not isinstance(data,dict) or data.get('status') != status: continue
        models.append(data)
        results.append(dict(file=str(path.relative_to(args.root)),model=data.get('model'),bindings=len(data.get('bindings',[])),issues=len(data.get('issues',[])),errors=validate_model(data,args.root,evidence_directory)))
    coverage=validate_catalogue_coverage(models,json.loads((args.root/'catalogue.json').read_text()),'partial' if args.stage=='partial' else 'ready-for-extraction')
    result=dict(models=len(models),bindings=sum(r['bindings'] for r in results),coverage_errors=coverage,results=results)
    result['passed']=not coverage and all(not r['errors'] for r in results)
    if args.output: args.output.write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps(result,indent=2))
    return 0 if result['passed'] else 1

if __name__=='__main__': raise SystemExit(main())
