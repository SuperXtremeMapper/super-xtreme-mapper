from pathlib import Path
import requests,bs4,hashlib,json,subprocess,concurrent.futures
ROOT=Path(__file__).parent
jobs=[]
def add(m,u,n):jobs.append((m,u,n))
ni={'s4-mk3':'TRAKTOR_KONTROL_S4_MK3_Manual_English_0719.pdf','s3':'TRAKTOR_KONTROL_S3_MK1_Manual_English_0120.pdf','s2-mk3':'TRAKTOR_KONTROL_S2_MK3_Manual_English_1218.pdf','x1-mk3':'Traktor_X1_MK3_Manual_English_0923.pdf','z1-mk2':'Traktor_Z1_Manual_EN_30102024.pdf','f1':'traktor_kontrol_f1_manual_english.pdf','mx2':'Traktor_MX2_user_guide-en.pdf'}
for m,f in ni.items():add(m,'https://docs.native-instruments.com/pdf-guides/traktor/'+f,'manual.pdf')
for m,f in {'xone-96':'2023/06/AP11645_2_XONE_96_USER_GUIDE.pdf','xone-92-mk2':'2024/10/Xone92-Mk2-User-Guide.pdf','xone-px5':'2023/06/AP10733_2_XONE_PX5_USER_GUIDE.pdf'}.items():add(m,'https://www.allen-heath.com/content/uploads/'+f,'manual.pdf')
herc=['djcontrolinpulset7','djcontrolinpulse500','djcontrolinpulse300mk2','djcontrolinpulse200mk2','djcontrolstarlight']
for m in herc:
 u='https://support.hercules.com/en/product/'+m+'-en/'
 add(m,u,'support.html')
 s=bs4.BeautifulSoup(requests.get(u).content,'html.parser');seen=set()
 for a in s.select('a[href]'):
  h=a['href'];t=a.get_text(' ',strip=True)
  if h in seen:continue
  if 'ts.hercules.com' in h and '.pdf' in h and ('User Manual' in t and ('languages' in t.lower()) or 'MIDI' in t or 'How to use' in t):
   add(m,h,'midi.pdf' if 'MIDI' in t else 'manual.pdf');seen.add(h)
  if 'djuced.com/kb/' in h:
   add(m,h.replace('?lang=fr',''),'djuced-midi.html');seen.add(h)
add('shared','https://www.native-instruments.com/products/traktor-z1','ni-current-downloads.html')
add('shared','https://www.native-instruments.com/products/traktor-mx2','ni-mx2-current.html')
add('shared','https://support.native-instruments.com/support/solutions/articles/69000880031-native-instruments-switching-your-controller-to-midi-mode','ni-midi-mode.html')
add('s4-mk3','https://community.native-instruments.com/discussion/9022/why-does-the-s4mk3-still-not-have-midi-mode','ni-staff-midi-explanation.html')
def download(j):
 m,u,n=j;d=ROOT/m;d.mkdir(exist_ok=True);res={'url':u,'file':str((d/n).relative_to(ROOT))}
 try:
  r=requests.get(u,timeout=90);res.update(status_code=r.status_code,final_url=r.url);r.raise_for_status()
  if n.endswith('.pdf') and not r.content.startswith(b'%PDF'):raise ValueError('Not PDF bytes')
  p=d/n;p.write_bytes(r.content);res.update(bytes=len(r.content),sha256=hashlib.sha256(r.content).hexdigest())
  t=p.with_suffix('.txt')
  if n.endswith('.pdf'):subprocess.run(['pdftotext','-layout',str(p),str(t)],check=True)
  else:
   s=bs4.BeautifulSoup(r.content,'html.parser')
   for el in s(['script','style']):el.decompose()
   t.write_text(s.get_text('\n',strip=True))
  res['text_file']=str(t.relative_to(ROOT))
 except Exception as e:res['error']=str(e)
 return res
results=list(concurrent.futures.ThreadPoolExecutor(max_workers=8).map(download,jobs))
(ROOT/'downloads.json').write_text(json.dumps(results,indent=2))
for r in results: print(r['file'],r.get('bytes'),r.get('error','OK'))
