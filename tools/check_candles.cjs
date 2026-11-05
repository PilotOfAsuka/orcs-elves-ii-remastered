const assert=require('node:assert/strict'),path=require('node:path'),fs=require('node:fs');
const{boot,root}=require('./cinematic/common.cjs');
(async()=>{
 const g=await boot({coreDirectory:path.join(root,'build/qa-core')}),{Brew,core}=g;
 assert.equal(core._oe2_qa_candle_geometry(),1,'mirrored/repeating/two-sided/hidden/clipped/stacked wall candles');
 core._oe2_qa_map(2);let stable=0;for(let i=0;i<1500;i++){let s=g.step(40);if(s.state===7)Brew.continueText();if([8,11,13].includes(s.state))Brew.key(0xe037);if(s.state===3&&!s.cinematic_active){if(++stable>8)break;}else stable=0;}
 assert.equal(g.model().map_id,2);
 assert.equal(core._oe2_qa_lamp_frames(),1,'all native flame frames, extinguished frames and hidden lamps');
 const lamps=[];
 for(const tile of[150]){
  const off=core._oe2_qa_lamp_state(tile,1);assert.equal(off,0,`tile ${tile}: native extinguish opcode removes light`);
  assert.equal(core._oe2_qa_lamp_state(tile,0),1,`tile ${tile}: native relight opcode restores light`);lamps.push(tile);
 }
 core._oe2_qa_map(4);stable=0;for(let i=0;i<1500;i++){let s=g.step(40);if(s.state===7)Brew.continueText();if([8,11,13].includes(s.state))Brew.key(0xe037);if(s.state===3&&!s.cinematic_active){if(++stable>8)break;}else stable=0;}
 Brew.save();const saved=[0,1,2].map(i=>Buffer.from(Brew.testFile('SD_'+i)));
 const line=core._oe2_qa_candle();assert.ok(line>=0,'real map-4 candle wall exists');
 const model=Brew.json(),classic=Buffer.from(Brew.image('world')),differences=[];
 fs.mkdirSync(path.join(root,'build/proofs'),{recursive:true});
 for(let quality=0;quality<3;quality++){
  Brew.quality(quality);core._oe2_qa_wall_light(0);const before=Buffer.from(Brew.image('lit'));
  core._oe2_qa_wall_light(1);const after=Buffer.from(Brew.image('lit'));assert.notDeepEqual(after,before,'painted candle illuminates the scene');
  let changed=0;for(let i=0;i<after.length;i+=4)if(after[i]!==before[i]||after[i+1]!==before[i+1]||after[i+2]!==before[i+2])changed++;
  differences.push({quality,changed,pixels:after.length/4});
  assert.equal(Brew.json(),model,'lighting getters preserve game state');assert.deepEqual(Buffer.from(Brew.image('world')),classic,'Classic art untouched');
  if(quality===2){fs.writeFileSync(path.join(root,'build/proofs/candle-without-light.rgba'),before);fs.writeFileSync(path.join(root,'build/proofs/candle-lit.rgba'),after);}
 }
 saved.forEach((bytes,i)=>assert.deepEqual(Buffer.from(Brew.testFile('SD_'+i)),bytes,'rendering preserves native saves'));
 const report={line,lamps,geometry:true,purity:true,differences};fs.writeFileSync(path.join(root,'build/candle-check.json'),JSON.stringify(report,null,2));console.log(JSON.stringify(report));
})().catch(e=>{console.error(e);process.exitCode=1;});
