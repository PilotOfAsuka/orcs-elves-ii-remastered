#!/usr/bin/env python3
from pathlib import Path
import json,re,sys
ROOT=Path(__file__).resolve().parents[1]
source=ROOT/'research/localization/catalog.json'
compiled=ROOT/'ui/locales/ru.json'
if source.exists():rows=json.loads(source.read_text())
elif compiled.exists():
    # The checked-in presentation catalog makes UI-only builds self-contained.
    ids=json.loads(compiled.read_text())['ids']
    rows=[{'id':id,'en':entry['en']} for id,entry in ids.items()]
else:raise SystemExit('Run tools/catalog_text.py first')
translations={}
for path in sorted((ROOT/'localization/ru').glob('[0-9][0-9].json')):translations.update(json.loads(path.read_text()))
def key(text):
    text=text.replace('-\n','').replace('|','\n').replace('@','')
    text=re.sub(r'(?<=[A-Za-z])-(?=[A-Za-z])','',text)
    return ' '.join(''.join(c for c in text if 32<=ord(c)<127 or c=='\n').split())
by_key={};missing=[]
for row in rows:
    k=key(row['en']);ru=translations.get(row['id'])
    if ru is not None:by_key.setdefault(k,ru)
for row in rows:
    k=key(row['en']);ru=translations.get(row['id'],by_key.get(k))
    if ru is None:
        if not re.search('[A-Za-z]',row['en']):ru=row['en']
        else:missing.append(row);continue
    row['ru']=ru;by_key[k]=ru
# Common names/literals also emitted by executable strings and dynamic UI.
by_key.update({'Ellon':'Эллон','Elli':'Элли','You':'Вы','Your':'Ваш','None':'Нет','Both':'Звук и вибрация','FX':'Эффекты','Classic':'Классика','Remastered':'Ремастер'})
texts={};ids={};templates=[]
for row in rows:
    if 'ru' not in row:continue
    en,ru=row['en'],row['ru'];k=key(en);ids[row['id']]={'en':en,'ru':ru};texts[k]=ru
    if re.search('%[1-6]',en):
        literal=re.sub('%[1-6]','',k)
        if len(re.sub('[^A-Za-z]','',literal))>=3:templates.append({'en':k,'ru':ru,'multiline':len(en.strip().splitlines())>1})
    left=en.strip().split('\n');right=ru.strip().split('\n')
    if len(left)==len(right) and len(left)>1:
        for a,b in zip(left,right):
            if a.strip() and b.strip() and not re.search('%[1-6]',a):texts.setdefault(key(a),b)
    if row['id'].startswith('19:'):
        for a,b in zip(en.split(',')[1:],ru.split(',')[1:]):texts.setdefault(key(a),b)
texts.update(by_key)
cases=json.loads((ROOT/'localization/ru/cases.json').read_text()) if (ROOT/'localization/ru/cases.json').exists() else {}
phrases=sorted([k for k in texts if not re.search('%[1-6]',k) and len(k)>=5 and len(k.split())>=2],key=len,reverse=True)
result={'texts':texts,'ids':ids,'templates':sorted(templates,key=lambda r:len(re.sub('%[1-6]','',r['en'])),reverse=True),'phrases':phrases,'cases':cases,'coverage':{'total':len(rows),'translated':len(rows)-len(missing),'missing':len(missing)}}
out=ROOT/'ui/locales';out.mkdir(exist_ok=True);(out/'ru.json').write_text(json.dumps(result,ensure_ascii=False,separators=(',',':'))+'\n')
if source.exists():(ROOT/'research/localization/missing.json').write_text(json.dumps(missing,ensure_ascii=False,indent=2))
# Validate formatting arguments before runtime. Case annotations are presentation metadata.
for row in rows:
    if 'ru' in row and set(re.findall('%[1-6]',row['en']))!=set(re.findall('%[1-6]',row['ru'])):raise SystemExit('Placeholder mismatch: '+row['id'])
print(json.dumps(result['coverage']))
if '--strict' in sys.argv and missing:raise SystemExit('Translation incomplete')
