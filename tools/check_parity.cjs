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
  let checks=0,lastStory=-100;const menus=new Set(),states=new Set(),events=[];
  async function check(command, apply) {
    apply();const expected=await native(command), model=JSON.parse(Brew.json());
    assert.deepEqual(model,expected.model,`state mismatch after ${command}, tick ${model.ticks}`);
    assert.equal(crc(Brew.image('frame')),expected.screen_crc,`screen mismatch at ${model.ticks}`);
    assert.equal(crc(Brew.image('world')),expected.world_crc,`world mismatch at ${model.ticks}`);
    checks++;states.add(model.state);return model;
  }
  try {
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
    const result={checks,ticks:JSON.parse(Brew.json()).ticks,states:[...states].sort((a,b)=>a-b),screen:'exact RGBA CRC32 parity',world:'exact RGBA CRC32 parity',saveFiles:files,saveBytes:'exact binary parity',final:JSON.parse(Brew.json()),events};
    fs.writeFileSync(path.join(root,'build/parity-result.json'),JSON.stringify(result,null,2));
    console.log(JSON.stringify({...result,events:events.length,final:{state:result.final.state,map:result.final.map_id,hp:result.final.hud.health}},null,2));
  } finally {child.stdin.end('q\n');fs.writeFileSync(path.join(root,'build/parity-native.log'),stderr);}
})().catch(e=>{console.error(e);process.exitCode=1;});
