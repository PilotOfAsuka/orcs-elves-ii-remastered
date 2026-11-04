const {boot,settle}=require('./common.cjs'),fs=require('node:fs'),path=require('node:path');
(async()=>{
 const g=await boot();await settle(g);const routes=JSON.parse(fs.readFileSync(path.join(g.out,'routes.json'))),route=routes.actors[0].route,commands=[];
 async function action(a){commands.push(a);g.Brew.action(a);for(let i=0;i<15;i++){let s=g.step(40);if(s.state===7)g.Brew.continueText();}let wait=0;while(g.model().state!==3&&wait++<80){let s=g.step(40);if(s.state===7)g.Brew.continueText();}const s=g.model();console.log(JSON.stringify({a,x:s.x,y:s.y,angle:s.angle,state:s.state,hp:s.hud.health,target:s.hud.target_health,context:s.hud.context,notice:s.hud.notices}));return s;}
 await action(12); // The wand refuses to fight at this point in the original story.
 let kills=0;
 for(let index=1;index<route.length;index++){
  const [tx,ty]=route[index];
  let s=g.model(),dx=tx*64+32-s.x,dy=ty*64+32-s.y;
  const wanted=dx>0?0:dx<0?512:dy>0?768:256;
  let turns=0;while(((g.model().angle%1024)+1024)%1024!==wanted&&turns++<3){let delta=(wanted-g.model().angle+4096)%1024;await action(delta<=512?3:4);}
  let shots=0;while(g.model().hud.target_health>0&&shots++<10){await action(6);if(g.model().hud.target_health<=0)kills++;}
  if(kills>0)break;
  s=await action(1);if(s.x!==tx*64+32||s.y!==ty*64+32){
   if(s.hud.target_health>0){let shots=0;while(g.model().hud.target_health>0&&shots++<10)await action(6);if(g.model().hud.target_health<=0){kills++;break;}}
   const jumped=route.findIndex(([x,y],i)=>i>=index&&s.x===x*64+32&&s.y===y*64+32);if(jumped>=index)index=jumped;else{console.log('BLOCKED',tx,ty);break;}
  }
 }
 fs.writeFileSync(path.join(g.out,'gameplay-commands.json'),JSON.stringify({commands,kills,final:g.model()},null,2));
})().catch(e=>{console.error(e);process.exitCode=1;});
