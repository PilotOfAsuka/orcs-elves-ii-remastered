/* Actual native status rules in the isolated QA core, never a browser save. */
const assert=require('node:assert/strict'),path=require('node:path'),fs=require('node:fs');
const {boot,root}=require('./cinematic/common.cjs');
(async()=>{
 const g=await boot({coreDirectory:path.join(root,'build/qa-core')}),{Brew,core}=g;
 const model=()=>JSON.parse(Brew.json()),effects=()=>model().hud.effects;
 core._oe2_qa_status(-1,0,0);assert.deepEqual(effects(),[]);
 core._oe2_qa_status(0,0,9);assert.deepEqual(effects(),[],'familiar energy hidden in human form');
 core._oe2_qa_status_familiar(1);assert.deepEqual(effects(),[{id:0,amount:0,turns:9}]);core._oe2_qa_status_familiar(0);
 core._oe2_qa_status(-1,0,0);
 core._oe2_qa_status(7,10,30);core._oe2_qa_status(6,-4,8);core._oe2_qa_status(10,-2,5);
 assert.deepEqual(effects(),[{id:6,amount:-4,turns:8},{id:7,amount:10,turns:30},{id:10,amount:-2,turns:5}]);
 const idle=effects();for(let i=0;i<25;i++)g.step(40);assert.deepEqual(effects(),idle,'clock ticks do not consume effect turns');
 core._oe2_qa_status_turn();assert.deepEqual(effects(),[{id:6,amount:-4,turns:7},{id:7,amount:10,turns:29},{id:10,amount:-2,turns:4}]);
 for(let i=0;i<4;i++)core._oe2_qa_status_turn();assert.ok(!effects().some(e=>e.id===10),'expired poison disappears');
 core._oe2_qa_status(-1,0,0);
 core._oe2_qa_status(7,10,30);core._oe2_qa_status(12,10,6);
 assert.deepEqual(effects(),[{id:6,amount:-15,turns:6},{id:7,amount:20,turns:6},{id:8,amount:10,turns:6}],'native compound effects aggregate stats and earliest expiry');
 for(let i=0;i<6;i++)core._oe2_qa_status_turn();assert.deepEqual(effects(),[{id:7,amount:10,turns:24}],'longer strength bonus remains after compound effect ends');
 assert.equal(Brew.save(),1);for(let i=0;i<10;i++)g.step(40);
 const saved=effects(),bytes=Buffer.from(Brew.testFile('SD_0'));
 for(let quality=0;quality<3;quality++){
  Brew.quality(quality);const before=Brew.json(),world=Buffer.from(Brew.image('world'));
  Brew.image('lit');assert.equal(Brew.json(),before);assert.deepEqual(Buffer.from(Brew.image('world')),world);assert.deepEqual(Buffer.from(Brew.testFile('SD_0')),bytes);
 }
 core._oe2_qa_status(-1,0,0);assert.deepEqual(effects(),[]);assert.equal(Brew.load(),1);
 for(let i=0;i<160;i++){const m=g.step(40);if([8,11,13].includes(m.state))Brew.key(0xe037);if(m.state===7)Brew.continueText();if(m.state===3&&m.map_id>0)break;}
 assert.deepEqual(effects(),saved,'save/load preserves native remaining turns');
 const result={positiveAndNegative:true,idleDoesNotTick:true,turnCounts:true,expiration:true,compound:true,familiar:true,saveLoad:true,pureQualityGetters:3};
 fs.writeFileSync(path.join(root,'build/status-effects-result.json'),JSON.stringify(result,null,2));console.log(JSON.stringify(result));
})().catch(error=>{console.error(error);process.exitCode=1;});
