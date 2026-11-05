const path=require('node:path'),fs=require('node:fs'),crypto=require('node:crypto');
const root=path.resolve(__dirname,'../..'),out=path.join(root,'build/cinematic');
async function boot({audio=false,coreDirectory=path.join(out,'core')}={}){
  process.chdir(coreDirectory);let core,clock=0;const clips={},events=[],channels=new Map(),gains=new Map();
  const factory=require(path.join(coreDirectory,'brew-core.js'));
  globalThis.createBrewModule=async options=>(core=await factory(options));
  require(path.join(root,'web/runtime.js'));
  const sound=globalThis.BrewAudio;
  sound.stop=channel=>{if(channels.has(channel)){events.push({kind:'stop',channel,ms:clock});channels.delete(channel);}};
  sound.play=(channel,pointer,samples,rate,loops)=>{
    sound.stop(channel);const pcm=Buffer.from(core.HEAPU8.subarray(pointer,pointer+samples*2));
    const id=crypto.createHash('sha256').update(pcm).digest('hex').slice(0,16);
    if(audio&&!clips[id]){fs.mkdirSync(path.join(out,'audio'),{recursive:true});fs.writeFileSync(path.join(out,'audio',id+'.pcm'),pcm);}
    clips[id]={samples,rate};const event={kind:'play',channel,ms:clock,id,rate,samples,loops,gain:gains.get(channel)??1};
    events.push(event);channels.set(channel,event);
  };
  sound.playing=channel=>{const item=channels.get(channel);return !!item&&(item.loops<0||clock-item.ms<item.samples*1000/item.rate);};
  sound.volume=(channel,value)=>{gains.set(channel,Math.max(0,Math.min(1,value/100)));events.push({kind:'volume',channel,ms:clock,gain:gains.get(channel)});};
  const model=()=>JSON.parse(Brew.json());
  const step=ms=>{clock+=ms;Brew.advance(ms);return model();};
  await Brew.init({persist:false,seed:7});
  let stable=0;
  for(let tick=0;tick<1600;tick++){
    const s=step(40);
    if(s.state===2){const row=s.items.find(i=>/^(Yes|New Game|Normal|Start Game|Play)$/i.test(i.text.trim())&&!(i.flags&5));if(row)Brew.menu(s.menu_id,row.index);}
    else if([8,11,13].includes(s.state))Brew.key(0xe037);
    else if(s.state===7)Brew.continueText();
    if(s.state===3&&!s.cinematic_active){if(++stable>=8)return {Brew,core,model,step,events,clips,channels,get clock(){return clock;},root,out};}else stable=0;
  }
  throw new Error('First dungeon did not become ready');
}
module.exports={boot,root,out};
module.exports.settle=async function(game){
  game.Brew.action(1);
  for(let i=0;i<250;i++){
    const s=game.step(40);if(s.state===7)game.Brew.continueText();
  }
  if(game.model().state!==3)throw new Error('Opening cave-in did not settle');
};
