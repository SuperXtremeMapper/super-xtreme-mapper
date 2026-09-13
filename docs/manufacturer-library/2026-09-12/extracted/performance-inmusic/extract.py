"""Reproducible, source-specific transcription. No runtime profile generation."""
import json,re
from pathlib import Path
BASE=Path(__file__).resolve().parents[2]; OUT=Path(__file__).resolve().parent
CAT=json.loads((BASE/'catalogue.json').read_text())['models']
D={}
def init(model,slug):
 m=next(x for x in CAT if x['model']==model); src=next(s for s in m['sources'] if 'programmer' in s['local_file'].lower() or 'protocol' in s['kind'] or 'specification' in s['local_file'].lower() or 'owner-and-midi' in s['local_file'])
 text=(BASE/src['extracted_text']).read_text();
 if '--- PDF PAGE' not in text: text='\n'.join(f'--- PDF PAGE {i+1} ---\n{p}' for i,p in enumerate(text.split('\f')) if p.strip())
 raw=OUT/'raw'/f'{slug}-protocol.txt';raw.write_text(text)
 d=dict(schema_version=1,manufacturer=m['manufacturer'],model=model,status='documented-extraction',hardware_tested=False,sources=[dict(id='protocol',**{k:src[k] for k in ['local_file','url','sha256']})],scope='',bindings=[],issues=[],raw_evidence=[dict(source_id='protocol',file=str(raw.relative_to(BASE/'extracted')),extraction_method='Archived PDF layout text with PDF page markers; diagrams additionally visually transcribed where noted.')]);D[slug]=d;return d,text

def add(d,control,typ,num,ch,direction='device-to-host',encoding='absolute 7-bit',values=None,mode='documented MIDI mode',page='protocol',notes=None):
 d['bindings'].append(dict(id=f"b{len(d['bindings'])+1:05d}",control=control,direction=direction,message_type=typ,channel=ch,number=num,encoding=encoding,values={} if values is None else values,mode=mode,evidence=[dict(source_id='protocol',locator=page)],app_support='requires-adapter',notes=(notes or [])+(['Channel unspecified/configurable or ignored in this source context; no default inferred.'] if ch is None else [])))
def issue(d,id,desc,page,excluded=None,severity='scope'):
 d['issues'].append(dict(id=id,severity=severity,description=desc,evidence=[dict(source_id='protocol',locator=page)],excluded_bindings=excluded or []))
ABS=dict(min=0,max=127);BTN=dict(press=127,release=0)
# UC4: complete explicit factory ranges, 18 setups; no extrapolation beyond the chart.
d,t=init('UC4','faderfox-uc4');d['scope']='Factory setups 1–18: every encoder, push button with an assigned note, green button and all nine faders in each group; feedback uses same assignments. Editable assignments remain configuration dependent.'
for setup in range(1,19):
 for g in range(8):
  normal=setup<=16
  specs=[('Encoder', 'cc',[8,16,24,32,72,80,88,96][g] if normal else [0,8,16,24,56,48,32,56][g],setup if normal else (14 if g==4 else 13 if g==7 else setup-4),8),('Push button','note',g*8 if normal else 120 if g==7 else None,setup if normal else 13,8),('Green button','note',64+g*8 if normal else [64,72,104,96,80,88,120,56][g],setup if normal else 14 if g==6 else setup-4,8),('Fader','cc',[32,40,48,56,104,104,104,104][g] if normal else 40,setup if normal else setup-4,8),('Fader 9','cc',112 if normal else 48,setup if normal else 14,1)]
  for label,typ,start,ch,count in specs:
   if start is None: continue
   for k in range(count):
    c=f'{label} {k+1}' if count>1 else label;mode=f'Factory setup {setup}, group {g+1}'
    vals=ABS if typ=='cc' else {'press':'configured upper value','release':'configured lower value'}
    add(d,c,typ,start+k,ch,encoding='absolute 7-bit' if typ=='cc' else 'momentary note',values=vals,mode=mode,page='PDF p13 Factory settings; pp8–10 editing semantics')
    if label!='Push button':add(d,c+' feedback',typ,start+k,ch,'host-to-device','value/display feedback' if typ=='cc' else 'LED feedback using matching button command',vals,mode,'PDF p13 Factory settings; p8 Display scale')
  if not normal and g==4:
   for k,n in [(3,122),(4,123)]:add(d,f'Push button {k}','note',n,14,encoding='momentary note',mode=f'Factory setup {setup}, group 5',page='PDF p13 factory notes 122–123; p6 track group buttons 3–4')
issue(d,'editable-protocols','CCr1 1/127 and CCr2 63/65, high-resolution CC MSB 0–31 plus LSB MSB+32, pitch bend, channel pressure and program change are editable alternatives, not factory bindings. SysEx backup format is not specified. Program-change is outside stage-1 message_type vocabulary.','PDF pp9–12',['Non-factory assignments and SysEx dump bytes'],'unsupported')
# LC6000

d,t=init('LC6000 PRIME','denon-lc6000-prime');d['scope']='All definite scalar send buttons/encoders and receive LED addresses; documented paired jog/pitch messages retained as compound. RGB palette interpretation and scrub pair quarantined.'
labels={1:'Play/Pause',2:'Cue',5:'Track Skip Previous',6:'Track Skip Next',3:'Beat Jump Back',4:'Beat Jump Forward',7:'Censor',8:'Loop In',9:'Loop Out',10:'Auto Loop Set',16:'Back',17:'Forward',18:'Select press',19:'Vinyl',20:'Sync',21:'Master Deck',22:'Key Lock',23:'Slip',24:'Pitch -',25:'Pitch +',26:'Shift',27:'Hot Cue Mode',30:'Loop Mode',28:'Roll Mode',29:'Slicer Mode',**{32+i:f'Performance Pad {i+1}' for i in range(8)},40:'Platter Touch',68:'Parameter Back',69:'Parameter Forward',70:'Needle Drop Touch'}
for n,c in labels.items():add(d,c,'note',n,1,encoding='Note On 127; Note Off 0',values=BTN,page='PDF pp2–3 Inbound Send Messages')
for n,c in [(3,'Auto Loop Size'),(6,'Select Turn')]:add(d,c,'cc',n,1,encoding='relative directional data',values={'reverse':[64,127],'forward':[1,63],'semantics':'slow to fast relative data; exact delta formula unspecified'},page='PDF p3 Inbound CC')
for c,hi,lo,enc in [('Jog Wheel',55,54,'double precision relative CC pair'),('Pitch Slider',8,40,'double precision absolute CC pair')]:add(d,c,'compound',None,1,encoding=enc,values={'upper_cc':hi,'lower_cc':lo,'byte_bounds':[0,127]},page='PDF p4 Double Precision Control',notes=['Preserves byte pairing; no undocumented combination/delta formula imposed.'])
for n in [*range(1,11),18,19,20,21,22,23,24,25,26,41,42,43,68,69,27,30,28,29]:add(d,{10:'Auto Loop Light Ring',18:'Select Light Ring',41:'Pitch Arrow Back',42:'Pitch Center',43:'Pitch Arrow Forward'}.get(n,labels.get(n))+' LED','note',n,1,'host-to-device','LED brightness state',{'0':'off','1':'dim','2–127':'full brightness'},page='PDF p5 Outbound Receive Messages')
for n in range(32,41):add(d,f'Performance Pad {n-31} RGB' if n<40 else 'Platter LED Ring','note',n,1,'host-to-device','palette velocity; color interpretation quarantined',{},page='PDF p6 RGB LEDs',notes=['Palette decimal and hex columns disagree by one; no off/color value normalized.'])
issue(d,'needle-duplicate','Needle Drop Scrub upper and lower CC both printed as decimal 64 / hex 0x40. Ambiguous pair excluded.','PDF p4',['Needle Drop Scrub CC pair'],'conflict')
issue(d,'palette-offset','Every decimal velocity is one above hexadecimal column (OFF decimal 1 vs hex 0). RGB addresses retained without palette interpretation.','PDF pp7–9',['All RGB color/off velocity meanings'],'conflict')
issue(d,'wheel-display','Wheel display needs SysEx; manual gives no wire format.','PDF p6',['Wheel display SysEx'],'unsupported')
# APC mini

d,t=init('APC mini mk2','akai-apc-mini-mk2');d['scope']='Complete clip address range, track/scene/Shift buttons and faders; all sixteen documented RGB behavior channels. Session input channel unspecified within documented 0–15 range; Drum/Note port contexts kept separate.'
palette={str(int(n)):c.upper() for c,n in re.findall(r'(#[0-9A-Fa-f]{6})\s+(\d+)',t)};d['color_palette']=palette
for base,label in [(100,'Track Button'),(112,'Scene Launch')]:
 for k in range(8):
  add(d,f'{label} {k+1}','note',base+k,1,encoding='Note On/Off; velocity unspecified',mode='Port 0',page='PDF pp15–16 Control Mapping')
  add(d,f'{label} {k+1} LED','note',base+k,1,'host-to-device','single-color LED',{'0':'off','1':'on','2':'blink','3–127':'on'},'Port 0','PDF pp2,6,15–16')
add(d,'Shift','note',122,1,encoding='Note On/Off',mode='Port 0',page='PDF p16')
beh=['solid 10%','solid 25%','solid 50%','solid 65%','solid 75%','solid 90%','solid 100%','pulse 1/16','pulse 1/8','pulse 1/4','pulse 1/2','blink 1/24','blink 1/16','blink 1/8','blink 1/4','blink 1/2']
for n in range(64):
 for mode,ch in [('Session View; port 0; source MIDI CH 00–0F',None),('Drum Mode; port 0',10),('Note Mode; port 1; protocol chart only',1)]:add(d,f'Clip Launch Button {n}','note',n,ch,encoding='Note On/Off',mode=mode,page='PDF p16 Control Mapping',notes=['Note mode owner configuration may alter musical note mapping; this is the protocol chart address, not a scale-derived layout.'])
 for ch,b in enumerate(beh,1):add(d,f'Clip Launch Button {n} LED','note',n,ch,'host-to-device','RGB palette velocity',{'min':0,'max':127,'behavior':b,'palette':'color_palette'},'Port 0 RGB LED control','PDF pp3–7')
for k in range(9):add(d,f'Fader {k+1}','cc',48+k,1,values=ABS,mode='Port 0',page='PDF p16 Channel Faders / Master Fader')
issue(d,'sysex-initialization','RGB SysEx uses paired MSB/LSB per 8-bit RGB component and pad ranges. Introduction reply claims four data bytes but lists nine faders; literal 00x4F/00x7F typos retained. Needs dedicated parser, initialization reply excluded.','PDF pp9–14',['Custom RGB SysEx, inquiry and introduction transactions'],'unsupported')
# Launchpad explicit diagram rows, not inferred formula
rows=[[11,12,13,14,15,16,17,18],[21,22,23,24,25,26,27,28],[31,32,33,34,35,36,37,38],[41,42,43,44,45,46,47,48],[51,52,53,54,55,56,57,58],[61,62,63,64,65,66,67,68],[71,72,73,74,75,76,77,78],[81,82,83,84,85,86,87,88]]
for model,slug in [('Launchpad Pro MK3','launchpad-pro-mk3'),('Launchpad X','launchpad-x'),('Launchpad Mini MK3','launchpad-mini-mk3')]:
 d,t=init(model,slug);pro='Pro' in model;pg=19 if pro else 10
 d['scope']='Entire Programmer mode diagram addresses transcribed individually from original PDF; input type and both accepted feedback types retained. No musical scale grid inferred. Full protocol retained for additional DAW/custom mode work.'
 controls=[(f'Pad row {r+1} bottom-up column {c+1}','note',n) for r,row in enumerate(rows) for c,n in enumerate(row)]
 controls += [(f'Top button {k+1}','cc',n) for k,n in enumerate([91,92,93,94,95,96,97,98])]+[(f'Right button {k+1} bottom-up','cc',n) for k,n in enumerate([19,29,39,49,59,69,79,89])]
 if pro:controls +=[(f'Left button {k+1} bottom-up','cc',n) for k,n in enumerate([10,20,30,40,50,60,70,80])]+[('Shift','cc',90)]+[(f'Track select {k+1}','cc',n) for k,n in enumerate([101,102,103,104,105,106,107,108])]+[(f'Track control {k+1}','cc',n) for k,n in enumerate([1,2,3,4,5,6,7,8])]
 for c,typ,n in controls+[('Logo','cc',99)]:
  if c!='Logo':add(d,c,typ,n,None,encoding='pad/button event; indicated Note or CC type',mode='Programmer mode; MIDI USB interface',page=f'PDF p{pg} Programmer mode layout (visual transcription)',notes=['Diagram establishes address and type; programmer input channel not stated explicitly on this page.'])
  for ch,behavior in [(1,'static'),(2,'flashing'),(3,'pulsing')]:
   for mt in ['note','cc']:add(d,c+' LED',mt,n,ch,'host-to-device','Novation palette index',{'min':0,'max':127,'behavior':behavior},'Programmer mode; MIDI USB interface',f'PDF p{pg} Programmer layout; Colouring the surface / Lighting modes',notes=['Palette swatches preserved in original PDF; RGB hex values not inferred.'])
 issue(d,'remaining-modes','DAW Session/Drum/Fader and factory/custom layouts are distinct contexts and are retained in full raw protocol, but not normalized here. SysEx lighting, configuration, scrolling and inquiry require dedicated adapters. Programmer input channel is not asserted from another mode.','PDF Programmer mode; DAW mode; SysEx message summary',['DAW and custom mode bindings; SysEx transactions'],'scope')
# XL3

d,t=init('Launch Control XL 3','launch-control-xl-3');d['scope']='Complete DAW physical address diagram; encoder absolute and relative variants, touch events, host position/LED feedback, and feature controls with query/report directions. Standalone surface is configurable.'
controls=[(f'Fader {k+1}',n) for k,n in enumerate([5,6,7,8,9,10,11,12])]+[(f'Encoder row {r+1} column {k+1}',n) for r,row in enumerate([[13,14,15,16,17,18,19,20],[21,22,23,24,25,26,27,28],[29,30,31,32,33,34,35,36]]) for k,n in enumerate(row)]
for c,n in controls:
 add(d,c,'cc',n,16,values=ABS,mode='DAW USB interface; absolute',page='PDF p9 diagram')
 if n>=13:
  add(d,c,'cc',n+64,16,encoding='relative offset binary pivot 64',values={'stationary':64,'clockwise':'value-64 for values >64','anticlockwise':'64-value for values <64'},mode='DAW USB interface; row relative enabled',page='PDF p10')
  add(d,c+' position','cc',n,16,'host-to-device','absolute position feedback',ABS,'DAW USB; absolute mode','PDF p10')
  add(d,c+' LED','cc',n,1,'host-to-device','palette index',ABS,'DAW USB interface','PDF pp11–12')
 add(d,c+' touch','cc',n,15,encoding='touch on/off',values=BTN,mode='DAW USB; touch events enabled',page='PDF pp10–11')
buttons=[(f'Upper button {k+1}',n) for k,n in enumerate([37,38,39,40,41,42,43,44])]+[(f'Lower button {k+1}',n) for k,n in enumerate([45,46,47,48,49,50,51,52])]+[('Page up',106),('Page down',107),('Track left',103),('Track right',102),('Record',118),('Play',116),('Shift',63),('Solo/Arm',65),('Mute/Select',66)]
for c,n in buttons:
 add(d,c,'cc',n,7 if n==63 else 1,encoding='button CC event',mode='DAW USB interface',page='PDF p9 diagram')
 if n!=63:add(d,c+' LED','cc',n,1,'host-to-device','palette index if control has LED',ABS,'DAW USB interface','PDF pp9,11–12')
features={30:('Surface mode select',{'1':'DAW Mixer','2':'DAW Control','6–9':'Custom 1–4','18–29':'Custom 5–16'}),63:('Shift',BTN),69:('Encoder row 1 relative',BTN),72:('Encoder row 2 relative',BTN),73:('Encoder row 3 relative',BTN),70:('Fader pickup',BTN),71:('Touch events',BTN),111:('LED brightness',ABS),112:('Screen brightness',ABS),113:('Temporary display timeout',{'min':0,'max':99,'unit':'1/10 sec; minimum 1 sec at 0'}),120:('Out2 MIDI thru',BTN),121:('Encoder curve',{'0':'slow','1':'medium','2':'fast'})}
for n,(c,v) in features.items():
 for dr,ch,enc in [('host-to-device',7,'feature set'),('host-to-device',8,'feature query'),('device-to-host',7,'feature reply')]:add(d,c,'cc',n,ch,dr,enc,v if enc!='feature query' else {},'DAW USB interface feature controls', 'PDF pp16–17')
for n,c in [(11,'Feature controls enable'),(12,'DAW mode enable')]:add(d,c,'note',n,16,'host-to-device','enable/disable',{'127':'enable','0':'disable'},'DAW USB interface','PDF pp8,16')
issue(d,'global-channel-typo','Global MIDI channel CC100 table says hex 00–0e (0–15), and 0Eh (15) channel16. Inconsistent last value excluded.','PDF p17',['Global MIDI channel feature CC100'],'conflict')
issue(d,'screen-conflicts','Screen target IDs conflict: configuration stationary 53/temporary54 versus bitmap32/33. Bitmap message/response terminate 7F rather than F7. p10 custom mode ranges overlap Custom8; p17 coherent range retained.','PDF pp10,13–15,17',['Bitmap/screen SysEx; p10 overlapping custom-mode values'],'conflict')
issue(d,'complex-feedback','RGB LED and screen text/bitmap SysEx retained raw; standalone custom mappings are editable, not fixed. Diagram auxiliary CC104 lacks a clear semantic label and is quarantined pending manufacturer clarification.','PDF pp7,9,12–15',['Standalone custom controls; RGB/screen SysEx; auxiliary CC104'],'unsupported')
# APC40: mode 1/2 momentary note chart; mode 0 banking preserved for definite CCs.
d,t=init('APC40 mkII','akai-apc40-mkii');d['scope']='Complete unambiguous Mode 1/2 input note chart, track faders, primary knob CC banks, host LED and ring feedback. Generic Mode 0 device-knob banks retained separately. Duplicate/misaligned inbound labels and Cue conflict excluded.'
d['color_palette']={str(int(n)):c.upper() for c,n in re.findall(r'(#[0-9a-fA-F]{6})\s+(\d+)',t)}
common={**{n:f'Clip Launch {n+1}' for n in range(40)},80:'Master',81:'Stop All Clips',**{82+k:f'Scene Launch {k+1}' for k in range(5)},87:'Pan',88:'Sends',89:'User',90:'Metronome',91:'Play',92:'Stop',93:'Record',94:'Up',95:'Down',96:'Right',97:'Left',98:'Shift',99:'Tap Tempo',100:'Nudge -',101:'Nudge +',102:'Session Record',103:'Bank Lock'}
track={48:'Record Arm',49:'Solo',50:'Activator',51:'Track Selection',52:'Track Stop',66:'Crossfader A/B'}
for n,c in common.items():add(d,c,'note',n,None,encoding='momentary Note On/Off',values={'note_on_velocity':127,'note_off_velocity':127,'release_velocity_ignored':True},mode='Mode 1 or Mode 2',page='PDF pp30–34 inbound note chart',notes=['Source says channel ignored for notes outside 0x30–0x49.'])
for n,c in track.items():
 for ch in range(1,9):add(d,f'Track {ch} {c}','note',n,ch,encoding='momentary Note On/Off',values={'note_on_velocity':127,'note_off_velocity':127},mode='Mode 1 or Mode 2',page='PDF pp30–33 inbound note chart',notes=['Source zero-based channels 0–7 converted to 1–8.'])
# Device button channels unclear in mode1/2 because prose routes whole 0x30–0x49 through tracks; normalize as unspecified.
for n,c in [(58,'Device Left'),(59,'Device Right'),(60,'Bank Left'),(61,'Bank Right'),(62,'Device On/Off'),(63,'Device Lock'),(64,'Clip/Device View')]:add(d,c,'note',n,None,encoding='momentary Note On/Off',values={'note_on_velocity':127,'note_off_velocity':127},mode='Mode 1 or Mode 2; device buttons not internally banked',page='PDF pp12,30,32',notes=['Exact nonbanked output channel not stated; do not infer from generic mode.'])
for ch in range(1,9):add(d,f'Track {ch} Fader','cc',7,ch,values=ABS,mode='All modes',page='PDF p34',notes=['Source channels 0–7 converted to 1–8.'])
for n,c in [(14,'Master Fader'),(15,'Crossfader'),(64,'Footswitch')]:add(d,c,'cc',n,None,encoding='absolute position' if n!=64 else 'press/release CC',values=ABS if n!=64 else BTN,mode='All modes; channel unspecified',page='PDF pp34–36')
for k in range(8):
 for ch in range(1,10):add(d,f'Device Knob {k+1} bank {ch}','cc',16+k,ch,values=ABS,mode='Mode 0; tracks 1–8 and Master bank 9',page='PDF pp11,34–35')
 add(d,f'Device Knob {k+1}','cc',16+k,None,values=ABS,mode='Mode 1/2; not internally banked',page='PDF pp12,34–35')
 add(d,f'Track Knob {k+1}','cc',48+k,None,values=ABS,mode='All modes; not banked',page='PDF pp11,36')
add(d,'Tempo Knob','cc',13,None,encoding='relative two-complement 7-bit',values={'0':'stationary','1–63':'positive delta = value','64–127':'negative delta = value-128'},page='PDF p37 Relative Controller messages')
rgbbeh=['Primary color','Secondary oneshot 1/24','Secondary oneshot 1/16','Secondary oneshot 1/8','Secondary oneshot 1/4','Secondary oneshot 1/2','Secondary pulse 1/24','Secondary pulse 1/16','Secondary pulse 1/8','Secondary pulse 1/4','Secondary pulse 1/2','Secondary blink 1/24','Secondary blink 1/16','Secondary blink 1/8','Secondary blink 1/4','Secondary blink 1/2']
for n in [*range(40),82,83,84,85,86]:
 for ch,behavior in enumerate(rgbbeh,1):add(d,common[n]+' LED','note',n,ch,'host-to-device','RGB palette velocity',dict(min=0,max=127,behavior=behavior,palette='color_palette'),'Host LED control; modes govern ownership','PDF pp13–22')
for n,c in track.items():
 for ch in range(1,9):add(d,f'Track {ch} {c} LED','note',n,ch,'host-to-device','LED state',{'0':'off','1':'yellow','2–127':'orange'} if n==66 else {'0':'off','1':'on','2':'blink','3–127':'on'} if n==52 else {},'Host LED control','PDF pp15–16',notes=['No state values inferred where merged chart cells omit a definition.'])
for n,c in [(58,'Device Left'),(59,'Device Right'),(60,'Bank Left'),(61,'Bank Right'),(62,'Device On/Off'),(63,'Device Lock'),(64,'Clip/Device View'),(65,'Detail View'),(80,'Master'),(87,'Pan'),(88,'Sends'),(89,'User'),(90,'Metronome'),(91,'Play'),(93,'Record'),(102,'Session Record')]:add(d,c+' LED','note',n,None,'host-to-device','on/off LED',{'0':'off','1–127':'on'},'Host LED control; channel ignored except generic bank behavior','PDF pp16–17')
for k in range(8):
 for mode,channels in [('Mode 0; banked tracks/master',range(1,10)),('Mode 1/2; unbanked',[None])]:
  for ch in channels:
   add(d,f'Device Knob {k+1} ring position','cc',16+k,ch,'host-to-device','LED ring position',ABS,mode,'PDF pp23–24,27–29')
   add(d,f'Device Knob {k+1} ring style','cc',24+k,ch,'host-to-device','LED ring style',{'0':'off','1':'single','2':'volume','3':'pan','4–127':'single'},mode,'PDF pp24–25')
 add(d,f'Track Knob {k+1} ring position','cc',48+k,None,'host-to-device','LED ring position',ABS,'Host feedback; track knobs not banked','PDF pp25–26')
 add(d,f'Track Knob {k+1} ring style','cc',56+k,None,'host-to-device','LED ring style',{'0':'off','1':'single','2':'volume','3':'pan','4–127':'single'},'Host feedback; track knobs not banked','PDF pp25–26')
issue(d,'ambiguous-inbound-labels','Inbound table repeats Device Knob1–8 at CC0x18–0x1F and Track Knob1–8 at CC0x38–0x3F, which outbound chart identifies as ring-style addresses. Do not recast as physical input. Note0x41 is both Detail View and stray Metronome(8); unlabeled CLIP STOP row retained raw.','PDF pp32–36; pp24–26',['Input CC24–31, CC56–63; Note65 Detail View/Metronome ambiguity'],'conflict')
issue(d,'cue-encoding-conflict','Cue Level CC0x2F appears in absolute and relative inbound tables. Relative table defines signed delta but no authoritative correction distinguishes Cue. Excluded pending clarification.','PDF pp35,37',['Cue Level input CC47'],'conflict')
issue(d,'mode-and-sysex','Generic-mode note banking/toggles are not normalized beyond definite CC banks. Introduction/inquiry and ring segment bit patterns remain complete raw evidence; dedicated adapter required.','PDF pp2–12,27–29',['Generic-mode note behavior; SysEx initialization/inquiry; detailed ring segment lookup'],'scope')
for slug,d in D.items():
 if (OUT/'raw'/f'{slug}.png').exists():
  d['raw_evidence'].append(dict(source_id='protocol',file=f'performance-inmusic/raw/{slug}.png',extraction_method='Original PDF layout diagram rendered with pdftoppm; transcribed numeric cells in bindings; retained as visual evidence.'))
 (OUT/(slug+'.json')).write_text(json.dumps(d,indent=2)+'\n')
 print(slug,len(d['bindings']),len(d['issues']))
