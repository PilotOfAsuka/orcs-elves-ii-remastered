/* Uses a separate disposable Chrome profile and a loopback-only server.
 * No user's browser session, save origin or public assets are read/modified. */
const fs=require('node:fs'),path=require('node:path'),http=require('node:http'),{spawn}=require('node:child_process');
const root=path.resolve(__dirname,'..'),delay=ms=>new Promise(r=>setTimeout(r,ms));
(async()=>{
 const profile=fs.mkdtempSync(path.join(root,'build/gpu-chrome-')),errors=[],server=http.createServer((req,res)=>{
  const urlPath=decodeURI(new URL(req.url,'http://localhost').pathname);
  const file=path.resolve(root,'.'+urlPath+(urlPath.endsWith('/')?'index.html':''));if(!file.startsWith(root+path.sep)){res.writeHead(403);return res.end();}
  fs.readFile(file,(err,data)=>{if(err){res.writeHead(404);return res.end();}res.setHeader('Content-Type',({'.html':'text/html','.js':'text/javascript','.json':'application/json','.wasm':'application/wasm'})[path.extname(file)]||'application/octet-stream');res.setHeader('Cross-Origin-Opener-Policy','same-origin');res.setHeader('Cross-Origin-Embedder-Policy','require-corp');res.end(data);});
 });await new Promise(r=>server.listen(0,'127.0.0.1',r));
 const chrome=spawn('/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',['--headless=new','--no-first-run','--no-default-browser-check','--disable-background-networking','--disable-component-update','--disable-sync','--remote-debugging-port=0','--user-data-dir='+profile,'about:blank'],{stdio:'ignore'});
 let ws;try{
  const active=path.join(profile,'DevToolsActivePort');for(let i=0;i<200&&!fs.existsSync(active);i++)await delay(100);const [port,endpoint]=fs.readFileSync(active,'utf8').trim().split('\n');
  ws=new WebSocket('ws://127.0.0.1:'+port+endpoint);await new Promise((r,j)=>{ws.onopen=r;ws.onerror=j;});let id=0;const pending=new Map();
  ws.onmessage=event=>{const m=JSON.parse(event.data);if(m.id){const p=pending.get(m.id);pending.delete(m.id);m.error?p.reject(Error(JSON.stringify(m.error))):p.resolve(m.result);}else if(m.method==='Runtime.exceptionThrown')errors.push(m.params.exceptionDetails);else if(m.method==='Runtime.consoleAPICalled'&&m.params.type==='error')errors.push(m.params.args.map(a=>a.value||a.description));};
  const send=(method,params={},sessionId)=>new Promise((resolve,reject)=>{pending.set(++id,{resolve,reject});ws.send(JSON.stringify({id,method,params,sessionId}));});
  const {targetId}=await send('Target.createTarget',{url:'about:blank'}),{sessionId}=await send('Target.attachToTarget',{targetId,flatten:true});
  await send('Runtime.enable',{},sessionId);await send('Page.enable',{},sessionId);
  if(process.argv[2]==='ui'){
   const fixtures=JSON.parse(fs.readFileSync(path.join(root,'build/gpu-check/fixtures.json'))),rows=[];
   await send('Page.addScriptToEvaluateOnNewDocument',{source:`localStorage.setItem('oe2-brew-ui-language','en');localStorage.setItem('oe2-brew-graphics','remastered');localStorage.setItem('oe2-brew-debug','1');localStorage.setItem('oe2-brew-quality',new URLSearchParams(location.search).get('quality')||'1');localStorage.setItem('oe2-brew-light-processing-preset','high');`},sessionId);
   await send('Emulation.setDeviceMetricsOverride',{width:480,height:920,deviceScaleFactor:1,mobile:false},sessionId);
   const evaluate=async expression=>{const r=await send('Runtime.evaluate',{expression,returnByValue:true,awaitPromise:true},sessionId);if(r.exceptionDetails)throw Error(JSON.stringify(r.exceptionDetails));return r.result.value;};
   for(const quality of[1,2])for(const backend of['cpu','gpu']){
    await send('Page.navigate',{url:'http://127.0.0.1:'+server.address().port+'/build/gpu-preview/?quality='+quality+'&lighting='+backend},sessionId);
    let ready=false;for(let i=0;i<120;i++){await delay(500);if(await evaluate('!!window.Brew?.ready&&!!window.QACore')){ready=true;break;}}
    if(!ready)throw Error('Godot preview boot failed '+JSON.stringify(errors));
    const pose=fixtures.find(f=>f.id==='map2-q'+quality).parameters;
    const angle=(Math.round(Math.atan2(-pose[8],pose[7])*1024/(2*Math.PI))+1024)&1023;
    await evaluate(`(()=>{let stable=0;const model=()=>JSON.parse(Brew.json());for(let t=0;t<1600;t++){Brew.paused=false;Brew.advance(40);const s=model();if(s.state===2){const row=s.items.find(i=>/^(Yes|New Game|Normal|Start Game|Play)$/i.test(i.text.trim())&&!(i.flags&5));if(row)Brew.menu(s.menu_id,row.index);}else if([8,11,13].includes(s.state))Brew.key(0xe037);else if(s.state===7)Brew.continueText();if(s.state===3&&!s.cinematic_active){if(++stable>=8)break;}else stable=0;}QACore._oe2_qa_map(2);stable=0;for(let t=0;t<1600;t++){Brew.advance(40);const s=model();if(s.state===7)Brew.continueText();if([8,11,13].includes(s.state))Brew.key(0xe037);if(s.state===3&&!s.cinematic_active){if(++stable>=8)break;}else stable=0;}QACore._oe2_qa_light_view(${pose[9]},${pose[10]},${angle});return model().map_id;})()`);
    await delay(800);
    const stats=await evaluate(`new Promise(resolve=>{const times=[],preparation=[],core=[],render=[],start=performance.now();let last=start;function step(){const now=performance.now();times.push(now-last);last=now;preparation.push(Brew.presentationMs);core.push(Brew.tickMs);render.push(Brew.lightMs);if(times.length<100)requestAnimationFrame(step);else{const median=a=>a.sort((a,b)=>a-b)[Math.floor(a.length/2)];resolve({fps:100000/(now-start),prepareMs:median(preparation),coreMs:median(core),rendererMs:median(render),gpuActive:Brew.gpuActive,map:JSON.parse(Brew.json()).map_id});}}requestAnimationFrame(step);})`);
    if(stats.gpuActive!==(backend==='gpu')||stats.map!==2)throw Error('Godot GPU/CPU routing failed '+JSON.stringify(stats));
    if(backend==='gpu'){
     const poseBefore=await evaluate('(()=>{const s=JSON.parse(Brew.json());return [s.x,s.y,s.angle];})()');
     const toggle=async()=>{await send('Input.dispatchKeyEvent',{type:'keyDown',key:'F2',code:'F2',windowsVirtualKeyCode:113,nativeVirtualKeyCode:113},sessionId);await send('Input.dispatchKeyEvent',{type:'keyUp',key:'F2',code:'F2',windowsVirtualKeyCode:113,nativeVirtualKeyCode:113},sessionId);await delay(300);};
     await toggle();if(await evaluate('Brew.gpuActive'))throw Error('Classic retained the GPU material');
     await toggle();if(!await evaluate('Brew.gpuActive'))throw Error('Remastered did not restore GPU material');
     const poseAfter=await evaluate('(()=>{const s=JSON.parse(Brew.json());return [s.x,s.y,s.angle];})()');
     if(JSON.stringify(poseBefore)!==JSON.stringify(poseAfter))throw Error('Graphics toggle changed player position');
     stats.classicToggle=true;
    }
    const capture=await send('Page.captureScreenshot',{format:'png'},sessionId);fs.writeFileSync(path.join(root,'build/gpu-check/ui-'+backend+'-q'+quality+'.png'),Buffer.from(capture.data,'base64'));
    rows.push({quality,backend,...stats});
   }
   const result={ok:errors.length===0,rows,errors};fs.writeFileSync(path.join(root,'build/gpu-check/ui-report.json'),JSON.stringify(result,null,2));console.log(JSON.stringify(result,null,2));if(errors.length)process.exitCode=1;return;
  }
  await send('Page.navigate',{url:'http://127.0.0.1:'+server.address().port+'/tools/check_gpu_browser.html'},sessionId);
  let result;for(let i=0;i<120;i++){await delay(500);const r=await send('Runtime.evaluate',{expression:'window.gpuCheck',returnByValue:true},sessionId);if(r.result.value){result=r.result.value;break;}}
  if(!result)throw Error('GPU check timed out');fs.writeFileSync(path.join(root,'build/gpu-check/browser-report.json'),JSON.stringify({result,errors},null,2));
  const capture=await send('Page.captureScreenshot',{format:'png'},sessionId);fs.writeFileSync(path.join(root,'build/gpu-check/browser.png'),Buffer.from(capture.data,'base64'));
  console.log(JSON.stringify({result,errors},null,2));if(!result.ok||errors.length)process.exitCode=1;
 }finally{ws?.close();chrome.kill();server.close();}
})().catch(e=>{console.error(e);process.exitCode=1;});
