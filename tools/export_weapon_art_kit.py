"""Export lossless original weapon layers for an artist; no game/build changes."""
from pathlib import Path
import argparse,hashlib,json,re,struct,subprocess,tempfile,zipfile,shutil
from PIL import Image,ImageDraw,ImageFont
ROOT=Path(__file__).resolve().parents[1]
NAME='Orcs-Elves-II-Weapon-Art-Kit-BREW-7.0.41'
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--output',type=Path,default=ROOT/'dist'/NAME,help='New handoff folder; existing folders and ZIPs are preserved')
OUT=parser.parse_args().output.resolve();NAME=OUT.name;ZIP=OUT.parent/(NAME+'.zip')
if OUT.exists() or ZIP.exists():raise RuntimeError('Existing handoff preserved; choose a new output name')
TMP=Path(tempfile.mkdtemp(prefix='weapon-kit-',dir=ROOT/'build'));RAW=TMP/'raw';RAW.mkdir();KIT=TMP/NAME;KIT.mkdir()
def extract(rid):
 p=RAW/str(rid);subprocess.run([str(ROOT/'build/native/src/oe2tool'),'extract',str(ROOT/'gamedata/orcsandelves2.bar'),str(rid),str(p)],check=True,stdout=subprocess.DEVNULL);return p
u16=lambda p,o:struct.unpack_from('<H',p,o)[0]
i32=lambda p,o:struct.unpack_from('<i',p,o)[0]
sha=lambda b:hashlib.sha256(b).hexdigest()
def rgb(c):return (((c>>11)&31)*255//31,((c>>5)&63)*255//63,(c&31)*255//31,255)
def clean(s):return s.replace('--','\x01').replace('-','').replace('\x01','-').replace('|','\n').replace('\\n','\n').strip()
bar=ROOT/'gamedata/orcsandelves2.bar';mod=(ROOT/'gamedata/orcsandelves2.mod').read_bytes()
assert sha(bar.read_bytes())=='508aa62a368cc77c64113a68c5485f43871bf18fa819a58ae8e3aac085265c2f'
p=extract(1002).read_bytes();offsets=struct.unpack_from('<'+'i'*i32(p,0),p,4)
strings=[clean(x.decode('cp1252')) for x in p[4+offsets[1]:4+offsets[2]].split(b'\0')]
p=extract(1000).read_bytes();weapons=[]
for n in range(u16(p,0)):
 tile,sub,e,es,w,name,longname,desc=struct.unpack_from('<hBBBhhhh',p,2+n*13)
 if (e,es)==(6,1):
  title=strings[longname];slug=re.sub('[^a-z0-9]+','_',title.lower()).strip('_')
  weapons.append({'weapon_id':w,'name':title,'hud_name':strings[name],'sprite_tile':w+1,'icon_id':sub,'folder':f'weapons/{w:02}_{slug}','native_hand_offsets':list(struct.unpack_from('<4h',mod,0x4613c+w*8))})
weapons.sort(key=lambda w:w['weapon_id']);assert [w['weapon_id'] for w in weapons]==list(range(11))
p=extract(1003).read_bytes();cursor=2;palettes=[]
for _ in range(u16(p,0)):
 n=u16(p,cursor);cursor+=2;palettes.append([rgb(u16(p,cursor+2*j)) for j in range(n)]);cursor+=n*2
p=extract(1004).read_bytes();counts=struct.unpack_from('<6i',p);cursor=24+(counts[0]+counts[1])*8
maps=[struct.unpack_from('<2i',p,cursor+8*j) for j in range(counts[2])];cursor+=counts[2]*8+(counts[3]+counts[4])*2
remap=list(struct.unpack_from('<'+'H'*counts[5],p,cursor));starts=sorted({v for v in remap if v<len(maps)})
shapes=extract(1005).read_bytes()[4:];texels=extract(1006).read_bytes();records=[];images={}
def decode(tile,frame):
 material=remap[tile]+frame;ofs,pal=maps[material];shape=shapes[ofs:];x0,x1,y0,y1=shape[8:12]
 assert 0<=x0<=x1<88 and 0<=y0<=y1<88,(tile,frame,'non-native crop')
 source=i32(shape,0);start=i32(texels,4+source*4)+4
 end=i32(texels,4+(source+1)*4)+4 if source+1<i32(texels,0) else len(texels)
 raw=texels[start+1:end];data=[v for b in raw for v in (b&15,b>>4)] if texels[start]==4 else raw
 image=Image.new('RGBA',(88,88),(0,0,0,0));pixels=image.load();stride=(y1-y0+8)//8;k=0
 for x in range(x0,x1+1):
  for y in range(y0,y1+1):
   if shape[12+(x-x0)*stride+(y-y0)//8]&(1<<((y-y0)&7)):
    pixels[x,y]=palettes[pal][data[k]];k+=1
 assert k<=len(data)
 return image,{'sprite_tile':tile,'frame':frame,'material':material,'texel_source':source,'palette':pal,'native_bounds_inclusive':[x0,x1,y0,y1]}
def save(image,relative,meta):
 p=KIT/relative;p.parent.mkdir(parents=True,exist_ok=True);image.save(p,format='PNG')
 saved=Image.open(p);assert saved.mode=='RGBA' and saved.size==image.size and saved.tobytes()==image.tobytes()
 alpha=image.getchannel('A');values=set(alpha.tobytes());assert values<=set((0,255)) and (meta.get('kind')=='inventory_icon' or values==set((0,255))),(relative,values)
 record={'file':relative,'width':image.width,'height':image.height,'mode':'RGBA','alpha_values':sorted(values),'rgba_sha256':sha(image.tobytes()),'png_sha256':sha(p.read_bytes()),**meta}
 records.append(record);images[relative]=image;return relative
for w in weapons:
 tile=w['sprite_tile'];end=next((n for n in starts if n>remap[tile]),len(maps));w['frames']=[]
 for frame in range(end-remap[tile]):
  im,meta=decode(tile,frame);w['frames'].append(save(im,f"{w['folder']}/sprite_{tile:03}_frame_{frame:02}.png",{'kind':'held_weapon_layer','weapon_id':w['weapon_id'],**meta}))
assert sum(len(w['frames']) for w in weapons)==65
# Icons preserve the native 24-square canvas and the original RGB565/magenta key.
atlas=Image.open(extract(3029)).convert('RGBA')
for w in weapons:
 x=w['icon_id']%16*24;y=w['icon_id']//16*24;icon=atlas.crop((x,y,x+24,y+24));out=[]
 for r,g,b,a in icon.get_flattened_data():
  c=((r>>3)<<11)|((g>>2)<<5)|(b>>3);out.append((0,0,0,0) if c==0xf81f else rgb(c))
 icon.putdata(out);w['icon']=save(icon,f"inventory_icons/{w['weapon_id']:02}_{Path(w['folder']).name[3:]}.png",{'kind':'inventory_icon','resource_id':3029,'icon_id':w['icon_id'],'weapon_id':w['weapon_id']})
# The native world effects reuse the same texture data as the orb glow layers.
for tile in (14,15,16):
 end=next((n for n in starts if n>remap[tile]),len(maps))
 for frame in range(end-remap[tile]):
  im,meta=decode(tile,frame);save(im,f'reference_shared_fx/sprite_{tile:03}_frame_{frame:02}.png',{'kind':'shared_effect_reference',**meta})
aliases={}
for row in records:aliases.setdefault(row['rgba_sha256'],[]).append(row['file'])
shared=[files for files in aliases.values() if len(files)>1]
manifest={'game':'Orcs & Elves II','version':'BREW 7.0.41','source_bar_sha256':sha(bar.read_bytes()),'source_mod_sha256':sha(mod),'native_sprite_canvas':[88,88],'native_inventory_icon_canvas':[24,24],'format':'PNG RGBA8, original unscaled colors and bitshape transparency','weapon_count':len(weapons),'held_layer_frames':65,'inventory_icons':11,'shared_effect_reference_frames':17,'weapons':weapons,'files':records,'identical_rgba_groups':shared,'shared_layer_usage':[{'tile':7,'frames':[2,3,4,5],'used_by_weapons':[5,6],'purpose':'Shared charged-crossbow overlay'},{'tile':8,'frames':[0,1],'purpose':'Flaming Sword arm layer; blade/fire uses frames 2..6'},{'tiles':[9,10,11],'purpose':'Orb hand/body frames 0/1; separate glow/effect frames 2 onward'}]}
(KIT/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
# A separate preview: native-size cells on a checkerboard, never an editing source.
sheet=Image.new('RGB',(1120,60+124*11),'#17201d');d=ImageDraw.Draw(sheet);font=ImageFont.load_default(size=15)
d.text((12,12),'Original BREW weapon layers - 88 x 88 / RGBA - all native frames',font=font,fill='#eadbb5')
for row,w in enumerate(weapons):
 y=60+row*124;d.text((12,y+20),f"{w['weapon_id']:02} {w['name']}",font=font,fill='#eadbb5')
 for n,f in enumerate(w['frames']):
  x=220+n*100
  for cy in range(0,88,8):
   for cx in range(0,88,8):d.rectangle((x+cx,y+cy,x+min(87,cx+7),y+min(87,cy+7)),fill='#394942' if ((cx+cy)//8)%2 else '#60716a')
  sheet.paste(images[f],(x,y),images[f]);d.text((x,y+93),f'frame {n:02}',font=font,fill='#eadbb5')
(KIT/'preview').mkdir();sheet.save(KIT/'preview/all_weapon_frames.png')
rows='\n'.join(f"| {w['weapon_id']:02} | {w['name']} | {len(w['frames'])} | `{w['folder']}` |" for w in weapons)
readme=f'''# Orcs & Elves II — исходники оружия для художника

BREW 7.0.41. Исходная графика, без увеличения, фильтров и запечённого освещения.

- `weapons/` — все 65 кадров/слоёв 11 видов оружия, включая фамильяра. Каждый PNG: **88×88, RGBA**.
- `inventory_icons/` — 11 оригинальных иконок **24×24, RGBA**.
- `reference_shared_fx/` — 17 справочных кадров общих магических эффектов. Они повторно используют изображения из основных слоёв; соответствия есть в manifest.json.
- `preview/all_weapon_frames.png` — обзор всех кадров на шахматном фоне. Это только просмотр, не исходник для правок.
- `manifest.json` — соответствия оружие → спрайт → кадр, палитры, общие слои, исходные размеры/положение и контрольные суммы для обратной привязки.

## Как подготовить исправления

1. Редактируй отдельные PNG из `weapons/` и при необходимости `inventory_icons/`.
2. Сохраняй имена, папки, размер холста и положение рисунка. **Не обрезай прозрачные поля и не центрируй кадры заново.**
3. Сохраняй PNG RGBA с прозрачным фоном. Шахматная подложка не должна попадать в рисунок.
4. Не объединяй руку, оружие и свечение в один слой: игра накладывает их отдельно. У арбалетов общий слой заряда находится в sprite_007, кадры 02–05; огненный меч использует отдельные слои руки и клинка.
5. Свет, красная вспышка урона и прозрачность персонажа накладываются игрой — они не запечены в исходниках. У некоторых магических слоёв используется сложение цвета: их чёрные пиксели являются частью оригинала, а не ошибкой вырезания фона.
6. Можно вернуть весь архив или только изменённые файлы с прежними путями. Для загрузки исправлений в игру будет отдельно подключена замена текстур и проверена анимация.

У основных спрайтов оригинальная маска прозрачности жёсткая: alpha 0/255. Иконки сохранены со своим оригинальным фоном; некоторые из них полностью непрозрачны. RGB и эта маска сохранены без потерь. Включены даже одинаковые и дополнительные оригинальные кадры: не удаляй их из-за сходства.

| ID | Оружие | Кадров/слоёв | Папка |
|---|---|---:|---|
{rows}

## English handoff notes

Edit the individual PNG files. Keep filenames, directory paths, native canvas dimensions (88×88 for weapon layers; 24×24 for icons), alignment and transparent padding. Do not flatten separate hand/glow layers or bake scene lighting. Export RGBA PNG, never JPEG or a checkerboard background. The reference shared effects duplicate native weapon-layer data; manifest.json records aliases. Return the edited files for a separate runtime replacement/integration pass.
'''
(KIT/'README_RU.md').write_text(readme)
assert len(records)==93
OUT.parent.mkdir(exist_ok=True);shutil.move(str(KIT),str(OUT))
with zipfile.ZipFile(ZIP,'w',zipfile.ZIP_DEFLATED,compresslevel=9) as archive:
 for p in sorted(OUT.rglob('*')):
  if p.is_file():archive.write(p,f'{NAME}/{p.relative_to(OUT)}')
with zipfile.ZipFile(ZIP) as archive:assert archive.testzip() is None
report={'folder':str(OUT),'zip':str(ZIP),'zip_bytes':ZIP.stat().st_size,'zip_sha256':sha(ZIP.read_bytes()),'weapons':len(weapons),'held_frames':65,'icons':11,'shared_effect_frames':17,'lossless_rgba_roundtrip':True,'original_dimensions':True,'alpha_preserved':True}
(ROOT/'build/weapon-art-kit-report.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report,indent=2))
