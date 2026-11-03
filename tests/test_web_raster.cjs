// Pure arithmetic tests; does not launch or automate a browser.
const fs=require('fs'),assert=require('assert/strict');
const raster=require('../game/rendering/raster.js');
const cases=JSON.parse(fs.readFileSync('build/web_raster_cases.json'));
for(const c of cases) {
 const actual=raster.encode(raster.render(raster.decode(c.base),raster.decode(c.texture),raster.decode(c.commands)));
 assert.equal(actual,c.expected,`mode ${c.mode}, count ${c.count}, sign ${c.sign}`);
}
console.log(JSON.stringify({comparisons:cases.length,passed:true}));
