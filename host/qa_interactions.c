/* Isolated interaction fixtures. Included only by build_core.py --qa. */
#include "game.h"
#include <math.h>
#include "lighting.h"
#ifdef __EMSCRIPTEN__
#include <emscripten.h>
#define QA EMSCRIPTEN_KEEPALIVE
#else
#define QA
#endif

QA void oe2_qa_map(int map) { Canvas_loadMap(g_app->canvas,map); }
QA void oe2_qa_menu(int menu) {
    g_app->menu->pricePercent=100;g_app->menu->storeItem2=-1;
    g_app->menu->mapId=g_app->canvas->mapId+1;
    MenuSystem_setMenu(g_app->menuSystem,menu);
}
QA void oe2_qa_gold(int gold) { g_app->player->gold=gold; }
QA int oe2_qa_focus(int index) {
    for(int i=0;i<g_app->render->numMapSprites;i++){
        Entity *ent=g_app->render->sprites[i].ent;
        if(!ent||!ent->name.len)continue;
        if(index--==0){g_app->player->facingEntity=ent;g_app->hud->targetEnt=NULL;return 1;}
    }
    g_app->player->facingEntity=NULL;g_app->hud->targetEnt=NULL;return 0;
}
QA int oe2_qa_candle(void) {
    Render *r=g_app->render;Canvas *c=g_app->canvas;
    for(int i=0;i<r->numLines;i++) {
        Line *l=&r->lines[i];if((l->flags&0x40000)||!(l->texture==61||l->texture==69))continue;
        float dx=l->x2-l->x1,dy=l->y2-l->y1,n=sqrtf(dx*dx+dy*dy);if(n<1)continue;
        float x=(l->x1+l->x2)*.5f-dy/n*40,y=(l->y1+l->y2)*.5f+dx/n*40;
        c->viewX=c->destX=(int)x;c->viewY=c->destY=(int)y;c->viewZ=c->destZ=36;
        c->viewAngle=c->destAngle=((int)lrintf(atan2f(-((l->y1+l->y2)*.5f-y),(l->x1+l->x2)*.5f-x)*1024/6.28318530718f)+1024)&1023;
        g_app->player->ce.x=c->viewX;g_app->player->ce.y=c->viewY;
        MenuSystem_setMenu(g_app->menuSystem,0);
        Canvas_renderView(c,c->viewX,c->viewY,c->viewAngle);return i;
    }
    return -1;
}
QA void oe2_qa_status(int effect,int amount,int turns) {
    Player *p=g_app->player;
    if(effect<0) { for(int i=0;i<14;i++)Player_removeBuff(p,i); }
    else if(effect<14) {
        Player_removeBuff(p,effect);
        if(turns>0)Player_setStatusEffect(p,effect,amount,1,turns);
    }
    Player_updateStats(p);
}
QA void oe2_qa_status_turn(void) { Player_advanceTurn(g_app->player); }
QA void oe2_qa_status_familiar(int value) { g_app->player->isFamiliar=value!=0; }

QA int oe2_qa_lock(int index) {
    Render *r=g_app->render;
    for(int i=0;i<r->numMapSprites;i++) {
        Sprite *s=&r->sprites[i];int tile=s->info&255;
        if((tile!=142&&tile!=144)||!s->ent)continue;
        if(index--!=0)continue;
        g_app->player->enableHelp=0;
        g_app->player->lockLevel=Entity_getEventParam68(s->ent);
        Canvas_setLockpick(g_app->canvas,s->ent);
        return String_length(&g_app->game->lockCombination);
    }
    return -1;
}
QA int oe2_qa_direction(int index) {
    if(index<0||index>=String_length(&g_app->game->lockCombination))return 0;
    return String_charAt(&g_app->game->lockCombination,index);
}
QA int oe2_qa_chest_tile(void) {
    Entity *ent=g_app->canvas->lockEntity;
    return ent?g_app->render->sprites[(ent->info&65535)-1].info&255:-1;
}
QA int oe2_qa_land(int tile) {
    Combat *c=g_app->combat,saved=*c;Canvas *cv=g_app->canvas;
    c->numActiveMissiles=0;c->weapon=&c->weapons[8];c->attacker=NULL;c->target=NULL;
    c->targetType=0;c->hitType=0;c->totalDamage=0;c->bonusFlag=0;c->projSprite=tile;
    int dx=g_app->render->viewCos/1024,dy=-g_app->render->viewSin/1024;
    GameSprite *missile=Combat_launchMissile(c,cv->viewX,cv->viewY,cv->viewX+dx,cv->viewY+dy,dy!=0,4);
    if(!missile){*c=saved;return 0;}
    missile->flags&=~4;
    Combat_resolveProjectiles(c);*c=saved;
    Canvas_renderView(cv,cv->viewX,cv->viewY,cv->viewAngle);
    return 1;
}

extern int ScriptThread_executeExtCommand(ScriptThread *,ScriptFrame *,int,int);
extern void BrewLight_qaWallCandles(int);
extern int BrewLight_qaCandleGeometry(void);
QA void oe2_qa_wall_light(int enabled){BrewLight_qaWallCandles(enabled);}
QA int oe2_qa_candle_geometry(void){return BrewLight_qaCandleGeometry();}
QA int oe2_qa_lamp_state(int tile,int state){
 for(int i=0;i<g_app->render->numMapSprites;i++){
  Sprite *s=&g_app->render->sprites[i];if((s->info&255)!=tile)continue;
  /* Exercise the shipped script opcode rather than inventing another state. */
  ScriptThread_executeExtCommand(NULL,NULL,0x62,((state?4:0xff)<<16)|i);
  return BrewLight_spriteEmits(s);
 }
 return -1;
}
QA void oe2_qa_dialogue(int style){
 Render *r=g_app->render;int text=0;
 for(int i=0;i<r->numByteCodes;i++)if(r->byteCodes[i*3]==8&&(r->byteCodes[i*3+1]&255)==style){text=(uint32_t)r->byteCodes[i*3+1]>>16;break;}
 Canvas_showDialogText(g_app->canvas,NULL,g_app->canvas->mapStringGroup,text,style,1,0);
}

QA int oe2_qa_npc_dialogue(void){
 for(int i=0;i<g_app->render->numMapSprites;i++){
  Entity *e=g_app->render->sprites[i].ent;if(!e||!e->def||e->def->eType!=3)continue;
  g_app->player->facingEntity=e;
  Canvas_showDialogText(g_app->canvas,NULL,g_app->canvas->mapStringGroup,0,0,1,0);
  return 1;
 }
 return 0;
}

QA int oe2_qa_lamp_frames(void){
 for(int j=0;j<2;j++){
  int tile=j?181:150;Sprite s={.info=(uint32_t)tile};
  for(int frame=0;frame<4;frame++){s.info=(uint32_t)tile|0x80000000u|((uint32_t)frame<<8);if(!BrewLight_spriteEmits(&s))return 0;}
  s.info=(uint32_t)tile|0x80000400u;if(BrewLight_spriteEmits(&s))return 0;
  s.info=(uint32_t)tile|0x10000u;if(BrewLight_spriteEmits(&s))return 0;
 }
 return 1;
}

QA int oe2_qa_candle_sprite_count(void){
 int count=0;for(int i=0;i<g_app->render->numMapSprites;i++){uint32_t f=g_app->render->sprites[i].info;int tile=f&255;if((f&0x40000u)&&(tile==61||tile==69))count++;}return count;
}
QA void oe2_qa_give_rings(void){for(int id=1;id<=8;id++)Player_give(g_app->player,2,id,1,1);}
QA int oe2_qa_strength(void){return g_app->player->ce.strength;}
