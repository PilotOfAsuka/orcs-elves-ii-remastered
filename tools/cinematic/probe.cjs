const {boot}=require('./common.cjs');
(async()=>{const g=await boot();for(let i=0;i<22;i++){
 let s=g.model();console.log(JSON.stringify({i,x:s.x,y:s.y,a:s.angle,state:s.state,hp:s.hud.health,ctx:s.hud.context,target:s.hud.target_health,notice:s.hud.notices}));
 if(s.state===7)g.Brew.continueText();else g.Brew.action(1);
 for(let j=0;j<12;j++)g.step(40);
}})().catch(e=>{console.error(e);process.exitCode=1;});
