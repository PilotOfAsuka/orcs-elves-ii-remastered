/* Native reference for cross-target replay. Test input is isolated from saves. */
#include "game.h"
#include "lighting.h"
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
        else if (line[0]=='v') {
            Render *r=calloc(1,sizeof(Render));
            r->numLines=1;r->effFloor=0;r->effCeil=64;
            r->lines[0]=(Line){.x1=64,.y1=0,.x2=64,.y2=128,.flags=0x10000};
            int blocked=!BrewLight_visible(r,32,64,32,96,64,32);
            int parallel=BrewLight_visible(r,32,64,32,32,96,32);
            int above=BrewLight_visible(r,32,64,96,96,64,96);
            r->lines[0].flags|=0x40000;
            int open=BrewLight_visible(r,32,64,32,96,64,32);
            Sprite sprite={.x=64,.y=64,.z=32,.scale=64,.info=32};
            r->spriteRemap[32]=0;r->spriteMap[0].ofs=0;r->shapeSpans[2]=0;r->shapeSpans[3]=87;
            for(int x=0;x<88;x++){
                int run=100+3*x;r->shapeSpans[4+x]=run-2;r->shapeSpans[run]=88<<8;r->shapeSpans[run+2]=127;
            }
            int silhouette=BrewLight_spriteBlocks(r,&sprite,32,64,32,96,64,32);
            r->shapeSpans[100+3*44]=127;
            int transparent=!BrewLight_spriteBlocks(r,&sprite,32,64,32,96,64,32);
            r->shapeSpans[100+3*44]=88<<8;sprite.x=128;
            int moved=!BrewLight_spriteBlocks(r,&sprite,32,64,32,96,64,32);
            sprite.x=64;sprite.info|=0x10000;
            int hidden=!BrewLight_spriteBlocks(r,&sprite,32,64,32,96,64,32);
            Entity meat={.info=0x4000000u};Sprite spit={.info=116,.ent=&meat};
            int campfire=BrewLight_spriteEmits(&spit);meat.info=0;
            int meatTaken=!BrewLight_spriteEmits(&spit);
            free(r);
            printf("{\"blocked\":%d,\"parallel\":%d,\"above\":%d,\"open\":%d,\"silhouette\":%d,\"transparent\":%d,\"moved\":%d,\"hidden\":%d,\"campfire\":%d,\"meatTaken\":%d}\n",blocked,parallel,above,open,silhouette,transparent,moved,hidden,campfire,meatTaken);
            fflush(stdout);continue;
        }
        unsigned long screen = crc32(0, (const Bytef *)oe2_frame(), 176*220*4);
        unsigned long world = crc32(0, (const Bytef *)oe2_world(), (uInt)(oe2_world_width()*oe2_world_height()*4));
        printf("{\"model\":%s,\"screen_crc\":%lu,\"world_crc\":%lu}\n",oe2_json(),screen,world);
        fflush(stdout);
    }
    return 0;
}
