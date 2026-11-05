const assert=require('node:assert/strict');
const {boot,root}=require('./cinematic/common.cjs');
const path=require('node:path');
(async()=>{
 const g=await boot({coreDirectory:path.join(root,'build/web')}),{Brew}=g;
 assert.equal(Brew.save(),1);for(let i=0;i<10;i++)g.step(40);
 let exported;globalThis.BrewAndroid={saveBackup:(name,text)=>{exported={name,text};}};
 await Brew.exportSave();assert.ok(exported.name.endsWith('.json'));
 const pack=JSON.parse(exported.text);assert.equal(pack.format,'orcs-elves-ii-brew-save');assert.ok(pack.files.Config&&pack.files.SD_0);
 const original=Buffer.from(Brew.testFile('SD_0'));await Brew.restoreBackup(exported.text,{load:false});assert.deepEqual(Buffer.from(Brew.testFile('SD_0')),original);
 const memory=new Map();globalThis.localStorage={getItem:key=>memory.get(key)??null,setItem:(key,value)=>memory.set(key,String(value))};
 const state=Brew.json();assert.equal(Brew.savedDebug(),false);Brew.debug(true);assert.equal(Brew.savedDebug(),true);Brew.debug(false);assert.equal(Brew.savedDebug(),false);assert.equal(Brew.json(),state);
 assert.equal(Brew.savedLightDistance(),4);
 for(const [old,steps]of[[125,4],[150,4],[250,7],[500,10]]){memory.set('oe2-brew-light-distance',String(old));assert.equal(Brew.savedLightDistance(),steps,'old setting migrates by preset name');}
 for(const steps of[4,7,10]){Brew.lightDistance(steps);assert.equal(Brew.savedLightDistance(),steps);}
 Brew.lightDistance(999);assert.equal(Brew.savedLightDistance(),10);Brew.lightDistance(0);assert.equal(Brew.savedLightDistance(),4);assert.equal(Brew.json(),state);
 console.log('Android save bridge, checksum round trip and persisted debug preference passed');
})().catch(error=>{console.error(error);process.exitCode=1;});
