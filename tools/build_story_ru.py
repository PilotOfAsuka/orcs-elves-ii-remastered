#!/usr/bin/env python3
"""Create separate Cyrillic text-only vector textures. Original parchment art is untouched."""
from pathlib import Path
import sys,json,re,html
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools/vendor/pylibs'))
from fontTools.ttLib import TTFont
from fontTools.pens.svgPathPen import SVGPathPen
font=TTFont(ROOT/'tools/vendor/fonts/NotoSerif-Bold.ttf');glyphs=font.getGlyphSet();cmap=font.getBestCmap();units=font['head'].unitsPerEm
metrics=font['hmtx'].metrics
OUT=ROOT/'ui/localized/ru';OUT.mkdir(parents=True,exist_ok=True)
texts=json.loads((ROOT/'localization/ru/story.json').read_text())
def width(text,size):return sum(metrics[cmap[ord(c)]][0] for c in text)*size/units
def layout(text,size,drop):
    words=text[1:].split() if drop else text.split();lines=[];line=''
    for word in words:
        room=112 if drop and len(lines)<3 else 140
        candidate=(line+' '+word).strip()
        if width(candidate,size)>room and line:lines.append(line);line=word
        else:line=candidate
    if line:lines.append(line)
    return lines
report=[]
for kind,pages in texts.items():
 for page,text in enumerate(pages):
    drop=page==0;size=11.0
    while True:
        lines=layout(text,size,drop)
        if len(lines)*size*1.21<=116 or size<9.0:break
        size-=.15
    if len(lines)*size*1.21>116:raise RuntimeError('Story page overflow')
    placements=[]
    if drop:placements.append((text[0],18,59,34))
    for n,line in enumerate(lines):placements.append((line,46 if drop and n<3 else 18,38+n*size*1.21,size))
    defs={};uses=[]
    for line,x,y,fs in placements:
        for char in line:
            name=cmap[ord(char)]
            if name not in defs:
                pen=SVGPathPen(glyphs);glyphs[name].draw(pen);defs[name]=(f'g{len(defs)}',pen.getCommands())
            ident=defs[name][0];uses.append(f'<use href="#{ident}" transform="translate({x:.3f} {y:.3f}) scale({fs/units:.6f} {-fs/units:.6f})"/>')
            x+=metrics[name][0]*fs/units
    paths=''.join(f'<path id="{ident}" d="{d}"/>' for ident,d in defs.values())
    svg=f'<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="704" height="704" viewBox="0 0 176 176"><defs>{paths}</defs><g fill="#17140e">'+''.join(uses)+'</g></svg>'
    # Both href spellings are supported by the project's SVG importer.
    svg=svg.replace('<use href=','<use xlink:href=')
    (OUT/f'{kind}_{page}.svg').write_text(svg)
    report.append({'page':f'{kind}:{page}','fontSize':round(size,2),'lines':len(lines),'text':text})
licenses=[]
for entry in font['name'].names:
    if entry.nameID in (0,13) and entry.platformID==3:
        value=entry.toUnicode()
        if value not in licenses:licenses.append(value)
(ROOT/'localization/FONT_LICENSE.txt').write_text('\n\n'.join(licenses)+'\n')
(ROOT/'research/localization/story-layout.json').write_text(json.dumps(report,ensure_ascii=False,indent=2))
print(json.dumps([{'page':r['page'],'font':r['fontSize'],'lines':r['lines']} for r in report]))
