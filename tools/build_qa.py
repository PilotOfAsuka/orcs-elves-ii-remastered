#!/usr/bin/env python3
from pathlib import Path
import subprocess
ROOT=Path(__file__).resolve().parents[1]
sources=sorted((ROOT/'engine/src/game').glob('*.c'))
sources += [ROOT/'engine/src/platform_sdl.c',ROOT/'host/bridge.c',ROOT/'host/lighting.c',ROOT/'host/presentation.c',ROOT/'host/qa_driver.c']
flags=subprocess.check_output(['pkg-config','--cflags','--libs','sdl2','zlib','libavcodec','libavutil'],text=True).split()
subprocess.run(['clang','-std=gnu17','-O2','-fwrapv','-funsigned-char','-DOE2_WEB_BRIDGE','-DOE2_LIGHTING_TEST','-I'+str(ROOT/'engine/src'),'-I'+str(ROOT/'engine/src/game'),*map(str,sources),str(ROOT/'build/native/src/liboe2core.a'),*flags,'-o',str(ROOT/'build/qa_driver')],check=True)
