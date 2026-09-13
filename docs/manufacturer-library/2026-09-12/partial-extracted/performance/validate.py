"""Check schema/provenance and reproducibility of this owned partial batch."""
import hashlib,json,subprocess,sys
from pathlib import Path
O=Path(__file__).resolve().parent
R=O.parent.parent
files=sorted(O.glob('*.json'))
assert len(files)==6
before={f.name:hashlib.sha256(f.read_bytes()).hexdigest() for f in files}
subprocess.run([sys.executable,str(O/'extract.py')],check=True)
assert before=={f.name:hashlib.sha256(f.read_bytes()).hexdigest() for f in files}
total=0
for f in files:
 d=json.loads(f.read_text());assert d['status']=='partial-extraction' and not d['hardware_tested']
 assert d['coverage_state']=='partial' and d['scope'] and d['setup_notes'] and d['missing_information']
 sources={s['id']:s for s in d['sources']}
 for s in sources.values():assert hashlib.sha256((R/s['local_file']).read_bytes()).hexdigest()==s['sha256']
 for raw in d['raw_evidence']:
  assert raw['source_id'] in sources and (O.parent/raw['file']).is_file()
  txt=(O.parent/raw['file']).read_text();assert '--- PDF PAGE' in txt or '--- ORIGINAL TEXT' in txt
 assert len({b['id'] for b in d['bindings']})==len(d['bindings'])
 for b in d['bindings']:
  assert set(['id','control','direction','message_type','channel','number','encoding','values','mode','evidence','app_support','notes'])<=b.keys()
  assert b['channel'] is None or 1<=b['channel']<=16
  assert b['number'] is None or 0<=b['number']<=127
  assert b['app_support']=='requires-adapter' and b['direction'] in ['device-to-host','host-to-device']
  assert b['evidence'] and all(e['source_id'] in sources and e['locator'] for e in b['evidence'])
  if b['channel'] is None:assert b['notes']
 for i in d['issues']:assert i['evidence'] and i['severity'] in ['scope','unsupported','conflict']
 total+=len(d['bindings'])
print(f'Validated six files, {total} contextual bindings, source hashes, schema invariants and deterministic regeneration.')
