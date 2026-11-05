#!/usr/bin/env python3
"""Extract the original twelve status icons; derived game art stays ignored."""
from pathlib import Path
import hashlib, subprocess
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]
out=ROOT/'ui/generated/effects';out.mkdir(parents=True,exist_ok=True)
raw=ROOT/'build/status-resources';raw.mkdir(parents=True,exist_ok=True)
bar=ROOT/'gamedata/orcsandelves2.bar'
assert hashlib.sha256(bar.read_bytes()).hexdigest()=='508aa62a368cc77c64113a68c5485f43871bf18fa819a58ae8e3aac085265c2f'
subprocess.run([str(ROOT/'build/native/src/oe2tool'),'extract',str(bar),'3030',str(raw/'icons.bmp')],check=True)
sheet=Image.open(raw/'icons.bmp').convert('RGBA')
assert sheet.size==(12,144)
pixels=sheet.load()
for y in range(sheet.height):
 for x in range(sheet.width):
  r,g,b,_=pixels[x,y]
  # Exactly the RGB565 conversion and magenta key used by Image_load.
  c=((r>>3)<<11)|((g>>2)<<5)|(b>>3)
  pixels[x,y]=(((c>>11)&31)*255//31,((c>>5)&63)*255//63,(c&31)*255//31,0 if c==0xf81f else 255)
for index in range(12):sheet.crop((0,index*12,12,index*12+12)).save(out/f'{index:02}.png')
print('Original status-effect icons decoded: 12')
