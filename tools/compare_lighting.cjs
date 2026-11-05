const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const root=path.resolve(__dirname,'..'),base=path.join(root,'build/lighting-bench',process.argv[3]||'baseline'),target=path.join(root,'build/lighting-bench',process.argv[2]||'after');
const before=JSON.parse(fs.readFileSync(path.join(base,'report.json'))),after=JSON.parse(fs.readFileSync(path.join(target,'report.json'))),results=[];
for(const b of before){
 const a=after.find(row=>row.map===b.map&&row.reach===b.reach&&row.quality===b.quality);assert.ok(a,'matching scene/quality/reach');const name=`map${a.map}-r${a.reach}-q${a.quality}.rgba`,x=fs.readFileSync(path.join(base,name)),y=fs.readFileSync(path.join(target,name));assert.equal(x.length,y.length);
 let max=0,squared=0,changed=0,over1=0;for(let j=0;j<x.length;j++){if(j%4===3){assert.equal(x[j],y[j]);continue;}const d=Math.abs(x[j]-y[j]);max=Math.max(max,d);squared+=d*d;changed+=d>0;over1+=d>1;}
 const rmse=Math.sqrt(squared/(x.length*.75));results.push({map:a.map,reach:a.reach,quality:a.quality,beforeMs:b.warmMs,afterMs:a.warmMs,speedup:b.warmMs/a.warmMs,motionBeforeMs:b.motionMs,motionAfterMs:a.motionMs,rgbMax:max,rmse,changedPercent:changed/(x.length*.75)*100,overOnePercent:over1/(x.length*.75)*100});
}
fs.writeFileSync(path.join(target,'comparison.json'),JSON.stringify(results,null,2));console.log(JSON.stringify(results.filter(r=>r.quality===2),null,2));
