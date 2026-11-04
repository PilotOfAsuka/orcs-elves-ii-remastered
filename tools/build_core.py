#!/usr/bin/env python3
"""Build the BREW C core for the browser; never imports the previous runtime."""
from pathlib import Path
import os
import subprocess
import shutil
import hashlib
import argparse

ROOT = Path(__file__).resolve().parents[1]
SDK = ROOT / 'tools/vendor/emsdk'
parser=argparse.ArgumentParser();parser.add_argument('--cinematic',action='store_true');options=parser.parse_args()
OUT = ROOT / ('build/cinematic/core' if options.cinematic else 'build/web')
OUT.mkdir(parents=True, exist_ok=True)
staging = ROOT / 'build/staging/gamedata'
staging.mkdir(parents=True, exist_ok=True)
for name in ('orcsandelves2.bar', 'orcsandelves2.mod'):
    expected = {'orcsandelves2.bar':'508aa62a368cc77c64113a68c5485f43871bf18fa819a58ae8e3aac085265c2f',
                'orcsandelves2.mod':'1b8664e937ef8c43c474dff9b82c398b46425c5cca43eff5919e4ce96fc3d750'}[name]
    if hashlib.sha256((ROOT/'gamedata'/name).read_bytes()).hexdigest() != expected:
        raise RuntimeError(f'{name}: expected the supported BREW 7.0.41 release')
    shutil.copy2(ROOT / 'gamedata' / name, staging / name)
shutil.copytree(ROOT / 'gamedata/audio', staging / 'audio', dirs_exist_ok=True)
env = dict(os.environ, EM_CONFIG=str(SDK / '.emscripten'))
sources = [ROOT / 'engine/src/bar.c', ROOT / 'engine/src/moddata.c']
sources += sorted((ROOT / 'engine/src/game').glob('*.c'))
sources += [ROOT / 'host/bridge.c', ROOT / 'host/platform_web.c', ROOT / 'host/pmd_web.c', ROOT / 'host/lighting.c', ROOT / 'host/presentation.c']
if options.cinematic:sources.append(ROOT/'tools/cinematic/bridge.c')
args = [str(SDK / 'upstream/emscripten/emcc'), '-std=gnu17', '-O2', '-g2', '-fwrapv', '-funsigned-char',
        '-DOE2_WEB_BRIDGE', '-D_POSIX_C_SOURCE=200809L', '-I' + str(ROOT / 'engine/src'),
        '-I' + str(ROOT / 'engine/src/game'), *map(str, sources), '-lm', '-sUSE_ZLIB=1',
        '-sMODULARIZE=1', '-sEXPORT_NAME=createBrewModule', '-sALLOW_MEMORY_GROWTH=1',
        '-sINITIAL_MEMORY=67108864', '-sENVIRONMENT=web,node', '-sFORCE_FILESYSTEM=1',
        '-lidbfs.js', '-sEXPORTED_RUNTIME_METHODS=FS,IDBFS,UTF8ToString,ccall,HEAPU8,HEAP16',
        '--no-entry', '--preload-file', str(staging) + '@/gamedata', '-o', str(OUT / 'brew-core.js')]
if options.cinematic:args.insert(1,'-DOE2_CINEMATIC_CAPTURE')
subprocess.run(args, cwd=ROOT, env=env, check=True)
print('BREW WebAssembly core built')
