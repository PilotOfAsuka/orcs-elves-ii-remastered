/* Native reference for cross-target replay. Test input is isolated from saves. */
#include "game.h"
#include <stdio.h>
#include <zlib.h>
int oe2_boot(const char *, int, int);
void oe2_tick(void), oe2_key(int), oe2_test_seed(unsigned);
int oe2_action_key(int), oe2_menu_select(int, int), oe2_world_width(void), oe2_world_height(void);
int oe2_save(void), oe2_load(void);
const char *oe2_json(void);
const uint32_t *oe2_frame(void), *oe2_world(void);
int main(int argc, char **argv) {
    if (argc != 2) return 1;
    oe2_test_seed(1);
    if (oe2_boot(argv[1], 176, 220) != 0) return 2;
    char line[256];
    while (fgets(line, sizeof(line), stdin)) {
        int a=0,b=0;
        if (line[0]=='t') oe2_tick();
        else if (line[0]=='s') oe2_save();
        else if (line[0]=='l') oe2_load();
        else if (line[0]=='m' && sscanf(line+1,"%d %d",&a,&b)==2) oe2_menu_select(a,b);
        else if (line[0]=='k' && sscanf(line+1,"%i",&a)==1) oe2_key(a);
        else if (line[0]=='a' && sscanf(line+1,"%d",&a)==1) oe2_key(oe2_action_key(a));
        else if (line[0]=='q') break;
        unsigned long screen = crc32(0, (const Bytef *)oe2_frame(), 176*220*4);
        unsigned long world = crc32(0, (const Bytef *)oe2_world(), (uInt)(oe2_world_width()*oe2_world_height()*4));
        printf("{\"model\":%s,\"screen_crc\":%lu,\"world_crc\":%lu}\n",oe2_json(),screen,world);
        fflush(stdout);
    }
    return 0;
}
