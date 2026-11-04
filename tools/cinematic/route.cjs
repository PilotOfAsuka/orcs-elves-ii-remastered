const {boot,settle}=require('./common.cjs');const fs=require('node:fs'),path=require('node:path');
(async()=>{const g=await boot();await settle(g);const survey=JSON.parse(g.core.UTF8ToString(g.core._oe2_film_survey()));survey.player=g.model();fs.writeFileSync(path.join(g.out,'settled.json'),JSON.stringify(survey));
const start=[Math.floor(survey.player.x/64),Math.floor(survey.player.y/64)],queue=[start],parents=new Map([[start.join(','),null]]);
for(let at=0;at<queue.length;at++){
 const [x,y]=queue[at];for(const [dx,dy]of[[1,0],[0,1],[-1,0],[0,-1]]){
  const a=x+dx,b=y+dy,key=[a,b].join(',');if(a<0||b<0||a>=32||b>=32||parents.has(key))continue;
  if(g.core._oe2_film_clear(x*64+32,y*64+32,a*64+32,b*64+32)){parents.set(key,[x,y]);queue.push([a,b]);}
 }
}
const actors=survey.sprites.filter(a=>a.health>0&&!(a.info&0x10000)).map(a=>{let key=[Math.floor(a.x/64),Math.floor(a.y/64)].join(','),route=[];while(parents.has(key)){const p=key.split(',').map(Number);route.push(p);const prev=parents.get(key);if(!prev)break;key=prev.join(',');}return {...a,route:route.reverse()};}).filter(a=>a.route.length>1).sort((a,b)=>a.route.length-b.route.length);
console.log(JSON.stringify({start,reachable:queue.length,actors:actors.slice(0,4)},null,2));fs.writeFileSync(path.join(g.out,'routes.json'),JSON.stringify({start,reachable:queue,actors},null,2));
})().catch(e=>{console.error(e);process.exitCode=1;});
