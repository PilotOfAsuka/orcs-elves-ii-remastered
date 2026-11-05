/* Real native movement/turn input in disposable Dwarkar games, with AI disabled
 * to isolate renderer timing. This is not a combat/full-game playthrough. */
const {boot,root}=require('./cinematic/common.cjs'),path=require('node:path'),fs=require('node:fs'),assert=require('node:assert/strict');
const median=a=>[...a].sort((a,b)=>a-b)[Math.floor(a.length/2)];
const backend=process.argv[2]||'gpu';assert.ok(['cpu','gpu'].includes(backend));
(async()=>{
 const g=await boot({coreDirectory:path.join(root,'build/qa-core')}),{Brew,core}=g,rows=[];
 for(const quality of[1,2]){
  core._oe2_qa_map(2);let stable=0;for(let t=0;t<1600;t++){const s=g.step(40);if(s.state===7)Brew.continueText();if([8,11,13].includes(s.state))Brew.key(0xe037);if(s.state===3&&!s.cinematic_active){if(++stable>8)break;}else stable=0;}
  let s=g.model();core._oe2_qa_light_view(s.x,s.y,s.angle);Brew.quality(quality);Brew.lightDistance(20);
  const visits=new Map(),times=[],trace=[];let moved=0,blocked=0,frames=0;
  const advance=()=>{const s=g.step(40);if(s.state===7)Brew.continueText();if([8,11,13,17].includes(s.state))Brew.key(0xe037);const before=Brew.json(),classic=Buffer.from(Brew.image('world'));Brew.image(backend==='gpu'?'gpu':'lit');times.push(Brew.lightMs);assert.equal(Brew.json(),before);assert.deepEqual(Buffer.from(Brew.image('world')),classic);frames++;};
  const settle=()=>{for(let t=0;t<250&&(g.model().state!==3||g.model().cinematic_active);t++)advance();};
  for(let turn=0;turn<24;turn++){
   s=g.model();assert.equal(s.map_id,2);const cx=Math.floor(s.x/64),cy=Math.floor(s.y/64),key=[cx,cy].join(',');visits.set(key,(visits.get(key)||0)+1);
   const options=[[1,0,0],[0,-1,256],[-1,0,512],[0,1,768]].filter(([dx,dy])=>core._oe2_qa_light_floor(cx+dx,cy+dy)&&core._oe2_qa_light_clear(s.x,s.y,s.x+dx*64,s.y+dy*64));
   options.sort((a,b)=>(visits.get([cx+a[0],cy+a[1]].join(','))||0)-(visits.get([cx+b[0],cy+b[1]].join(','))||0));if(!options.length)break;
   const [dx,dy,angle]=options[0];
   for(let t=0;t<4&&(g.model().angle&1023)!==angle;t++){Brew.action(3);for(let n=0;n<10;n++)advance();settle();}
   s=g.model();assert.equal(s.angle&1023,angle,'native turn reaches the requested direction');
   const before=[s.x,s.y];Brew.action(1);for(let n=0;n<16;n++)advance();settle();s=g.model();
   if(s.x!==before[0]||s.y!==before[1])moved++;else{blocked++;visits.set([cx+dx,cy+dy].join(','),100+turn);}
   trace.push({x:s.x,y:s.y,angle:s.angle,state:s.state});
  }
  assert.ok(moved>=8,`only ${moved} actual movement steps`);const ordered=[...times].sort((a,b)=>a-b);const row={map:2,backend,quality,moved,blocked,visited:visits.size,frames,prepareMs:median(times),p95Ms:ordered[Math.floor(ordered.length*.95)],trace};rows.push(row);console.log(JSON.stringify({...row,trace:undefined}));
 }
 fs.writeFileSync(path.join(root,`build/gpu-check/walk-${backend}-report.json`),JSON.stringify({rows,pure:true},null,2));
 if(backend==='gpu'){
  const other=path.join(root,'build/gpu-check/walk-cpu-report.json');
  if(fs.existsSync(other)){const cpu=JSON.parse(fs.readFileSync(other));for(const row of rows)assert.deepEqual(row.trace,cpu.rows.find(r=>r.quality===row.quality).trace,'same native walk and events in both backends');}
 }
})().catch(e=>{console.error(e);process.exitCode=1;});
