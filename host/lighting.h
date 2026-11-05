#ifndef BREW_LIGHTING_H
#define BREW_LIGHTING_H
#include "game.h"
void BrewLight_begin(Render *r);
void BrewLight_fade(int level);
int BrewLight_nativeTarget(void);
void BrewLight_floor(Render *r,int x,int y,int u,int v,int du,int dv,int count,int ceiling);
void BrewLight_span(Render *r,int x,int y,int count,int projection,int sprite);
void BrewLight_weapon(Render *r,int x,int y,int count);
void BrewLight_tagCaster(Render *r,Sprite *sprite);
void BrewLight_poseCaster(Render *r,int x,int y,int z,int tile,int frame,int flags,int mode,int scale);
int BrewLight_spriteBlocks(const Render *r,const Sprite *s,float ax,float ay,float az,float bx,float by,float bz);
int BrewLight_spriteEmits(const Sprite *s);
void BrewLight_impact(const GameSprite *missile,int flaming);
int BrewLight_weaponBottom(void);
const uint32_t *BrewLight_classic(const uint32_t *original,int w,int h);
const uint32_t *BrewLight_render(const uint32_t *original,int w,int h);
int BrewLight_visible(const Render *r,float ax,float ay,float az,float bx,float by,float bz);
#endif
