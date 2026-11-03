// Pure numeric comparisons with the portable oracle; no browser automation.
const fs=require('fs'),assert=require('assert/strict'),crypto=require('crypto');
const raster=require('../game/rendering/raster.js');
const fixture=JSON.parse(fs.readFileSync('build/web_weapon_cases.json'));
const base=raster.decode(fixture.base),texture=Int8Array.from(raster.decode(fixture.texture)),edges=raster.decode(fixture.edges);
let fast=0;
for(const c of fixture.cases){
 const pixels=base.slice(),result=raster.sprite2D(c.input,pixels,texture,edges);
 assert.ok(!result.unsupported,JSON.stringify(c.input));
 assert.equal(result.empty,c.value);
 assert.equal(crypto.createHash('sha256').update(Buffer.from(pixels.buffer).toString('hex')).digest('hex'),c.expected,JSON.stringify(c.input));
 fast++;
}
for(const bad of [{...fixture.cases[0].input,shape:-1}]){
 const pixels=base.slice();
 assert.equal(raster.sprite2D(bad,pixels,texture,edges).unsupported,true);
 assert.deepEqual(pixels,base,'unsupported geometry must leave pixels untouched');
}
console.log(JSON.stringify({comparisons:fast,passed:true}));
