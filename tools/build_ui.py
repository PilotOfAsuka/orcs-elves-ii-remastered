#!/usr/bin/env python3
from pathlib import Path
import subprocess
import shutil

ROOT = Path(__file__).resolve().parents[1]
GODOT = '/Applications/Godot.app/Contents/MacOS/Godot'
OUT = ROOT / 'build/web'
(ROOT / 'ui/export_presets.cfg').write_text('''[preset.0]
name="Web"
platform="Web"
runnable=true
export_filter="all_resources"
include_filter=""
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
subprocess.run([GODOT, '--headless', '--path', str(ROOT/'ui'), '--editor', '--import', '--quit'], check=True)
subprocess.run([GODOT, '--headless', '--path', str(ROOT/'ui'), '--export-release', 'Web', str(OUT/'index.html')], check=True)
html = (OUT/'index.html').read_text()
needle = '<script src="index.js"></script>'
if needle not in html:
    raise RuntimeError('Godot shell changed: cannot locate engine script')
html = html.replace(needle, '<script src="brew-core.js"></script>\n<script src="runtime.js"></script>\n'+needle)
(OUT/'index.html').write_text(html)
shutil.copy2(ROOT/'web/runtime.js', OUT/'runtime.js')
print('BREW + existing Godot UI exported')
