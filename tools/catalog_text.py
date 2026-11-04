#!/usr/bin/env python3
"""Extract every original string group. Inputs remain local; translations are presentation-only."""
from pathlib import Path
import json,re,struct,subprocess
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'research/localization';OUT.mkdir(parents=True,exist_ok=True)
path=OUT/'strings.bin'
subprocess.run([str(ROOT/'build/native/src/oe2tool'),'extract',str(ROOT/'gamedata/orcsandelves2.bar'),'1002',str(path)],check=True)
p=path.read_bytes();n=struct.unpack_from('<i',p)[0];offsets=struct.unpack_from('<'+'i'*n,p,4)
def clean(s):
    # One '-' is a discretionary phone-font break; '--' represents a real dash.
    return s.replace('--','\x01').replace('-','').replace('\x01','-').replace('\\n','\n').replace('\\%','%').replace('|','\n')
def key(s):
    return re.sub(r'\s+',' ',''.join(c for c in s if ord(c)<127).replace('-','').replace('@','')).strip()
rows=[];seen={}
for group in range(n-1):
    for index,raw in enumerate(p[4+offsets[group]:4+offsets[group+1]].split(b'\0')):
        if not raw:continue
        en=clean(raw.decode('cp1252'));ident=f'{group}:{index}'
        row={'id':ident,'en':en,'key':key(en)};rows.append(row)
        seen.setdefault(row['key'],{'id':ident,'en':en,'ids':[]})['ids'].append(ident)
unique=list(seen.values())
for group in range(n-1):
    out=[r for r in unique if r['id'].startswith(str(group)+':')]
    (OUT/f'group-{group:02}.json').write_text(json.dumps(out,ensure_ascii=False,indent=2)+'\n')
(OUT/'catalog.json').write_text(json.dumps(rows,ensure_ascii=False,indent=2)+'\n')
print(json.dumps({'entries':len(rows),'unique':len(unique),'words':sum(len(r['en'].split()) for r in unique)}))
