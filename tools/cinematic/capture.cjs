const {boot,settle}=require('./common.cjs'),png=require('./png.cjs'),fs=require('node:fs'),path=require('node:path');
const FPS=60;
function recorder(g,name){
 const frames=[],dir=path.join(g.out,name);fs.mkdirSync(dir,{recursive:true});const startClock=g.clock;let index=0,ticks=0;
 function step(){const desired=Math.floor((index+1)*5/12);while(ticks<desired){g.step(40);ticks++;}}
 function capture(extra={}){
  let model=g.model();const mode=extra.mode||'remastered',raw=g.Brew.image(mode==='classic'?'classic':'lit'),scale=mode==='classic'?1:4;
  const file=String(index).padStart(5,'0')+'.png';fs.writeFileSync(path.join(dir,file),png(raw,176*scale,164*scale));
  frames.push({image:name+'/'+file,model,mode,...extra});index++;return model;
 }
 function finish(){fs.writeFileSync(path.join(g.out,name+'.json'),JSON.stringify({fps:FPS,startClock,frames,audio:{events:g.events,clips:g.clips,endClock:g.clock}}));console.log(name,frames.length,'frames');}
 return {frames,step,capture,finish,get index(){return index;}};
}
function angleTo(x,y,tx,ty){return (Math.atan2(-(ty-y),tx-x)*1024/(2*Math.PI)+1024)%1024;}
(async()=>{
 const name=process.argv[2]||'fly',g=await boot({audio:true});await settle(g);g.Brew.quality(2);
 if(name==='fly'){
  g.Brew.action(12);for(let i=0;i<15;i++)g.step(40);
  const rec=recorder(g,name);
  const shots=[
   {id:'opening',seconds:4,x:800,y:1120,dx:14,dy:35,z:35,tx:800,ty:1248},
   {id:'classic',seconds:3,x:800,y:1152,dx:0,dy:0,z:35,tx:800,ty:1248,mode:'classic'},
   {id:'maximum',seconds:4,x:800,y:1152,dx:0,dy:0,z:35,tx:800,ty:1248},
   {id:'torch',seconds:5,x:480,y:1312,dx:0,dy:44,z:34,tx:480,ty:1471},
   {id:'horde',seconds:5,x:1304,y:1304,dx:12,dy:12,z:35,tx:1408,ty:1440},
   {id:'vault',seconds:5,x:600,y:1872,dx:14,dy:18,z:36,tx:608,ty:1952},
   {id:'finale',seconds:6,x:792,y:1120,dx:12,dy:48,z:36,tx:800,ty:1248}
  ];
  for(const shot of shots){
   for(let i=0;i<shot.seconds*FPS;i++){
    rec.step();if(g.model().state===7)g.Brew.continueText();
    const t=i/(shot.seconds*FPS-1),ease=t*t*(3-2*t),x=shot.x+shot.dx*ease,y=shot.y+shot.dy*ease,z=shot.z;
    const a=angleTo(x,y,shot.tx,shot.ty);g.core._oe2_film_view(x,y,z,a);
    rec.capture({fly:true,shot:shot.id,mode:shot.mode||'remastered',pose:[x,y,z,a]});g.core._oe2_film_restore();
   }
   console.log('Captured',shot.id);
  }
  rec.finish();
 }else{
  const rec=recorder(g,'gameplay'),commands=[12,3,3,1,1,1,3,1,1,6,6,6];
  for(const action of commands){
   g.Brew.action(action);
   for(let f=0;f<36;f++){
    rec.step();let s=g.model();if(s.state===7)g.Brew.continueText();
    rec.capture({shot:action===6?'combat':'explore',action:f<10?action:0});
   }
  }
  for(let f=0;f<120;f++){rec.step();if(g.model().state===7)g.Brew.continueText();rec.capture({shot:'combat'});}
  g.Brew.action(7);
  for(let f=0;f<180;f++){rec.step();rec.capture({shot:'map'});}
  g.Brew.action(7);for(let f=0;f<12;f++){rec.step();rec.capture({shot:'resume'});}
  g.Brew.save();for(let f=0;f<240;f++){rec.step();rec.capture({shot:'save'});}
  rec.finish();
 }
})().catch(e=>{console.error(e);process.exitCode=1;});
