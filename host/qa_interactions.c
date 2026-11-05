/* Isolated interaction fixtures. Included only by build_core.py --qa. */
#include "game.h"
#ifdef __EMSCRIPTEN__
#include <emscripten.h>
#define QA EMSCRIPTEN_KEEPALIVE
#else
#define QA
#endif

QA void oe2_qa_map(int map) { Canvas_loadMap(g_app->canvas,map); }
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
