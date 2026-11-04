const path=require('node:path'), fs=require('node:fs'), {spawn}=require('node:child_process'), readline=require('node:readline'), assert=require('node:assert/strict');
const root=path.resolve(__dirname,'..');
process.chdir(path.join(root,'build/web'));
globalThis.createBrewModule=require('./../build/web/brew-core.js');
require(path.join(root,'web/runtime.js'));
const crcTable=Uint32Array.from({length:256},(_,n)=>{for(let k=0;k<8;k++) n=n&1?0xedb88320^(n>>>1):n>>>1;return n>>>0;});
function crc(bytes){let n=0xffffffff;for(const b of bytes)n=crcTable[(n^b)&255]^(n>>>8);return(n^0xffffffff)>>>0;}
(async()=>{
  const dir=fs.mkdtempSync(path.join(root,'build/qa-native-'));
  for(const file of ['orcsandelves2.mod','orcsandelves2.bar'])fs.copyFileSync(path.join(root,'gamedata',file),path.join(dir,file));
  const child=spawn(path.join(root,'build/qa_driver'),[dir],{env:{...process.env,SDL_VIDEODRIVER:'dummy',SDL_AUDIODRIVER:'dummy'}});
  const lines=readline.createInterface({input:child.stdout}), queue=[];let waiting;
  lines.on('line',line=>{if(!line.startsWith('{'))return;if(waiting){let resolve=waiting;waiting=null;resolve(JSON.parse(line));}else queue.push(JSON.parse(line));});
  let stderr='';child.stderr.on('data',s=>stderr+=s);
  child.on('error',e=>{throw e;});
  async function native(command){child.stdin.write(command+'\n');return queue.length?queue.shift():new Promise(resolve=>waiting=resolve);}
  await Brew.init({persist:false,seed:1});
  let checks=0,lastStory=-100;const menus=new Set(),states=new Set(),events=[],cinemaFrames=new Set(),lightFrames=[],textSamples=new Set();
  function collectText(value,field=''){
    if(Array.isArray(value))value.forEach(v=>collectText(v,field));
    else if(value&&typeof value==='object')Object.entries(value).forEach(([k,v])=>collectText(v,k));
    else if(typeof value==='string'&&value&&['text','help','value','dialogue','left','right','context','notices','cinematic','weapon_name','name','travel_name','stats'].includes(field))textSamples.add(value);
  }
  async function check(command, apply) {
    apply();const expected=await native(command), model=JSON.parse(Brew.json());
    collectText(model);
    assert.deepEqual(model,expected.model,`state mismatch after ${command}, tick ${model.ticks}`);
    assert.equal(crc(Brew.image('frame')),expected.screen_crc,`screen mismatch at ${model.ticks}`);
    assert.equal(crc(Brew.image('world')),expected.world_crc,`world mismatch at ${model.ticks}`);
    if(model.cinematic_active)cinemaFrames.add(crc(Brew.image('world')));
    if(model.world_width>0&&[3,7,17].includes(model.state)){Brew.image('lit');lightFrames.push(Brew.lightMs);}
    if(model.world_width===176&&[3,7,17].includes(model.state)&&checks%300===0){Brew.quality(2);assert.equal(Brew.image('lit').length,704*656*4);Brew.quality(0);}
    checks++;states.add(model.state);return model;
  }
  try {
    assert.deepEqual(await native('v'),{blocked:1,parallel:1,above:1,open:1,silhouette:1,transparent:1,moved:1,hidden:1,campfire:1,meatTaken:1,upper:1,below:1,contact:1},'geometric shadow rays: wall, parallel, above and opened door');
    for(let t=0;t<1000;t++) {
      const s=await check('t',()=>Brew.advance(40));
      let command;
      if(s.state===2 && !menus.has(s.menu_id)) {
        let row=s.items.find(i=>/^(No|New Game|Normal|Start Game|Play)$/i.test(i.text.trim())&&!(i.flags&5))||s.items.find(i=>!(i.flags&5));
        if(row){menus.add(s.menu_id);command=`m${s.menu_id} ${row.index}`;await check(command,()=>Brew.menu(s.menu_id,row.index));}
      }
      if([8,11,13].includes(s.state)&&t-lastStory>=10){command='k57399';await check(command,()=>Brew.key(0xe037));lastStory=t;}
      if(s.state===7&&t%10===0){command='k57397';await check(command,()=>Brew.key(0xe035));}
      if(s.state===3&&t%10===0){const action=t>550?(t%40===0?3:1):1;command=`a${action}`;await check(command,()=>Brew.action(action));}
      if(command)events.push({tick:t,command});
    }
    for(let t=0;t<10;t++)await check('t',()=>Brew.advance(40));
    await check('a7',()=>Brew.action(7));
    for(let t=0;t<5;t++)await check('t',()=>Brew.advance(40));
    assert.equal(JSON.parse(Brew.json()).state,5,'map opened');
    await check('a7',()=>Brew.action(7));
    for(let t=0;t<5;t++)await check('t',()=>Brew.advance(40));
    await check('s',()=>Brew.save());
    for(let t=0;t<8;t++)await check('t',()=>Brew.advance(40));
    const files=fs.readdirSync(dir).filter(name=>name.startsWith('SD_'));
    assert.ok(files.includes('SD_0'),'player save exists');
    assert.ok(files.length>=2,'world save exists');
    for(const name of files)assert.deepEqual(Buffer.from(Brew.testFile(name)),fs.readFileSync(path.join(dir,name)),`save parity ${name}`);
    await check('a3',()=>Brew.action(3));
    for(let t=0;t<10;t++)await check('t',()=>Brew.advance(40));
    await check('l',()=>Brew.load());
    for(let t=0;t<10;t++)await check('t',()=>Brew.advance(40));
    await check('k57399',()=>Brew.key(0xe037));
    for(let t=0;t<10;t++)await check('t',()=>Brew.advance(40));
    assert.ok([3,7].includes(JSON.parse(Brew.json()).state),'saved level resumed');
    assert.ok(cinemaFrames.size>8,`cinematic must display moving frames: ${cinemaFrames.size}`);
    const archive=await Brew.backupData(),savedPlayer=Buffer.from(Brew.testFile('SD_0'));
    const damaged=JSON.parse(archive);damaged.files.SD_0.sha256='0'.repeat(64);
    await assert.rejects(()=>Brew.restoreBackup(JSON.stringify(damaged),{load:false}),/checksum/);
    assert.deepEqual(Buffer.from(Brew.testFile('SD_0')),savedPlayer,'rejected backup leaves save intact');
    Brew.testWriteFile('SD_0',Uint8Array.of(1,2,3));
    await Brew.restoreBackup(archive,{load:false});
    assert.deepEqual(Buffer.from(Brew.testFile('SD_0')),savedPlayer,'backup restores exact binary save');
    const parityModel=JSON.parse(Brew.json()),replayTicks=parityModel.ticks;
    for(let i=0;i<15&&JSON.parse(Brew.json()).hud.weapon!==1;i++){Brew.action(12);for(let j=0;j<12;j++)Brew.advance(40);}
    assert.equal(JSON.parse(Brew.json()).hud.weapon,1,'staff test fixture');
    const weaponBottom=Brew.testWeaponBottom();
    const before=Brew.json(),classic=Buffer.from(Brew.image('world')),saves=files.map(n=>Buffer.from(Brew.testFile(n)));
    const times=[];let lit;
    for(let i=0;i<20;i++){lit=Buffer.from(Brew.image('lit'));times.push(Brew.lightMs);}
    assert.equal(Brew.json(),before,'lighting cannot mutate simulation');
    assert.deepEqual(Buffer.from(Brew.image('world')),classic,'Classic remains untouched');
    files.forEach((n,i)=>assert.deepEqual(Buffer.from(Brew.testFile(n)),saves[i],'lighting cannot mutate saves'));
    assert.notDeepEqual(lit,classic,'Remastered has a visible lighting pass');
    fs.writeFileSync(path.join(root,'build/lighting-classic.rgba'),classic);
    fs.writeFileSync(path.join(root,'build/lighting-remastered.rgba'),lit);
    const staff={originalBottom:weaponBottom,viewportHeight:JSON.parse(before).world_height,offset:JSON.parse(before).world_height-1-weaponBottom};
    const lighting={staff,firstMs:times[0],warmMeanMs:times.slice(1).reduce((a,b)=>a+b,0)/19,maxMs:Math.max(...times),width:JSON.parse(before).world_width,height:JSON.parse(before).world_height};
    lighting.qualities=[];
    for(let level=0;level<3;level++){
      Brew.quality(level);let image;
      const measurements=[];for(let i=0;i<3;i++){image=Buffer.from(Brew.image('lit'));measurements.push(Brew.lightMs);}
      assert.equal(image.length,176*164*4*(4**level),`actual render buffer at quality ${level}`);
      assert.equal(Brew.json(),before,`quality ${level} cannot mutate model`);
      assert.deepEqual(Buffer.from(Brew.image('world')),classic,`quality ${level} cannot mutate canonical world`);
      files.forEach((n,i)=>assert.deepEqual(Buffer.from(Brew.testFile(n)),saves[i],`quality ${level} cannot mutate saves`));
      fs.writeFileSync(path.join(root,`build/lighting-quality-${level}.rgba`),image);
      lighting.qualities.push({level,width:176*(2**level),height:164*(2**level),meanMs:measurements.reduce((a,b)=>a+b,0)/3,maxMs:Math.max(...measurements)});
    }
    Brew.action(5);for(let i=0;i<4;i++)Brew.advance(40);
    const menuState=JSON.parse(Brew.json());assert.equal(menuState.state,2,'quality menu fixture');
    assert.equal(Brew.image('lit').length,menuState.world_width*menuState.world_height*16*4,'High supports menu backdrop geometry');
    Brew.quality(0);
    const samples=[...lightFrames].sort((a,b)=>a-b);lighting.replay={frames:samples.length,meanMs:samples.reduce((a,b)=>a+b,0)/samples.length,p95Ms:samples[Math.floor(samples.length*.95)],maxMs:samples.at(-1)};
    const result={lighting,cinematicUniqueFrames:cinemaFrames.size,checks,ticks:replayTicks,fixtureTicks:JSON.parse(Brew.json()).ticks-replayTicks,states:[...states].sort((a,b)=>a-b),screen:'exact RGBA CRC32 parity',world:'exact RGBA CRC32 parity',saveFiles:files,saveBytes:'exact binary parity',final:parityModel,events};
    fs.writeFileSync(path.join(root,'build/parity-result.json'),JSON.stringify(result,null,2));
    fs.writeFileSync(path.join(root,'build/ui-text-samples.json'),JSON.stringify([...textSamples],null,2));
    console.log(JSON.stringify({...result,events:events.length,final:{state:result.final.state,map:result.final.map_id,hp:result.final.hud.health}},null,2));
  } finally {child.stdin.end('q\n');fs.writeFileSync(path.join(root,'build/parity-native.log'),stderr);}
})().catch(e=>{console.error(e);process.exitCode=1;});
