#include "platform.h"
#include <emscripten.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>

static uint32_t clockMs = 1000;
static char dataDir[1024] = "/gamedata";
int Plat_init(int w, int h, const char *title) { (void)w; (void)h; (void)title; return 0; }
void Plat_shutdown(void) {}
uint32_t Plat_uptimeMs(void) { return clockMs; }
void Plat_setVirtualClock(int enabled, uint32_t now) { (void)enabled; clockMs = now; }
void Plat_delay(uint32_t ms) { (void)ms; }
void Plat_present(const uint16_t *fb, int pitch) { (void)fb; (void)pitch; }
int Plat_pollEvents(PlatKeyEvent *ev, int max, int *count) { (void)ev; (void)max; *count = 0; return 1; }
int Plat_isMinimized(void) { return 0; }
void Plat_vibrate(int ms) { (void)ms; }
void Plat_setWindowTitle(const char *title) { (void)title; }
void Plat_setDataDir(const char *dir) { snprintf(dataDir, sizeof(dataDir), "%s", dir); }
const char *Plat_dataDir(void) { return dataDir; }
const char *Plat_dataPath(const char *name) {
    static char path[2100];
    snprintf(path, sizeof(path), "/oe2-brew-v1/%s", name);
    return path;
}
int Plat_fileRead(const char *name, uint8_t **data, size_t *len) {
    *data = NULL; *len = 0;
    FILE *f = fopen(Plat_dataPath(name), "rb");
    if (!f) return -1;
    if (fseek(f, 0, SEEK_END) != 0) { fclose(f); return -1; }
    long size = ftell(f);
    if (size < 0) { fclose(f); return -1; }
    rewind(f);
    uint8_t *p = malloc((size_t)size + 1);
    if (!p || fread(p, 1, (size_t)size, f) != (size_t)size) { free(p); fclose(f); return -1; }
    fclose(f); p[size] = 0; *data = p; *len = (size_t)size; return 0;
}
int Plat_fileWrite(const char *name, const void *data, size_t len) {
    char final[2100], tmp[2110];
    snprintf(final, sizeof(final), "%s", Plat_dataPath(name));
    snprintf(tmp, sizeof(tmp), "%s.tmp", final);
    FILE *f = fopen(tmp, "wb");
    if (!f) return -1;
    if (fwrite(data, 1, len, f) != len) { fclose(f); remove(tmp); return -1; }
    if (fclose(f) != 0 || rename(tmp, final) != 0) { remove(tmp); return -1; }
    EM_ASM({ if (globalThis.Brew) globalThis.Brew.sync(); });
    return 0;
}
int Plat_fileRemove(const char *name) {
    int result = remove(Plat_dataPath(name));
    if (!result) EM_ASM({ if (globalThis.Brew) globalThis.Brew.sync(); });
    return result;
}
int Plat_fileExists(const char *name) { struct stat s; return stat(Plat_dataPath(name), &s) == 0; }
int Audio_init(void) { return 0; }
void Audio_shutdown(void) { for (int i = 0; i < AUDIO_CHANNELS; i++) Audio_stop(i); }
void Audio_play(int channel, const int16_t *pcm, int samples, int rate, int loops) {
    EM_ASM({ globalThis.BrewAudio?.play($0, $1, $2, $3, $4); }, channel, pcm, samples, rate, loops);
}
void Audio_stop(int channel) { EM_ASM({ globalThis.BrewAudio?.stop($0); }, channel); }
int Audio_isPlaying(int channel) { return EM_ASM_INT({ return globalThis.BrewAudio?.playing($0) ? 1 : 0; }, channel); }
void Audio_setVolume(int channel, int volume) { EM_ASM({ globalThis.BrewAudio?.volume($0, $1); }, channel, volume); }
void Audio_pauseAll(int pause) { EM_ASM({ globalThis.BrewAudio?.pause($0); }, pause); }
