#!/usr/bin/env python3
from pathlib import Path
import subprocess
import shutil
import hashlib
import json
import re

ROOT = Path(__file__).resolve().parents[1]
GODOT = '/Applications/Godot.app/Contents/MacOS/Godot'
OUT = ROOT / 'build/web'
(ROOT / 'ui/export_presets.cfg').write_text('''[preset.0]
name="Web"
platform="Web"
runnable=true
export_filter="all_resources"
include_filter="*.json"
exclude_filter=""
export_path="../build/web/index.html"
script_export_mode=2

[preset.0.options]
variant/extensions_support=false
variant/thread_support=false
vram_texture_compression/for_desktop=true
vram_texture_compression/for_mobile=false
html/export_icon=false
html/canvas_resize_policy=2
html/focus_canvas_on_start=true
progressive_web_app/enabled=false
''')
subprocess.run(['python3',str(ROOT/'tools/build_lock_icon.py')],check=True)
subprocess.run(['python3',str(ROOT/'tools/build_status_icons.py')],check=True)
subprocess.run(['python3',str(ROOT/'tools/build_menu_icons.py')],check=True)
subprocess.run(['python3',str(ROOT/'tools/build_portraits.py')],check=True)
subprocess.run(['python3',str(ROOT/'tools/build_localization.py'),'--strict'],check=True)
def godot(*args):
    result=subprocess.run([GODOT,*args],cwd=ROOT,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT)
    print(result.stdout,end='')
    if result.returncode or re.search(r'(?:SCRIPT ERROR:|ERROR:)',result.stdout):
        raise RuntimeError('Godot reported errors; do not publish this export')
godot('--headless','--path',str(ROOT/'ui'),'--editor','--import','--quit')
godot('--headless','--path',str(ROOT/'ui'),'--export-release','Web',str(OUT/'index.html'))
html = (OUT/'index.html').read_text()
needle = '<script src="index.js"></script>'
if needle not in html:
    raise RuntimeError('Godot shell changed: cannot locate engine script')
# Content-named UI pack prevents an older root release from surviving browser caches.
tag=hashlib.sha256(b''.join((OUT/name).read_bytes() for name in ('index.pck','brew-core.wasm'))+(ROOT/'web/runtime.js').read_bytes()).hexdigest()[:16]
pack=f'game-ui.{tag}.pck'
for old in OUT.glob('game-ui.*.pck'): old.unlink()
shutil.copy2(OUT/'index.pck',OUT/pack)
match=re.search(r'const GODOT_CONFIG = (.*?);',html)
if not match: raise RuntimeError('Godot shell configuration missing')
config=json.loads(match.group(1));config['mainPack']=pack
config['fileSizes'][pack]=config['fileSizes'].pop('index.pck')
html=html[:match.start(1)]+json.dumps(config,separators=(',',':'))+html[match.end(1):]
html = html.replace(needle, f'<script src="brew-core.js?v={tag}"></script>\n<script src="runtime.js?v={tag}"></script>\n<script src="index.js?v={tag}"></script>')
(OUT/'index.html').write_text(html)
shutil.copy2(ROOT/'web/runtime.js', OUT/'runtime.js')
print('BREW + existing Godot UI exported')
