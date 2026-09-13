"""Reproduce this evidence-only batch from verified local manufacturer archives."""
from pathlib import Path
import hashlib, json, re, subprocess
HERE=Path(__file__).resolve().parent
BASE=HERE.parent.parent
catalogue=json.loads((BASE/'catalogue.json').read_text())
models=[m for m in catalogue['models'] if m['source_grade']=='partial' and m['source_manifest'].startswith('ni-hercules-ah/')]
assert len(models)==12

def slug(s): return re.sub(r'[^a-z0-9]+','-',s.lower()).strip('-')
def issue(id,description,locators,excluded=None,severity='scope'):
 return dict(id=id,severity=severity,description=description,evidence=[dict(source_id=s,locator=l) for s,l in locators],excluded_bindings=excluded or [])
def ev(s,l): return (s,l)
shared=next(s for s in json.loads((BASE/'ni-hercules-ah/downloads.json').read_text()) if s['file']=='shared/ni-midi-mode.html')
supp=dict(kind='manufacturer-source',url=shared['url'],local_file='ni-hercules-ah/'+shared['file'],sha256=shared['sha256'],bytes=shared['bytes'],pages=None,existing_archive=False,extracted_text='ni-hercules-ah/'+shared['text_file'])
supp_models=['Traktor Kontrol S2 MK3','Traktor Kontrol S3','Traktor MX2']
(HERE/'supplemental-sources.json').write_text(json.dumps({'reason':'Existing archived official shared reference cited by catalogue evidence_locators; register as additive per-model catalogue source before final validation.','models':supp_models,'sources':[supp]},indent=2)+'\n')
summary=[]
for m in models:
 name=m['model']; key=Path(m['source_manifest']).parent.name; outslug=slug(name)
 original_sources=list(m['sources'])
 if name in supp_models and not any(s['local_file']==supp['local_file'] for s in original_sources): original_sources.append(supp)
 sources=[];raw=[]; id_for={}
 for n,s in enumerate(original_sources,1):
  sid=f's{n}';p=BASE/s['local_file']; assert hashlib.sha256(p.read_bytes()).hexdigest()==s['sha256'],p
  sources.append({k:s[k] for k in ['local_file','url','sha256']}|{'id':sid});id_for[Path(s['local_file']).name]=sid
  rawname=f'{outslug}-{sid}.txt'; dest=HERE/'raw'/rawname
  if p.suffix=='.pdf':
   content=subprocess.check_output(['pdftotext','-layout',str(p),'-']).decode();pages=content.split('\f')
   if not pages[-1].strip():pages.pop()
   dest.write_text('\n'.join(f'=== PDF PAGE {i} ===\n{t}' for i,t in enumerate(pages,1)))
   method='pdftotext -layout; complete PDF retained as page-addressed text; no OCR or inferred labels'
  else:
   content=(BASE/s['extracted_text']).read_text(); dest.write_text('=== HTML DOCUMENT (unpaginated) ===\n'+content)
   method='Complete archived HTML-to-text extraction copied; unpaginated document marker; original HTML remains authoritative'
  raw.append(dict(source_id=sid,file=f'ni-hercules-ah/raw/{rawname}',extraction_method=method))
 manual=id_for['manual.pdf']; issues=[];setup=[];missing=[];bindings=[]
 scope='Documentation-only extraction of the archived owner manual and support material. No model-specific numeric MIDI addresses, channels, value encodings or LED receive assignments are established; native/software control descriptions are not wire-message evidence.'
 if m['manufacturer']=='Hercules':
  page={'djcontrolinpulse200mk2':28,'djcontrolinpulse200mk3':29,'djcontrolinpulse300mk2':31,'djcontrolinpulset7':47,'djcontrolstarlight':3}[key]
  setup=['Connect the controller to the computer using its USB cable. Connect speakers to the master/speaker outputs and headphones to the headphone output as described in the installation section.']
  if key=='djcontrolinpulset7':setup.insert(0,'Connect the supplied power adapter and cable, then press POWER after connecting USB. The shared manual covers T7 and T7 Premium; no distinct Premium MIDI map is established.')
  if key=='djcontrolstarlight':setup.append('The archived getting-started guide uses Serato DJ Lite; install that software for its documented workflow.')
  issues.append(issue('setup-provenance','The setup notes describe the owner-manual connection workflow; they do not establish a generic MIDI mode or numeric mapping.',[ev(manual,f'PDF page {page}; Installation / Connections' if page!=3 else 'PDF page 3; Install the DJ equipment')]))
  controls={'djcontrolinpulse200mk2':'8, 14, 18, 35, 45','djcontrolinpulse200mk3':'8, 15, 19, 38, 49','djcontrolinpulse300mk2':'8, 15, 21, 38, 39, 56','djcontrolinpulset7':'14, 28, 55, 56, 79, 84','djcontrolstarlight':'2–6'}[key]
  evidence=[ev(manual,f'PDF pages {controls}; English hardware/control and operating descriptions')]
  if 'djuced-midi.html' in id_for:evidence.append(ev(id_for['djuced-midi.html'],'Controls > Mixer Controls, Decks Controls and Pads Modes; software action mapping'))
  issues.append(issue('no-wire-address-chart','The retained control descriptions identify software actions and pad modes, not per-control MIDI status/address/value tables. No Note/CC bindings can be normalized from these descriptions.',evidence,['All input controls and all LED/output controls pending manufacturer wire-address documentation']))
  if key=='djcontrolinpulset7':
   setup.append('The control-panel MIDI controls test shows a green DIN icon when it receives a command from a tested control; this is a reception check, not a published address table.')
   issues.append(issue('midi-test-not-protocol','A green DIN icon confirms reception only and does not identify status, channel, address or value bytes.',[ev(manual,'PDF page 84 / printed page 83; MIDI controls test')]))
  missing=['Model-specific control-to-Note/CC addresses and MIDI channel assignments.','Shift, pad-mode and deck-layer wire-message differences.','Jog-wheel/encoder direction, resolution and acceleration encoding; button press/release values.','LED, pad-color and meter receive addresses and value semantics.','Any required generic MIDI mode or firmware-specific protocol setup beyond the documented software workflow.']
 elif key=='f1':
  ce=id_for['controller-editor.pdf']
  scope='Documentation-only extraction of F1 ordinary MIDI mode and configurable Controller Editor assignments. No pinned template with concrete per-control numeric addresses/channels is archived. Proprietary NHL User Map and native Remix Deck behavior are excluded from MIDI bindings.'
  setup=['In Traktor Preferences > Traktor Kontrol F1, select MIDI Mode instead of User Map; then press SHIFT + BROWSE (MIDI) to enter ordinary MIDI mode. Press the same combination again to return to Performance mode.','Use Controller Editor to select the desired template; templates cannot be switched from the F1 hardware. Capture/export the selected template before creating a concrete map.','SHIFT changes Controller Editor pages; its Gate or Toggle behavior is configured in the Pages pane. The F1 SHIFT button is lit in MIDI mode.']
  issues.append(issue('setup-provenance','Ordinary MIDI mode requires the MIDI Mode preference; User Map uses NHL. Controller Editor template and page selection determine the assignment context.',[ev(manual,'PDF pages 119–121, section 4.12; page 128, section 5.1.4'),ev(ce,'PDF pages 162–164; sections 14.1–14.2')]))
  issues.append(issue('template-required','F1 controls except SHIFT are freely assignable subject to control type. Editor capability descriptions do not establish a single fixed per-control numeric map.',[ev(ce,'PDF pages 162–168; sections 14.1–14.3')],['All template-dependent input assignments and LED/display receive assignments']))
  missing=['Pinned/exported Controller Editor template with per-page input/output addresses and channels.','Template-specific encoder turn/push message types, values and direction encoding.','Selected RGB pad single/dual/HSB modes and display message assignments; no fixed LED address map is established.']
 else:
  if key in ['s2-mk3','s3','mx2']:
   sid=id_for['ni-midi-mode.html']
   if key=='mx2':setup=['Hold left SHIFT + right SHIFT to switch between Native and MIDI mode.']
   else:setup=['Use the latest controller firmware as required by the official support article. Hold the left FLX button while connecting the controller to enter MIDI mode; disconnect it to leave MIDI mode.','The article explicitly excludes this model from the automatic Controller Editor switching workflow.']
   issues.append(issue('setup-provenance','Model-specific mode entry is documented in the archived official shared support article; generic Controller Editor examples must not be treated as this model’s wire map.',[ev(sid,'Switching to MIDI Mode Manually; '+name+' row'+(' and *** firmware footnote; Switching to MIDI Mode Automatically exception' if key!='mx2' else ''))]))
  elif key=='x1-mk3':
   setup=['Hold SHIFT and press Mode Select to enter MIDI mode; the display below the button shows the active mode.']
   issues.append(issue('setup-provenance','Mode entry and active-mode display are explicitly described.',[ev(manual,'PDF page 9 / printed page 7; section 5 Effect Control, item 1 Mode Select Button')]))
  elif key=='z1-mk2':
   setup=['Press --- together with the ☰ menu button to switch to MIDI mode; the center display shows MIDI MODE. Press the combination again to return to Traktor mode.']
   issues.append(issue('setup-provenance','MIDI mode entry/exit is documented separately from native deck A/B versus C/D switching.',[ev(manual,'PDF page 8 / printed page 6; Using the Traktor Z1 MK2 as a MIDI Controller')]))
  if key!='xone-px5':
   issues.append(issue('no-wire-address-chart','The owner manual describes native control functions without a complete numeric MIDI address/channel/encoding table. MIDI-mode availability does not establish those wire values.',[ev(manual,{'s2-mk3':'PDF pages 10–50; setup, hardware overview and operation','s3':'PDF pages 6–39; setup, hardware overview and operation','mx2':'PDF pages 9–21; overview and Customizing your MX2 (printed pages 7–19)','x1-mk3':'PDF pages 9–18; Effect Control, Transport Control, Mixer Control and customization','z1-mk2':'PDF pages 6–16; Using the Z1 with Traktor and customization'}[key])],['All per-control MIDI inputs and outputs; no numeric wire map established']))
   if key=='s2-mk3':issues.append(issue('model-generation-boundary','S2 MK2 addresses and Controller Editor templates must not be transferred to S2 MK3. Its documented FLX-at-connection mode entry is model-specific.',[ev(id_for['ni-midi-mode.html'],'Controller Model table: S2 MK2 versus S2 MK3 rows; automatic switching exception')],['Any S2 MK2-derived assignment']))
   missing=['Manufacturer control-to-message table with numeric MIDI addresses and channels.','Mode/shift/deck-layer address differences in MIDI mode.','Encoder/jog-wheel value encoding and button press/release bytes.','LED/display/meter receive protocol and values; native display behavior does not establish MIDI feedback.']
 if key=='xone-px5':
  web=id_for['midi.html']
  scope='Partial numeric extraction: all 12 explicitly assigned CC controls (CC0–CC11) in the default MIDI channel 16 context. Numeric value/direction encoding is not specified. All Note-name assignments are quarantined because the manufacturer mapping and note-conversion chart disagree on octave zero; host receive semantics remain unresolved.'
  controls=['Channel 1 fader','Channel 2 fader','Channel 3 fader','Channel 4 fader','Crossfader','Xone FILTER FREQ','Xone:FX ASSIGN','Xone:FX SELECT','Xone:FX INTERVAL','Xone:FX DECAY','Xone:FX FOCUS','Xone:FX LEVEL']
  for n,control in enumerate(controls):
   page=33 if n<5 else (31 if n==5 else 32);group='FADERS' if n<5 else ('XONE FILTER' if n==5 else 'XONE:FX')
   bindings.append(dict(id=slug(control)+'-cc',control=control,direction='device-to-host',message_type='cc',channel=16,number=n,encoding='CC address documented; value range and absolute/relative direction semantics unspecified',values={},mode='Default MIDI channel 16; user-configurable channel',evidence=[dict(source_id=manual,locator=f'PDF page {page}; {group} table, {control} / CC{n}'),dict(source_id=web,locator=f'MIDI Control > {"Faders" if n<5 else ("Xone:VCF" if n==5 else "Xone:FX")}; CC{n} row')],app_support='requires-adapter',notes=['Channel 16 is the documented default, not a claim about a previously configured mixer. The selected channel persists across power cycles.','No value endpoints, rotary direction encoding or matching host-to-device binding are inferred.'],source_group=group))
  setup=['The default MIDI channel is 16. Hold FX SELECT to enter CONFIG, select CHANNEL, press FX SELECT to highlight the current channel, rotate to choose a channel and press to confirm.','Use FX SELECT to choose EXIT from CHANNEL, then EXIT from CONFIG. The selected MIDI channel persists when power is switched off.']
  issues=[issue('setup-provenance','MIDI channel configuration and persistence determine the channel for these default-context CC assignments.',[ev(manual,'PDF page 34; MIDI CHANNEL CHANGE'),ev(web,'Changing the MIDI Channel, steps 1–5 and persistence note')]),issue('note-octave-conflict','FX-mode table starts at C-2, but the same manufacturer support article maps numeric Note 0 to C-1 in its Octave/Note Numbers and CC/Hex/Note conversion tables. All Note-name bindings are withheld rather than selecting an octave convention.',[ev(manual,'PDF pages 30–33; all Note-name MIDI CONTROL tables'),ev(web,'Channel FX MODE Select Switches versus Octave / Note Numbers and CC / Hex / Note conversion tables')],['Channel FX MODE INT/EXT for A and channels 1–4','Channel FILTER selects A, 1–4 and EXT RTN','Channel CUE selects A, 1–4 and XONE:FX','XONE FILTER HPF/BPF/LPF/ON','XONE:FX PRE/POST, MODE, TAP, ON, CUE and FX X-FADE X/Y','XONE:SYNC BEAT LEFT/RIGHT, BEND LEFT/RIGHT, STOP/PLAY'],severity='conflict'),issue('conversion-hex-conflict','The supplemental CC conversion table lists decimal 13/14/15 against 0x0C/0x0D/0x0E. The extracted CC0–11 assignments are outside the erroneous rows; no corrected source values are invented.',[ev(web,'CC / Hex / Note conversion table, decimal 13–15 rows')],['Conversion-table rows 13–15'],severity='conflict'),issue('values-and-feedback-unspecified','The manual says the mixer can send and receive MIDI, but its assignment charts do not specify per-control data ranges, rotary direction encoding, Note release bytes or host feedback values. CC input addresses are retained with empty values; no host-to-device mirror is inferred.',[ev(manual,'PDF page 29; MIDI CONTROL introduction; pages 31–33 assignment tables')],['All host-to-device bindings pending receive semantics; rotary value encoding; Note release semantics'])]
  missing=['Resolve the mapping-versus-conversion-table Note octave conflict using manufacturer clarification or hardware capture.','Establish CC value ranges and rotary absolute/relative/direction semantics.','Document per-control host-to-device receive values and LED feedback semantics.','Confirm actual configured MIDI channel on the unit; default 16 may have been changed.']
 result=dict(schema_version=1,manufacturer=m['manufacturer'],model=name,status='partial-extraction',coverage_state='partial' if bindings else 'documentation-only',hardware_tested=False,sources=sources,scope=scope,bindings=bindings,setup_notes=setup,missing_information=missing,issues=issues,raw_evidence=raw)
 (HERE/(outslug+'.json')).write_text(json.dumps(result,indent=2,ensure_ascii=False)+'\n')
 summary.append(dict(model=name,file=outslug+'.json',coverage_state=result['coverage_state'],bindings=len(bindings),sources=len(sources),raw_files=len(raw)))
(HERE/'README.md').write_text('# NI, Hercules and Xone:PX5 partial evidence batch\n\nEvidence only; no hardware validation or application integration. All 12 CC assignments in the PX5 chart are preserved with unspecified value encoding. Eleven remaining models have no established numeric wire map and deliberately contain zero bindings. Full owner/protocol PDFs are retained in page-marked text, including multilingual manuals. HTML sources retain complete archived text.\n\nRun `python3 extract.py` in this directory to reproduce, requiring pdftotext. Original archive hashes are verified before extraction. The shared NI mode-entry article is listed in supplemental-sources.json for additive catalogue registration.\n\n| Model | State | Bindings |\n|---|---|---:|\n'+''.join(f"| {s['model']} | {s['coverage_state']} | {s['bindings']} |\n" for s in summary))
print(json.dumps(summary,indent=2))
