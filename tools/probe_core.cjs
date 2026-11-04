const path = require('node:path');
const root = path.resolve(__dirname, '..');
process.chdir(path.join(root,'build/web'));
globalThis.createBrewModule = require(path.join(root, 'build/web/brew-core.js'));
require(path.join(root, 'web/runtime.js'));
(async () => {
  await Brew.init({persist:false});
  let last = '', storyAt = -100;
  const choices = new Set();
  for (let t=0;t<1200;t++) {
    Brew.advance(40);
    const s=JSON.parse(Brew.json()), key=`${s.state}:${s.menu_id}`;
    if (last!==key) { console.log(t, key, s.items.map(i=>`${i.index}:${i.text}`).join(' / '), `world=${s.world_width}x${s.world_height}`, `hp=${s.hud.health}`,`pos=${s.x},${s.y}`); last=key; }
    if (s.state===2 && !choices.has(s.menu_id)) {
      let row=s.items.find(i=>/^(Yes|New Game|Normal|Start Game|Play)$/i.test(i.text.trim()) && !(i.flags&5));
      if (!row) row=s.items.find(i=>!(i.flags&5));
      if (row) { choices.add(s.menu_id); console.log('choose',s.menu_id,row.index,row.text); Brew.menu(s.menu_id,row.index); }
    }
    if ([8,11,13].includes(s.state) && t-storyAt>=10) { Brew.key(0xe037);storyAt=t; }
    if (s.state===7 && t%10===0) Brew.key(0xe035);
    if (s.state===3 && t%10===0) Brew.action(1);
    if (s.fatal) throw new Error('BREW fatal');
  }
  const s=JSON.parse(Brew.json());
  console.log('END',JSON.stringify(s).slice(0,1000));
})().catch(e=>{console.error(e);process.exitCode=1});
