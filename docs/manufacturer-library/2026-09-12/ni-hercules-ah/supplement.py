from pathlib import Path
import requests,bs4,hashlib,json,subprocess,concurrent.futures
ROOT=Path(__file__).parent
exec((ROOT/'collect.py').read_text().split('ni={')[0])
exec('def download'+(ROOT/'collect.py').read_text().split('def download')[1].split('results=list')[0])
for m,u,n in [
('xone-96','https://support.allen-heath.com/hc/en-gb/articles/43053562464017-Xone-96-User-Guide','manual.html'),
('xone-96','https://support.allen-heath.com/hc/en-gb/articles/43084536824849-Xone-96-MIDI-Implementation','midi.html'),
('xone-96','https://www.allen-heath.com/content/uploads/2023/06/X96_MIDI-Control-Overview.pdf','midi.pdf'),
('xone-px5','https://support.allen-heath.com/hc/en-gb/articles/43523536283409-Xone-PX5-MIDI-Control','midi.html'),
('djcontrolinpulse200mk3','https://support.hercules.com/en/product/djcontrolinpulse200mk3-en/','support.html'),
('djcontrolinpulse200mk3','https://ts.hercules.com/download/sound/manuals/DJC_Inpulse_200_MK3/DJControl_Inpulse_200_MK3_User_Manual_-_21_Languages.pdf','manual.pdf'),
('f1','https://www.native-instruments.com/fileadmin/ni_media/downloads/manuals/Controller_Editor_Manual_English_2017_11.pdf','controller-editor.pdf')]:add(m,u,n)
results=list(concurrent.futures.ThreadPoolExecutor(max_workers=6).map(download,jobs))
old=json.loads((ROOT/'downloads.json').read_text());old+=results
(ROOT/'downloads.json').write_text(json.dumps(old,indent=2))
for r in results:print(r['file'],r.get('bytes'),r.get('error','OK'))
