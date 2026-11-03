#!/usr/bin/env python3
"""Import only matching English text data; never execute the comparison JAR."""
import argparse, hashlib, json, re, zipfile
from pathlib import Path
from analyze_jar import decode_index
ROOT=Path(__file__).resolve().parents[1]
p=argparse.ArgumentParser();p.add_argument('english_jar',type=Path);args=p.parse_args()
assert hashlib.sha256(args.english_jar.read_bytes()).hexdigest()=='6e834662707770d5631763245c766faf416dc8ad4fd3401d6f24b0f74a6ca029'
index=json.loads((ROOT/'research/reports/resource_index.json').read_text())['strings']
def english_groups(z):
 return [z.read(f'strings{d["bank"]}.bin')[d['offset']:d['offset']+d['size']].split(b'\0') for d in decode_index(z.read('strings.idx'))]
rows=[]
with zipfile.ZipFile(args.english_jar) as z:
 groups=english_groups(z);assert len(groups)==60
 for group in range(12):
  d=index[group*5+3]
  russian=(ROOT/'game/assets/original'/d['file']).read_bytes()[d['offset']:d['offset']+d['size']].split(b'\0')
  english=groups[group*5]
  assert len(russian)==len(english),(group,len(russian),len(english))
  for n,(ru,en) in enumerate(zip(russian,english)):
   if n==len(russian)-1 and not ru and not en: continue
   assert sorted(re.findall(rb'%[1-6]',ru))==sorted(re.findall(rb'%[1-6]',en)),(group,n)
   # Numeric puzzle strings stay authoritative from the supplied game.
   if re.fullmatch(rb'[\d. ]+',ru): en=ru
   rows.append({'id':group*1024+n,'ru_raw':ru.decode('latin1'),'en_raw':en.decode('latin1')})
(ROOT/'build/locale_import.json').write_text(json.dumps({'source_sha256':hashlib.sha256(args.english_jar.read_bytes()).hexdigest(),'rows':rows},ensure_ascii=False))
print(len(rows),'matched English entries; all placeholders agree')
