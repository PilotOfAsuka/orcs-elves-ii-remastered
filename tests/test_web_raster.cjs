// Pure arithmetic tests; does not launch or automate a browser.
const fs=require('fs'),assert=require('assert/strict');
const raster=require('../game/rendering/raster.js');
const cases=JSON.parse(fs.readFileSync('build/web_raster_cases.json'));
for(const c of cases) {
 const actual=raster.encode(raster.render(raster.decode(c.base),raster.decode(c.texture),raster.decode(c.commands)));
 assert.equal(actual,c.expected,`mode ${c.mode}, count ${c.count}, sign ${c.sign}`);
 const bytes=Int8Array.from(raster.decode(c.texture));
 const compact=raster.decodeTexels(Buffer.from(bytes.buffer).toString('base64'));
 assert.equal(raster.encode(raster.render(raster.decode(c.base),compact,raster.decode(c.commands))),c.expected,'byte texture '+c.mode);
}
// Presentation must preserve the pending Java ARGB buffer across frames.
const imageCase=cases.find(c=>c.mode===0&&c.count>0);
raster.texels=raster.decode(imageCase.texture);
raster.start(imageCase.base);raster.feed(imageCase.commands);
const argbBefore=raster.encode(raster.pixels),rgba=raster.decode(raster.preview());
assert.equal(argbBefore,imageCase.expected);
assert.equal(raster.encode(raster.pixels),argbBefore);
for(let i=0;i<rgba.length;i++) {
 const p=raster.pixels[i];
 assert.equal(rgba[i],(0xff000000|((p&255)<<16)|(p&0xff00)|((p>>>16)&255)));
}
raster.feed(imageCase.commands);
assert.equal(raster.readback(),raster.encode(raster.render(raster.decode(imageCase.expected),raster.texels,raster.decode(imageCase.commands))));
assert.equal(raster.pixels,null);
raster.start(imageCase.base);raster.feed(imageCase.commands);
const directRGBA=raster.rgba();
assert.ok(directRGBA instanceof Uint8Array);
assert.deepEqual(directRGBA,new Uint8Array(rgba.buffer));
assert.equal(raster.encode(new Int32Array(raster.readbackBytes().buffer)),imageCase.expected);
raster.start(imageCase.base);raster.feed(imageCase.commands);
const pair=raster.finishBytes();
assert.equal(raster.encode(new Int32Array(pair.buffer,0,pair.byteLength/8)),imageCase.expected);
assert.deepEqual(pair.subarray(pair.byteLength/2),directRGBA);
assert.equal(raster.pixels,null);
console.log(JSON.stringify({comparisons:cases.length,passed:true}));
