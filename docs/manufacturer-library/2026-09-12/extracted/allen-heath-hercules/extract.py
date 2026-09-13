import json,re,subprocess,pathlib
ROOT=pathlib.Path('docs/manufacturer-library/2026-09-12'); OUT=ROOT/'extracted/allen-heath-hercules'; CAT=json.load(open(ROOT/'catalogue.json'))['models']
def base(model):
 m=next(m for m in CAT if m['model']==model);return dict(schema_version=1,manufacturer=m['manufacturer'],model=model,status='documented-extraction',hardware_tested=False,sources=[dict(id=f's{i+1}',**{k:s[k] for k in ['local_file','url','sha256']}) for i,s in enumerate(m['sources'])],scope='',bindings=[],issues=[],raw_evidence=[])
def ev(s,l):return [dict(source_id=s,locator=l)]
def issue(d,msg,s,l,ex=[],severity='scope'):d['issues'].append(dict(id=f'issue-{len(d["issues"])+1}',severity=severity,description=msg,evidence=ev(s,l),excluded_bindings=ex))
def add(d,c,t,n,v,mode,loc,s='s1',direction='device-to-host',channel=16,encoding=None,notes=[]):
 d['bindings'].append(dict(id=f'b{len(d["bindings"])+1:04}',control=c,direction=direction,message_type=t,channel=channel,number=n,encoding=encoding or ('absolute 7-bit' if t=='cc' else 'note state'),values=v,mode=mode,evidence=ev(s,loc),app_support='requires-adapter',notes=notes+(['Channel-independent system MIDI message.'] if channel is None else [])))
def raw(d,sid,pages=None):
 s=next(s for s in d['sources'] if s['id']==sid);p=ROOT/s['local_file']; name=re.sub('[^a-z0-9]+','-',d['model'].lower()).strip('-')+'-'+sid+'.txt'; dest=OUT/name
 if p.suffix=='.pdf':
  txt=subprocess.check_output(['pdftotext','-layout',str(p),'-']).decode(); parts=txt.split('\f'); txt='\n'.join(f'=== PDF page {i+1} ===\n{v}' for i,v in enumerate(parts) if v.strip() and (pages is None or i+1 in pages));method='pdftotext -layout; original PDF page markers'
 elif p.suffix=='.png':txt='=== Diagram page 1: '+p.name+' ===\n'+subprocess.check_output(['tesseract',str(p),'stdout'],stderr=subprocess.DEVNULL).decode();method='Tesseract OCR of complete manufacturer diagram; image remains authoritative; spatial associations are represented by existing-profile provenance'
 else:
  if p.suffix=='.html':txt=p.with_suffix('.txt').read_text()
  else:txt=p.read_text()
  txt='=== HTML/text document page 1; section-addressed ===\n'+txt;method='Archived complete manufacturer text snapshot with section headings'
 dest.write_text(txt);d['raw_evidence'].append(dict(source_id=sid,file='allen-heath-hercules/'+name,extraction_method=method))
def save(d,slug): (OUT/(slug+'.json')).write_text(json.dumps(d,indent=2)+'\n')
for k in [1,2,3]:
 d=base(f'XONE:K{k}');p=json.load(open(f'XtremeMapping/XtremeMapping/Resources/ControllerProfiles/xone-k{k}-1.0.0.json')); em={e['id']:e for e in p['evidence']};sm={s['id']:next(v['id'] for v in d['sources'] if v['sha256']==s['sha256']) for s in p['sources']}
 def pe(es):return [dict(source_id=sm[em[e]['sourceID']],locator=em[e]['locator']) for e in es]
 for c in p['controls']:
  for b in c['bindings']:
   # Known printed contradiction is quarantined despite existing profile's supported correction.
   if k==2 and c['id']=='pot.switch.2.3' and b['direction']=='send' and b['layer'] in ['amber','green']:continue
   modes=[m['id'] for m in p['modes'] if c['group'] in m['layeredGroups']] if b['layer']!='base' else [m['id'] for m in p['modes']]
   vals={key:b[key] for key in ['valueMin','valueMax','color'] if b.get(key) is not None}
   add(d,c['name'],'cc' if b['kind']=='controlChange' else b['kind'],b['number'],vals,'factory map; '+ ('LED color '+b.get('color','unspecified')+'; return layer '+b['layer'] if b['direction']=='receive' else 'send layer '+b['layer'])+'; mode metadata attached', 'placeholder',channel=p['defaultChannel'],encoding=b['encoding'],direction='device-to-host' if b['direction']=='send' else 'host-to-device',notes=b['notes']+['Configured global channel; documented default 15.','Control group: '+c['group'],'Reserved in modes: '+str(c['reservedInModes'])])
   d['bindings'][-1]['evidence']=pe(b['evidence']);d['bindings'][-1]['app_support']='existing-profile'
 d['mode_configuration']=[{**m,'evidence':pe(m['evidence'])} for m in p['modes']];d['unit_maps']=[{**m,'evidence':pe(m['evidence'])} for m in p['unitMaps']]
 for lim in p['limitations']:
  issue(d,lim['message'],'s1','placeholder',severity='conflict' if 'misprint' in lim['message'] or '127/1' in lim['message'] else 'scope');d['issues'][-1]['evidence']=pe(lim['evidence'])
 
 if k==2:
  for i in d['issues']:
   if 'misprints' in i['description']:i['excluded_bindings']=['Pot switch row 2 column 3 amber and green send bindings; conflicting diagram note labels']
 d['scope']='Existing reviewed factory profile facts transcribed with original manufacturer provenance, distinct sends/returns and layers. Mode configuration and reservations retained. This extraction makes no additional hardware or integration claim; custom maps and unspecified velocities remain unresolved.'
 for s in d['sources']:raw(d,s['id'],[8,12,13,14,15] if k==1 else list(range(9,21)) if k==2 else None)
 save(d,f'xone-k{k}')
d=base('Xone:96');d['scope']='All explicitly numbered controls in official MIDI Control and input-source matrices; input and output kept separate. Default channel 16, configurable 1–16. Rotary selectors send discrete notes, not relative encoder CC.';raw(d,'s2')
for i in range(4):add(d,f'CH {i+1} fader','cc',i,{'min':0,'max':127},'default channel setting','MIDI Control / CH FADER','s2')
add(d,'Crossfader','cc',5,{'min':0,'max':127},'default channel setting','MIDI Control / XFADER','s2')
rows=[(f'CH {c} CUE',i) for i,c in enumerate(['1','2','3','4','A','B','C','D'])]+[(f'VCF {f} {c}',n) for f,ns in [(1,[10,11,12,13]),(2,[14,15,16,17])] for c,n in zip(['HPF','BPF','LPF','ON/OFF'],ns)]+[('CH C ON/OFF',8),('CH D ON/OFF',9),('MUTE ON/OFF',18)]
for c,n in rows:
 for dire in ['device-to-host','host-to-device']:add(d,c,'note',n,{'off':0,'on':127},'default channel setting','MIDI Control / '+c,'s2',dire)
for c,ns in [('1',[19,20,21,22]),('2',[23,24,25,26]),('3',[27,28,29,30]),('4',[31,32,33,34]),('A',[35,36,37,38]),('B',[39,40,41,42])]:
 for position,n in zip(['USB 1','PHONO' if c.isdigit() else 'MIC '+c,'LINE' if c.isdigit() else 'RTN '+c,'USB 2'],ns):add(d,'CH '+c+' input source','note',n,{'off':0,'on':127},'rotary switch position '+position,'CH IP SOURCE MIDI VALUES / '+c+' / '+position,'s2',notes=['Discrete selector position, not relative encoder.'])
for c,n in zip(['1','2','3','4','A','B','C','D','LR MIX'],range(43,52)):add(d,'PHONES 2 source','note',n,{'off':0,'on':127},'rotary switch position '+c,'MIDI Control / PHONES 2 / '+c,'s2')
issue(d,'Addresses apply to configured channel 1–16; bindings show documented default 16.','s2','MIDI Channel Setup');save(d,'xone-96')
d=base('Xone:92 Mk2');raw(d,'s1',[23,24,25,35,36]);d['scope']='Complete four documented CC addresses plus documented clock and transport functions. Transmit only; default channel 16 with internal channel 15 option.'
for c,n in [('FILTER 1 FREQ',12),('FILTER 2 FREQ',13),('Crossfader',92),('DATA controller',94)]:add(d,c,'cc',n,{'min':0,'max':127} if n!=94 else {},'internal DATA jumper enabled' if n==94 else 'normal operation','PDF page 24 / MIDI Control Codes / '+c,notes=['Default 16; internal option 15.'])
add(d,'Tap Tempo LFO 2 clock','realtime',None,{},'master tempo clock','PDF pages 23–25 / MIDI Control Codes / MIDI Implementation Chart',channel=None,encoding='MIDI timing clock; exact byte not printed')
add(d,'Start/Stop','compound',None,{'first_press':'start','second_press':'stop + rewind'},'normal operation','PDF page 24 / START / STOP',channel=None,encoding='MIDI start; stop plus rewind, exact byte sequence not printed')
issue(d,'Start/stop-rewind byte sequence and CC94 range not explicitly specified; transport retained as descriptive compound, no invented bytes. Received column documents no supported MIDI input.','s1','PDF pages 24–25 / MIDI Control Codes / MIDI Implementation Chart');save(d,'xone-92-mk2')
d=base('Euphonia');raw(d,'s2');d['scope']='Entire MIDI message list normalized: transmit-to-computer controls, discrete selectors and timing clock. Chart status bytes 90/B0 identify channel 1; no receive map is asserted.'
def eu(c,t,n,v=None,mode='documented chart mode',page=3):add(d,c,t,n,v if v is not None else {'min':0,'max':127} if t=='cc' else {'off':0,'on':127},mode,f'PDF page {page} / {c}','s2',channel=1,encoding='discrete CC state' if t=='cc' and v is not None else None)
eu('MIC selector','cc',79,{'OFF':0,'ON':64,'TALKOVER':127},page=2);eu('MIC EQ HI','cc',30,page=2);eu('MIC EQ LOW','cc',31,page=2)
for ch,nums in enumerate([[1,2,3,4,5,17],[6,7,8,9,10,18],[12,14,15,21,22,19],[80,81,92,82,83,20]],1):
 pg=2 if ch<4 else 3
 for c,n in zip(['TRIM','HI','MID','LOW','SEND','CH ROTARY VOLUME'],nums):eu(f'CH{ch} {c}','cc',n,page=pg)
 eu(f'CH{ch} CUE','note',9+ch,page=pg)
 for pos,n in zip(['PC','DIGITAL','LINE','PHONO'],[49+4*ch,46+4*ch,47+4*ch,48+4*ch]):eu(f'CH{ch} INPUT SELECTOR','note',n,mode='position '+pos+'; previous selection OFF, new selection ON',page=pg)
for c,t,n in [('VIEW','note',88),('MASTER INSERT','note',96),('MASTER LEVEL','cc',24),('BOOTH EQ LOW','cc',110),('BOOTH EQ HI','cc',109),('BOOTH LEVEL','cc',25),('HEADPHONES MONO/SPLIT','note',33),('HEADPHONES MIXING','cc',27),('HEADPHONES LEVEL','cc',26),('LOW SEND','note',80),('LOW VOLUME','cc',103),('MID SEND','note',81),('MID VOLUME','cc',104),('HI SEND','note',82),('HI VOLUME','cc',105)]:eu(c,t,n)
eu('BRIGHTNESS','cc',89,{'1':0,'2':32,'3':64,'4':96,'5':127});eu('BOOST LEVEL','note',83,{'0dB':0,'+6dB':64,'+12dB':127})
for c,n in [('HPF',42),('DELAY',55),('TAPE ECHO',51),('ECHO VERB',43),('REVERB',62),('SHIMMER',54),('EXT',50)]:eu('EFFECT SELECT','cc',n,{'off':0,'on':127},'position '+c+'; previous selection OFF, new selection ON',4)
eu('TAP','cc',78,{'off':0,'on':127},page=4)
for c,n in [('TIME',106),('PARAMETER',107),('RETURN LEVEL',108)]:eu(c,'cc',n,page=4)
add(d,'Timing Clock','realtime',None,{'status_hex':'F8'},'documented chart mode','PDF page 4 / Timing Clock','s2',channel=None,encoding='MIDI Timing Clock')
issue(d,'Source only specifies MIDI-IN (to computer). No host-to-device control map or LED-return behavior is established.','s2','PDF pages 2–4 / MIDI-IN (to computer)');save(d,'euphonia')
d=base('DJControl Inpulse 500');raw(d,'s2');d['scope']='Both decks, mixer and browser numeric scalar addresses, explicit pad modes 1–8 with Shift, palette and meter data. Source anomalies are quarantined; all 14 protocol pages retained. Human channel derived from status nibble, not printed zero-based Channel column.'
P=(ROOT/'ni-hercules-ah/djcontrolinpulse500/midi.txt').read_text().split('\f')
palette=dict(zip([0,2,3,16,18,28,31,48,64,66,76,80,82,92,96,99,116,124,127],['No light','Blue low','Blue','Green low','Cyan low','Green','Cyan','Lime low','Red low','Fuchsia low','Orange low','Yellow low','White low','Lime','Red','Fuchsia','Orange','Yellow','White']))
def he(c,t,n,ch,pg,mode='unshifted',dire='device-to-host',v=None,enc=None):
 add(d,c,t,n,v if v is not None else {'off':0,'on':127},mode,f'PDF page {pg} / {c}','s2',direction=dire,channel=ch,encoding=enc)
# Exact individually printed pad rows; no assumed grid formula.
for pg,page in enumerate(P,1):
 for line in page.splitlines():
  m=re.search(r'(P([12])-\d+)\s+Pad\s+(\d+)\s+Toggle\s+(\+Shift|-)\s+Mode\s+(\d+)',line)
  if not m:continue
  adr=re.findall(r'\b(9[0-9A-F])\s+([0-9A-F]{2})\b',line)
  if not adr and (pg==3 and m.group(3)=='1' and m.group(4)=='+Shift' and m.group(5)=='2'):adr=[('96','18'),('96','18')]
  if len(adr)!=2:
   issue(d,'Pad row requires recovery of split address cells.','s2',f'PDF page {pg} / '+m.group(0),[m.group(0)]);continue
  for i,(st,n) in enumerate(adr):
   he(f'Deck {m.group(2)} Pad {m.group(3)} ({m.group(1)})','note',int(n,16),int(st[1],16)+1,pg,f'Mode {m.group(5)}; '+('Shift' if m.group(4)=='+'+'Shift' else 'unshifted'),'device-to-host' if i==0 else 'host-to-device',None if i==0 else {'palette':palette},'note gate' if i==0 else 'velocity selects pad LED color')
# Per-deck rows appear separately on pages 1–2 and 10–11.
for deck,ch,sh,p1,p2 in [(1,2,5,1,2),(2,3,6,10,11)]:
 for name,n,pg in [('Play',7,p1),('Cue',6,p1),('In',9,p1),('Out',10,p1),('Sync',5,p1 if deck==1 else p2),('Vinyl',3,p2),('Slip',1,p2),('Quant',2,p2)]:
  for mode,c in [('unshifted',ch),('Shift',sh)]:
   for dire in ['device-to-host','host-to-device']:he(f'Deck {deck} {name}','note',n,c,pg,mode,dire)
 he(f'Deck {deck} Shift','note',4,ch,p1)
 he(f'Deck {deck} In','note',11,ch,p1,'long press')
 for mode,c in [('unshifted',ch),('Shift',sh)]:
  for name,n,pg in [('Autoloop rotation',14,p1),('Jog rotation',9,p2),('Jog rotation Vinyl',10,p2)]:he(f'Deck {deck} {name}','cc',n,c,pg,mode,v={'counterclockwise':[127,64],'clockwise':[1,63],'semantics':'slow to fast'},enc='relative signed increment; 7F..40 CCW, 01..3F CW')
  he(f'Deck {deck} Autoloop push','note',44,c,p1,mode)
 for name,a,b in [('Fwd',28,33),('Rev',29,34),('Beat-Align',45,47),('Tempo',44,46),('Up',30,35),('Down',31,36)]:
  for mode,n in [('Guide On',a),('Guide Off',b)]:he(f'Deck {deck} {name} backlight','note',n,ch,p1 if name in ['Fwd','Rev','Beat-Align'] and deck==1 else p2,mode,'host-to-device')
 he(f'Deck {deck} Big 1 backlight','note',48,ch,p2,'normal','host-to-device')
 # Chart's mode buttons explicitly enumerate 1..8 and long-press 1A..4A; modes 3/4/7/8 have irregular Shift markings retained below.
 for n,mode,gesture in [(15,'1','unshifted'),(19,'5','Shift'),(64,'1A','long press'),(16,'2','unshifted'),(20,'6','Shift'),(65,'2A','long press'),(17,'3','unshifted'),(21,'7','unshifted'),(66,'3A','long press'),(18,'4','Shift'),(22,'8','unshifted'),(67,'4A','long press')]:
  he(f'Deck {deck} Pad mode {mode}','note',n,ch,p2,gesture)
  if 'A' not in mode:he(f'Deck {deck} Pad mode {mode} LED','note',n,ch,p2,gesture,'host-to-device')
 issue(d,f'Deck {deck} Centre backlight has blank note address; jog touch CC08 overlaps tempo MSB CC08, including Shift. Exclude both ambiguous controls and associated tempo LSB pending manufacturer clarification.','s2',f'PDF page {p2} / D{deck}-13, D{deck}-15, D{deck}-16',[f'Deck {deck} Centre LED',f'Deck {deck} Jog touch',f'Deck {deck} Tempo MSB/LSB'],severity='conflict')
# Paired analog rows, preserving components and their documented relationship.
def pair(c,coarse,ch,pg,mode='unshifted'):
 for part,n in [('MSB',coarse),('LSB',coarse+32)]:he(c,'cc',n,ch,pg,mode+'; '+part,v={'min':0,'max':127,'component':part,'paired_cc':coarse+32 if part=='MSB' else coarse},enc='7-bit component of paired MSB/LSB analog value')
pair('M-1 Xfader',0,1,5)
he('M-2 Xfader curve on/off','note',24,1,5);he('M-2 Xfader curve','cc',11,1,5,v={'Mix':0,'Scratch':127},enc='discrete curve selection')
issue(d,'M-3 Deck 1 volume repeats B1 00 for both MSB/LSB and B4 20 for both shifted components; excluded without correction.','s2','PDF page 5 / M-3',['Deck 1 volume MSB/LSB, unshifted and Shift'],severity='conflict')
for mode,ch in [('unshifted',3),('Shift',6)]:pair('M-4 Deck 2 volume',0,ch,5,mode)
for deck,ch,sh in [(1,2,5),(2,3,6)]:
 for mode,c in [('unshifted',ch),('Shift',sh)]:
  he(f'Deck {deck} PFL','note',12,c,5,mode)
  if mode=='unshifted':he(f'Deck {deck} PFL LED','note',12,c,5,mode,'host-to-device')
  for name,n,pg in [('Filter',1,5),('Low',2,6),('Mid',3,6),('Hi',4,6),('Gain',5,6 if deck==1 else 7)]:pair(f'Deck {deck} {name}',n,c,pg,mode)
issue(d,'Shifted Deck 1/2 PFL output cells are malformed (4 94 0C and 5 95 0C); excluded.','s2','PDF page 5 / M-5 and M-7',['Shifted Deck 1 and Deck 2 PFL LED output'],severity='conflict')
he('M-6 Guides','note',1,1,5)
issue(d,'M-6 Guides output lists 90 01 00 but detail says off/on, and its input duplicates B4 Assistant 90 01. Both input interpretations and Guides output require clarification.','s2','PDF page 5 M-6; page 8 B4',['M-6 Guides and B4 Assistant input; M-6 Guides output'],severity='conflict')
d['bindings']=[b for b in d['bindings'] if b['control']!='M-6 Guides']
for i in range(4):
 for mode,ch in [('unshifted',1),('Shift',4)]:
  for dire in ['device-to-host','host-to-device']:he(f'M-{10+i} FX{i+1}','note',20+i,ch,6,mode,dire)
for deck,ch in [(1,2),(2,3)]:
 for i in range(9):he(f'M-22 Deck {deck} meter LED {i+1}','note',49+i,ch,7,'individual LED','host-to-device')
issue(d,'Deck meter CC40 table includes malformed upper bound 7FF. Individual LED notes normalized; CC meter thresholds remain raw.','s2','PDF page 7 / M-22',['Deck 1/2 meter CC40 thresholds'],severity='conflict')
for c,n,pg in [('M-23 Mic volume',6,7),('M-24 Mic hi',7,7),('M-25 Mic low',8,7),('M-26 Aux volume',9,7),('M-27 Aux Filter',10,7),('M-28 Master volume',3,7),('M31 Cue-Master',5,8),('M32 Headphones volume',4,8)]:pair(c,n,1,pg)
for c,n in [('M-23 Mic green',16),('M-23 Mic red',17),('M-26 Aux green',18),('M-26 Aux red',19)]:he(c,'note',n,1,7,'indicator','host-to-device')
for deck in [1,2]:
 for i in range(5):he(f'M-29 Master meter side {deck} LED {i+1}','note',6+(deck-1)*5+i,1,8,'individual LED','host-to-device')
issue(d,'Master meter CC40/41 threshold ranges retained in raw evidence; endpoint transcription requires review.','s2','PDF page 8 / M-29',['Master meter CC40/41 aggregated levels'])
# Master PFL status bytes are in the MIDI IN (to computer) columns.
for mode,ch in [('unshifted',1),('Shift',4)]:he('M-30 Master PFL','note',2,ch,8,mode)
for deck,ch,sh in [(1,2,5),(2,3,6)]:
 for mode,c,n in [('unshifted',ch,13),('Shift',sh,13),('long press',ch,14)]:he(f'B{deck} Load {deck}','note',n,c,8,mode)
issue(d,'B2 Load 2 Shift printed channel 4 conflicts with status 95 (human channel 6). Binding excluded until clarified.','s2','PDF page 8 / B2 Load 2 Shift',['B2 Load 2 Shift'],severity='conflict')
d['bindings']=[b for b in d['bindings'] if not(b['control']=='B2 Load 2' and b['mode']=='Shift')]
for mode,ch,n in [('unshifted',1,1),('Shift',4,1),('Assistant',1,2)]:he('B3 Energy rotation','cc',n,ch,8,mode,v={'counterclockwise':[127,64],'clockwise':[1,63],'semantics':'slow to fast'},enc='relative signed increment')
for mode,ch in [('unshifted',1),('Shift',4)]:he('B3 Energy push','note',0,ch,8,mode)
# Browser LED table: preserve exact row text for supported 90 status, quarantine malformed 09 rows.
colors={};bad=[]
for pg in [8,9,10]:
 for line in P[pg-1].splitlines():
  m=re.search(r'\b(90|09) 04 ([0-9A-F]{2})\b',line)
  if not m:continue
  if m.group(1)=='09':bad.append(line.strip());continue
  colors[str(int(m.group(2),16))]=re.sub(r'\s+',' ',line[:m.start()].strip())
he('B3 Energy LED','note',4,1,8,'color / brightness effects; complete table PDF pages 8–10','host-to-device',{'documented_rows':colors,'off':0},'velocity-indexed color and animation')
issue(d,'Browser Energy LED table prints illegal status 09 for several Deep Sky Blue / Medium spring green rows. These palette values are excluded; other 90 04 rows retained verbatim.','s2','PDF pages 8–9 / B3 Energy LED color table',bad,severity='conflict')
issue(d,'Deck 2 mode 4A printed channel 2 conflicts with status 91 (human channel 2, Deck 1). Binding excluded.','s2','PDF page 11 / P2-4 Mode 4A',['Deck 2 Pad mode 4A input'],severity='conflict')
d['bindings']=[b for b in d['bindings'] if b['control']!='Deck 2 Pad mode 4A']
# Reassign IDs after quarantining.
for i,b in enumerate(d['bindings'],1):b['id']=f'b{i:04}'
save(d,'djcontrol-inpulse-500')
for p in OUT.glob('*.json'):
 x=json.load(open(p));print(p.name,len(x['bindings']),len(x['issues']))
for k in [1,2,3]:
 path=OUT/f'xone-k{k}.json';d=json.load(open(path));d['existing_profile']={'id':f'allen-heath.xone-k{k}','version':'1.0.0','local_file':f'../../../XtremeMapping/XtremeMapping/Resources/ControllerProfiles/xone-k{k}-1.0.0.json'};save(d,f'xone-k{k}')
d=json.load(open(OUT/'euphonia.json'));raw(d,'s1',[45]);d['bindings'][-1]['evidence'].append({'source_id':'s1','locator':'PDF page 45 / USB/MIDI: MIDI timing clock is always sent'});d['bindings'][-1]['mode']='always sent'
for b in d['bindings']:
 if b['channel']==1:b['notes'].append('Channel 1 is established by chart status 90/B0; no configurable MIDI channel setting was identified in the archived owner manual. This does not assert a separate user-selectable default.')
save(d,'euphonia')
