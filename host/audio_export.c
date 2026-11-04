/* Convert original BREW CMF/QCELP resources once at build time. Runtime uses
 * exactly the decoded mono PCM; no alternate soundtrack or game assets. */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <zlib.h>
#include "bar.h"
#include "pmd.h"

int main(int argc, char **argv) {
    Bar bar;
    if (argc != 3 || Bar_open(&bar, argv[1]) != 0) return 1;
    int count = 0, failures = 0;
    for (int i = 0; i < bar.count; i++) {
        size_t len = 0;
        unsigned char *raw = Bar_load(&bar, bar.entries[i].id, &len);
        if (!raw) continue;
        if (len >= 4 && !memcmp(raw, "cmid", 4)) {
            int16_t *pcm = NULL;
            int samples = 0;
            if (Pmd_decode(raw, len, &pcm, &samples) != 0) {
                fprintf(stderr, "Failed resource %d %s\n", bar.entries[i].id, bar.entries[i].name);
                failures++;
            } else {
                char path[2048];
                snprintf(path, sizeof(path), "%s/%08lx-%zu.pcm", argv[2], (unsigned long)crc32(0, raw, (uInt)len), len);
                FILE *out = fopen(path, "wb");
                if (!out) return 2;
                for (int j = 0; j < samples; j++) {
                    fputc((uint16_t)pcm[j] & 255, out);
                    fputc((uint16_t)pcm[j] >> 8, out);
                }
                if (fclose(out) != 0) return 2;
                count++;
                free(pcm);
            }
        }
        free(raw);
    }
    Bar_close(&bar);
    printf("BREW audio: %d decoded, %d failed\n", count, failures);
    return failures ? 1 : 0;
}
