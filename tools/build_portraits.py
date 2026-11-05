#!/usr/bin/env python3
"""Pack original BREW faces and sprite closeups; no replacement artwork."""
from pathlib import Path
import struct,subprocess
from PIL import Image
ROOT=Path(__file__).resolve().parents[1];raw=ROOT/'build/portrait-raw';raw.mkdir(exist_ok=True)
out=ROOT/'ui/generated/dialogue';out.mkdir(parents=True,exist_ok=True)
def extract(rid):
 p=raw/str(rid)
 subprocess.run([str(ROOT/'build/native/src/oe2tool'),'extract',str(ROOT/'gamedata/orcsandelves2.bar'),str(rid),str(p)],check=True,stdout=subprocess.DEVNULL)
 return p
u16=lambda p,o:struct.unpack_from('<H',p,o)[0]
i32=lambda p,o:struct.unpack_from('<i',p,o)[0]
def color(c):return (((c>>11)&31)*255//31,((c>>5)&63)*255//63,(c&31)*255//31,0 if c==0xf81f else 255)
def original_image(rid):
 im=Image.open(extract(rid)).convert('RGBA');im.putdata([color(((r>>3)<<11)|((g>>2)<<5)|(b>>3)) for r,g,b,a in im.getdata()]);return im
atlas=Image.new('RGBA',(16*48,17*48))
def put(index,im):atlas.paste(im.resize((48,48),Image.Resampling.NEAREST),((index%16)*48,(index//16)*48))
put(0,original_image(3028).crop((0,0,20,20)));put(1,original_image(3021).crop((0,0,20,20)))
p=extract(1003).read_bytes();cursor=2;palettes=[]
for _ in range(u16(p,0)):
 count=u16(p,cursor);cursor+=2;palettes.append([color(u16(p,cursor+2*j)) for j in range(count)]);cursor+=count*2
p=extract(1004).read_bytes();counts=struct.unpack_from('<6i',p);cursor=24+(counts[0]+counts[1])*8
maps=[struct.unpack_from('<2i',p,cursor+8*j) for j in range(counts[2])];cursor+=counts[2]*8+(counts[3]+counts[4])*2
remap=list(struct.unpack_from('<'+'H'*counts[5],p,cursor));shapes=extract(1005).read_bytes()[4:];texels=extract(1006).read_bytes()
for tile,start in enumerate(remap[:256]):
 if start>=len(maps):continue
 ofs,pal=maps[start];shape=shapes[ofs:];x0,x1,y0,y1=shape[8:12];source=i32(shape,0);offset=i32(texels,4+source*4)+4
 end=i32(texels,4+(source+1)*4)+4 if source+1<i32(texels,0) else len(texels)
 data=texels[offset+1:end];data=[q for b in data for q in (b&15,b>>4)] if texels[offset]==4 else data
 im=Image.new('RGBA',(88,88));pixels=im.load();stride=(y1-y0+8)//8;k=0
 for x in range(x0,x1+1):
  for y in range(y0,y1+1):
   if shape[12+(x-x0)*stride+(y-y0)//8]&(1<<((y-y0)&7)):
    if x<88 and y<88:pixels[x,y]=palettes[pal][data[k]]
    k+=1
 # Upper body, centered on the original front-facing sprite.
 side=max(20,min(48,y1-y0+1));cx=(x0+x1)//2
 put(2+tile,im.crop((cx-side//2,y0,cx-side//2+side,y0+side)))
icons=original_image(3007)
for index in range(8):put(258+index,icons.crop((0,index*20,14,index*20+20)))
atlas.save(out/'portraits.png')
