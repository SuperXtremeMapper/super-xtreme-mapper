"""Offline source extraction; never generates runnable device profiles."""
import json,re,hashlib,unicodedata
from pathlib import Path
import pdfplumber
OUT=Path(__file__).resolve().parent
BASE=OUT.parent.parent
GROUP=BASE/'pioneer-alphatheta'
manifest=json.loads((GROUP/'manifest.json').read_text())
clean=lambda s: re.sub(r'\s+',' ',unicodedata.normalize('NFKC',s or '')).strip()
status_re=re.compile(r'[89ABCDE][0-9A-Fnmps](?:/[89ABCDE][0-9A-Fnmps])*')

def tables(slug):
 cache=OUT/(slug+'-tables.txt')
 if cache.exists(): return json.loads(cache.read_text())
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
    result.append({'page':pn,'table':ti+1,'rows':resolved,'original_rows':rows})
 cache.write_text(json.dumps(result,ensure_ascii=False,indent=2)); return result

def extract(m):
 slug=m['model'].lower(); data=tables(slug)
 src=next(s for s in m['sources'] if s.get('kind')=='midi-implementation' and s.get('status')=='downloaded')
 text=(GROUP/slug/'midi-layout.txt').read_text(); pages=text.split('\f'); pages=pages[:-1] if not pages[-1].strip() else pages
 raw=OUT/(slug+'-protocol.txt'); raw.write_text(''.join(f'\n===== PDF PAGE {i} =====\n{p}' for i,p in enumerate(pages,1)))
 bindings=[]; issues=[]; last={}; skipped=[]
 def issue(sev,desc,loc,row): issues.append({'id':f'issue-{len(issues)+1:04d}','severity':sev,'description':desc,'evidence':[{'source_id':'midi','locator':loc}],'excluded_bindings':[clean(str(row))]})
 for t in data:
  pn=t['page']; ti=t['table']
  if slug=='cdj-3000x': ctrl,fig,group=2,1,0
  elif slug=='djm-a9': ctrl,fig,group=2,1,0
  elif slug=='omnis-duo': ctrl,fig,group=3,2,1
  elif slug=='xdj-az': ctrl,fig,group=(4,3,2) if pn==1 else (3,2,1)
  elif slug=='djm-s11' and pn in (6,7): ctrl,fig,group=3,2,1
  elif slug=='djm-s11' and pn==8: ctrl,fig,group=1,0,None
  else: ctrl,fig,group=2,1,0
  # Dedicated feedback tables use communication name, not Function as control.
  feedback=any('Communication' in str(r) or "'Name'" in str(r) for r in t['original_rows'][:4])
  if feedback:
   ctrl,fig,group=1,None,0
   for hr in t['rows'][:4]:
    for j,v in enumerate(hr):
     if v and ('Communication' in v or v=='Name'): ctrl=j; break
  for hr in t['rows'][:30]:
   if 'UI name' in hr:
    ctrl=hr.index('UI name'); fig=ctrl-1; group=ctrl-2; break
  for ri,r in enumerate(t['rows']):
   r=[clean(v) for v in r]; orig=[clean(v) for v in t['original_rows'][ri]]
   derived_decimal=False
   if slug=='xdj-az' and pn==2 and ri==114 and r[12]=='B4' and r[13]=='96' and not r[14]:
    r[14]='60'; derived_decimal=True
   inds=[]
   for j,v in enumerate(r):
    if not status_re.fullmatch(v) or j+2>=len(r): continue
    offset=2 if slug in ('cdj-3000x','xdj-rx3','xdj-az','omnis-duo') and j>0 and r[j-1] in ('NOTE','CC') else 1
    nt=r[j+offset]
    if re.fullmatch(r'[0-9A-Fa-f]{1,2}(?:[ /][0-9A-Fa-f]{1,2})*',nt) and all(int(n,16)<128 for n in re.split(r'[ /]',nt)):
     if j+offset+1<len(r) and (r[j+offset+1] in ('hh','MSB LSB','MSB','LSB','') or re.fullmatch(r'[0-9A-F]{1,2}',r[j+offset+1]) or slug=='djm-a9'): inds.append(j)
   if slug in ('cdj-3000x','xdj-rx3','xdj-az','omnis-duo'):
    inds=[j for j in inds if j>0 and (r[j-1] in ('NOTE','CC') or not any(status_re.fullmatch(v) for v in r[max(0,j-3):j]))]
   loc=f'PDF p.{pn}, table {ti}, row {ri+1}'
   malformed=slug=='ddj-rev5' and pn==2 and len(r)>8 and r[7:9]==['NOTE','NOTE']
   if malformed:
    issue('conflict','Visually verified manufacturer table has displaced NOTE/decimal/pitch-name fields in MIDI-IN status columns for BASS / PAD 3; input excluded, explicit independent MIDI-OUT retained.',loc,r)
    inds=[j for j in inds if j>=13]
   # Record real explicit control cells before evaluating rows so hardware rows reset context.
   control=r[ctrl] if ctrl<len(r) else ''
   is_protocol=bool(inds) or 'Hardware Control' in ' '.join(r) or 'Hardware control' in ' '.join(r)
   if is_protocol and control and control not in ('UI name','User Interface') and not any(v in control for v in ['MIDI channel','MIDI Channel','assignment','MIDI assign']): last['control']=control
   if is_protocol and fig is not None and fig<len(r) and r[fig] and r[fig] not in ('Fig.','Part No.'): last['fig']=r[fig]
   if is_protocol and group is not None and group<len(r) and r[group] and r[group] not in ('Group',): last['group']=r[group]
   if not inds:
    if slug=='djm-a9' and ('F8' in r or 'FA' in r or 'FC' in r):
     for j in [j for j,v in enumerate(r) if v in ('F8','FA','FC')]:
      bindings.append({'id':f'b{len(bindings)+1:05d}','control':'Timing Clock','source_group':'System realtime','source_figure':'-', 'direction':'device-to-host','message_type':'realtime','channel':None,'number':None,'encoding':'MIDI system realtime byte','values':{'status_hex':r[j],'source_row':r},'mode':'MIDI transmission','evidence':[{'source_id':'midi','locator':loc}],'app_support':'requires-adapter','notes':['System realtime messages do not carry a MIDI channel.']})
    continue
   if not control: control=last.get('control','')
   if slug=='xdj-rx3' and pn==4 and ri>=95: control='JOG DISPLAY / '+('Cue marker' if 'Hide Cue' in ' '.join(r) else 'Position angle')
   if not control or control in ('UI name','User Interface') or len(control)>150:
    issue('scope','Control label not reliably recovered from this page boundary; raw row retained.',loc,r);continue
   # Two status columns = input followed by output. One status may be receive only.
   for ii,idx in enumerate(inds):
    st=r[idx]; direction='device-to-host'; typ={'8':'note','9':'note','A':'poly-aftertouch','B':'cc','C':'compound','D':'channel-aftertouch','E':'pitch-bend'}[st[0]]
    if malformed or feedback or len(inds)>1 and ii>0: direction='host-to-device'
    if not feedback and len(inds)==1 and any('MIDI' in v and 'OUT' in v for v in r[:idx]): continue
    if not feedback and len(inds)==1:
     # For regular controller charts the receive-only status has '-' input cells three slots before it.
     if idx>=13 and r[idx-3] in ('-','') and r[idx-2] in ('-',''): direction='host-to-device'
    cdj=slug=='cdj-3000x'; special=slug in ('xdj-rx3','xdj-az','omnis-duo')
    if special and r[idx-1] not in ('NOTE','CC'): direction='host-to-device'
    number_idx=idx+2 if (cdj or special) and direction=='device-to-host' else idx+1
    if number_idx>=len(r): continue
    nt=r[number_idx]; bytestr=r[number_idx+1] if number_idx+1<len(r) else ''
    slash_addresses='/' in nt
    nums=re.split(r'[ /]',nt)
    if not nums or not all(re.fullmatch('[0-9A-Fa-f]{1,2}',n) and int(n,16)<128 for n in nums):
     issue('scope','Non-scalar/ambiguous data-1 field requires further normalization.',loc,r);continue
    numbers=[int(n,16) for n in nums]
    # Decimal reference to the left of the first status identifies channel and number.
    before=r[:inds[0]]; noteidx=next((j for j in range(len(before)-1,-1,-1) if before[j] in ('NOTE','CC')),None)
    chtext=before[noteidx-1] if noteidx is not None and noteidx>0 else ''
    if chtext in ('NOTE','CC') and noteidx>1: chtext=before[noteidx-2]
    if len(set(chtext.split()))==1 and chtext.split(): chtext=chtext.split()[0]
    if slug=='ddj-rev7' and pn==1:
     match=next((re.fullmatch(r'(\d+(?:/\d+)*) (NOTE|CC)',v) for v in before if re.fullmatch(r'(\d+(?:/\d+)*) (NOTE|CC)',v)),None)
     if match: chtext=match[1]
    fixed=[int(s[1],16)+1 for s in st.split('/') if s[1] in '0123456789ABCDEF']
    chans=[int(x) for x in chtext.split('/')] if re.fullmatch(r'\d+(?:/\d+)*',chtext) and all(1<=int(x)<=16 for x in chtext.split('/')) else []
    if fixed and chans and fixed!=chans and direction=='device-to-host':
     # Fixed status rows with multiple reference channels are a source contradiction.
     issue('conflict',f'Decimal channel reference {chtext} disagrees with status {st}; excluded.',loc,r);continue
    channels=fixed or chans or [None]
    # Check decimal number reference where present (not note octave name).
    dec=''
    if cdj or special:
     if direction=='device-to-host': dec=r[idx+1]
    elif noteidx is not None and noteidx+1<len(before): dec=before[noteidx+1]
    if dec and re.fullmatch(r'\d+(?:[ /]\d+)*',dec):
     dn=[int(n) for n in re.split(r'[ /]',dec)]
     if dn!=numbers and not (len(dn)>1 and len(numbers)==1 and numbers[0] in dn) and direction=='device-to-host':
      issue('conflict',f'Decimal data-1 {dec} disagrees with hexadecimal {nt}; excluded.',loc,r);continue
    details=r[-1] or (r[-2] if len(r)>1 else '')
    if slug=='djm-a9': details=' | '.join(r[idx+2:])
    prefix=r[:noteidx-1] if noteidx is not None else r[:idx]
    context=' | '.join(v for v in prefix if v and v not in (control,last.get('group'),last.get('fig')))
    notes=['Numeric bytes are authoritative over octave names. Source-perspective MIDI-IN means device to host; MIDI-OUT means host to device.']
    if not fixed and not chans: notes.append('MIDI channel configurable in device utility; no default inferred.' if slug in ('cdj-3000x','djm-a9') else 'Channel unspecified in this row; parameterized status retained without an inferred default.')
    if not r[ctrl]: notes.append('Control label continues from preceding protocol page/table.')
    if len(numbers)>1:
     encoding='Ordered paired CC bytes (MSB then LSB); preserve source-specific range and semantics'
     if not (slash_addresses and typ=='note') and (typ!='cc' or 'MSB' not in (bytestr+' '+details)): issue('scope','Multiple data-1 bytes without a reliably documented MSB/LSB pair.',loc,r);continue
    elif 'MSB' in bytestr or 'LSB' in bytestr: encoding='Component of source-documented MSB/LSB pair; not an independent scalar control'
    elif 'clockwise' in details.lower() and ('0x41' in details or '64 when' in details): encoding='Signed motion/speed centered on 0x40; exact source semantics in values'
    elif 'clockwise' in details.lower() and ('0x01' in details or '0x7F' in details): encoding='Relative movement; positive clockwise and wrapped negative counterclockwise, source range retained'
    elif typ=='note': encoding='Note status with data-2 semantics exactly as documented; press/release and feedback may differ'
    else: encoding='MIDI data byte with source-documented semantics'
    if slash_addresses: encoding='Source-listed slash-separated Note addresses; retain both addresses without inferring ordering or per-position association'
    if derived_decimal: notes.append('Hexadecimal data-1 cell is blank in extraction; numeric address 96 is explicitly documented in adjacent decimal column (hexadecimal 60).')
    for ch in channels:
     vals={'status_template_hex':st,'data1_hex':nums,'data2_source':bytestr,'details_source':details,'reference_channel_source':chtext}
     if len(numbers)>1: vals['components']=[{'message_type':typ,'number':n,'role':role} for n,role in zip(numbers,['source-listed address 1','source-listed address 2'] if slash_addresses else ['MSB','LSB'])]
     entry={'id':f'b{len(bindings)+1:05d}','control':control,'source_group':'TOUCH MIDI SCREEN' if slug=='djm-s11' and pn in (8,9) else (last.get('group','') if group is not None else ''), 'source_figure':last.get('fig','') if fig is not None else '', 'direction':direction,'message_type':'compound' if len(numbers)>1 else typ,'channel':ch,'number':None if len(numbers)>1 else numbers[0],'encoding':encoding,'values':vals,'mode':context or 'MIDI chart; no additional mode specified','evidence':[{'source_id':'midi','locator':loc}],'app_support':'requires-adapter','notes':notes}
     if slug=='ddj-flx4' and 'BEAT SYNC' in control:
      entry['notes'].append('Manufacturer footnote *3, PDF p.5: BEAT SYNC transmits on button release.');entry['evidence'].append({'source_id':'midi','locator':'PDF p.5, footnote *3'})
     if slug=='ddj-flx4' and 'FX ON/OFF' in control:
      entry['notes'].append('Manufacturer footnote *4, PDF p.5: NOTE ON reception blinks the button; NOTE OFF reception lights the button.');entry['evidence'].append({'source_id':'midi','locator':'PDF p.5, footnote *4'})
     bindings.append(entry)
     if direction=='device-to-host' and any('same' in v.lower() and ('midi' in v.lower() or any('midi' in w.lower() for w in r)) for v in r[idx+1:]):
      clone=json.loads(json.dumps(entry));clone['id']=f'b{len(bindings)+1:05d}';clone['direction']='host-to-device';clone['notes'].append('Receive address explicitly marked same as MIDI-IN in manufacturer table.');bindings.append(clone)
 # Flag any numeric chart rows not normalized or already quarantined.
 covered={e['locator'] for x in bindings+issues for e in x['evidence']}
 for table in data:
  for ri,rr in enumerate(table['rows'],1):
   locator=f"PDF p.{table['page']}, table {table['table']}, row {ri}"
   if locator not in covered and any(v and re.fullmatch(r'[9B][0-9A-Fnmps](?:/[9B][0-9A-Fnmps])*',clean(v)) for v in rr):
    issue('scope','Numeric chart row retained but not normalized: compound/slash address or nonstandard cell structure requires manual resolution.',locator,rr)
 # Coalesce only byte-for-byte equal semantic rows; retain all row evidence.
 unique={}
 for b in bindings:
  key=json.dumps({k:v for k,v in b.items() if k not in ('id','evidence')},sort_keys=True)
  if key in unique: unique[key]['evidence']+=b['evidence']
  else: unique[key]=b
 bindings=list(unique.values())
 for i,b in enumerate(bindings,1): b['id']=f'b{i:05d}'
 out={'schema_version':1,'manufacturer':m['manufacturer'],'model':m['model'],'status':'documented-extraction','hardware_tested':False,'sources':[{'id':'midi','local_file':'pioneer-alphatheta/'+src['file'],'url':src['url'],'sha256':src['sha256']}],'scope':'Numeric manufacturer MIDI chart extraction across all protocol pages. Per-channel expansions follow explicit decimal channel lists. Ordered CC pairs, mode/shift contexts and feedback are retained. No runnable profile or native HID/display/motor emulation claim. See issues for unnormalized rows.','bindings':bindings,'issues':issues,'raw_evidence':[{'source_id':'midi','file':'pioneer-alphatheta/'+raw.name,'extraction_method':'Archived pdftotext -layout text with explicit PDF page markers; original PDF authoritative.'},{'source_id':'midi','file':'pioneer-alphatheta/'+slug+'-tables.txt','extraction_method':'pdfplumber ruled table extraction, original rows plus resolved merged rectangles; page/table/row locators are one-based indices in this evidence.'}]}
 issue('scope','Complete protocol page text is retained. Footnotes, color palettes, hardware-only rows and channel-allocation explanations remain authoritative raw context; no hardware validation. Table extraction preserves merged-cell context; combined modifier cells are retained literally and do not imply every modifier simultaneously.',f'PDF pp.1–{len(pages)}',[])
 (OUT/(slug+'.json')).write_text(json.dumps(out,ensure_ascii=False,indent=2)+'\n')
 print(slug,len(bindings),len(issues),flush=True)
for m in manifest['models']:
 if m['status']=='ready-for-extraction': extract(m)
