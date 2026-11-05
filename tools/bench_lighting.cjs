/* Repeatable renderer-only local scenes. Not a mobile FPS claim. */
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const{boot,root}=require('./cinematic/common.cjs');
const label=process.argv[2]||'after',directory=process.argv[3]||'build/qa-core',reaches=(process.argv[4]||'4,7,10').split(',').map(Number),qualities=(process.argv[5]||'0,1,2').split(',').map(Number);
assert.ok(reaches.every(n=>Number.isInteger(n)&&[4,7,10].includes(n)));assert.ok(qualities.every(n=>[0,1,2].includes(n)));
const hash=b=>crypto.createHash('sha256').update(b).digest('hex');
const median=a=>[...a].sort((a,b)=>a-b)[Math.floor(a.length/2)];
(async()=>{
 const g=await boot({coreDirectory:path.join(root,directory)}),{Brew,core}=g,model=()=>JSON.parse(Brew.json());
 const out=path.join(root,'build/lighting-bench',label);fs.mkdirSync(out,{recursive:true});const report=[];
 for(const map of[4,5,6]){
  core._oe2_qa_map(map);let stable=0;for(let t=0;t<1600;t++){let s=g.step(40);if(s.state===7)Brew.continueText();if([8,11,13].includes(s.state))Brew.key(0xe037);if(s.state===3&&!s.cinematic_active){if(++stable>8)break;}else stable=0;}
  assert.equal(model().map_id,map);const spawn=model(),candidates=[];
  for(let n=0;n<40;n++){
   const x=core._oe2_qa_light_point(n,0),y=core._oe2_qa_light_point(n,1);if(x<0)break;
   for(const[dx,dy]of[[64,0],[-64,0],[0,64],[0,-64]]){
    const cx=Math.max(32,Math.min(2016,Math.floor((x+dx)/64)*64+32)),cy=Math.max(32,Math.min(2016,Math.floor((y+dy)/64)*64+32));
    const angle=(Math.round(Math.atan2(-(y-cy),x-cx)*1024/(2*Math.PI))+1024)&1023;candidates.push({x:cx,y:cy,angle});
   }
  }
  candidates.unshift({x:spawn.x,y:spawn.y,angle:spawn.angle});Brew.quality(0);Brew.lightDistance(10);
  const ranked=[];for(const pose of candidates){core._oe2_qa_light_view(pose.x,pose.y,pose.angle);Brew.image('lit');ranked.push({...pose,lights:core._oe2_qa_light_profile(3),casters:core._oe2_qa_light_profile(4)});}
  ranked.sort((a,b)=>b.lights-a.lights||b.casters-a.casters);
  const baselinePath=path.join(root,'build/lighting-bench/baseline/report.json'),baseline=label!=='baseline'&&fs.existsSync(baselinePath)?JSON.parse(fs.readFileSync(baselinePath)).find(row=>row.map===map):null;
  const pose=baseline?baseline.pose:ranked[0];core._oe2_qa_light_view(pose.x,pose.y,pose.angle);Brew.image('lit');
  const scene={x:pose.x,y:pose.y,angle:pose.angle,lights:core._oe2_qa_light_profile(3),casters:core._oe2_qa_light_profile(4)};console.log(JSON.stringify({map,name:spawn.menu_context.level_name,points:(candidates.length-1)/4,scene}));
  for(const reach of reaches)for(const quality of qualities){
   Brew.lightDistance(reach);Brew.quality(quality);core._oe2_qa_light_view(scene.x,scene.y,scene.angle);
   const before=Brew.json(),classic=Buffer.from(Brew.image('world')),coldStart=performance.now();let pixels=Buffer.from(Brew.image('lit'));const cold=performance.now()-coldStart;
   const warm=[],stages=[];for(let i=0;i<8;i++){pixels=Buffer.from(Brew.image('lit'));warm.push(Brew.lightMs);stages.push([0,1,2].map(k=>core._oe2_qa_light_profile(k)));}
   const sourceStats={lights:core._oe2_qa_light_profile(3),casters:core._oe2_qa_light_profile(4),sourceCandidates:core._oe2_qa_light_profile(5),coneCulled:core._oe2_qa_light_profile(6)};
   assert.equal(Brew.json(),before);assert.deepEqual(Buffer.from(Brew.image('world')),classic);
   const name=`map${map}-r${reach}-q${quality}`,digest=hash(pixels);fs.writeFileSync(path.join(out,name+'.rgba'),pixels);
   const motion=[];const hashes=[];
   for(let i=0;i<8;i++){core._oe2_qa_light_view(scene.x+(i%4)*2,scene.y+(i%3)*2,scene.angle+i*4);Brew.image('lit');motion.push(Brew.lightMs);hashes.push(hash(Brew.image('lit')));}
   const modes=[];if(quality===2&&reach===10){for(let mode=1;mode<=2;mode++){core._oe2_qa_light_cost(mode);const times=[];for(let i=0;i<5;i++){Brew.image('lit');times.push(Brew.lightMs);}modes.push({mode,median:median(times)});}core._oe2_qa_light_cost(0);}
   report.push({map,name:spawn.menu_context.level_name,reach,processingSteps:reach,sourceReference:120,quality,pose:scene,...sourceStats,coldMs:cold,warmMs:median(warm),motionMs:median(motion),stages:[0,1,2].map(k=>median(stages.map(s=>s[k]))),sha256:digest,motionHashes:hashes,modes});
  }
 }
 fs.writeFileSync(path.join(out,'report.json'),JSON.stringify(report,null,2));console.log(JSON.stringify(report.map(({map,reach,quality,lights,warmMs,motionMs,stages,modes})=>({map,reach,quality,lights,warmMs,motionMs,stages,modes}))));
})().catch(e=>{console.error(e);process.exitCode=1;});
