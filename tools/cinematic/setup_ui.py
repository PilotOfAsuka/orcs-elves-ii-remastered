from pathlib import Path
import shutil,re
ROOT=Path(__file__).resolve().parents[2]
target=ROOT/'build/cinematic/ui'
shutil.copytree(ROOT/'ui',target,dirs_exist_ok=True,ignore=shutil.ignore_patterns('.godot','export_presets.cfg'))
p=target/'project.godot';s=p.read_text()
for key,value in [('viewport_width',360),('viewport_height',640),('window_width_override',540),('window_height_override',960)]:
 s=re.sub(r'window/size/'+key+r'=\d+','window/size/'+key+'='+str(value),s)
p.write_text(s)
print(target)
