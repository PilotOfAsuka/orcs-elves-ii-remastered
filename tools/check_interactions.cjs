/* Disposable BREW fixtures, never enabled in release WASM. */
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const {boot,root}=require('./cinematic/common.cjs');
(async()=>{
 const index=Number(process.argv[2]||0),g=await boot({coreDirectory:path.join(root,'build/qa-core')});
 const {Brew,core}=g,model=()=>JSON.parse(Brew.json());
 const map=Number(process.argv[3]||1);
 if(map!==1){core._oe2_qa_map(map);let stable=0;for(let i=0;i<1400;i++){const s=g.step(40);if(s.state===7)Brew.continueText();else if([8,11,13].includes(s.state))Brew.key(0xe037);if(s.state===3&&!s.cinematic_active){if(++stable>=8)break;}else stable=0;}assert.equal(model().map_id,map);}
 const length=core._oe2_qa_lock(index);assert.ok(length>=3);
 let s=model();assert.equal(s.state,19);assert.equal(s.lock.length,length);assert.equal(s.lock.attempts,0);
 const keys={1:0xe031,2:0xe032,3:0xe033,4:0xe034};
 const press=action=>{Brew.key(keys[action]||action);g.step(40);return model();};
 const first=core._oe2_qa_direction(0),wrong=first%4+1;
 s=press(wrong);assert.equal(s.lock.slot,0);assert.equal(s.lock.hits,0);assert.equal(s.lock.attempts,1);assert.equal(s.lock.last_direction,wrong);
 s=press(first);assert.equal(s.lock.hits,1);assert.equal(s.lock.slot,0);
 s=press(wrong);assert.equal(s.lock.hits,0);assert.equal(s.lock.slot,0);
 s=press(first);s=press(first);assert.equal(s.lock.slot,1);assert.equal(s.lock.hits,0);
 const next=core._oe2_qa_direction(1);s=press(next%4+1);assert.equal(s.lock.slot,1,'wrong input preserves completed tumblers');
 s=press(0xe030);assert.equal(s.state,3,'cancel returns to playing');assert.equal(core._oe2_qa_chest_tile(),142,'cancel leaves chest locked');
 core._oe2_qa_lock(index);s=model();assert.equal(s.lock.slot,0);assert.equal(s.lock.hits,0);assert.equal(s.lock.attempts,0,'new attempt starts its own counter');
 for(let slot=0;slot<length;slot++){
  const correct=core._oe2_qa_direction(slot);assert.ok(correct>=1&&correct<=4);
  s=press(correct);assert.equal(s.lock.slot,slot);assert.equal(s.lock.hits,1);
  s=press(correct);
  if(slot<length-1){assert.equal(s.lock.slot,slot+1);assert.equal(s.lock.hits,0);}
 }
 assert.equal(s.state,3,'all tumblers open the real chest');assert.equal(core._oe2_qa_chest_tile(),143,'original locked chest becomes closed unlocked chest');
 assert.equal(s.lock.attempts,length*2);assert.equal(s.fatal,0);
 const prior=Brew.json(),canonical=Buffer.from(Brew.image('world'));
 Brew.quality(0);const before=Buffer.from(Brew.image('lit'));
 assert.equal(core._oe2_qa_land(225),1,'original projectile resolver ran');
 const landedModel=Brew.json(),landedClassic=Buffer.from(Brew.image('world'));
 const flash=Buffer.from(Brew.image('lit'));assert.notDeepEqual(flash,before,'arrival visibly lights the world');
 assert.equal(Brew.json(),landedModel);assert.deepEqual(Buffer.from(Brew.image('world')),landedClassic);
 assert.equal(model().hud.health,JSON.parse(prior).hud.health,'presentation flash does not deal damage');
 const png=require('./cinematic/png.cjs');fs.writeFileSync(path.join(root,`build/impact-${index}-peak.png`),png(flash,176,164));
 for(let i=0;i<10;i++)g.step(40);
 const faded=Buffer.from(Brew.image('lit'));assert.notDeepEqual(flash,faded,'flash decays');
 for(let quality=0;quality<3;quality++){Brew.quality(quality);const state=Brew.json(),classic=Buffer.from(Brew.image('world'));assert.equal(Brew.image('lit').length,176*164*4*(4**quality));assert.equal(Brew.json(),state);assert.deepEqual(Buffer.from(Brew.image('world')),classic);}
 assert.equal(typeof core._oe2_qa_direction,'function');
 console.log(JSON.stringify({map,chest:index,length,wrongInput:true,twoPresses:true,cancel:true,retry:true,unlocked:true,impact:true,qualities:3,canonicalUntouched:true}));
})().catch(error=>{console.error(error);process.exitCode=1;});
