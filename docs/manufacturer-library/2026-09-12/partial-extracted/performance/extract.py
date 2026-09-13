"""Reproduce only this performance partial batch from immutable archived manufacturer text."""
import json,re,hashlib
from pathlib import Path
OUT=Path(__file__).resolve().parent
ROOT=OUT.parent.parent
MAN=json.loads((ROOT/'performance/manifest.json').read_text())
models={x['id']:x for x in MAN['models']}
IN='device-to-host'; HOST='host-to-device'
def ev(s,loc):return {'source_id':s,'locator':loc}
def start(slug):
 m=models[slug];d=dict(schema_version=1,manufacturer=m['manufacturer'],model=m['model'],status='partial-extraction',coverage_state='partial',hardware_tested=False,sources=[],scope='',bindings=[],issues=[],raw_evidence=[],setup_notes=[],missing_information=list(m.get('gaps',[])))
 for doc in m['documents']:
  path=ROOT/'performance'/doc['local_file']; assert hashlib.sha256(path.read_bytes()).hexdigest()==doc['sha256']
  sid=doc['type']; d['sources'].append(dict(id=sid,local_file='performance/'+doc['local_file'],url=doc['direct_url'],sha256=doc['sha256']))
  txt=ROOT/'performance'/doc.get('text_file',doc['local_file'])
  if txt.suffix!='.txt':txt=path.with_suffix('.txt')
  raw=OUT/'raw'/f'{slug}-{sid}.txt'
  t=txt.read_text();raw.write_text(t if '--- PDF PAGE' in t else '--- ORIGINAL TEXT DOCUMENT (unpaginated) ---\n'+t)
  d['raw_evidence'].append(dict(source_id=sid,file=str(raw.relative_to(OUT.parent)),extraction_method='Complete archived page-marked PDF text; original PDF authoritative' if '--- PDF PAGE' in t else 'Complete original manufacturer text; unpaginated sections preserved'))
 return d

def add(d,c,typ,ch,num,vals,mode,loc,s='owner-and-midi-guide',direction=IN,encoding=None,notes=None,group=None):
 b=dict(id=f'b{len(d["bindings"])+1:05d}',control=c,direction=direction,message_type=typ,channel=ch,number=num,encoding=encoding or {'cc':'7-bit control change','note':'note on/off','sysex':'manufacturer SysEx bytes','poly-aftertouch':'polyphonic key pressure'}[typ],values=vals,mode=mode,evidence=[ev(s,loc)],app_support='requires-adapter',notes=notes or [])
 if group:b['source_group']=group
 d['bindings'].append(b);return b

def issue(d,desc,loc,excluded=None,severity='scope',s='owner-and-midi-guide'):
 d['issues'].append(dict(id=f'i{len(d["issues"])+1:03d}',severity=severity,description=desc,evidence=[ev(s,loc)],excluded_bindings=excluded or []))
def pages(slug,fn):return re.split(r'--- PDF PAGE \d+ ---',(ROOT/'performance'/slug/fn).read_text())
def save(d,slug):
 assert d['scope'] and d['issues'] and d['missing_information']
 (OUT/f'{slug}.json').write_text(json.dumps(d,indent=2,ensure_ascii=False)+'\n')
 print(slug,len(d['bindings']))

# EC4: the source defines sequential 16-control ranges, group pairs, and channel=setup.
d=start('faderfox-ec4');d['scope']='All readable factory encoder/input-feedback and push-button ranges for setups 1–14, groups 1–7 and 9–15. Clipped groups 8/16 and special Ableton setups excluded. No learned/custom settings are assumed.'
for setup in range(1,15):
 for group in list(range(1,8))+list(range(9,16)):
  for k in range(16):
   n=((group-1)%8)*16+k
   add(d,f'Encoder {k+1}','cc',setup,n,{'min':0,'max':127},f'Factory setup {setup}; group {group}','PDF p.15 Factory settings / Encoder 1–16',notes=['Source explicitly gives channel = setup number, CCAb absolute 7-bit and acceleration Acc3.'])
   add(d,f'Encoder {k+1} value feedback','cc',setup,n,{'min':0,'max':127},f'Factory setup {setup}; group {group}','PDF p.6 Operation incoming MIDI feedback; p.15 factory encoder table',direction=HOST,notes=['Incoming feedback updates encoders and displays; factory address/channel from p.15.'])
   add(d,f'Push button {k+1}','note',setup,n,{},f'Factory setup {setup}; group {group}','PDF p.15 Factory settings / Push button 1–16',notes=['Source specifies Note and Key mode; velocity not assigned from an assumed default.'])
d['setup_notes']=['Select the required setup and group; this extraction covers factory assignments for setups 1–14 only. Learned assignments change number, channel and message type and are saved automatically.']
issue(d,'Factory scope and setup guidance; learn mode changes stored assignments.','PDF pp.6–7 Operation; p.15 Learn mode and Factory settings')
issue(d,'Original PDF p.15 right edge clips the group 8/16 endpoint to 112–12. No endpoint repair or extrapolation is made.','PDF p.15 Factory settings',['Groups 8 and 16, all setups, encoder/push ranges'], 'conflict')
issue(d,'Setups 15/16 have special Ableton script assignments without numeric mapping; configurable NRPN/pitch-bend/aftertouch/relative types lack fixed addresses here.','PDF pp.11–13 command configuration; p.15 setup 15/16',['Special Ableton assignments; custom controls'])
save(d,'faderfox-ec4')

# Twister, explicitly section-local conventions.
d=start('midi-fighter-twister');p=pages('midi-fighter-twister','owner-and-midi-guide.txt');d['scope']='Complete explicit bank 1–4 encoder CC/note/relative modes and switch CC/note tables, encoder value feedback, RGB/ring animation addresses, and bank 1–8 selection protocol. System side/shift addresses and RGB colour channel contradictions remain quarantined.'
for bank in range(1,5):
 rows=re.findall(r'Encoder\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+([A-G]#?-?\d)',p[16+bank]);assert len(rows)==16
 for i,ec,en,sc,sn,note in rows:
  i,ec,en,sc,sn=map(int,[i,ec,en,sc,sn]);mode=f'Default bank {bank}';loc=f'PDF p.{16+bank} Bank {bank} MIDI encoder table; p.4 Encoders; p.15 Switch Action'
  norm=['Appendix explicitly numbers channels 0–15: encoder 0 becomes human 1; switch 1 becomes human 2. Settings can remap addresses.']
  add(d,f'Encoder {i}','cc',ec+1,en,{'min':0,'max':127},mode,loc,notes=norm)
  add(d,f'Encoder {i} switch','cc',sc+1,sn,{'on':127,'off':0},mode+'; CC Hold or CC Toggle',loc,notes=norm)
  add(d,f'Encoder {i} switch','note',sc+1,sn,{'note_hold_on_velocity':127,'note_hold_off_velocity':0},mode+'; Note Hold or Note Toggle configured',loc,notes=norm+['Note address shares explicitly tabulated CC number; note-name column agrees.'])
  add(d,f'Encoder {i}','note',ec+1,en,{'velocity':'encoder value'},mode+'; Note encoder type configured','PDF p.16 Encoder MIDI Type; '+loc,notes=norm)
  add(d,f'Encoder {i}','cc',ec+1,en,{'clockwise':65,'anticlockwise':63},mode+'; Enc 3FH/41H type configured','PDF p.16 Encoder MIDI Type; '+loc,encoding='relative CC 3Fh/41h',notes=norm)
  add(d,f'Encoder {i} value display','note',1,en,{'velocity':'encoder value'},mode+'; Note encoder type configured','PDF p.4 Encoders; '+loc,direction=HOST,notes=norm)
  add(d,f'Encoder {i} value display','cc',1,en,{'min':0,'max':127},mode,'PDF p.4 Encoders; '+loc,direction=HOST,notes=norm)
  for ch,label in [(3,'RGB'),(6,'indicator ring')]:
   for typ in ['cc','note']:
    add(d,f'Encoder {i} {label} animation',typ,ch,sn,{'rgb_gate':[1,8],'rgb_pulse':[10,16],'rgb_brightness':[17,47],'indicator_gate':[49,56],'indicator_pulse':[57,64],'indicator_brightness':[65,95],'rainbow':127,'none':[0,48]},mode,'PDF p.6 animation channel convention 1–16; pp.23–26 Appendix 2 (0–15)',direction=HOST,notes=['p.6 human channels 3/6 agree with p.26 zero-based 2/5. Value 9 is contradictory and excluded. Full timing/brightness table retained in raw evidence.'])
for bank in range(1,9):
 for direction in [IN,HOST]:
  add(d,f'Bank {bank} select','cc',4,bank-1,{'on':127,'off':0} if direction==IN else {'select':127},'Default system channel; eight-bank firmware','PDF p.8 Advanced Bank Control (explicit channels 1–16)',direction=direction,notes=['System channel configurable; table is interpreted by p.8 local 1–16 convention.'])
d['setup_notes']=['Use Midi Fighter Utility to configure bank navigation and switch actions, then press Send To Midi Fighter to save. Four bank address tables are documented; eight-bank selection is documented separately.']
issue(d,'Setup instructions and configurable switch modes.','PDF pp.8,10–11,13,15')
issue(d,'System (4) in Appendix side/shift tables may mean zero-based 4, but p.7 explicitly says human channel 4. Quarantine side and shift messages rather than choose a conflicting channel.','PDF pp.2,7,17–22',['All side-button and Shift Page A/B addresses'], 'conflict')
issue(d,'RGB colour p.4 channel 2 under global zero-based nomenclature differs from p.6 channel-2 example explicitly one-based. Colour feedback quarantined. p.5 RGB pulse starts at 9, Appendix p.23 calls 9 None: value 9 excluded.','PDF pp.2,4–6,23–26',['RGB colour feedback; animation value 9'],'conflict')
issue(d,'Only four banks have per-control address tables despite eight-bank navigation; Super Knob secondary address not specified. Extended palette is graphical without textual RGB values.','PDF pp.3,8,15,17–29',['Banks 5–8 encoder/switch maps; Super Knob secondary CC'])
d['missing_information']+=['Resolve system/colour channel contradictions and animation value 9; supply bank 5–8 per-control tables and Super Knob numbers.']
save(d,'midi-fighter-twister')

# 3D: explicit numeric table rows, reject disagreements with the note-name field.
d=start('midi-fighter-3d');p=pages('midi-fighter-3d','owner-and-midi-guide.txt');d['scope']='All consistent numeric arcade and side rows in four bank tables, optional Ableton CCs, ring colour/animation feedback, and bank selection. Only the consistent clockwise-relative rotation table and edge/pickup state notes are retained; contradictory edge CCs and other rotation directions/modes are quarantined. Channels follow the explicit global 0–15 convention in p.2.'
def note_number(x):
 m=re.fullmatch(r'([A-G])(#?)(-?\d+)',x);return (int(m[3])+1)*12+{'C':0,'D':2,'E':4,'F':5,'G':7,'A':9,'B':11}[m[1]]+bool(m[2])
for bank in range(1,5):
 for i,ch,name,n,cch,cn in re.findall(r'Arcade Button\s+(\d+)\s+(\d+)\s+([A-G]#?-?\d)\s+(\d+)\s+(\d+)\s+(\d+)',p[13+bank]):
  i,ch,n,cch,cn=map(int,[i,ch,n,cch,cn]);mode=f'Bank {bank}';loc=f'PDF p.{13+bank} Bank {bank} MIDI arcade table; pp.2,4–5'
  add(d,f'Arcade button {i}','cc',cch+1,cn,{'pressed':127,'released':0},mode+'; Ableton/Momentary CC enabled',loc,notes=['Channel converted using p.2 explicit zero-based nomenclature.'])
  if note_number(name)!=n:
   issue(d,f'Arcade button {i} bank {bank}: note name {name} and numeric note {n} disagree.',loc,[f'Bank {bank} arcade {i} note and its feedback'],'conflict');continue
  add(d,f'Arcade button {i}','note',ch+1,n,{'pressed_velocity_default':127,'release':'Note Off'},mode,loc,notes=['Velocity configurable; channel converted from source zero-based convention.'])
  add(d,f'Arcade button {i} ring colour','note',ch+1,n,{'disable_midi_colour':0,'force_configured_active_colour':[121,127],'bright_red_example':13},mode,loc,direction=HOST,notes=['Full graphical colour palette retained in PDF; no guessed colour names. Channel follows p.2.'])
  add(d,f'Arcade button {i} ring animation','note',5,n,{'brightness':[18,33],'gate':[34,41],'pulse':[42,49]},mode,'PDF pp.2,5,19 Appendix 2; '+loc,direction=HOST,notes=['Source channel 4 converted to human 5; complete animation rates retained in raw table.'])
 for side,i,ch,name,n in re.findall(r'([LR]H) Side Switch\s+(\d+)\*?\s+(\d+)\s+([A-G]#?-?\d)\s+(\d+)',p[13+bank]):
  n=int(n)
  if note_number(name)!=n:
   issue(d,f'{side} switch {i} bank {bank}: {name} disagrees with numeric {n}.',f'PDF p.{13+bank} side-switch table',[f'Bank {bank} {side} switch {i}'],'conflict');continue
  add(d,f'{side} side switch {i}','note',int(ch)+1,n,{},f'Bank {bank}; Bank Side Buttons enabled',f'PDF pp.2,6,12; p.{13+bank} side-switch table',notes=['For unbanked side controls, use bank-1 addresses; source banked-default prose is inconsistent.'])
for bank in range(1,5):
 for direct in [IN,HOST]:add(d,f'Bank {bank} select','note',5,bank-1,{'on':'select bank','off':'previous bank inactive'} if direct==IN else {'note_on':'select bank'},'Four Banks Mode','PDF pp.2,6 Advanced Bank Control',direction=direct,notes=['Source channel 4 normalized to 5 using p.2 explicit 0–15 convention.'])
for i,ch,*numbers in re.findall(r'Arcade Button\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)',p[18]):
 for bank,number in enumerate(numbers,1):
  add(d,f'Arcade button {i} clockwise rotation','cc',int(ch)+1,int(number),{'semantics':'proportional to rotation from button-press orientation'},f'Bank {bank}; Relative rotation; button held and pickup mode','PDF pp.2,7 Relative Mode; p.18 Button Rotation MIDI',notes=['Only clockwise channel-5 case agrees between prose and numeric table; zero-based 5 normalized to human 6. Counterclockwise/absolute addresses excluded.'])
for control,n in [('Any edge active',17),('Pickup mode',29)]:
 add(d,control,'note',5,n,{'note_on':'state active','note_off':'all edges inactive'} if n==17 else {'note_on':'device picked up'},'Motion state event','PDF pp.2,7 Edge Tilt Messages',notes=['Source F0/F1 pitches converted using the C-1=0 convention demonstrated in Appendix note-name/numeric pairs; source channel 4 normalized to human 5. These state notes are distinct from contradictory edge CC addresses.'])
d['setup_notes']=['Use Midi Fighter Utility to select Four Banks Mode, Bank Side Buttons and Ableton momentary CC behaviour; save edits with Send To Midi Fighter. Absolute rotation home position is set when powered on.']
issue(d,'Setup context and channel nomenclature: normalization uses p.2 explicit 0–15 convention; verify on hardware before runtime integration.','PDF pp.2,6,8,10–13')
issue(d,'Edge Tilt p.18 has note names in Primary CC and secondary 40/39/38/43, contradicting p.7 CC0–7. Rotation p.18 gives only channel 5 while pp.7–8 distinguish relative directions and absolute channel 4; only the agreeing clockwise-relative case is retained.','PDF pp.7–8,18',['Edge Tilt primary/secondary; counterclockwise-relative and absolute rotation'],'conflict')
issue(d,'Ring colour chart is graphical and not colour-name normalized; Super Combo sequence details are deliberately undisclosed.','PDF pp.4,12',['Complete RGB colour-name palette; Super Combo map'])
d['missing_information']+=['Resolve motion and note-name/numeric contradictions; verify channel convention and bank-side defaults.']
save(d,'midi-fighter-3d')

# Korg native fixed map is distinct from configurable scene/DAW mappings.
d=start('korg-nanokontrol2');sid='midi-implementation';d['scope']='Complete fixed Native KORG mode input and LED CC tables, plus documented identity/search/native/scene SysEx commands. Normal CC scenes and DAW factory addresses are not inferred from capabilities or parameter offsets.'
buttons=[('Cycle',46),('REW',43),('FF',44),('STOP',42),('PLAY',41),('REC',45)]
for group in range(1,9):
 for name,base in [('Solo',32),('Mute',48),('Rec',64)]:buttons.append((f'Group {group} {name}',base+group-1))
for name,n in buttons:
 add(d,name+' LED','cc',16,n,{'off':[0,64],'on':[65,127]},'Native KORG mode','Section 4(1) Native KORG mode Display LEDs',sid,HOST)
for name,n in buttons+[('Previous Track',58),('Next Track',59),('Marker Set',60),('Previous Marker',61),('Next Marker',62)]:
 add(d,name,'cc',16,n,{'on':127,'off':0},'Native KORG mode','Section 4(2) Native KORG Mode Button Output',sid)
for group in range(1,9):
 for name,base in [('Knob',16),('Slider',0)]:add(d,f'Group {group} {name}','cc',16,base+group-1,{'min':0,'max':127},'Native KORG mode','Section 4(3) Native KORG Mode Knob/Slider Output',sid)
header='F0 42 4g 00 01 13 00 '
cmds=[('Current Scene Data Dump Request','1F 10 00',HOST,'3-1(1)'),('Scene Write Request','1F 11 00',HOST,'3-1(2)'),('Native mode In/Out Request','00 00 qq',HOST,'3-1(3)'),('Mode Request','1F 12 00',HOST,'3-1(4)'),('Current Scene Data Dump','7F 7F 02 03 05 40 [388 packed data bytes]',HOST,'3-1(5)'),('Current Scene Data Dump','7F 7F 02 03 05 40 [388 packed data bytes]',IN,'3-1(5)'),('Data Load Completed','5F 23 00',IN,'3-1(6)'),('Data Load Error','5F 24 00',IN,'3-1(7)'),('Write Completed','5F 21 00',IN,'3-1(8)'),('Write Error','5F 22 00',IN,'3-1(9)'),('Native mode In/Out','40 00 rr',IN,'3-1(10)'),('Mode Data','5F 42 mm',IN,'3-1(11)')]
for name,body,direction,loc in cmds:
 add(d,name,'sysex',None,None,{'hex_template':header+body+' F7','g':'global channel nibble 0–15','qq':{'0':'Out request','1':'In request'},'rr':{'2':'Out','3':'In'},'mm':{'0':'Normal','1':'Native'}} if 'mode' in name.lower() else {'hex_template':header+body+' F7','g':'global channel nibble 0–15'},'Device configuration/Native mode control',loc,sid,direction,notes=['No channel-voice channel; global channel parameter g is configurable. Scene dump 339 bytes packed to 388 bytes per NOTE 1/2 and TABLE 1.'])
for name,body,direction,loc in [('Identity request','F0 7E gg 06 01 F7',HOST,'2-1'),('Identity reply','F0 7E 0g 06 02 42 13 01 00 00 xx xx xx xx F7',IN,'1-2'),('Search device request','F0 42 50 00 dd F7',HOST,'2-3'),('Search device reply','F0 42 50 01 0g dd 13 01 00 00 xx xx xx xx F7',IN,'1-4')]:
 add(d,name,'sysex',None,None,{'hex_template':body,'gg':'00–0F global device channel or 7F any channel','g':'global channel 0–15','dd':'echo-back ID','xx':'firmware version bytes'},'Device discovery',loc,sid,direction,notes=['Global device ID is configurable; SysEx has no channel-voice channel.'])
d['setup_notes']=['The fixed controls here require Native KORG mode, entered with the documented Native mode In request. Normal CC-mode assignments come from the current scene; read that scene before creating an application mapping.']
issue(d,'Native entry and scene read guidance derive from the manufacturer SysEx protocol.','Sections 3-1(1),(3),(5),(10); 4',s=sid)
issue(d,'Scene parameter numbers in TABLE 1 are byte offsets, not factory CC numbers; no normal-mode defaults are extracted. DAW mode pitch-bend capability does not establish per-slider addresses.','Section 1-1; TABLE 1 Scene Parameter', ['Normal-mode factory map; DAW-mode map'],s=sid)
d['missing_information']+=['Native map is documented but untested; normal-mode scene defaults and DAW mode-specific bindings remain unavailable. Packed scene bytes preserved as raw evidence rather than full parameter codec.']
save(d,'korg-nanokontrol2')

# LCXL system-exclusive feedback addresses are independent of selected template input map.
d=start('launch-control-xl-legacy');sid='programmer-reference';d['scope']='All 48 LED indices and 24 toggle-button indices with explicit template parameters, all 16 template reset/buffer/test controls, and bidirectional template-change SysEx. Full factory input address map absent.'
labels=[f'{row} knob {i}' for row in ['Top','Middle','Bottom'] for i in range(1,9)]+[f'{row} channel button {i}' for row in ['Top','Bottom'] for i in range(1,9)]+['Device','Mute','Solo','Record Arm','Up','Down','Left','Right']
for index,label in enumerate(labels):
 add(d,label+' LED','sysex',None,None,{'hex_template':'F0 00 20 29 02 11 78 Template Index Value F7','index':index,'template_min':0,'template_max':15,'value_formula':'16*Green + Red + Flags','green':[0,3],'red':[0,3],'flags':{'normal':12,'flash':8,'double_buffer':0},'normal_colours':{'off':12,'red_low':13,'red_full':15,'amber_low':29,'amber_full':63,'yellow_full':62,'green_low':28,'green_full':60},'flashing_colours':{'red':11,'amber':59,'yellow':58,'green':56}},'Any template, including background','PDF pp.4–5 value encoding; p.7 Set LEDs',sid,HOST,notes=['SysEx index is stored in values.index, not a note/CC number. Template byte selects user 0–7 or factory 8–15. Multiple index/value pairs supported.'])
for index,label in enumerate(labels[24:]):
 add(d,label+' toggle state','sysex',None,None,{'hex_template':'F0 00 20 29 02 11 7B Template Index Value F7','index':index,'template_min':0,'template_max':15,'off':0,'on':127},'Buttons configured Toggle; any template','PDF p.7 Toggle button states',sid,HOST,notes=['No channel in SysEx. Non-toggle buttons ignore this command; multiple index/value pairs supported.'])
for t in range(16):
 for label,vals,loc in [('Reset LEDs/buffers',{'value':0},'p.5 Reset'),('Double buffering',{'formula':'32 + 4*Update + Display + 16*Copy + 8*Flash','Update':[0,1],'Display':[0,1],'Copy':[0,1],'Flash':[0,1]},'p.6 Control double-buffering'),('LED test',{'low':125,'medium':126,'full':127},'p.6 Turn on all LEDs')]:
  add(d,label,'cc',t+1,0,vals,f'Template {t} (channel selects template)','PDF '+loc,sid,HOST,notes=['Zero-indexed template n maps to human channel n+1, independent of input channels.'])
for direction in [IN,HOST]:add(d,'Current template','sysex',None,None,{'hex_template':'F0 00 20 29 02 11 77 Template F7','template_min':0,'template_max':15},'Template selection/notification','PDF p.8 Change current template / Template changed',sid,direction,notes=['SysEx has no channel; user templates 0–7, factory 8–15.'])
d['setup_notes']=['Use Launch Control XL Editor for user-template assignments. SysEx feedback can target any template; legacy note feedback requires matching the currently selected template channel and note/CC.']
issue(d,'Template setup and feedback matching requirements.','PDF pp.3,5,8',s=sid)
issue(d,'Input notes/CCs/channels depend on templates; the reference does not supply the full factory input map. The p.8 dial LED note diagram is graphical and does not establish full per-template input maps.','PDF pp.3,8',['Factory input bindings; legacy template-dependent note feedback'],s=sid)
issue(d,'Appendix external-flashing off example repeats hex 20h but gives decimal 33; normative p.6 bit formula retained and inconsistent example excluded.','PDF pp.6,9',['Appendix external-flash-off hex example'],'conflict',sid)
save(d,'launch-control-xl-legacy')

# Neon: parse every explicit table cell, keeping source page, section, bank/deck and modifiers.
d=start('neon');sid='midi-chart';p=pages('neon','midi-chart-1.txt');d['scope']='All unambiguous numeric cells across eight performance mode/layer pages and performance-button table, expanded per pad/LED and retained per bank/deck/context. Note/CC input and mirrored output follow p.9; LED-only rows are output. Suspect copy errors and malformed ranges quarantined. pp values remain unspecified.'
def neon_cell(token,label,mode,loc,led=False):
 m=re.fullmatch(r'([9AB][0-9A-Fa-f]),([0-9A-Fa-f]{2})(?:-([0-9A-Fa-f]{2}))?,pp',token)
 if not m:
  issue(d,'Malformed/placeholder chart cell retained without address repair: '+token,loc,[mode+' '+label],'conflict',sid);return
 status=int(m[1],16);lo=int(m[2],16);hi=int(m[3],16) if m[3] else lo
 assert 0<=lo<=hi<=127
 for idx,num in enumerate(range(lo,hi+1),1):
  control=label
  if hi>lo:
   control=label.replace('1-8',str(idx)).replace('1-5',str(idx))
   if control==label:control+=f' {idx}'
  typ={9:'note',10:'poly-aftertouch',11:'cc'}[status>>4]
  for direction in ([HOST] if led else [IN,HOST]):
   add(d,control,typ,(status&15)+1,num,{},mode,loc+'; PDF p.9 Notes: MIDI IN = MIDI OUT',sid,direction,encoding='7-bit pp data byte (value semantics not specified)',notes=['Exact source token: '+token,'pp interpretation is not supplied; no assumed velocity, release, relative increment or RGB palette. Output mirroring follows source MIDI IN = MIDI OUT; hardware/MIDI LED behaviour remains context-dependent.'],group=mode)
for page in range(1,9):
 mode=re.search(r'((?:SAMPLE|SLICER|HOT CUE|HOT LOOP) MODE[^\n]+)',p[page])[1].strip();section=None;headers=[]
 for line in p[page].splitlines():
  st=line.strip()
  if st.startswith('Pad 1-8'):
   section='Pads';headers=['Pad 1-8','Pad 1-8 (Shift)','Pad 1-8 + Trax (move)']+(['MODE + PAD 1-8','REPEAT + PAD 1-8','SYNC + PAD 1-8','BANK button','BANK button (Shift)'] if page==1 else ['CENSOR + PAD 1-8','SLIP + PAD 1-8','DECK SYNC + PAD 1-8','DECK button','DECK button (Shift)'])
  elif st.startswith('MODE ') or st.startswith('CENSOR '):
   section='Mode switches';headers=['MODE','MODE (Shift)','REPEAT','REPEAT (Shift)','SYNC','SYNC (Shift)','Velocity ON','After Touch ON'] if page==1 else ['CENSOR','CENSOR (Shift)','SLIP','SLIP (Shift)','DECK SYNC','DECK SYNC (Shift)','Velocity ON','Velocity ON (Shift)']
  elif st.startswith('After Touch ON'):
   section='Aftertouch';headers=['After Touch ON','After Touch ON (Shift)']
  elif st.startswith('LED 1-5 PAD 1'):
   section='Pad LEDs';headers=[f'LED 1-5 PAD {i}' for i in range(1,9)]
  elif st.startswith('TRAX-encoder'):
   section='TRAX encoder';headers=['TRAX turn','TRAX press','TRAX turn (Shift)','TRAX press (Shift)','Pad 1-8 + Trax (move)']
  elif st.startswith('LOOP-encoder'):
   section='LOOP encoder';headers=['LOOP turn','LOOP press','LOOP turn (Shift)','LOOP press (Shift)']
  row=re.match(r'\s*(Bank|Deck) ([ABCD](?:\+D)?)\s+(.*)',line)
  if not row or not section:continue
  bank=row[1]+' '+row[2];tokens=row[3].split()
  if row[2]=='C+D':
   if page==1 and section=='Pads' and tokens==['96,49,pp']:neon_cell(tokens[0],'BANK button (Shift)',mode+'; Bank C+D',f'PDF p.{page} {section} Bank C+D')
   continue
  # The p.1 TRAX rows include right-hand annotations: first five cells are the actual table.
  if page==1 and section=='TRAX encoder':tokens=tokens[:5]
  if len(tokens)!=len(headers):
   issue(d,'Table row length requires manual interpretation: '+line.strip(),f'PDF p.{page} {section}',[mode+' '+bank],'scope',sid);continue
  for col,(label,token) in enumerate(zip(headers,tokens)):
   context=mode+'; '+bank;loc=f'PDF p.{page} {section}, {bank}, column {label}'
   if (page>=2 and section=='Mode switches' and row[2] in ['C','D'] and label=='DECK SYNC') or (page==7 and section=='Mode switches' and row[2]=='B' and label=='Velocity ON'):
    issue(d,'Suspected copied address duplicates another control/deck: '+token,loc,[context+' '+label],'conflict',sid);continue
   if page==1 and section in ['TRAX encoder','LOOP encoder'] and '*' in token:
    # Explicit annotation resolves source-deck dependence, not the selected sampler bank.
    if section=='TRAX encoder':resolved=f'96,{32+ord(row[2])-65:02X},pp';neon_cell(resolved,label,context+'; entered from '+bank,loc+' and right-hand source-deck annotation');continue
    # The four rows are sampler bank placeholders, each with four explicitly annotated source-deck cases.
    for deck in range(4):
     addr=[4+deck,36+deck,73+deck,99+deck][col];status=['B6','96','B6','96'][col]
     neon_cell(f'{status},{addr:02X},pp',label,context+f'; entered from Deck {chr(65+deck)}',loc+' and below-table source-deck annotation')
    continue
   if ('Velocity' in label or 'After Touch' in label) and '-' in token:label+=' PAD 1-8'
   neon_cell(token,label,context,loc,section=='Pad LEDs')
headers=['Sampler 1st layer','Sampler 2nd layer','Slicer 1st layer','Slicer 2nd layer','Hot Cue 1st layer','Hot Cue 2nd layer','Hot Loop 1st layer','Hot Loop 2nd layer']
for deck,rest in re.findall(r'Deck ([ABCD])\s+([^\n]+)',p[9]):
 tokens=rest.split()
 if len(tokens)!=8:continue
 for col,(label,token) in enumerate(zip(headers,tokens)):
  if deck=='D' and col in [1,6]:issue(d,'Deck D performance-mode row diverges from other deck offsets and overlaps other functions: '+token,'PDF p.9 PERFORMANCE MODE buttons',[f'Deck D {label}'],'conflict',sid);continue
  neon_cell(token,label+' button',f'Performance mode selection; Deck {deck}','PDF p.9 PERFORMANCE MODE buttons')
neon_cell('93,44,pp','Long press HOT CUE','Long press HOT CUE button','PDF p.9 Long press HOT CUE Button')
for deck in range(4):neon_cell(f'{0x93+deck:02X},0D,pp','Sampler trigger',f'Sampler Mode 1st layer; Deck {chr(65+deck)}','PDF p.9 Sampler Mode 1st layer TRIGGER')
add(d,'Slave link connected','sysex',None,None,{'hex_bytes':'F0 0A 40 F7'},'Slave link cable connection','PDF p.9 SysEx messages',sid,IN,notes=['No channel. Source calls slave TM1.'])
issue(d,'Enable/disable Deck SysEx bytes are shown but message direction is not explicit; retained as raw protocol.','PDF p.9 SysEx messages',['F0 0A 00/01/02 F7 enable/disable Deck commands'],s=sid)
d['setup_notes']=['Startup is HOT CUE first layer. Each deck remembers its last performance mode. Sampler second-layer velocity and aftertouch are always enabled. In sampler first layer, an incoming bank-button MIDI message changes the bank.']
issue(d,'Mode and bank setup guidance; input/output mirroring and hardware-driven versus MIDI-driven LEDs.','PDF p.9 Notes and Bank/Deck-buttons behaviour',s=sid)
issue(d,'pp value semantics, release encodings, encoder increments and LED RGB palette are not defined; numeric addresses do not imply runtime compatibility.','PDF pp.1–9 tables and Notes',s=sid)
d['missing_information']+=['Correct Deck C/D SYNC duplicate notes; Deck D sampler/hot-loop performance selection; Deck B hot-loop velocity channel; malformed period/comma range cells; pp and RGB semantics.']
save(d,'neon')

# Local review summary, counts are contextual records, not unique physical controls.
rows=[]
for slug in ['midi-fighter-3d','midi-fighter-twister','faderfox-ec4','korg-nanokontrol2','launch-control-xl-legacy','neon']:
 d=json.loads((OUT/f'{slug}.json').read_text());rows.append(f'| {d["manufacturer"]} {d["model"]} | {len(d["bindings"])} | {len(d["issues"])} |')
(OUT/'README.md').write_text('# Performance partial manufacturer extraction\n\nStage-2 evidence only; no hardware validation or application integration. Counts retain bank, setup, template, mode and direction contexts. SysEx controls are protocol bindings, not physical controls.\n\n| Model | Normalized bindings | Issues |\n|---|---:|---:|\n'+'\n'.join(rows)+'\n\nRun `python3 extract.py` in this directory to reproduce this batch. Every source hash is verified before extraction. All source documents have complete local text copies in raw/, preserving page markers or the original unpaginated text structure. Original PDFs remain authoritative. Specific missing information, setup provenance, quarantined cells and coverage scope are recorded in each model JSON.\n')
