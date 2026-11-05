/* Native ARM anchor reference, isolated original layers, no persistent saves. */
const assert=require('node:assert/strict'),path=require('node:path'),fs=require('node:fs'),crypto=require('node:crypto');
const{boot,root}=require('./cinematic/common.cjs');
const label=process.argv[2]||'after',directory=process.argv[3]||'build/qa-core',verify=!label.startsWith('before'),isolated=process.argv[4]!=='scene';
(async()=>{
 const mod=fs.readFileSync(path.join(root,'gamedata/orcsandelves2.mod'));
 assert.equal(mod.readUInt32LE(0x130f0),0xe2421013,'original ARM subtracts 19 directly from weapon-space x');
 assert.equal(mod.readUInt32LE(0x13110),0xe241100d,'original ARM flame y offset is -13');
 const g=await boot({coreDirectory:path.join(root,directory)}),{Brew,core}=g,out=path.join(root,'build/sword-alignment',label);fs.mkdirSync(out,{recursive:true});
 const report=[];
 for(let attack=0;attack<2;attack++)for(let phase=0;phase<4;phase++)for(let quality=0;quality<3;quality++){
  Brew.quality(quality);core._oe2_qa_sword_pose(attack,phase,isolated?1:0);
  const commands=[0,1].map(n=>Array.from({length:8},(_,field)=>core._oe2_qa_weapon_command(n,field)));
  assert.equal(core._oe2_qa_weapon_command(2,0),-1,'only original body and fire layers');
  const body=commands[0],fire=commands[1],scale=352,scaled=x=>(Math.imul(scale,x<<8)+0xff00)>>16;
  const wx=mod.readInt16LE(0x4613c+7*8+(attack?4:0)),wy=mod.readInt16LE(0x4613c+7*8+(attack?6:2))-64;
  const bx=88+scaled(wx-32),by=164-scaled(64-wy),expectedX=attack?bx:88+scaled(wx-19),expectedY=attack?by:164-scaled(64-(wy-13));
  assert.equal(body[0],8);assert.equal(body[1],attack?1:0);assert.equal(body[2],bx);assert.equal(body[3],by);
  assert.equal(fire[0],8);assert.equal(fire[1],attack?6:phase+2);assert.equal(fire[3],expectedY);assert.equal(fire[4],4,'original additive flame');
  if(verify)assert.equal(fire[2],expectedX,'flame uses the original ARM anchor, without a second -32');
  const state=Brew.json(),classic=Buffer.from(Brew.image('world')),lit=Buffer.from(Brew.image('lit'));assert.equal(Brew.json(),state);
  assert.equal(lit.length,176*164*4*4**quality);assert.deepEqual(Buffer.from(Brew.image('world')),classic);
  const name=`${attack?'attack':'idle'}-${phase}-q${quality}`;
  if(quality===0)fs.writeFileSync(path.join(out,name+'.rgba'),classic);
  fs.writeFileSync(path.join(out,name+'-lit.rgba'),lit);
  report.push({attack,phase,quality,body:{x:body[2],y:body[3]},fire:{x:fire[2],y:fire[3]},expectedFire:{x:expectedX,y:expectedY},frame:fire[1],classicSha256:crypto.createHash('sha256').update(classic).digest('hex')});
 }
 fs.writeFileSync(path.join(out,'report.json'),JSON.stringify(report,null,2));console.log(JSON.stringify({cases:report.length,nativeArmAligned:report.every(r=>r.fire.x===r.expectedFire.x&&r.fire.y===r.expectedFire.y),pure:true}));
})().catch(e=>{console.error(e);process.exitCode=1;});
