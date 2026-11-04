/* Build-time QCELP decoding avoids shipping an unrelated media framework in
 * the browser. Both CRC and original byte length identify a BREW clip. */
#include "pmd.h"
#include <stdio.h>
#include <stdlib.h>
#include <zlib.h>

int Pmd_decode(const uint8_t *cmf, size_t len, int16_t **pcm, int *samples) {
    char path[256];
    *pcm = NULL;
    *samples = 0;
    snprintf(path, sizeof(path), "/gamedata/audio/%08lx-%zu.pcm", (unsigned long)crc32(0, cmf, (uInt)len), len);
    FILE *f = fopen(path, "rb");
    if (!f) return -1;
    if (fseek(f, 0, SEEK_END) != 0) { fclose(f); return -1; }
    long bytes = ftell(f);
    if (bytes <= 0 || bytes % 2 || bytes > 64000000) { fclose(f); return -1; }
    rewind(f);
    uint8_t *raw = malloc((size_t)bytes);
    if (!raw || fread(raw, 1, (size_t)bytes, f) != (size_t)bytes) {
        free(raw); fclose(f); return -1;
    }
    fclose(f);
    /* WebAssembly is little endian. PCM files have explicit little-endian samples. */
    *pcm = (int16_t *)raw;
    *samples = (int)(bytes / 2);
    return 0;
}
