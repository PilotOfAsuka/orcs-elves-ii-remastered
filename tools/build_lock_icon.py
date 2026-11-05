#!/usr/bin/env python3
"""Decode the two original BREW padlock frames for the custom modal (not Git)."""
from pathlib import Path
import struct,subprocess,hashlib
from PIL import Image
ROOT=Path(__file__).resolve().parents[1];raw=ROOT/'build/lock-resources';out=ROOT/'ui/generated/lock'
raw.mkdir(parents=True,exist_ok=True);out.mkdir(parents=True,exist_ok=True)
bar=ROOT/'gamedata/orcsandelves2.bar'
assert hashlib.sha256(bar.read_bytes()).hexdigest()=='508aa62a368cc77c64113a68c5485f43871bf18fa819a58ae8e3aac085265c2f'
for rid,name in {1003:'palettes',1004:'mappings',1005:'bitshapes',1006:'stexels'}.items():
 subprocess.run([str(ROOT/'build/native/src/oe2tool'),'extract',str(bar),str(rid),str(raw/(name+'.bin'))],check=True)
def u16(p,o):return struct.unpack_from('<H',p,o)[0]
def i32(p,o):return struct.unpack_from('<i',p,o)[0]
p=(raw/'palettes.bin').read_bytes();at=2;palettes=[]
for _ in range(u16(p,0)):
 count=u16(p,at);at+=2;palette=[]
 for _ in range(count):
  c=u16(p,at);at+=2;palette.append((((c>>11)&31)*255//31,((c>>5)&63)*255//63,(c&31)*255//31,255))
 palettes.append(palette)
p=(raw/'mappings.bin').read_bytes();counts=struct.unpack_from('<6i',p);at=24;maps=[];remaps=[]
for n in counts[:3]:maps.append([struct.unpack_from('<2i',p,at+j*8)for j in range(n)]);at+=n*8
for n in counts[3:]:remaps.append(struct.unpack_from('<'+'H'*n,p,at));at+=n*2
shapes=(raw/'bitshapes.bin').read_bytes()[4:];texels=(raw/'stexels.bin').read_bytes()
for frame in range(2):
 ofs,palette=maps[2][remaps[2][13]+frame];shape=shapes[ofs:];index=i32(shape,0)
 start=i32(texels,4+index*4)+4;end=i32(texels,8+index*4)+4 if index+1<i32(texels,0)else len(texels)
 values=texels[start+1:end]
 if texels[start]==4:values=[n for b in values for n in (b&15,b>>4)]
 x0,x1,y0,y1=shape[8:12];stride=(y1-y0+8)//8;k=0;image=Image.new('RGBA',(88,88));pixels=image.load()
 for x in range(x0,x1+1):
  for y in range(y0,y1+1):
   if shape[12+(x-x0)*stride+(y-y0)//8]&(1<<((y-y0)&7)):
    if x<88 and y<88:pixels[x,y]=palettes[palette][values[k]]
    k+=1
 # Replace the phone sprite's pixel border with our own bronze modal frame.
 image.crop((16,18,73,75)).save(out/('ready.png'if frame else 'idle.png'))
print('Original padlock frames decoded')
