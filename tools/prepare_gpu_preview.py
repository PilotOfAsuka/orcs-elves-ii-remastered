#!/usr/bin/env python3
"""Stage a disposable GPU browser fixture, never the published/live bundle."""
from pathlib import Path
import shutil

root = Path(__file__).resolve().parents[1]
out = root / 'build/gpu-preview'
shutil.copytree(root / 'build/web', out, dirs_exist_ok=True)
for source in (root / 'build/qa-core').glob('brew-core.*'):
    shutil.copy2(source, out / source.name)
runtime = (root / 'web/runtime.js').read_text()
assert 'Brew.init().catch' in runtime
(out / 'runtime.js').write_text(runtime.replace('Brew.init().catch', 'Brew.init({persist:false,seed:7}).catch'))
html = (out / 'index.html').read_text()
assert '<script src="runtime.js' in html
html = html.replace('<script src="runtime.js', '<script>const qaFactory=createBrewModule;createBrewModule=async function(options){window.QACore=await qaFactory(options);return window.QACore;};</script>\n<script src="runtime.js')
(out / 'index.html').write_text(html)
print('Prepared isolated, nonpersistent GPU browser fixture')
