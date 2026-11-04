const path=require('node:path'),assert=require('node:assert/strict');
const root=path.resolve(__dirname,'..');process.chdir(path.join(root,'build/web'));
globalThis.createBrewModule=require(path.join(root,'build/web/brew-core.js'));
require(path.join(root,'web/runtime.js'));
(async()=>{
  await Brew.init({persist:false,seed:1});let intro=false;
  for(let tick=0;tick<1200;tick++){
    Brew.advance(40);const s=JSON.parse(Brew.json());
    if(s.state===2){
      const row=s.items.find(i=>/^(No|New Game|Normal|Start Game|Play)$/i.test(i.text.trim())&&!(i.flags&5));
      if(row)Brew.menu(s.menu_id,row.index);
    }else if([8,11,13].includes(s.state))Brew.key(0xe037);
    else if(s.state===7){
      Brew.continueText();const after=JSON.parse(Brew.json());
      assert.ok(after.state!==7||after.dialogue!==s.dialogue,'one Continue consumes the native typing and pages');
      assert.equal(after.ticks,s.ticks,'Continue does not advance simulation time');intro=true;
    }else if(s.state===3&&intro&&!s.cinematic_active){
      Brew.action(11);Brew.advance(40);const tutorial=JSON.parse(Brew.json());
      assert.equal(tutorial.state,7,'first dagger selection opens its original tutorial');
      assert.match(tutorial.dialogue,/This magic dagger/);
      assert.ok(tutorial.dialog_lines>tutorial.dialog_view,'exercise multiple native pages');
      Brew.continueText();const after=JSON.parse(Brew.json());
      assert.equal(after.state,3,'one Continue closes the entire weapon tutorial');
      assert.equal(after.ticks,tutorial.ticks);assert.equal(after.x,tutorial.x);assert.equal(after.y,tutorial.y);
      assert.equal(after.hud.health,tutorial.hud.health);
      console.log('Intro and multi-page dagger tutorial continue in one click, without advancing time or moving the player');return;
    }
  }
  throw new Error('Dialogue fixture not reached');
})().catch(e=>{console.error(e);process.exitCode=1;});
