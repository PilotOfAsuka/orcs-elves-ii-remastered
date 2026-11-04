"""Original BREW title music/SFX plus restrained trailer transition impacts."""
from pathlib import Path
import json,wave
import numpy as np
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'build/cinematic';RATE=48000
edit=json.loads((OUT/'edit.json').read_text());duration=len(edit['frames'])/60
mix=np.zeros(round(duration*RATE),dtype=np.float64);cache={}
def clip(id,rate):
 if id not in cache:
  a=np.frombuffer((OUT/'audio'/(id+'.pcm')).read_bytes(),dtype='<i2').astype(np.float64)/32768
  cache[id]=np.interp(np.arange(round(len(a)*RATE/rate))*rate/RATE,np.arange(len(a)),a)
 return cache[id]
def put(data,at,gain=1):
 start=round(at*RATE);offset=max(0,-start);start=max(0,start);count=min(len(data)-offset,len(mix)-start)
 if count>0:mix[start:start+count]+=data[offset:offset+count]*gain
sources={key:json.loads((OUT/(key+'.json')).read_text()) for key in ['fly','gameplay']}
music='c0024aed7337c235';bed=clip(music,8000);cross=RATE
stride=len(bed)-cross
for start in range(0,len(mix),stride):
 data=bed.copy();data[:cross]*=np.linspace(0,1,cross);data[-cross:]*=np.linspace(1,0,cross);put(data,start/RATE,0.38)
for segment in edit['segments']:
 source=sources[segment['source']];events=source['audio']['events'];begin=source['startClock']+segment['source_start']/60*1000;end=begin+segment['frames']/60*1000
 for index,event in enumerate(events):
  if event['kind']!='play' or event['id']==music or event['samples']/event['rate']>5:continue
  stop=event['ms']+event['samples']/event['rate']*1000
  for later in events[index+1:]:
   if later['channel']==event['channel'] and later['kind'] in ['stop','play']:stop=min(stop,later['ms']);break
  left=max(begin,event['ms']);right=min(end,stop)
  if right<=left:continue
  pcm=clip(event['id'],event['rate']);a=round((left-event['ms'])*RATE/1000);b=round((right-event['ms'])*RATE/1000)
  put(pcm[a:b],segment['start']/60+(left-begin)/1000,event['gain']*0.85)
# Short low impacts make editorial cuts legible without replacing game SFX.
rng=np.random.default_rng(9)
for index,segment in enumerate(edit['segments']):
 t=np.arange(round(0.7*RATE))/RATE
 boom=(np.sin(2*np.pi*(65*t-20*t*t))+0.3*np.sin(2*np.pi*110*t))*np.exp(-t*8)*0.095
 noise=rng.normal(0,1,len(t));soft=np.convolve(noise,np.ones(40)/40,mode='same')
 boom+=soft*np.exp(-t*13)*0.13
 put(boom,segment['start']/60)
mix[:RATE//2]*=np.linspace(0,1,RATE//2);mix[-RATE:]*=np.linspace(1,0,RATE)
peak=np.max(np.abs(mix));mix*=min(1,0.94/max(peak,1e-6))
stereo=np.column_stack([mix,mix]);pcm=np.clip(stereo*32767,-32768,32767).astype('<i2')
with wave.open(str(OUT/'mix.wav'),'wb')as f:f.setnchannels(2);f.setsampwidth(2);f.setframerate(RATE);f.writeframes(pcm.tobytes())
print('Mixed original game music and SFX:',duration,'seconds; peak',round(float(np.max(np.abs(mix))),3))
