/* Presentation adapter. All decisions, scripts, combat and menu actions remain
 * in the BREW C core. This file reads its state and forwards user input. */
#include "game.h"
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
static uint32_t storyPixels[176 * 176];
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
    worldRevision++;
}
void OE2_captureStory(int x, int y) {
    IBitmap *b = Brew_screen();
    if (!b || x < 0 || y < 0 || x + 176 > b->width || y + 176 > b->height) return;
    for (int row = 0; row < 176; row++) for (int col = 0; col < 176; col++)
        storyPixels[row * 176 + col] = rgba(b->px[(y + row) * b->pitch + x + col]);
}

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
API void oe2_key(int key) { if (g_app) Applet_HandleEvent(g_app, EVT_KEY, (uint16_t)key, 0); }
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
API void oe2_choice(int index) {
    if (g_app && g_app->canvas->state == 7 && (g_app->canvas->dialogFlags & 4) && index >= 0 && index < 2) {
        g_app->canvas->dialogChoice = index;
        oe2_key(AVK_SELECT);
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
    if (g_app && (g_app->canvas->state == 3 || g_app->canvas->state == 5))
        MenuSystem_setMenu(g_app->menuSystem, 500);
}
API int oe2_load(void) {
    if (!g_app || (g_app->canvas->state != 2 && g_app->canvas->state != 3)) return 0;
    return Game_loadSaveGame(g_app->game, 1);
}
API int oe2_world_width(void) { return worldW; }
API int oe2_world_height(void) { return worldH; }
API int oe2_world_revision(void) { return worldRevision; }
API const uint32_t *oe2_world(void) { return worldPixels; }
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
        else if (c >= 32 && c <= 126) add("%c", c);
    }
    add("\"");
}
API const char *oe2_json(void) {
    used = 0; json[0] = 0;
    if (!g_app) { add("{}"); return json; }
    Canvas *c = g_app->canvas; Player *p = g_app->player;
    MenuSystem *m = g_app->menuSystem; Hud *h = g_app->hud;
    add("{\"state\":%d,\"map_id\":%d,\"ticks\":%d,\"x\":%d,\"y\":%d,\"angle\":%d,\"fatal\":%d,\"world_revision\":%d,\"world_width\":%d,\"world_height\":%d,",
        c->state, c->mapId, ticks, c->viewX, c->viewY, c->viewAngle, g_app->fatalError, worldRevision, worldW, worldH);
    add("\"menu_id\":%d,\"menu_type\":%d,\"selected\":%d,\"items\":[", m->menu, m->type, m->selectedIndex);
    if (c->state == 2) for (int i = 0; i < m->numItems; i++) {
        if (i) add(",");
        add("{\"index\":%d,\"flags\":%u,\"text\":", i, m->items[i].flags); string(&m->items[i].text);
        add(",\"value\":"); string(&m->items[i].text2);
        add(",\"help\":"); string(&m->items[i].help); add("}");
    }
    add("],\"left\":"); string(&c->softKeyLeft); add(",\"right\":"); string(&c->softKeyRight);
    add(",\"story_page\":%d,\"story_pages\":%d,\"dialogue\":", c->storyPage, c->storyPageCount);
    string(&c->dialogText);
    add(",\"dialog_flags\":%d,\"dialog_choice\":%d,\"dialog_style\":%d,\"dialog_top\":%d,\"dialog_lines\":%d,",
        c->dialogFlags, c->dialogChoice, c->dialogStyle, c->dialogTopLine, c->dialogNumLines);
    int wi = p->ce.weapon;
    EntityDef *weapon = wi >= 0 && wi < 11 ? EntityDefs_find(g_app->entityDefs, 6, 1, wi) : NULL;
    int ammoType = wi >= 0 && wi < 11 ? g_app->combat->weapons[wi].ammoType : 0;
    add("\"hud\":{\"health\":%d,\"max_health\":%d,\"armor\":%d,\"max_armor\":%d,\"weapon\":%d,\"ammo\":%d,\"weapon_name\":",
        p->ce.health, p->ce.maxHealth, CombatEntity_getArmorPoints(&p->ce), CombatEntity_getMaxArmorPoints(&p->ce), wi,
        ammoType > 0 && ammoType < 7 ? p->ammo[ammoType] : -1);
    string(weapon ? &weapon->name : NULL);
    add(",\"context\":"); string(&h->caption1);
    add(",\"cinematic\":"); string(&h->caption2);
    add(",\"notices\":"); string(h->numMessages > 0 ? &h->messages[0] : NULL);
    int targetHp = -1, targetMax = 0;
    if (h->targetEnt && h->targetEnt->monster) { targetHp = h->targetEnt->monster->ce.health; targetMax = h->targetEnt->monster->ce.maxHealth; }
    add(",\"target_health\":%d,\"target_max\":%d},\"lock\":{\"slot\":%d,\"hits\":%d,\"done\":%d,\"tries\":%d,\"length\":%d}",
        targetHp, targetMax, c->lockSlot, c->lockCorrectHits, c->lockDone, p->lockpickTries, c->lockString.len);
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
