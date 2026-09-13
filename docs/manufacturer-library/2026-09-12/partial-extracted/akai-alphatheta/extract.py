"""Offline source extraction; never generates runnable device profiles."""
import json,re,hashlib,unicodedata
from pathlib import Path
import pdfplumber
OUT=Path(__file__).resolve().parent
BASE=OUT.parent.parent
GROUP=BASE/'pioneer-alphatheta'
clean=lambda s: re.sub(r'\s+',' ',unicodedata.normalize('NFKC',s or '')).strip()
status_re=re.compile(r'[89ABCDE][0-9A-Fnmps](?:/[89ABCDE][0-9A-Fnmps])*')

def tables(slug):
 cache=OUT/(slug+'-tables.txt')
 result=[]
 with pdfplumber.open(GROUP/slug/'midi-implementation.pdf') as pdf:
  for pn,page in enumerate(pdf.pages,1):
   for ti,t in enumerate(page.find_tables()):
    if len(t.columns)<10: continue
    rows=t.extract(); cells={c:val or '' for row,vals in zip(t.rows,rows) for c,val in zip(row.cells,vals) if c is not None}
    ys=sorted(set(c[1] for c in t.cells)|set(c[3] for c in t.cells))
    xs=sorted(set(c[0] for c in t.cells)|set(c[2] for c in t.cells))
    resolved=[]
    for ri,row in enumerate(t.rows):
     y=(ys[ri]+ys[ri+1])/2
     rr=[]
     for j in range(len(xs)-1):
      x=(xs[j]+xs[j+1])/2
      c=next((c for c in t.cells if c[0]<=x<c[2] and c[1]<=y<c[3]),None)
      rr.append(cells[c] if c else None)
     resolved.append(rr)
    result.append({'page':pn,'table':ti+1,'rows':resolved,'original_rows':rows,'trigger_row_text':[' '.join(w['text'] for w in page.extract_words() if xs[4] <= (w['x0']+w['x1'])/2 < xs[6] and ys[k] <= (w['top']+w['bottom'])/2 < ys[k+1]) for k in range(len(resolved))]})
 cache.write_text(json.dumps(result,ensure_ascii=False,indent=2)); return result


CATALOGUE=json.loads((BASE/'catalogue.json').read_text())['models']
def evidence(source,loc): return [{'source_id':source,'locator':loc}]
def issue(doc,severity,description,loc,excluded=None,source='manual'):
 doc['issues'].append(dict(id=f"issue-{len(doc['issues'])+1:04d}",severity=severity,description=description,evidence=evidence(source,loc),excluded_bindings=excluded or []))
def base(model):
 m=next(m for m in CATALOGUE if m['model']==model)
 d=dict(schema_version=1,manufacturer=m['manufacturer'],model=model,status='partial-extraction',coverage_state='documentation-only',hardware_tested=False,sources=[],scope='',bindings=[],issues=[],raw_evidence=[],setup_notes=[],missing_information=[])
 for s in m['sources']:
  sid='midi' if s['kind']=='midi-implementation' else 'manual'
  assert hashlib.sha256((BASE/s['local_file']).read_bytes()).hexdigest()==s['sha256']
  d['sources'].append(dict(id=sid,**{k:s[k] for k in ('local_file','url','sha256')}))
  path=BASE/s['extracted_text']
  if sid=='midi':path=BASE/'pioneer-alphatheta/slab/midi-layout.txt'
  pages=path.read_text().split('\f')
  if not pages[-1].strip(): pages.pop()
  raw=OUT/(model.lower()+'-'+sid+'-pages.txt')
  raw.write_text(''.join(f'\n===== PDF PAGE {n} =====\n{p}' for n,p in enumerate(pages,1)))
  d['raw_evidence'].append(dict(source_id=sid,file='akai-alphatheta/'+raw.name,extraction_method='Complete archived PDF text with explicit one-based PDF page markers; original PDF authoritative.'))
 return d

def akai():
 d=base('APC64')
 d['scope']='Documentation-only: custom pad notes/channels, fader CC assignments, routing, aftertouch and project storage are documented as editable capabilities. No actual project/preset map is present; numeric control addresses are not established.'
 d['setup_notes']=['Press CUSTOM to open Custom Mode; edit assignments with APC64 Project Editor (manual p.50).','Use Get Project and choose a stored slot or RAM to retrieve active assignments; save the actual project together with a future mapping (p.58).','In the editor, choose each pad note/channel, poly-aftertouch enable and USB/MIDI routing; faders have configurable CC1/CC2, optional note and MIDI channel (pp.52,57).']
 d['missing_information']=['Actual selected Project/RAM pad-note, fader-CC and channel assignments.','Double (2 CC) ordering, range and numeric interpretation; do not assume a 14-bit CC pair.','Host-to-device LED message addresses and color protocol; editor local on/off colors do not establish receive messages.','Complete fixed Ableton/standalone map and per-pad numeric drum defaults.']
 issue(d,'scope','Custom Mode entry, editor assignments and Get Project setup are documented, but no actual selected preset is archived. Ableton chord channel 1/drum channel 16 alone do not establish control addresses.','PDF pp.29,47,50,52,57–58')
 issue(d,'unsupported','Poly-aftertouch is a documented optional pad capability; no fixed per-pad address evidence is established. Double-CC faders and local color editor settings must not be converted into guessed scalar or LED bindings.','PDF pp.52,57',['Unspecified poly-aftertouch pad assignments','Unspecified two-CC fader interpretation','Unproven host LED feedback'])
 (OUT/'apc64.json').write_text(json.dumps(d,indent=2)+'\n')
 d=base('MPD218')
 d['scope']='Documentation-only: owner guide establishes three pad/control banks, 16 selectable programs, velocity-sensitive pads and CC knobs, but refers to separate unarchived Preset Documentation for the addresses. No factory template is inferred.'
 d['setup_notes']=['Connect by USB and select MPD218 as the controller in the DAW preferences (manual p.3).','Select the intended pad and control banks; hold Prog Select and press a pad to choose the same-numbered program (pp.4–5).','Obtain the MPD218 Editor Software and Preset Documentation identified by the guide before establishing program-specific mappings (pp.3,5).','Pads suppress normal MIDI while NR Config or Prog Select is held; Note Repeat follows the configured internal or external clock (p.5).']
 d['missing_information']=['Factory/program-specific pad note numbers, knob CC numbers and MIDI channels for every bank.','Separate Preset Documentation/editor guide and actual selected program.','Pressure message type/address semantics and host LED receive protocol.','Exact knob value encoding; 360-degree travel and CC capability alone do not establish relative or absolute encoding.']
 issue(d,'scope','USB setup, bank/program selection, normal-MIDI suppression and Note Repeat configuration are documented. The guide explicitly directs readers to separate Preset Documentation, absent from this archive.','PDF pp.3–5',['All unverified factory/program note and CC assignments'])
 issue(d,'unsupported','Pressure sensitivity and external clock operation are documented capabilities, without complete pressure or feedback protocol bytes in this guide.','PDF pp.4–5',['Unspecified pressure messages','Unproven LED receive messages'])
 (OUT/'mpd218.json').write_text(json.dumps(d,indent=2)+'\n')

def slab():
 d=base('SLAB'); ts=tables('slab');d['coverage_state']='partial'
 d['scope']='All four official MIDI chart pages processed, retaining transport, encoder, strip and 16-pad/eight-page rows including SHIFT and receive directions. E1 encoder-mode input/output addresses are quarantined for contradictory channels. Poly-aftertouch retained as unsupported. Source-specific relative values and ordered strip CC pairs remain explicit; no runtime integration.'
 d['raw_evidence'].append(dict(source_id='midi',file='akai-alphatheta/slab-tables.txt',extraction_method='pdfplumber ruled tables, resolved merged rectangles and per-row trigger crops. One-based table/row locators; complete original rows retained.'))
 group=''; last_trigger=''
 for t in ts:
  idx=11 if t['page']==1 else 12
  for ri,rr in enumerate(t['rows'][3:],4):
   r=[clean(v) for v in rr]; loc=f"PDF p.{t['page']}, table {t['table']}, row {ri}"
   if r[0]:group=r[0]
   trigger=clean(t['trigger_row_text'][ri-1])
   shifted='+SHIFT' in trigger
   last_trigger=r[4].replace('+SHIFT','').strip()
   context='; '.join(v for v in [r[3], ('aftertouch' if r[7]=='Aftertouch' else last_trigger), 'SHIFT held' if shifted else 'without SHIFT'] if v)
   if r[1]=='E1':
    issue(d,'conflict',f'E1 {"shifted" if shifted else "unshifted"} note {r[8]}: decimal channel 1 conflicts with both status 96 bytes (channel 7). Both directions excluded; neither address interpretation selected.',loc,[f'E1 note {r[8]} device-to-host',f'E1 note {r[8]} host-to-device'],'midi');continue
   for j,direction in [(idx,'device-to-host'),(idx+3,'host-to-device')]:
    st=r[j]
    if st=='-':continue
    assert re.fullmatch('[9AB][0-9A-F]',st),(loc,r)
    ch=int(st[1],16)+1; assert ch==int(r[6]),(loc,r)
    nums=[int(n,16) for n in r[j+1].split()];dec=[int(n) for n in r[8].split()]
    # Touch strip Mode 1 first row lists only decimal MSB, but both explicit hex bytes.
    assert nums==dec or (t['page']==1 and ri==55 and nums==[14,46] and dec==[14]),(loc,r)
    typ={'9':'note','A':'poly-aftertouch','B':'cc'}[st[0]]
    details=r[-1];vals=dict(status_hex=st,data1_hex=r[j+1],data2_source=r[j+2],details_source=details)
    enc='Source-defined MIDI data byte';notes=['Chart MIDI-IN means to computer; MIDI-OUT means from computer.']
    if 'CW=0x01' in details:
     enc='Relative one-step direction codes: CW 0x01, CCW 0x41 (not two’s-complement)';vals.update(clockwise=1,counterclockwise=65)
    elif len(nums)==2:
     enc='Ordered CC pair: MSB then LSB; source bounds 00/00 through 7F/7F';vals['components']=[dict(message_type='cc',number=n,role=role) for n,role in zip(nums,['MSB','LSB'])];vals.update(minimum_bytes=[0,0],maximum_bytes=[127,127])
     if dec!=nums:notes.append('Decimal reference gives only 14; hexadecimal column explicitly supplies both 0E and 2E.')
    elif direction=='host-to-device' and r[j+2]=='HH':
     enc='LED color-number feedback';vals.update(color_number_min=1,color_number_max=127);notes.append('No RGB byte conversion or zero-value LED behavior inferred from color-number range.')
    elif 'OFF=0x00, ON=0x7F' in details:enc='Note on/off state encoded in data2';vals.update(off=0,on=127)
    elif '0x00(min) - 0x7F(max)' in details:enc='7-bit pressure' if typ=='poly-aftertouch' else '7-bit note velocity';vals.update(minimum=0,maximum=127)
    if typ=='poly-aftertouch' and not details:notes.append('Data2 range not repeated in this source row; no row-specific range inferred.')
    d['bindings'].append(dict(id=f"b{len(d['bindings'])+1:05d}",control=r[2],source_group=group,source_figure=r[1],direction=direction,message_type='compound' if len(nums)>1 else typ,channel=ch,number=None if len(nums)>1 else nums[0],encoding=enc,values=vals,mode=context,evidence=evidence('midi',loc),app_support='unsupported' if typ=='poly-aftertouch' else 'requires-adapter',notes=notes))
 d['setup_notes']=['Select DIAL mode with DIAL MODE for dial MIDI output; FOCUS instead emulates mouse wheel/click (MIDI chart p.4, footnotes 1–2).','STRIP MODE toggles Mode 1/Mode 2; OCTAVE buttons switch pad pages 1–8 (p.4, footnotes 3–4).','Match the chart SHIFT, pad page and strip mode context to the selected mapping. Encoder-mode E1 channel conflict remains unresolved (p.1).']
 d['missing_information']=['Manufacturer correction for E1 unshifted note 16 and shifted note 17: decimal channel 1 versus hexadecimal 96/channel 7.','Adapter support for source-specific 01/41 encoder motion, paired strip CCs and color-number feedback.','Runtime support for poly-aftertouch; all 128 documented pressure rows retained as unsupported.','Numeric RGB palette for color numbers, zero-value receive behavior where omitted, and encoder touch data2 semantics where blank are not established by the chart.','Hardware validation and runnable application integration remain outside this extraction.']
 issue(d,'unsupported','All 128 explicitly addressed poly-aftertouch pad/page rows are retained but marked unsupported; these are pressure messages, not scalar note/CC controls.','PDF pp.2–4',source='midi')
 issue(d,'scope','Dial/strip/page setup comes from footnotes 1–4. Relative 01/41 movement is not two’s-complement; ordered strip bytes and color-number feedback require adapters. Empty data2 details remain unknown.','PDF p.4, footnotes 1–4; p.1 encoder/strip rows; pp.2–4 pad rows',source='midi')
 (OUT/'slab.json').write_text(json.dumps(d,indent=2,ensure_ascii=False)+'\n')
 print('SLAB',len(d['bindings']),'bindings',len(d['issues']),'issues')
if __name__=='__main__':
 akai();slab()
