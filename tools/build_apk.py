#!/usr/bin/env python3
"""Build a locally signed offline Android test APK from the current Web export."""
from pathlib import Path
import argparse,hashlib,json,os,shutil,subprocess,zipfile
ROOT=Path(__file__).resolve().parents[1]
parser=argparse.ArgumentParser();parser.add_argument('--version-code',type=int,default=1);parser.add_argument('--version-name',default='0.2.1-test');args=parser.parse_args()
sdk=Path(os.environ.get('ANDROID_SDK_ROOT',str(Path.home()/'Library/Android/sdk')))
versions=sorted((sdk/'build-tools').iterdir(),key=lambda p:tuple(map(int,p.name.split('.'))))
tools=versions[-1];platform=sdk/'platforms/android-35/android.jar'
work=ROOT/'build/android';assets=work/'assets/game';classes=work/'classes';dex=work/'dex'
for folder in (assets,classes,dex):
 if folder.exists():shutil.rmtree(folder)
 folder.mkdir(parents=True)
web=ROOT/'build/web';packs=list(web.glob('game-ui.*.pck'))
if len(packs)!=1:raise RuntimeError('Build the Web export first')
names=['index.html','index.js','index.wasm','index.png',packs[0].name,'index.audio.position.worklet.js','index.audio.worklet.js','brew-core.js','brew-core.wasm','brew-core.data','runtime.js']
if (web/'runtime.js').read_bytes()!=(ROOT/'web/runtime.js').read_bytes():raise RuntimeError('Rebuild the Web export after runtime changes')
manifest={'version':args.version_name,'source_revision':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),'files':{}}
for name in names:
 data=(web/name).read_bytes();(assets/name).write_bytes(data);manifest['files'][name]={'bytes':len(data),'sha256':hashlib.sha256(data).hexdigest()}
for name in ('LICENSE','SOURCES.md'):shutil.copy2(ROOT/name,assets/name)
(assets/'game-build.json').write_text(json.dumps(manifest,indent=2))
def run(*command):subprocess.run(list(map(str,command)),cwd=ROOT,check=True)
run(tools/'aapt2','compile','--dir',ROOT/'android/res','-o',work/'resources.zip')
run(tools/'aapt2','link','-o',work/'unsigned.apk','--manifest',ROOT/'android/AndroidManifest.xml','-I',platform,work/'resources.zip','-A',work/'assets','--replace-version','--version-code',args.version_code,'--version-name',args.version_name)
run('javac','--release','8','-classpath',platform,'-d',classes,*sorted((ROOT/'android/src').rglob('*.java')))
run(tools/'d8','--lib',platform,'--min-api','26','--output',dex,*sorted(classes.rglob('*.class')))
with zipfile.ZipFile(work/'unsigned.apk','a',compression=zipfile.ZIP_DEFLATED)as archive:
 for file in dex.glob('*.dex'):archive.write(file,file.name)
run(tools/'zipalign','-f','4',work/'unsigned.apk',work/'aligned.apk')
private=ROOT/'android/.private';private.mkdir(exist_ok=True);key=private/'test.keystore'
if not key.exists():
 run('keytool','-genkeypair','-keystore',key,'-alias','oe2-test','-storepass','android','-keypass','android','-keyalg','RSA','-keysize','2048','-validity','10000','-dname','CN=Orcs Elves II Local Test')
 os.chmod(key,0o600)
out=ROOT/'dist'/('Orcs-Elves-II-'+args.version_name+'.apk');out.parent.mkdir(exist_ok=True)
run(tools/'apksigner','sign','--ks',key,'--ks-key-alias','oe2-test','--ks-pass','pass:android','--key-pass','pass:android','--out',out,work/'aligned.apk')
run(tools/'apksigner','verify','--verbose',out)
run(tools/'zipalign','-c','4',out)
with zipfile.ZipFile(out)as archive:
 for name,record in manifest['files'].items():
  assert hashlib.sha256(archive.read('assets/game/'+name)).hexdigest()==record['sha256'],name
 assert archive.read('classes.dex')[:4]==b'dex\n'
assert not (assets/'brew-core.js').read_text().find('_oe2_qa_lock')>=0,'Never ship QA fixtures'
report={'apk':out.name,'bytes':out.stat().st_size,'sha256':hashlib.sha256(out.read_bytes()).hexdigest(),'game':manifest}
(work/'verified.json').write_text(json.dumps(report,indent=2))
print(json.dumps({k:v for k,v in report.items()if k!='game'},indent=2))
