/* Selected light identities must not depend on where the player looks. */
const assert=require('node:assert/strict'),path=require('node:path'),fs=require('node:fs');
const{boot,root}=require('./cinematic/common.cjs');
(async()=>{
 const g=await boot({coreDirectory:path.join(root,'build/qa-core')}),{Brew,core}=g,results=[];
 assert.equal(core._oe2_qa_light_region(),1,'circular influence intersection at every direction and preset');
 Brew.quality(0);
 for(const[map,x,y]of[[4,992,1504],[5,1248,1056],[6,1184,1056]]){
  core._oe2_qa_map(map);let stable=0;for(let t=0;t<1600;t++){const s=g.step(40);if(s.state===7)Brew.continueText();if([8,11,13].includes(s.state))Brew.key(0xe037);if(s.state===3&&!s.cinematic_active){if(++stable>8)break;}else stable=0;}
  assert.equal(g.model().map_id,map);
  for(const reach of[5,15,20]){
   Brew.lightDistance(reach);let expected;
   for(let angle=0;angle<1024;angle+=64){
    core._oe2_qa_light_view(x,y,angle);const before=Brew.json();Brew.image('lit');assert.equal(Brew.json(),before);
    const keys=Array.from({length:core._oe2_qa_light_profile(3)},(_,n)=>core._oe2_qa_light_selected(n));
    if(expected)assert.deepEqual(keys,expected,`map ${map}, radius ${reach}: same sources through 360 degrees`);else expected=keys;
   }
   results.push({map,reach,lookDirections:16,sourceKeys:expected});
  }
 }
 fs.writeFileSync(path.join(root,'build/radius-lighting-check.json'),JSON.stringify({directions:144,results},null,2));console.log(JSON.stringify({directions:144,sourceSelectionIndependentOfYaw:true,pure:true}));
})().catch(e=>{console.error(e);process.exitCode=1;});
