from pathlib import Path
import json,copy
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'build/cinematic'
sources={key:json.loads((OUT/(key+'.json')).read_text()) for key in ['fly','gameplay']}
frames=[];segments=[]
def add(source,indices,caption,duration=2.2,languages=None):
 start=len(frames)
 for n,index in enumerate(indices):
  frame=copy.deepcopy(sources[source]['frames'][index]);t=n/60
  frame['caption']=caption if t<duration else ''
  frame['caption_alpha']=min(1,t/0.15,max(0,(duration-t)/0.25))
  frame['language']='ru' if languages and t>=languages else 'en'
  frames.append(frame)
 segments.append({'source':source,'source_start':indices[0],'frames':len(indices),'start':start,'caption':caption})
def shot(id):return [i for i,f in enumerate(sources['fly']['frames']) if f['shot']==id]
add('fly',shot('opening'),'THE DUNGEON\nLIVES AGAIN',2.7)
add('fly',shot('classic'),'YOUR CLASSIC.\nPRESERVED.',2.5)
add('fly',shot('maximum'),'ONE TAP.\nREMASTERED HIGH.',3.1)
add('gameplay',list(range(36,324)),'TOUCH CONTROLS.\nBUILT FOR YOUR SCREEN.',2.4)
add('gameplay',list(range(324,552)),'STEP IN.\nFIGHT BACK.',1.6)
add('fly',shot('torch'),'DYNAMIC LIGHT.\nCAST SHADOWS.',2.5)
add('gameplay',[i for i,f in enumerate(sources['gameplay']['frames']) if f['shot']=='map'],'EXPLORE.\nFIND YOUR WAY.',1.9)
add('fly',shot('vault'),'ENGLISH & RUSSIAN.\nSWITCH ANYTIME.',4.3,languages=2.5)
add('gameplay',[i for i,f in enumerate(sources['gameplay']['frames']) if f['shot']=='save'],'SAVE YOUR PROGRESS.\nRETURN ANYTIME.',2.7)
add('fly',shot('horde'),'NO INSTALL.\nJUST PLAY.',2.5)
add('fly',shot('finale'),'ORCS & ELVES II\nPLAY IN YOUR BROWSER',6)
assert all(f['model']['map_id']==1 for f in frames)
assert all(f['caption'].isascii() for f in frames)
edit={'fps':60,'width':1080,'height':1920,'language':'English','frames':frames,'segments':segments}
(OUT/'edit.json').write_text(json.dumps(edit))
print('Vertical English trailer:',len(frames)/60,'seconds,',len(frames),'frames')
