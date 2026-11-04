#!/usr/bin/env python3
"""Decode original BREW indexed resources for inspection; never modifies them."""
from pathlib import Path
import struct,json,subprocess
from PIL import Image,ImageDraw
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'research/textures';RAW=OUT/'raw'
RAW.mkdir(parents=True,exist_ok=True)
for rid,name in {1003:'palettes',1004:'mappings',1005:'bitshapes',1006:'stexels',1007:'wtexels',1008:'ftexels'}.items():
    subprocess.run([str(ROOT/'build/native/src/oe2tool'),'extract',str(ROOT/'gamedata/orcsandelves2.bar'),str(rid),str(RAW/(name+'.bin'))],check=True)
def u16(p,o):return struct.unpack_from('<H',p,o)[0]
def i32(p,o):return struct.unpack_from('<i',p,o)[0]
p=(RAW/'palettes.bin').read_bytes();cursor=2;palettes=[]
for _ in range(u16(p,0)):
    count=u16(p,cursor);cursor+=2;pal=[]
    for j in range(count):
        c=u16(p,cursor);cursor+=2;pal.append((((c>>11)&31)*255//31,((c>>5)&63)*255//63,(c&31)*255//31,255))
    palettes.append(pal+[(0,0,0,255)]*(256-len(pal)))
p=(RAW/'mappings.bin').read_bytes();counts=struct.unpack_from('<6i',p);cursor=24;maps=[];remaps=[]
for n in counts[:3]:
    maps.append([struct.unpack_from('<2i',p,cursor+j*8) for j in range(n)]);cursor+=n*8
for n in counts[3:]:
    remaps.append(list(struct.unpack_from('<'+'H'*n,p,cursor)));cursor+=n*2
def texels(kind,index):
    p=(RAW/(kind+'.bin')).read_bytes();o=i32(p,4+index*4)+4
    end=i32(p,4+(index+1)*4)+4 if index+1<i32(p,0) else len(p)
    data=p[o+1:end]
    return [q for b in data for q in (b&15,b>>4)] if p[o]==4 else list(data)
records=[];groups={}
for kind,entries,remap,size,bank in [('wall',maps[0],remaps[0],117,'wtexels'),('flat',maps[1],remaps[1],64,'ftexels')]:
    folder=OUT/kind;folder.mkdir(exist_ok=True);rows=[]
    for idx,(source,palette) in enumerate(entries):
        data=texels(bank,source);image=Image.new('RGBA',(size,size));pixels=image.load();pal=palettes[palette]
        for y in range(size):
            for x in range(size):pixels[x,y]=pal[data[x*size+y if kind=='wall' else y*size+x]]
        image.save(folder/f'{idx:03}.png')
        ids=[i for i,v in enumerate(remap) if v==idx]
        row={'kind':kind,'material':idx,'source':source,'palette':palette,'ids':ids,'image':str((folder/f'{idx:03}.png').relative_to(OUT))}
        records.append(row);rows.append(row)
    groups[kind]=rows
shapes=(RAW/'bitshapes.bin').read_bytes()[4:];folder=OUT/'sprite';folder.mkdir(exist_ok=True);rows=[]
valid=sorted(set(v for v in remaps[2] if v<len(maps[2])))
for tile,start in enumerate(remaps[2]):
    if start>=len(maps[2]):continue
    end=next((v for v in valid if v>start),len(maps[2]))
    for frame in range(end-start):
        ofs,palette=maps[2][start+frame];shape=shapes[ofs:];x0,x1,y0,y1=shape[8:12]
        if not (x0<=x1<128 and y0<=y1<128):raise ValueError((tile,frame,x0,x1,y0,y1))
        data=texels('stexels',i32(shape,0));stride=(y1-y0+8)//8;k=0
        image=Image.new('RGBA',(88,88));pixels=image.load();pal=palettes[palette]
        for x in range(x0,x1+1):
            for y in range(y0,y1+1):
                if shape[12+(x-x0)*stride+(y-y0)//8]&(1<<((y-y0)&7)):
                    if x<88 and y<88:pixels[x,y]=pal[data[k]]
                    k+=1
        path=folder/f'{tile:03}_{frame:02}.png';image.save(path)
        row={'kind':'sprite','tile':tile,'frame':frame,'material':start+frame,'source':i32(shape,0),'palette':palette,'bounds':[x0,x1,y0,y1],'image':str(path.relative_to(OUT))}
        records.append(row)
        if frame==0:rows.append(row)
groups['sprite-first']=rows
for group,rows in groups.items():
    for page in range((len(rows)+99)//100):
        sheet=Image.new('RGB',(1280,1440),'#22302a');draw=ImageDraw.Draw(sheet)
        for n,row in enumerate(rows[page*100:(page+1)*100]):
            image=Image.open(OUT/row['image']);image.thumbnail((120,120),Image.Resampling.NEAREST)
            x=(n%10)*128;y=(n//10)*144;sheet.paste(image,(x+(128-image.width)//2,y),image)
            label=(f"tile {row['tile']}" if 'tile' in row else f"mat {row['material']} ids {','.join(map(str,row['ids']))}")
            draw.text((x+3,y+121),label,fill='#e9dfc8')
        sheet.save(OUT/f'{group}-{page}.png')
summary={'palettes':len(palettes),'wall_materials':len(maps[0]),'flat_materials':len(maps[1]),'sprite_frames':len(maps[2]),'sprite_ids':len(groups['sprite-first']),'records':records}
(OUT/'catalog.json').write_text(json.dumps(summary,indent=2))
print(json.dumps({k:v for k,v in summary.items() if k!='records'}))
