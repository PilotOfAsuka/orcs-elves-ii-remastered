/* Actual level geometry and current-frame exact-light reference. No real saves. */
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');
const{boot,root}=require('./cinematic/common.cjs');
(async()=>{
 const g=await boot({coreDirectory:path.join(root,'build/qa-core')}),{Brew,core}=g,scenes=[[4,992,1504,586],[5,1248,1056,512],[6,1184,1056,768]],results=[];
 assert.equal(core._oe2_qa_light_cone(),1,'finite processing cones preserve near sources and off-screen influence');
 for(const[map,x,y,angle]of scenes){
  core._oe2_qa_map(map);let stable=0;for(let n=0;n<1600;n++){const s=g.step(40);if(s.state===7)Brew.continueText();if([8,11,13].includes(s.state))Brew.key(0xe037);if(s.state===3&&!s.cinematic_active){if(++stable>8)break;}else stable=0;}
  assert.equal(g.model().map_id,map);assert.equal(core._oe2_qa_light_rays(),1,'48,000 accelerated/reference rays, original and changed walls');
  for(const reach of[4,7,10])for(let quality=0;quality<3;quality++){
   Brew.lightDistance(reach);Brew.quality(quality);let max=0,total=0,squared=0,changed=0;
   for(let pose=0;pose<16;pose++){
    core._oe2_qa_light_view(x+(pose%4)*3,y+(pose%3)*3,angle+pose*5);g.step(40);
    const state=Brew.json(),classic=Buffer.from(Brew.image('world'));
    core._oe2_qa_light_cost(0);const sampled=Buffer.from(Brew.image('lit'));
    core._oe2_qa_light_cost(3);const exact=Buffer.from(Brew.image('lit'));core._oe2_qa_light_cost(0);
    assert.equal(sampled.length,exact.length);assert.equal(Brew.json(),state);assert.deepEqual(Buffer.from(Brew.image('world')),classic);
    for(let i=0;i<exact.length;i++){
     if(i%4===3){assert.equal(sampled[i],exact[i]);continue;}
     const d=Math.abs(sampled[i]-exact[i]);max=Math.max(max,d);squared+=d*d;changed+=d>0;total++;
    }
   }
   const rmse=Math.sqrt(squared/total);assert.ok(max<=2,`map ${map}, reach ${reach}, quality ${quality}: maximum RGB difference ${max}`);assert.ok(rmse<.1,`RMSE ${rmse}`);if(!quality)assert.equal(max,0,'Low stays exact');
   results.push({map,reach,quality,poses:16,max,rmse,changedPercent:changed/total*100});
  }
 }
 fs.writeFileSync(path.join(root,'build/lighting-check.json'),JSON.stringify({acceleratedRays:144000,frames:432,results},null,2));console.log(JSON.stringify({acceleratedRays:144000,frames:432,results}));
})().catch(e=>{console.error(e);process.exitCode=1;});
