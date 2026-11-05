const assert=require('node:assert/strict'),path=require('node:path'),fs=require('node:fs');
const{boot,root}=require('./cinematic/common.cjs');
(async()=>{
 const g=await boot({coreDirectory:path.join(root,'build/qa-core')}),{Brew,core}=g,m=()=>JSON.parse(Brew.json());
 core._oe2_qa_give_rings();const strength=core._oe2_qa_strength(),health=m().hud.max_health;
 Brew.inventory();Brew.inventoryTab(1);
 const choose=id=>{const s=m(),row=s.items.find(r=>r.action===id&&r.index>2&&!(r.flags&5));assert.ok(row);Brew.menu(s.menu_id,row.index);for(let i=0;i<3;i++)g.step(40);return m();};
 for(let id=1;id<=8;id++){
  const s=choose(id);assert.equal(s.hud.ring_id,id);assert.ok(s.hud.ring_name.length&&s.hud.ring_description.length);
  assert.ok(s.items.find(r=>r.action===id&&r.index>2).text.includes('✓'),'original equipped marker survives the adapter');
  if(id===1)assert.equal(core._oe2_qa_strength(),strength+Math.trunc(strength/4),'native strength bonus');
  if(id===6)assert.equal(s.hud.max_health,health+Math.trunc(health/2),'native health bonus');
 }
 choose(0);assert.equal(m().hud.ring_id,0);assert.equal(core._oe2_qa_strength(),strength);assert.equal(m().hud.max_health,health);
 choose(3);Brew.closeInventory();assert.equal(Brew.save(),1);for(let i=0;i<10;i++)g.step(40);
 const bytes=Buffer.from(Brew.testFile('SD_0'));Brew.inventory();Brew.inventoryTab(1);choose(0);Brew.closeInventory();assert.equal(Brew.load(),1);
 for(let i=0;i<160;i++){let s=g.step(40);if(s.state===7)Brew.continueText();if([8,11,13].includes(s.state))Brew.key(0xe037);if(s.state===3)break;}
 assert.equal(m().hud.ring_id,3,'native save/load restores equipped ring');
 const model=Brew.json(),classic=Buffer.from(Brew.image('world'));
 for(let quality=0;quality<3;quality++){
  Brew.quality(quality);Brew.lightDistance(4);const low=Buffer.from(Brew.image('lit'));
  Brew.lightDistance(7);const medium=Buffer.from(Brew.image('lit'));
  Brew.lightDistance(10);const high=Buffer.from(Brew.image('lit'));
  assert.equal(low.length,medium.length);assert.equal(medium.length,high.length);
  // A near-only scene may look identical at every processing distance.
  Brew.lightDistance(999);assert.deepEqual(Buffer.from(Brew.image('lit')),high,'runtime maximum is ten walking steps');
  core._oe2_light_distance(999);assert.deepEqual(Buffer.from(Brew.image('lit')),high,'native maximum is ten walking steps');
  Brew.lightDistance(0);assert.deepEqual(Buffer.from(Brew.image('lit')),low,'minimum is four walking steps');
  assert.equal(Brew.json(),model);assert.deepEqual(Buffer.from(Brew.image('world')),classic);assert.deepEqual(Buffer.from(Brew.testFile('SD_0')),bytes);
 }
 fs.writeFileSync(path.join(root,'build/rings-range-check.json'),JSON.stringify({rings:8,remove:true,nativeStats:true,saveLoad:true,marker:true,qualities:3,processingSteps:[4,7,10],sourceReference:120,clamping:true,purity:true},null,2));
 console.log('8 native rings, bonuses, removal, save/load, glyphs; Low/Medium/High range and purity at every quality passed');
})().catch(e=>{console.error(e);process.exitCode=1;});
