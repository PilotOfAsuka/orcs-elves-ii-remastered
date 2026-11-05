const assert=require('node:assert/strict'),path=require('node:path'),fs=require('node:fs');
const{boot,root}=require('./cinematic/common.cjs');
(async()=>{
 const g=await boot({coreDirectory:path.join(root,'build/qa-core')}),{Brew,core}=g,m=()=>JSON.parse(Brew.json());
 const select=(index)=>{const s=m();Brew.menu(s.menu_id,index);for(let i=0;i<3;i++)g.step(40);return m();};
 const before=m();Brew.inventory();assert.equal(m().menu_id,501,'top backpack opens the items directly');
 for(let tab=0;tab<4;tab++){Brew.inventoryTab(tab);assert.equal(m().menu_id,501+tab);}
 Brew.closeInventory();assert.equal(m().state,3);Brew.inventory();Brew.key(0xe036);assert.equal(m().state,3,"Escape/Android Back exits inventory directly");assert.equal(m().x,before.x);assert.equal(m().y,before.y);
 core._oe2_qa_menu(303);core._oe2_qa_gold(5000);
 let s=m();const row=s.items.find(i=>(i.flags&0x20)&&!(i.flags&5));assert.ok(row,'stock item exists');
 const price=Number(row.value.trim());s=select(row.index);assert.equal(s.menu_id,309);
 Brew.tradeOffer(0);assert.equal(m().menu_id,312,'zero offer is refused by original merchant');assert.equal(m().menu_context.gold,5000);
 s=select(m().items.at(-1).index);assert.equal(s.menu_id,309);
 Brew.tradeCancel();assert.equal(m().menu_id,303,'cancel does not buy');assert.equal(m().menu_context.gold,5000);
 s=select(row.index);assert.equal(s.menu_id,309);Brew.tradeOffer(price);s=m();assert.equal(s.menu_id,311,'original offer accepted');assert.equal(s.menu_context.gold,5000-price);
 select(m().items.at(-1).index);assert.equal(m().menu_id,303);
 core._oe2_qa_menu(1);s=m();assert.ok(s.items.filter(i=>i.flags&0x400).length>=6,'level completion metrics');
 for(let label=0;label<3;label++)for(let fallback=0;fallback<2;fallback++){core._oe2_qa_focus_label(label,fallback);assert.equal(m().hud.target_name,'','technical native label hidden before RU/EN localization');}
 core._oe2_qa_focus(0);s=m();assert.ok(s.hud.target_name.length>0,'native look-at name exported');core._oe2_qa_focus(10000);assert.equal(m().hud.target_name,'','name clears on empty focus');
 for(const [style,name,portrait] of[[1,'Ellon',0],[8,'Elli',1]]){
  core._oe2_qa_dialogue(style);const d=m();assert.equal(d.dialog_speaker,name);assert.equal(d.dialog_portrait,portrait);
  const original=Brew.json();for(let i=0;i<5;i++)Brew.json();assert.equal(Brew.json(),original,'dialogue getters preserve script/game state');Brew.continueText();
 }
 if(core._oe2_qa_npc_dialogue()){const d=m();assert.ok(d.dialog_speaker.length);assert.ok(d.dialog_portrait>=2);}
 fs.writeFileSync(path.join(root,'build/frontend-result.json'),JSON.stringify({directInventory:true,tabs:4,cancelNoPurchase:true,refusedOffer:true,acceptedOffer:true,correctGold:true,levelMetrics:true,focusName:true,hiddenTechnicalLabels:6,speakerPortraits:true},null,2));
 const fixtures=[];for(const id of[3,100,101,501,502,503,504,303,304,305,306,307,308,309,310,311,312,313,1]){core._oe2_qa_menu(id);fixtures.push(m());}
 fs.writeFileSync(path.join(root,'build/menu-fixtures.json'),JSON.stringify(fixtures));
 console.log('Native inventory, merchant offer/cancel/purchase, metrics and focus-name fixtures passed');
})().catch(e=>{console.error(e);process.exitCode=1;});
