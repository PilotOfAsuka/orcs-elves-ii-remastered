const {boot,settle}=require('./common.cjs'),png=require('./png.cjs'),fs=require('node:fs'),path=require('node:path');
(async()=>{const g=await boot();await settle(g);g.Brew.action(12);for(let i=0;i<15;i++)g.step(40);g.Brew.quality(2);
const shots=[['campfire',1120,1600,36,768],['corridor',256,1632,32,0],['torch',480,1312,34,768],['orcs',1312,1312,34,896],['meat',800,1152,36,768],['vault',608,1888,36,768]];
for(const [name,x,y,z,a]of shots){g.core._oe2_film_view(x,y,z,a);const raw=g.Brew.image('lit');fs.writeFileSync(path.join(g.out,name+'.png'),png(raw,704,656));g.core._oe2_film_restore();}
console.log('Saved six actual High-rendered camera views');
})().catch(e=>{console.error(e);process.exitCode=1;});
