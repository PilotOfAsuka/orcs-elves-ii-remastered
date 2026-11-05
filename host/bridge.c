/* Presentation adapter. All decisions, scripts, combat and menu actions remain
 * in the BREW C core. This file reads its state and forwards user input. */
#include "game.h"
#include "lighting.h"
#include "presentation.h"
#include <stdarg.h>
#include <stdio.h>
#ifdef __EMSCRIPTEN__
#include <emscripten.h>
#define API EMSCRIPTEN_KEEPALIVE
#else
#define API
#endif

static uint32_t nowMs = 1000;
static uint32_t worldPixels[640 * 640], screenPixels[640 * 640];
static uint32_t storyPixels[176 * 176],classicPixels[176*164];
static uint32_t storyBase[176*176],travelPixels[176*203];
static char travelName[128];
static char detailStats[2048];
void OE2_captureDetails(const String *stats) {
    size_t len=stats&&stats->buf?stats->len:0;
    if(len>=sizeof(detailStats))len=sizeof(detailStats)-1;
    if(len)memcpy(detailStats,stats->buf,len);
    detailStats[len]=0;
}
static int worldW, worldH, worldRevision, ticks;
static char json[65536];
static size_t used;

API void oe2_test_seed(unsigned seed) {
    char value[32]; snprintf(value, sizeof(value), "%u", seed);
    setenv("OE2_SEED", value, 1);
}

static uint32_t rgba(uint16_t c) {
    return (((c >> 11) & 31) * 255 / 31) | ((((c >> 5) & 63) * 255 / 63) << 8) |
           (((c & 31) * 255 / 31) << 16) | 0xff000000u;
}

/* Called after the world and weapon are drawn, before the phone UI. Retaining
 * this image also keeps dialogs from baking their pixels into the game view. */
void OE2_captureWorld(const int16_t *rect) {
    IBitmap *b = Brew_screen();
    int x = rect[0], y = rect[1], w = rect[2], h = rect[3];
    if (!b || x < 0 || y < 0 || w <= 0 || h <= 0 || x + w > b->width || y + h > b->height) return;
    worldW = w; worldH = h;
    for (int row = 0; row < h; row++)
        for (int col = 0; col < w; col++)
            worldPixels[row * w + col] = rgba(b->px[(y + row) * b->pitch + x + col]);
    if(w==176&&h==164&&BrewLight_nativeTarget())memcpy(classicPixels,BrewLight_classic(worldPixels,w,h),(size_t)w*h*4);
    worldRevision++;
}
void OE2_captureRenderedWorld(Render *r) {
    int16_t rect[4]={(int16_t)r->fbOffsetX,(int16_t)r->fbOffsetY,(int16_t)r->width,(int16_t)r->height};
    OE2_captureWorld(rect);
}
void OE2_captureStory(int x, int y) {
    IBitmap *b = Brew_screen();
    if (!b || x < 0 || y < 0 || x + 176 > b->width || y + 176 > b->height) return;
    for (int row = 0; row < 176; row++) for (int col = 0; col < 176; col++)
        storyPixels[row * 176 + col] = rgba(b->px[(y + row) * b->pitch + x + col]);
}
static void captureImage(uint32_t *out,int x,int y,int w,int h){
    IBitmap *b=Brew_screen();if(!b||x<0||y<0||x+w>b->width||y+h>b->height)return;
    for(int row=0;row<h;row++)for(int col=0;col<w;col++)out[row*w+col]=rgba(b->px[(y+row)*b->pitch+x+col]);
}
void OE2_captureStoryBase(int x,int y){captureImage(storyBase,x,y,176,176);}
void OE2_captureTravel(int x,int y,const String *name){
    captureImage(travelPixels,x,y,176,203);
    snprintf(travelName,sizeof(travelName),"%s",name&&name->buf?name->buf:"");
}
API const uint32_t *oe2_story_base(void){return storyBase;}
API const uint32_t *oe2_travel(void){return travelPixels;}

API int oe2_boot(const char *dir, int width, int height) {
    if (g_app || width < 128 || height < 128 || width > 640 || height > 640) return -1;
    Plat_setVirtualClock(1, nowMs);
    if (Brew_init(dir, width, height) != 0 || Plat_init(width, height, "Orcs & Elves II") != 0) return -2;
    Audio_init();
    Applet *app = App_create(width, height);
    if (!app) return -3;
    Applet_HandleEvent(app, EVT_APP_START, 0, 0);
    return 0;
}
API void oe2_tick(void) {
    if (!g_app) return;
    Plat_setVirtualClock(1, nowMs);
    Applet_Tick(g_app);
    nowMs += 40; ticks++;
}
void OE2_projectileImpact(const GameSprite *missile, int flaming) {
    BrewLight_impact(missile, flaming);
}
API void oe2_key(int key) {
    if(!g_app)return;
    if(g_app->canvas->state==2&&key==AVK_SOFT1){
        MenuSystem *m=g_app->menuSystem;
        if(m->menu==3)return; /* A browser title screen has no phone Exit. */
        if(m->menu>=500&&m->menu<=504){MenuSystem_setMenu(m,0);return;}
        if(m->menu==309){m->digitEntry=0;MenuSystem_setMenu(m,m->backMenu);return;}
    }
    Applet_HandleEvent(g_app, EVT_KEY, (uint16_t)key, 0);
}
API int oe2_action_key(int action) {
    if (!g_app) return 0;
    for (int k = AVK_0; k <= AVK_9; k++) if (Canvas_getKeyAction(g_app->canvas, k) == action) return k;
    for (int k = AVK_STAR; k <= AVK_SOFT4; k++) if (Canvas_getKeyAction(g_app->canvas, k) == action) return k;
    return 0;
}
API int oe2_menu_select(int expectedMenu, int index) {
    if (!g_app || g_app->canvas->state != 2) return 0;
    MenuSystem *m = g_app->menuSystem;
    if (m->menu != expectedMenu || index < 0 || index >= m->numItems || (m->items[index].flags & 5)) return 0;
    m->selectedIndex = index;
    oe2_key(AVK_SELECT);
    return 1;
}
API void oe2_continue_dialogue(void) {
    if(!g_app||g_app->canvas->state!=7)return;
    Canvas *c=g_app->canvas;
    /* Our reader already shows the complete text. Consume only the original
     * typing/page actions; never advance the clock or skip a script event. */
    for(int i=0;i<128 && c->state==7;i++) {
        int top=c->dialogTopLine,typed=c->dialogTypeLine;
        Canvas_handleDialogEvents(c,AVK_SELECT);
        if(c->state!=7 || !(c->dialogTopLine>top || (c->dialogTopLine==top && c->dialogTypeLine>typed)))break;
    }
}
API void oe2_choice(int index) {
    if (g_app && g_app->canvas->state == 7 && (g_app->canvas->dialogFlags & 4) && index >= 0 && index < 2) {
        g_app->canvas->dialogChoice = index;
        oe2_continue_dialogue();
    }
}
API int oe2_save(void) {
    if (!g_app || g_app->canvas->state != 3) return 0;
    Canvas *c = g_app->canvas;
    if (c->viewX != c->destX || c->viewY != c->destY || c->viewAngle != c->destAngle) return 0;
    Canvas_saveState(c, 3, 0, 0x28);
    return 1;
}
API void oe2_inventory(void) {
    if (g_app && (g_app->canvas->state == 3 || g_app->canvas->state == 5) &&
        !g_app->player->isFamiliar && g_app->player->statusEffects[9].turns==0) {
        MenuSystem_setMenu(g_app->menuSystem, 500);
        MenuSystem_setMenu(g_app->menuSystem, 501);
    }
}
API void oe2_inventory_tab(int tab) {
    if(!g_app||tab<0||tab>3||g_app->canvas->state!=2)return;
    int id=g_app->menuSystem->menu;
    if(id<500||id>510)return;
    MenuSystem_setMenu(g_app->menuSystem,501+tab);
}
API void oe2_close_inventory(void) {
    if(g_app&&g_app->canvas->state==2&&g_app->menuSystem->menu>=500&&g_app->menuSystem->menu<=510)
        MenuSystem_setMenu(g_app->menuSystem,0);
}
API int oe2_trade_offer(int value) {
    if(!g_app||g_app->canvas->state!=2||g_app->menuSystem->menu!=0x135||value<0||value>99999)return 0;
    MenuSystem *m=g_app->menuSystem; m->selectedIndex=2;m->digitEntry=1;g_app->menu->offerActive=1;
    char digits[8];snprintf(digits,sizeof(digits),"%d",value);
    for(char *p=digits;*p;p++)MenuSystem_handleNumberEntry(m,AVK_0+*p-'0');
    MenuSystem_handleNumberEntry(m,AVK_SELECT);
    return 1;
}
API void oe2_trade_cancel(void) {
    if(g_app&&g_app->canvas->state==2&&g_app->menuSystem->menu==0x135) {
        g_app->menuSystem->digitEntry=0;
        MenuSystem_setMenu(g_app->menuSystem,g_app->menuSystem->backMenu);
    }
}
API void oe2_item_details(int menu,int index) {
    if(!g_app||g_app->canvas->state!=2)return;
    MenuSystem *m=g_app->menuSystem;
    if(m->menu!=menu||index<0||index>=m->numItems||!(m->items[index].flags&0x20))return;
    m->selectedIndex=index;MenuSystem_select(m);
}
API int oe2_load(void) {
    if (!g_app || (g_app->canvas->state != 2 && g_app->canvas->state != 3)) return 0;
    return Game_loadSaveGame(g_app->game, 1);
}
API int oe2_world_width(void) { return worldW; }
API int oe2_world_height(void) { return worldH; }
API int oe2_world_revision(void) { return worldRevision; }
API const uint32_t *oe2_world(void) { return worldPixels; }
API const uint32_t *oe2_lit_world(void) { return BrewView_lit(worldPixels,worldW,worldH); }
API const uint32_t *oe2_classic_world(void) { return worldW==176&&worldH==164?classicPixels:worldPixels; }
API void oe2_light_distance(int percent){BrewLight_setRange(percent);}
API void oe2_quality(int level) { BrewView_setQuality(level); }
API int oe2_weapon_bottom(void) { return BrewLight_weaponBottom(); }
API const uint32_t *oe2_frame(void) {
    IBitmap *b = Brew_screen();
    if (b) for (int y = 0; y < b->height; y++) for (int x = 0; x < b->width; x++)
        screenPixels[y * b->width + x] = rgba(b->px[y * b->pitch + x]);
    return screenPixels;
}
API const uint32_t *oe2_story(void) {
    return storyPixels;
}
static void add(const char *fmt, ...) {
    if (used >= sizeof(json) - 1) return;
    va_list args; va_start(args, fmt);
    int n = vsnprintf(json + used, sizeof(json) - used, fmt, args);
    va_end(args);
    if (n > 0) used += (size_t)n < sizeof(json) - used ? (size_t)n : sizeof(json) - used - 1;
}
static void string(const String *s) {
    add("\"");
    if (s && s->buf) for (int i = 0; i < s->len; i++) {
        unsigned char c = (unsigned char)s->buf[i];
        if (c == '\"' || c == '\\') add("\\%c", c);
        else if (c == '\n' || c == '|') add("\\n");
        else if (c == 0x7f) add("\\u2026");
        else if (c == 0x87) add("\\u2713");
        else if (c == 0x80) add("\\u00b7");
        else if (c >= 32 && c <= 126) add("%c", c);
    }
    add("\"");
}
/* Identify a scripted speaker from the exact event tile, never the nearest
 * decorative character. These reads leave script cursors and game RNG intact. */
static Entity *dialogSpeaker(const Canvas *c){
 if(c->state!=7||c->dialogStyle==1||c->dialogStyle==8||c->dialogStyle==2||c->dialogStyle==3||c->dialogStyle==4||c->dialogStyle==9)return NULL;
 Render *r=g_app->render;ScriptThread *owner=c->dialogOwner;
 if(owner)for(int f=owner->numFrames-1;f>=0;f--)for(int i=0;i<r->numTileEvents;i++){
  if((r->tileEvents[i]&0x7ffffffu)!=(owner->frames[f].event&0x7ffffffu))continue;
  int tile=r->eventTiles[i]&1023;
  for(Entity *e=g_app->game->entityGrid[tile];e;e=e->nextOnTile)
   if(e->def&&(e->def->eType==3||e->def->eType==2))return e;
 }
 Entity *e=g_app->player->facingEntity;
 return c->dialogStyle==0&&e&&e->def&&(e->def->eType==3||e->def->eType==2)?e:NULL;
}
API const char *oe2_json(void) {
    used = 0; json[0] = 0;
    if (!g_app) { add("{}"); return json; }
    Canvas *c = g_app->canvas; Player *p = g_app->player;
    MenuSystem *m = g_app->menuSystem; Hud *h = g_app->hud;
    add("{\"state\":%d,\"map_id\":%d,\"ticks\":%d,\"x\":%d,\"y\":%d,\"angle\":%d,\"fatal\":%d,\"world_revision\":%d,\"world_width\":%d,\"world_height\":%d,",
        c->state, c->mapId, ticks, c->viewX, c->viewY, c->viewAngle, g_app->fatalError, worldRevision, worldW, worldH);
    Camera *camera=g_app->game->activeCamera;
    String travel={.buf=travelName,.len=(int)strlen(travelName)};add("\"travel_name\":");string(&travel);add(",");
    add("\"cinematic_active\":%s,\"camera\":[%d,%d,%d,%d],",Game_isCinematicActive(g_app->game)?"true":"false",
        camera?camera->x:0,camera?camera->y:0,camera?camera->z:0,camera?camera->angle:0);
    add("\"menu_id\":%d,\"menu_type\":%d,\"selected\":%d,\"items\":[", m->menu, m->type, m->selectedIndex);
    if (c->state == 2) for (int i = 0; i < m->numItems; i++) {
        if (i) add(",");
        add("{\"index\":%d,\"flags\":%u,\"action\":%d,\"icon\":%d,\"text\":", i, m->items[i].flags,m->items[i].action,m->items[i].param); string(&m->items[i].text);
        add(",\"value\":"); string(&m->items[i].text2);
        add(",\"help\":"); string(&m->items[i].help); add("}");
    }
    add("],\"menu_context\":{\"gold\":%d,\"offer\":%d,\"back\":%d,\"level_name\":",p->gold,m->offerValue,m->backMenu);
    string(&g_app->render->mapName);add("},\"notes\":[");
    if(c->state==2 && m->menu==0x70)for(int i=0;i<p->numNotebookIndexes && i<8;i++) {
        if(i)add(",");
        add("{\"id\":\"%d:%d\",\"done\":%s,\"failed\":%s}",c->mapStringGroup,p->notebookIndexes[i],
            Player_isQuestDone(p,i)?"true":"false",Player_isQuestFailed(p,i)?"true":"false");
    }
    add("],\"details\":{");
    if(c->state==2 && m->menu==400) {
        add("\"text\":");string(&g_app->menu->detailsText);
        add(",\"name\":");string(&g_app->menu->detailsText2);
        String stats={.buf=detailStats,.len=(int)strlen(detailStats)};
        add(",\"stats\":");string(&stats);
    }
    add("},\"left\":"); string(&c->softKeyLeft); add(",\"right\":"); string(&c->softKeyRight);
    add(",\"story_page\":%d,\"story_pages\":%d,\"dialogue\":", c->storyPage, c->storyPageCount);
    string(&c->dialogText);
    add(",\"dialog_flags\":%d,\"dialog_choice\":%d,\"dialog_style\":%d,\"dialog_top\":%d,\"dialog_lines\":%d,\"dialog_typed\":%d,\"dialog_view\":%d,",
        c->dialogFlags, c->dialogChoice, c->dialogStyle, c->dialogTopLine, c->dialogNumLines,c->dialogTypeLine,c->dialogViewLines);
    Entity *speaker=dialogSpeaker(c);
    String speakerName={0},dialogTitle={0};int portrait=-1;
    if(c->state==7){
        if(c->dialogStyle==1){speakerName=(String){.buf="Ellon",.len=5};portrait=0;}
        else if(c->dialogStyle==8){speakerName=(String){.buf="Elli",.len=4};portrait=1;}
        else if(speaker){speakerName=speaker->name.len?speaker->name:speaker->def->name;portrait=2+speaker->def->tileIndex;}
        if(c->dialogStyle==2||c->dialogStyle==9){
            dialogTitle=c->dialogText;dialogTitle.len=0;
            while(dialogTitle.len<c->dialogText.len&&dialogTitle.buf[dialogTitle.len]!='|')dialogTitle.len++;
            if(c->dialogPortrait>=0&&c->dialogPortrait<8)portrait=258+c->dialogPortrait;
        }
    }
    add("\"dialog_speaker\":");string(&speakerName);add(",\"dialog_title\":");string(&dialogTitle);add(",\"dialog_portrait\":%d,",portrait);
    int wi = p->ce.weapon;
    EntityDef *weapon = wi >= 0 && wi < 11 ? EntityDefs_find(g_app->entityDefs, 6, 1, wi) : NULL;
    int ammoType = wi >= 0 && wi < 11 ? g_app->combat->weapons[wi].ammoType : 0;
    add("\"hud\":{\"health\":%d,\"max_health\":%d,\"armor\":%d,\"max_armor\":%d,\"weapon\":%d,\"ammo\":%d,\"weapon_name\":",
        p->ce.health, p->ce.maxHealth, CombatEntity_getArmorPoints(&p->ce), CombatEntity_getMaxArmorPoints(&p->ce), wi,
        ammoType > 0 && ammoType < 7 ? p->ammo[ammoType] : -1);
    string(weapon ? &weapon->name : NULL);
    /* Match the original modifier list, including stacked stat effects and
     * familiar energy only while possessing. Merely read native counters. */
    add(",\"effects\":[");
    int effectFirst = 1;
    for (int i = 0; i < 12; i++) {
        const Buff *buff = &p->buffs[i];
        if (buff->turns <= 0 || (i == 0 && !p->isFamiliar)) continue;
        add("%s{\"id\":%d,\"amount\":%d,\"turns\":%d}", effectFirst ? "" : ",", i, buff->amount, buff->turns);
        effectFirst = 0;
    }
    add("]");
    int ringId=p->equippedRing;
    EntityDef *ring=ringId>0&&ringId<9&&(p->rings&(1u<<ringId))?EntityDefs_find(g_app->entityDefs,6,2,ringId):NULL;
    add(",\"rings_owned\":%u,\"ring_id\":%d,\"ring_name\":",p->rings,ring?ringId:0);string(ring?(ring->longName.len?&ring->longName:&ring->name):NULL);
    add(",\"ring_description\":");string(ring?&ring->description:NULL);
    add(",\"context\":"); string(&h->caption1);
    Entity *focus=p->facingEntity;
    add(",\"target_name\":");string(focus?(focus->name.len?&focus->name:focus->def?&focus->def->name:NULL):NULL);
    add(",\"events\":[");
    for(int i=0;i<h->numMessages&&i<3;i++){if(i)add(",");string(&h->messages[i]);}
    add("]");
    add(",\"cinematic\":"); string(&h->caption2);
    add(",\"notices\":"); string(h->numMessages > 0 ? &h->messages[0] : NULL);
    int targetHp = -1, targetMax = 0;
    if (h->targetEnt && h->targetEnt->monster) { targetHp = h->targetEnt->monster->ce.health; targetMax = h->targetEnt->monster->ce.maxHealth; }
    unsigned lockAttempts = (uint16_t)(((uint32_t)p->lockpickTries >> 16) - ((uint32_t)p->f270 >> 16));
    int lastDirection = lockAttempts && c->lockEntered.len > 0 ? String_charAt(&c->lockEntered, c->lockEntered.len - 1) : 0;
    add(",\"target_health\":%d,\"target_max\":%d},\"lock\":{\"slot\":%d,\"hits\":%d,\"done\":%d,\"tries\":%d,\"length\":%d,\"attempts\":%u,\"last_direction\":%d}",
        targetHp, targetMax, c->lockSlot, c->lockCorrectHits, c->lockDone, p->lockpickTries,
        TextUtil_strlenZ(g_app->textUtil, &g_app->game->lockCombination), lockAttempts, lastDirection);
    if (c->state == 5) {
        add(",\"map\":{\"level_id\":%d,\"hidden\":%s,\"x\":%.3f,\"y\":%.3f,\"angle\":%d,\"tiles\":[",
            c->mapId, g_app->game->automapFlag && c->mapId == 7 ? "true" : "false", c->viewX / 64.0, c->viewY / 64.0, c->viewAngle / 4);
        for (int i = 0; i < 1024; i++) add("%s%u", i ? "," : "", g_app->render->mapFlags[i]);
        add("],\"walls\":[");
        int first = 1;
        for (int i = 0; i < g_app->render->numLines; i++) {
            Line *l = &g_app->render->lines[i];
            if ((l->flags & 0x80) && !(l->flags & 0x40004)) {
                add("%s[%.4f,%.4f,%.4f,%.4f]", first ? "" : ",", l->x1 / 64.0, l->y1 / 64.0, l->x2 / 64.0, l->y2 / 64.0);
                first = 0;
            }
        }
        add("]}");
    }
    add("}");
    return json;
}
