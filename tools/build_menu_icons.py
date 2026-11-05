#!/usr/bin/env python3
from pathlib import Path
import subprocess
from PIL import Image
ROOT=Path(__file__).resolve().parents[1];out=ROOT/'ui/generated/menu';out.mkdir(parents=True,exist_ok=True)
p=ROOT/'build/menu-icons.bmp'
subprocess.run([str(ROOT/'build/native/src/oe2tool'),'extract',str(ROOT/'gamedata/orcsandelves2.bar'),'3029',str(p)],check=True)
im=Image.open(p).convert('RGBA');pixels=im.load()
for y in range(im.height):
 for x in range(im.width):
  r,g,b,_=pixels[x,y];c=((r>>3)<<11)|((g>>2)<<5)|(b>>3)
  pixels[x,y]=(((c>>11)&31)*255//31,((c>>5)&63)*255//63,(c&31)*255//31,0 if c==0xf81f else 255)
im.save(out/'items.png')

p=ROOT/'build/ring-icons.bmp'
subprocess.run([str(ROOT/'build/native/src/oe2tool'),'extract',str(ROOT/'gamedata/orcsandelves2.bar'),'3031',str(p)],check=True)
im=Image.open(p).convert('RGBA');pixels=im.load()
assert im.size==(18,180)
for y in range(im.height):
 for x in range(im.width):
  r,g,b,_=pixels[x,y];c=((r>>3)<<11)|((g>>2)<<5)|(b>>3)
  pixels[x,y]=(((c>>11)&31)*255//31,((c>>5)&63)*255//63,(c&31)*255//31,0 if c==0xf81f else 255)
im.save(out/'rings.png')
