/* Disposable routes through all seven original maps. CPU reference and GPU byte
 * inputs share one simulation; no real saves, no live game, no mobile FPS claim. */
const {boot,root}=require('./cinematic/common.cjs');
const path=require('node:path'),fs=require('node:fs'),assert=require('node:assert/strict');
const png=require('./cinematic/png.cjs');
const median=a=>[...a].sort((a,b)=>a-b)[Math.floor(a.length/2)];
(async()=>{
 const g=await boot({coreDirectory:path.join(root,'build/qa-core')}),{Brew,core}=g,out=path.join(root,'build/gpu-check');fs.mkdirSync(out,{recursive:true});
 const rows=[],fixtures=[];
 for(const map of[2,1,3,4,5,6,7]){
  core._oe2_qa_map(map);let stable=0;for(let t=0;t<1600;t++){const s=g.step(40);if(s.state===7)Brew.continueText();if([8,11,13].includes(s.state))Brew.key(0xe037);if(s.state===3&&!s.cinematic_active){if(++stable>8)break;}else stable=0;}
  assert.equal(g.model().map_id,map);let spawn=g.model();
  const start=[Math.floor(spawn.x/64),Math.floor(spawn.y/64)],queue=[start],seen=new Set([start.join(',')]);
  for(let at=0;at<queue.length;at++){const [x,y]=queue[at];for(const [dx,dy]of[[1,0],[-1,0],[0,1],[0,-1]]){const a=x+dx,b=y+dy,key=[a,b].join(',');if(seen.has(key)||!core._oe2_qa_light_floor(a,b)||!core._oe2_qa_light_clear(x*64+32,y*64+32,a*64+32,b*64+32))continue;seen.add(key);queue.push([a,b]);}}
  const poses=Array.from({length:8},(_,i)=>{const [x,y]=queue[Math.floor(i*(queue.length-1)/7)];return {x:x*64+32,y:y*64+32,angle:(i*137+spawn.angle)&1023};});
  for(const reach of[5,15,20])for(const quality of[0,1,2]){
   Brew.lightDistance(reach);Brew.quality(quality);let squared=0,channels=0,max=0;const cpu=[],gpu=[],cold=[];
   for(let index=0;index<poses.length;index++){
    const {x,y,angle}=poses[index];core._oe2_qa_light_view(x,y,angle);g.step(40);
    const state=Brew.json(),classic=Buffer.from(Brew.image('world'));
    const before=Buffer.from(Brew.image('lit'));cpu.push(Brew.lightMs);
    const colour=Buffer.from(Brew.image('gpu'));cold.push(Brew.lightMs);Brew.image('gpu');gpu.push(Brew.lightMs);
    const ptr=core._oe2_qa_gpu_reference(),ref=Buffer.from(core.HEAPU8.subarray(ptr,ptr+colour.length));
    for(let n=0;n<ref.length;n++)if(n%4!==3){let d=Math.abs(ref[n]-before[n]);max=Math.max(max,d);squared+=d*d;channels++;}
    assert.equal(Brew.json(),state);assert.deepEqual(Buffer.from(Brew.image('world')),classic);
    if(reach===20&&quality>0&&(index===3||(map===2&&quality===2&&index===5))){
     const id=`map${map}-q${quality}`+(index===5?'-near-source':'');const width=176*(1<<quality),height=164*(1<<quality);
     for(const [key,data]of Object.entries({colour,xy:Buffer.from(Brew.gpuBuffer('xy')),zna:Buffer.from(Brew.gpuBuffer('zna')),shadows:Buffer.from(Brew.gpuBuffer('shadows')),contact:Buffer.from(Brew.gpuBuffer('contact')),reference:ref,cpu:before}))fs.writeFileSync(path.join(out,id+'-'+key+'.rgba'),data);
     fs.writeFileSync(path.join(out,id+'-cpu.png'),png(before,width,height));fs.writeFileSync(path.join(out,id+'-gpu-reference.png'),png(ref,width,height));
     fixtures.push({id,map,width,height,parameters:JSON.parse(Brew.gpuParameters())});
    }
   }
   const rmse=Math.sqrt(squared/channels);
   // Original normals/positions and contact shade are encoded to byte textures.
   // These explicit bounds catch missing visibility, edges and geometry leakage.
   assert.ok(rmse<1,`${map}/${reach}/${quality}: RMSE ${rmse}, max ${max}`);
   assert.ok(max<=10,`${map}/${reach}/${quality}: isolated RGB error ${max}`);
   const row={map,name:spawn.menu_context.level_name,reach,quality,reachableCells:queue.length,poses:poses.length,cpuMs:median(cpu),gpuPrepareMs:median(gpu),coldPrepareMs:median(cold),rgbMax:max,rmse};rows.push(row);console.log(JSON.stringify(row));
  }
 }
 core._oe2_qa_map(2);for(let t=0;t<160;t++){let s=g.step(40);if(s.state===7)Brew.continueText();}
 const lamp=core._oe2_qa_lamp_position(150,0),x=core._oe2_qa_lamp_position(150,1),y=core._oe2_qa_lamp_position(150,2);assert.ok(lamp>=0);
 const keys=()=>Array.from({length:core._oe2_qa_light_profile(3)},(_,i)=>core._oe2_qa_light_selected(i));
 const gpuFrame=()=>{Brew.image('gpu');const ptr=core._oe2_qa_gpu_reference();return Buffer.from(core.HEAPU8.subarray(ptr,ptr+176*164*4*4**Brew.qualityLevel));};
 for(const quality of[0,1,2]){
  Brew.quality(quality);core._oe2_qa_lamp_state(150,0);core._oe2_qa_light_view(x-48,y,0);const on=gpuFrame();assert.ok(keys().includes(lamp));
  core._oe2_qa_lamp_state(150,1);core._oe2_qa_light_view(x-48,y,0);const off=gpuFrame();assert.ok(!keys().includes(lamp));assert.notDeepEqual(on,off);
  core._oe2_qa_lamp_state(150,0);core._oe2_qa_light_view(x-48,y,0);gpuFrame();assert.ok(keys().includes(lamp));
  assert.equal(core._oe2_qa_land(225),1);const before=Brew.json(),classic=Buffer.from(Brew.image('world'));gpuFrame();assert.ok(keys().some(k=>k>=3000&&k<3008),'arrival flash is included');assert.equal(Brew.json(),before);assert.deepEqual(Buffer.from(Brew.image('world')),classic);
  for(let t=0;t<12;t++)g.step(40);gpuFrame();assert.ok(!keys().some(k=>k>=3000&&k<3008),'arrival flash expires');
 }
 fs.writeFileSync(path.join(out,'report.json'),JSON.stringify({rows,pure:true,frames:rows.length*8,dynamic:{extinguish:true,relight:true,arrivalFlash:true,flashExpiry:true,qualities:3}},null,2));fs.writeFileSync(path.join(out,'fixtures.json'),JSON.stringify(fixtures));
})().catch(e=>{console.error(e);process.exitCode=1;});
