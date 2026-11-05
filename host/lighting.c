/* Presentation-only point lighting on original BREW texels. Surface positions
 * come from the software rasterizer. Shadow rays intersect current level
 * segments, so opening a door changes light visibility. No game state or RNG
 * is modified. This is a first software ray-shadow pass, not global GI/RTX. */
#include "lighting.h"
#include <math.h>
#include <string.h>
#include <limits.h>
#define MAX_PIXELS (704*880)
#define GRID_CELLS (128*128*24)
#define HIDDEN 0x40000u
#define NO_DEPTH 0x200000u
typedef struct { float x,y,z; signed char nx,ny,nz; unsigned char kind; } Surface;
typedef struct { float x,y,z,r,g,b,radius,power; int flicker,key; } Light;
typedef struct { int tile; float r,g,b,radius,power,height; int flicker; } Source;
typedef struct {float x,y,z,size;int frame;uint32_t flags;int active;} Caster;
/* IDs visually verified against all 205 sprite identities in catalog_textures.
 * Doors, ordinary bottles and bright painted decorations are not emitters. */
static const Source sources[]={
 {116,1,.42f,.10f,230,2.2f,-20,1},
 {130,1,.40f,.10f,240,2.2f,0,1}, {136,1,.52f,.19f,240,2.0f,24,1},
 {149,1,.30f,.06f,150,1.6f,0,1}, {150,1,.62f,.30f,210,1.6f,18,1},
 {181,1,.68f,.37f,150,1.2f,14,1}, {234,1,.40f,.10f,240,2.2f,0,1},
 {14,.35f,.65f,1,150,1.2f,0,0}, {15,.25f,1,.35f,150,1.2f,0,0}, {16,1,.18f,.10f,150,1.2f,0,0},
 {224,.25f,.55f,1,170,1.3f,0,0}, {230,1,.75f,.20f,150,1.3f,0,0}, {235,.6f,.2f,1,180,1.3f,0,0}, {238,.25f,.55f,1,170,1.3f,0,0},
 {220,1,.18f,.10f,140,1.1f,0,0}, {221,.25f,1,.35f,140,1.1f,0,0},
 {222,.35f,.65f,1,150,1.2f,0,0}, {223,1,.35f,.08f,170,1.6f,0,1},
 {225,.25f,.30f,1,110,.8f,0,0}, {227,1,.25f,.05f,170,1.5f,0,1},
 {242,1,.65f,.13f,130,1.0f,0,0}, {243,.14f,.30f,1,130,1.0f,0,0},
 {245,.2f,1,.25f,130,1.0f,0,0}, {252,.55f,.65f,1,170,1.4f,0,1}
};
static Surface surfaces[MAX_PIXELS];
static uint32_t lit[MAX_PIXELS],cachedHash,geometryHash;
static unsigned char checked[GRID_CELLS];
static uint16_t visibility[GRID_CELLS];
static uint16_t wallVisibility[GRID_CELLS];
static Caster casters[800],posedCasters[800],nativePoses[800];
static int casterTag=-1,lightCasters[8][800],casterCount[8];
static Surface *underWeapon;
static uint32_t *weaponBackground;
static size_t weaponCapacity;
static int weaponCopied;
/* A small, geometry-only distance field supplies smooth floor contact shade. */
static float wallDistance[3][129*129],wallAxisDistance[3][2][129*129];
static unsigned char wallChecked[3][129*129];
typedef struct {float x,y,distance;int axis,valid;} CornerCache;
static CornerCache cornerCache[704];
static Light lights[8];
/* Arrival events outlive the retired missile, independently of sprite slots. */
typedef struct {Light light;int time,map,active;} Impact;
static Impact impacts[8];
static unsigned nextImpact;
static int width,height,numLights,fadeLevel=255;
static Render *renderer;
static int lightDistance=100;
void BrewLight_setRange(int percent){lightDistance=percent<100?100:percent>150?150:percent;}
static float fx,fy,rx,ry;
static float clampf(float x,float a,float b){return x<a?a:x>b?b:x;}
static uint32_t hashWord(uint32_t h,uint32_t n){return (h^n)*16777619u;}
static const Source *sourceForSprite(const Sprite *s){
 if(s->info&(0x10000u|0x40000u))return NULL;
 int tile=s->info&255;
 /* Their fifth native frame contains an extinguished wick/empty lamp.
  * Script opcode 0x62 fixes that frame with the high bit; normal flames loop 0..3. */
 if((tile==150||tile==181)&&(s->info&0x80000000u)&&((s->info>>8)&15)>=4)return NULL;
 /* Native tile 116 draws its flaming meat only while this entity bit is set. */
 if(tile==116&&(!s->ent||!(s->ent->info&0x4000000u)))return NULL;
 for(unsigned i=0;i<sizeof(sources)/sizeof(sources[0]);i++)if(tile==sources[i].tile)return &sources[i];
 return NULL;
}
int BrewLight_spriteEmits(const Sprite *s){return sourceForSprite(s)!=NULL;}
void BrewLight_impact(const GameSprite *missile,int flaming){
 if(!missile||!missile->sprite||!g_app)return;
 const Source *p=sourceForSprite(missile->sprite);
 if(flaming){for(unsigned i=0;i<sizeof(sources)/sizeof(sources[0]);i++)if(sources[i].tile==224){p=&sources[i];break;}}
 if(!p)return; /* Physical arrows, blood, melee and debris do not emit. */
 unsigned slot=nextImpact++%8;
 float dx=missile->dest[0]-missile->start[0],dy=missile->dest[1]-missile->start[1],d=sqrtf(dx*dx+dy*dy);
 /* Keep a wall hit on the incoming side of its opaque surface. */
 float bias=d>.01f?fminf(4.f,d*.25f)/d:0;
 Light l={missile->dest[0]-dx*bias,missile->dest[1]-dy*bias,(float)missile->dest[2],
  p->r,p->g,p->b,fmaxf(190,p->radius*1.3f),p->power*3.4f,0,3000+(int)slot};
 impacts[slot]=(Impact){l,g_app->time,g_app->canvas->mapId,1};
}
static void put(int x,int y,float px,float py,float pz,float nx,float ny,float nz,int kind){
 if(x<0||y<0||x>=width||y>=height)return;
 Surface *s=&surfaces[y*width+x];s->x=px;s->y=py;s->z=pz;
 s->nx=(signed char)(nx*127);s->ny=(signed char)(ny*127);s->nz=(signed char)(nz*127);s->kind=(unsigned char)kind;
}
void BrewLight_begin(Render *r){
 renderer=r;width=r->width;height=r->height;
 if(width<1||height<1||width>704||height>880){width=height=0;return;}
 memset(surfaces,0,(size_t)width*height*sizeof(Surface));
 if(r==g_app->render){memset(nativePoses,0,sizeof(nativePoses));memset(posedCasters,0,sizeof(posedCasters));}
 else memcpy(posedCasters,nativePoses,sizeof(posedCasters));
 casterTag=-1;weaponCopied=0;fadeLevel=255;
 fx=r->viewCos/65536.f;fy=-r->viewSin/65536.f;rx=-fy;ry=fx;
}
int BrewLight_nativeTarget(void){return g_app&&renderer==g_app->render;}
void BrewLight_fade(int level){fadeLevel=level<fadeLevel?level:fadeLevel;}
void BrewLight_floor(Render *r,int x,int y,int u,int v,int du,int dv,int count,int ceiling){
 if(r!=renderer)return;
 uint32_t uu=(uint32_t)u,vv=(uint32_t)v;
 for(int i=0;i<count;i++,uu+=(uint32_t)du,vv+=(uint32_t)dv)
  put(x+i,y,(int32_t)uu/65536.f,(int32_t)vv/65536.f,(float)(ceiling?r->effCeil:r->effFloor),0,0,ceiling?-1:1,1);
}
void BrewLight_span(Render *r,int x,int y,int count,int projection,int sprite){
 if(r!=renderer||projection<=0||r->shade>=4||(sprite&&r->shade!=0))return;
 float t=(float)(sprite?r->projH:r->projW)/projection;
 float lateral=(2*x+1.f-width)/width;
 float px=r->viewX+(fx+rx*lateral)*t,py=r->viewY+(fy+ry*lateral)*t;
 float nx=-fx,ny=-fy;
 if(!sprite&&r->curLineIdx>=0&&r->curLineIdx<r->numLines){
  Line *l=&r->lines[r->curLineIdx];nx=(float)(l->y2-l->y1);ny=(float)(l->x1-l->x2);
  float n=sqrtf(nx*nx+ny*ny);if(n>0){nx/=n;ny/=n;}
  if(nx*(r->viewX-px)+ny*(r->viewY-py)<0){nx=-nx;ny=-ny;}
 }
 for(int i=0;i<count;i++){
  float z=r->viewZ+(height-2*(y+i)-1.f)*t/width;
  put(x,y+i,px,py,z,nx,ny,0,sprite?3:2);
 }
}
void BrewLight_weapon(Render *r,int x,int y,int count,int blend){
 /* Blended glows contain the background too. Keep its surface/normal so the
  * old bright background is not relit as a solid weapon-shaped overlay. */
 if(r!=renderer||count<=0||(blend>=1&&blend<=7))return;
 if(!weaponCopied){
  size_t pixels=(size_t)width*height;
  if(pixels>weaponCapacity){
   Surface *s=malloc(pixels*sizeof(Surface));uint32_t *b=malloc(pixels*sizeof(uint32_t));
   if(!s||!b){free(s);free(b);return;}
   free(underWeapon);free(weaponBackground);underWeapon=s;weaponBackground=b;weaponCapacity=pixels;
  }
  memcpy(underWeapon,surfaces,pixels*sizeof(Surface));
  for(int yy=0;yy<height;yy++)for(int xx=0;xx<width;xx++){
   uint16_t c=r->framebuffer[yy*(r->fbDib->nPitch/2)+xx];
   weaponBackground[yy*width+xx]=(((c>>11)&31)*255/31)|((((c>>5)&63)*255/63)<<8)|(((c&31)*255/31)<<16)|0xff000000u;
  }
  weaponCopied=1;
 }
 for(int i=0;i<count;i++)put(x,y+i,r->viewX+fx*20,r->viewY+fy*20,r->viewZ-8,-fx,-fy,0,4);
}
void BrewLight_tagCaster(Render *r,Sprite *s){casterTag=s&&r==renderer?(int)(s-r->sprites):-1;}
void BrewLight_poseCaster(Render *r,int x,int y,int z,int tile,int frame,int flags,int mode,int scale){
 if(r!=renderer||casterTag<0||casterTag>=800||mode!=0)return;
 int id=r->sprites[casterTag].info&255;
 if(id==116&&tile!=r->spriteRemap[118])return;
 if(tile!=r->spriteRemap[id]&&!(id==153&&tile==r->spriteRemap[152])&&!(id==116&&tile==r->spriteRemap[118]))return;
 posedCasters[casterTag]=(Caster){x,y,z,64.f*scale/65536.f,tile+frame,(uint32_t)flags,1};
 if(r==g_app->render)nativePoses[casterTag]=posedCasters[casterTag];
}
static int casterEligible(const Sprite *s){
 int tile=s->info&255;
 if((s->info&(0x10000u|0x40000u))||s->renderMode==4||tile<17||tile>=210||tile==137||tile==139||tile==161||tile==192||tile==193||tile==198||tile==206||tile==208)return 0;
 for(unsigned k=0;k<sizeof(sources)/sizeof(sources[0]);k++)if(tile==sources[k].tile&&tile!=116)return 0;
 return 1;
}
static Caster spriteCaster(const Render *r,const Sprite *s){
 int tile=s->info&255;
 return (Caster){s->x,s->y,s->z,(float)s->scale,r->spriteRemap[tile==116?118:tile]+((s->info>>8)&15),s->info,casterEligible(s)};
}
static int casterBlocks(const Render *r,const Caster *s,float ax,float ay,float az,float bx,float by,float bz){
 if(!s->active||s->size<=0||s->frame<0||s->frame>=1500)return 0;
 float nx=bx-s->x,ny=by-s->y;
 if(s->flags&0x180000u){nx=0;ny=1;}else if(s->flags&0x600000u){nx=1;ny=0;}
 float n=sqrtf(nx*nx+ny*ny);if(n<.01f)return 0;nx/=n;ny/=n;
 float dx=bx-ax,dy=by-ay,den=dx*nx+dy*ny;if(fabsf(den)<.0001f)return 0;
 float t=((s->x-ax)*nx+(s->y-ay)*ny)/den;if(t<=.025f||t>=.975f)return 0;
 float lateral=-(ax+t*dx-s->x)*ny+(ay+t*dy-s->y)*nx,z=az+(bz-az)*t;
 int column=(int)floorf((lateral/s->size+.5f)*88),row=(int)floorf((.5f-(z-s->z)/s->size)*88);
 if(column<0||column>=88||row<0||row>=88)return 0;
 if(s->flags&0x1000000u)column=87-column;if(s->flags&0x20000000u)row=87-row;
 int ofs=r->spriteMap[s->frame].ofs;const uint16_t *shape=r->shapeSpans;
 if(ofs<0||ofs+4>=0x16800||column<shape[ofs+2]||column>shape[ofs+3])return 0;
 int at=ofs+4+column-shape[ofs+2];if(at>=0x16800)return 0;
 int run=ofs+2+(int16_t)shape[at];
 for(int i=0;i<90&&run>=0&&run+1<0x16800;i++,run+=2){
  unsigned word=shape[run],start=word&255;if(start==127)return 0;
  if(row>=(int)start&&row<(int)(start+(word>>8)))return 1;
 }
 return 0;
}
int BrewLight_spriteBlocks(const Render *r,const Sprite *s,float ax,float ay,float az,float bx,float by,float bz){
 Caster c=spriteCaster(r,s);return casterBlocks(r,&c,ax,ay,az,bx,by,bz);
}
int BrewLight_visible(const Render *r,float ax,float ay,float az,float bx,float by,float bz){
 float dx=bx-ax,dy=by-ay;
 for(int i=0;i<r->numLines;i++){
  const Line *l=&r->lines[i];if(l->flags&(HIDDEN|NO_DEPTH))continue;
  float ex=(float)(l->x2-l->x1),ey=(float)(l->y2-l->y1),den=dx*ey-dy*ex;
  if(fabsf(den)<.0001f)continue;
  float qx=l->x1-ax,qy=l->y1-ay,t=(qx*ey-qy*ex)/den,u=(qx*dy-qy*dx)/den;
  if(t>.015f&&t<.985f&&u>=0&&u<=1){
   float z=az+(bz-az)*t,bottom=r->effFloor,top=64;
   if(l->flags&0xc0010000u){top=r->ceilHeight;bottom=(l->flags&0x10000u)?r->floorHeight:64;}
   if(z>bottom-.5f&&z<top+.5f)return 0;
  }
 }
 return 1;
}
static void candidate(Light value,float cx,float cy){
 value.radius*=lightDistance/100.f;
 float d=(value.x-cx)*(value.x-cx)+(value.y-cy)*(value.y-cy);
 if(d>value.radius*value.radius*2.25f)return;
 if(numLights<7){lights[numLights++]=value;return;}
 int worst=0;float far=-1;
 for(int i=0;i<7;i++){
  if(lights[i].key>=3000&&lights[i].key<3008&&!(value.key>=3000&&value.key<3008))continue;
  float a=lights[i].x-cx,b=lights[i].y-cy,n=a*a+b*b;if(n>far){far=n;worst=i;}
 }
 if(far>=0&&((value.key>=3000&&value.key<3008)||d<far))lights[worst]=value;
}
/* Wall identities 61/69 contain the small candle in the skull-and-bars niche.
 * The flame is at texel (79,91) of the original 117-square artwork. z1/z2
 * preserve its texture coordinate even on mirrored and repeated segments. */
static void wallCandles(Render *r,const Line *line,int key,float zOffset){
 if(line->flags&HIDDEN)return;
 float dx=line->x2-line->x1,dy=line->y2-line->y1,len=sqrtf(dx*dx+dy*dy),du=line->z2-line->z1;
 if(len<.01f||fabsf(du)<.01f)return;
 int multi=(line->flags&0xc0010000u)!=0;
 float top=multi?r->ceilHeight:64,bottom=multi?((line->flags&0x10000u)?r->floorHeight:64):r->effFloor;
 int dual=multi&&r->ceilHeight>64&&line->texture!=line->texture2,piece=0;
 for(;top>bottom;top-=64,piece++){
  int tile=dual&&piece%2==0?line->texture2:line->texture;
  float z=top-91.f*64/117+zOffset;
  if((tile!=61&&tile!=69)||z<bottom||z>top+zOffset||((line->flags&0x20000u)&&z>r->effCeil))continue;
  float low=fminf(line->z1,line->z2),high=fmaxf(line->z1,line->z2),flame=79.f*64/117;
  int first=(int)ceilf((low-flame)/64),last=(int)floorf((high-flame)/64);
  for(int repeat=first;repeat<=last;repeat++){
   float t=(flame+repeat*64-line->z1)/du;
   for(int side=0;side<((line->flags&1)?2:1);side++){
    float sign=side?-1:1;
    Light l={line->x1+t*dx-sign*dy/len*4,line->y1+t*dy+sign*dx/len*4,z,
     1,.63f,.24f,155,1.4f,1,key+piece*64+(repeat-first)*2+side};
    candidate(l,r->viewX,r->viewY);
   }
  }
  if(!multi)break;
 }
}
/* The same niche also appears as five wall-aligned decorations in map 6.
 * Match Render_drawSpriteAt's orientation, mirroring, width and vertical origin. */
static void spriteWallCandle(Render *r,const Sprite *s,int key){
 int tile=s->info&255;
 if((s->info&0x10000u)||!(s->info&0x40000u)||(tile!=61&&tile!=69)||((s->info&0x80000000u)&&((s->info>>8)&15)>=4))return;
 int half=s->scale/2,reverse=(s->info&0x1000000u)!=0;uint32_t f=s->info;
 Line l={.z1=0,.z2=half*2,.texture=tile,.texture2=tile,.flags=NO_DEPTH|0x20000u};
 if(f&0x4000000u)l.flags|=1;
 if(f&0x180000u){
  int sign=((f&0x80000u)?1:-1)*(reverse?-1:1);
  l.x1=s->x-sign*half;l.x2=s->x+sign*half;l.y1=l.y2=s->y;
 }else if(f&0x600000u){
  int sign=((f&0x200000u)?1:-1)*(reverse?-1:1);
  l.y1=s->y-sign*half;l.y2=s->y+sign*half;l.x1=l.x2=s->x;
 }else{
  float rx=r->viewSin/65536.f,ry=r->viewCos/65536.f,sign=reverse?-1:1;
  l.x1=(int)(s->x-sign*rx*half);l.x2=(int)(s->x+sign*rx*half);
  l.y1=(int)(s->y-sign*ry*half);l.y2=(int)(s->y+sign*ry*half);
 }
 wallCandles(r,&l,key,s->z-32.f);
}
#ifdef OE2_QA_INTERACTIONS
static int wallCandlesEnabled=1;
void BrewLight_qaWallCandles(int enabled){wallCandlesEnabled=enabled!=0;}
int BrewLight_qaCandleGeometry(void){
 Light saved[8];memcpy(saved,lights,sizeof(saved));int oldCount=numLights;
 Render *r=calloc(1,sizeof(Render));r->viewX=64;r->viewY=32;r->ceilHeight=64;
 Line l={.x1=0,.y1=0,.x2=128,.y2=0,.z1=0,.z2=128,.texture=61};
 float flame=79.f*64/117;
 numLights=0;wallCandles(r,&l,10000,0);
 int ok=numLights==2&&fabsf(lights[0].x-flame)<.01f&&lights[0].y==4;
 l.z1=128;l.z2=0;numLights=0;wallCandles(r,&l,10000,0);
 ok&=numLights==2&&fabsf(lights[0].x-(128-flame))<.01f;
 l.flags=1;numLights=0;wallCandles(r,&l,10000,0);ok&=numLights==4&&lights[1].y==-4;
 l.flags=HIDDEN;numLights=0;wallCandles(r,&l,10000,0);ok&=numLights==0;
 l.flags=0;r->effFloor=30;wallCandles(r,&l,10000,0);ok&=numLights==0;
 l.flags=0x10000;l.texture2=69;r->ceilHeight=128;numLights=0;wallCandles(r,&l,10000,0);ok&=numLights==4;
 free(r);memcpy(lights,saved,sizeof(saved));numLights=oldCount;return ok;
}
#endif
static void gather(Render *r){
 numLights=0;
 for(int i=0;i<8;i++){
  const Impact *impact=&impacts[i];int age=g_app->time-impact->time;
  if(!impact->active||impact->map!=g_app->canvas->mapId||age<0||age>=320)continue;
  Light l=impact->light;float decay=1-age/320.f;l.power*=decay*decay;
  candidate(l,r->viewX,r->viewY);
 }
 for(int i=0;i<r->numSprites&&i<800;i++){
  Sprite *s=&r->sprites[i];const Source *p=sourceForSprite(s);if(!p)continue;
  Light l={(float)s->x,(float)s->y,s->z+p->height,p->r,p->g,p->b,p->radius,p->power,p->flicker,i};candidate(l,r->viewX,r->viewY);
 }
 #ifdef OE2_QA_INTERACTIONS
 if(wallCandlesEnabled)
#endif
 {
 for(int i=0;i<r->numLines;i++){
  const Line *l=&r->lines[i];
  if(l->texture==61||l->texture==69||l->texture2==61||l->texture2==69)wallCandles(r,l,10000+i*256,0);
 }
 for(int i=0;i<r->numMapSprites;i++)spriteWallCandle(r,&r->sprites[i],300000+i*256);
 }
 /* Original molten-crack flat 199 is emissive only where that material occurs. */
 for(int i=0;i<1024;i++){
  if(!r->floorTiles[i])continue;
  uintptr_t address=(uintptr_t)r->floorTiles[i],base=(uintptr_t)r->flats;
  if(address<base||address>=base+sizeof(r->flats))continue;
  ptrdiff_t slot=(ptrdiff_t)((address-base)/(4096*sizeof(uint16_t)));
  if(slot>=0&&slot<r->numFlats&&r->flatIds[slot]==199){
   Light l={(i%32)*64.f+32,(i/32)*64.f+32,r->effFloor+4.f,1,.25f,.04f,160,1.0f,1,1000+i};candidate(l,r->viewX,r->viewY);
  }
 }
 for(int i=0;i<numLights;i++)for(int j=i+1;j<numLights;j++)if(lights[j].key<lights[i].key){Light a=lights[i];lights[i]=lights[j];lights[j]=a;}
 Player *p=g_app->player;Canvas *c=g_app->canvas;
 if(p->weapons&&(p->ce.weapon==0||p->ce.weapon==7||p->ce.weapon>=8)){
  int w=p->ce.weapon;float a=(c->viewAngle&1023)*(6.28318530718f/1024);
  Light l={c->viewX+cosf(a)*14,c->viewY-sinf(a)*14,c->viewZ-5.f,1,.62f,.28f,210,1.15f,0,2000};
  if(w==0){l.radius=105;l.power=.28f;}
  if(w==8){l.r=.35f;l.g=.65f;l.b=1;}else if(w==9){l.r=.25f;l.g=1;l.b=.35f;}else if(w==10){l.r=1;l.g=.18f;l.b=.10f;}else if(w==7){l.r=1;l.g=.38f;l.b=.08f;}
  l.radius*=lightDistance/100.f;lights[numLights++]=l;
 }
 uint32_t h=hashWord(2166136261u,(uint32_t)lightDistance);
 for(int i=0;i<r->numLines;i++){
  Line *l=&r->lines[i];h=hashWord(h,(uint32_t)l->x1);h=hashWord(h,(uint32_t)l->y1);h=hashWord(h,(uint32_t)l->x2);h=hashWord(h,(uint32_t)l->y2);h=hashWord(h,l->flags&(HIDDEN|NO_DEPTH|0xc0010000u));
 }
 h=hashWord(h,(uint32_t)r->effFloor);h=hashWord(h,(uint32_t)r->effCeil);
 h=hashWord(h,(uint32_t)r->floorHeight);h=hashWord(h,(uint32_t)r->ceilHeight);
 if(h!=geometryHash){geometryHash=h;memset(wallChecked,0,sizeof(wallChecked));}
 for(int i=0;i<r->numSprites&&i<800;i++){
  casters[i]=spriteCaster(r,&r->sprites[i]);
  if(casters[i].active&&posedCasters[i].active)casters[i]=posedCasters[i];
 }
 for(int j=0;j<numLights;j++){
  casterCount[j]=0;
  for(int i=0;i<r->numSprites&&i<800;i++){
   Caster *c=&casters[i];float dx=c->x-lights[j].x,dy=c->y-lights[j].y,range=lights[j].radius+c->size;
   if(!c->active||dx*dx+dy*dy>range*range)continue;
   lightCasters[j][casterCount[j]++]=i;
   h=hashWord(h,(unsigned)i);h=hashWord(h,(unsigned)(int)c->x);h=hashWord(h,(unsigned)(int)c->y);h=hashWord(h,(unsigned)(int)c->z);h=hashWord(h,(unsigned)c->frame);h=hashWord(h,(unsigned)(int)(c->size*16));h=hashWord(h,c->flags);
  }
 }
 for(int i=0;i<numLights;i++){h=hashWord(h,(uint32_t)lights[i].key);h=hashWord(h,(uint32_t)(int)(lights[i].x/16));h=hashWord(h,(uint32_t)(int)(lights[i].y/16));h=hashWord(h,(uint32_t)(int)(lights[i].z/8));}
 if(h!=cachedHash){cachedHash=h;memset(checked,0,sizeof(checked));}
}
static float visibilityAt(int ix,int iy,int iz,int light,int sprites){
 const Light *l=&lights[light];
 if(ix<0||ix>=128||iy<0||iy>=128||iz<0||iz>=24)return 1;
 int cell=(iz*128+iy)*128+ix;unsigned bit=1u<<light;
 if(!(checked[cell]&bit)){
  float x=ix*16+8.f,y=iy*16+8.f,z=iz*8+4.f;int hits=0,wallHits=0;
  for(int sample=-1;sample<=1;sample++){
   float bx=l->x+sample*3,by=l->y-sample*2;
   int visible=BrewLight_visible(renderer,x,y,z,bx,by,l->z);wallHits+=visible;
   if(visible)for(int i=0;i<casterCount[light];i++)if(casterBlocks(renderer,&casters[lightCasters[light][i]],x,y,z,bx,by,l->z)){visible=0;break;}
   hits+=visible;
  }
  visibility[cell]=(uint16_t)((visibility[cell]&~(3u<<(light*2)))|((unsigned)hits<<(light*2)));checked[cell]|=(unsigned char)bit;
  wallVisibility[cell]=(uint16_t)((wallVisibility[cell]&~(3u<<(light*2)))|((unsigned)wallHits<<(light*2)));
 }
 return (((sprites?visibility[cell]:wallVisibility[cell])>>(light*2))&3)/3.f;
}
static float mixf(float a,float b,float t){return a+(b-a)*t;}
static float shadow(const Surface *s,int light){
 float x=(s->x+s->nx/127.f*2)/16,y=(s->y+s->ny/127.f*2)/16,z=(s->z+s->nz/127.f*2)/8;
 int ix=(int)floorf(x),iy=(int)floorf(y),iz=(int)floorf(z);
 /* Interpolate along the receiver, never through its own wall plane. */
 float a,b;int u,v;
 if(s->nz){a=x-.5f;b=y-.5f;u=(int)floorf(a);v=(int)floorf(b);
  return mixf(mixf(visibilityAt(u,v,iz,light,s->kind!=3),visibilityAt(u+1,v,iz,light,s->kind!=3),a-u),mixf(visibilityAt(u,v+1,iz,light,s->kind!=3),visibilityAt(u+1,v+1,iz,light,s->kind!=3),a-u),b-v);
 }
 if(abs(s->nx)>=abs(s->ny)){a=y-.5f;b=z-.5f;u=(int)floorf(a);v=(int)floorf(b);
  return mixf(mixf(visibilityAt(ix,u,v,light,s->kind!=3),visibilityAt(ix,u+1,v,light,s->kind!=3),a-u),mixf(visibilityAt(ix,u,v+1,light,s->kind!=3),visibilityAt(ix,u+1,v+1,light,s->kind!=3),a-u),b-v);
 }
 a=x-.5f;b=z-.5f;u=(int)floorf(a);v=(int)floorf(b);
 return mixf(mixf(visibilityAt(u,iy,v,light,s->kind!=3),visibilityAt(u+1,iy,v,light,s->kind!=3),a-u),mixf(visibilityAt(u,iy,v+1,light,s->kind!=3),visibilityAt(u+1,iy,v+1,light,s->kind!=3),a-u),b-v);
}
static float wallDistanceAt(int x,int y,int axis,int layer){
 if(x<0||y<0||x>128||y>128)return 40;
 int cell=y*129+x;
 if(!wallChecked[layer][cell]){
  float px=x*16.f,py=y*16.f,best[2]={40*40,40*40};
  for(int i=0;i<renderer->numLines;i++){
   const Line *l=&renderer->lines[i];if(l->flags&(HIDDEN|NO_DEPTH))continue;
   /* Upper wall pieces do not touch the floor beneath them. */
   if(layer<2){
    float z=layer==0?renderer->effFloor:renderer->effCeil,bottom=renderer->effFloor,top=64;
    if(l->flags&0xc0010000u){top=renderer->ceilHeight;bottom=(l->flags&0x10000u)?renderer->floorHeight:64;}
    if(z<bottom-.5f||z>top+.5f)continue;
   }
   float dx=l->x2-l->x1,dy=l->y2-l->y1,den=dx*dx+dy*dy;
   if(den<1)continue;
   float t=clampf(((px-l->x1)*dx+(py-l->y1)*dy)/den,0,1);
   float qx=px-l->x1-dx*t,qy=py-l->y1-dy*t,d=qx*qx+qy*qy;
   int normal=fabsf(dx)>fabsf(dy)?1:0;if(d<best[normal])best[normal]=d;
  }
  wallAxisDistance[layer][0][cell]=sqrtf(best[0]);wallAxisDistance[layer][1][cell]=sqrtf(best[1]);
  wallDistance[layer][cell]=fminf(wallAxisDistance[layer][0][cell],wallAxisDistance[layer][1][cell]);wallChecked[layer][cell]=1;
 }
 return axis<0?wallDistance[layer][cell]:wallAxisDistance[layer][axis][cell];
}
static float roomDistance(const Surface *s,int axis){
 float x=s->x/16,y=s->y/16;int ix=(int)floorf(x),iy=(int)floorf(y);
 int layer=s->nz?(s->nz>0?0:1):2;
 return mixf(mixf(wallDistanceAt(ix,iy,axis,layer),wallDistanceAt(ix+1,iy,axis,layer),x-ix),mixf(wallDistanceAt(ix,iy+1,axis,layer),wallDistanceAt(ix+1,iy+1,axis,layer),x-ix),y-iy);
}
static float contactShade(const Surface *s,int column){
 if(s->kind==4)return 1;
 float distance;
 if(s->nz)distance=roomDistance(s,-1);
 else{
  distance=fminf(fabsf(s->z-renderer->effFloor),fabsf(renderer->effCeil-s->z));
  if(s->kind==2){
   int axis=abs(s->nx)>=abs(s->ny)?1:0;float corner;
   /* Wall x/y and normal are constant down a column. Reuse their distance
    * across rows; floor and ceiling receivers still sample in world space. */
   if(column>=0){
    CornerCache *c=&cornerCache[column];
    if(!c->valid||c->x!=s->x||c->y!=s->y||c->axis!=axis){
     c->x=s->x;c->y=s->y;c->axis=axis;c->distance=roomDistance(s,axis);c->valid=1;
    }
    corner=c->distance;
   }else corner=roomDistance(s,axis);
   distance=fminf(distance,corner);
  }
 }
 float t=clampf(distance/20,0,1);t=t*t*(3-2*t);
 return .35f+.65f*t;
}
#ifdef OE2_LIGHTING_TEST
int BrewLight_testContact(Render *r){
 Render *saved=renderer;renderer=r;memset(wallChecked,0,sizeof(wallChecked));
 Surface floor={.x=64,.y=64,.z=0,.nz=127,.kind=1},far=floor,ceiling=floor;
 far.x=96;ceiling.z=64;ceiling.nz=-127;
 Surface wall={.x=64,.y=64,.z=0,.nx=127,.kind=2},middle=wall,corner=wall;
 middle.z=32;corner.z=32;corner.y=0;
 r->numLines=2;r->lines[1]=(Line){.x1=64,.y1=0,.x2=128,.y2=0,.flags=0x10000};
 int valid=contactShade(&floor,-1)<.36f&&contactShade(&ceiling,-1)<.36f&&contactShade(&far,-1)>.99f;
 valid=valid&&contactShade(&wall,-1)<.36f&&contactShade(&middle,-1)>.99f&&contactShade(&corner,-1)<.36f;
 r->numLines=1;r->lines[0].flags=0x40000000u;r->ceilHeight=r->effCeil=128;memset(wallChecked,0,sizeof(wallChecked));
 valid=valid&&contactShade(&floor,-1)>.99f;
 renderer=saved;memset(wallChecked,0,sizeof(wallChecked));return valid;
}
#endif
static void glow(const Light *l,float flicker){
 /* Screen-space halo is depth-tested against real walls. Held light is lit
  * in weapon space instead, avoiding a floating glow in the camera centre. */
 if(l->key==2000)return;
 float dx=l->x-renderer->viewX,dy=l->y-renderer->viewY,d=dx*fx+dy*fy;
 if(d<12||!BrewLight_visible(renderer,renderer->viewX,renderer->viewY,renderer->viewZ,l->x,l->y,l->z))return;
 float cx=width*.5f+(dx*rx+dy*ry)*width/(2*d),cy=height*.5f-(l->z-renderer->viewZ)*width/(2*d);
 float scale=width/176.f;
 float radius=clampf(width*5.5f/d,1.5f*scale,12*scale),colour[3]={l->r,l->g,l->b};
 int x0=(int)fmaxf(0,cx-radius),x1=(int)fminf(width-1,cx+radius),y0=(int)fmaxf(0,cy-radius),y1=(int)fminf(height-1,cy+radius);
 for(int y=y0;y<=y1;y++)for(int x=x0;x<=x1;x++){
  float ax=(x-cx)/radius,ay=(y-cy)/radius,r2=ax*ax+ay*ay;if(r2>1)continue;
  const Surface *s=&surfaces[y*width+x];
  float receiver=(s->x-renderer->viewX)*fx+(s->y-renderer->viewY)*fy;
  if(s->kind==4||(s->kind&&receiver+12<d))continue;
  float strength=.008f*l->power*flicker*expf(-r2*4)*(fadeLevel/255.f)*(fadeLevel/255.f),out=0;
  uint32_t c=lit[y*width+x],pixel=0xff000000u;
  for(int ch=0;ch<3;ch++){float v=((c>>(ch*8))&255)/255.f;out=sqrtf(fminf(1,v*v+colour[ch]*strength));pixel|=(uint32_t)(out*255+.5f)<<(ch*8);}
  lit[y*width+x]=pixel;
 }
}
static uint32_t shadePixel(const Surface *s,uint32_t c,const float *flicker,int column){
  if(!s->kind)return c;
  float ao=contactShade(s,column),energy[3]={.17f*ao,.20f*ao,.27f*ao};
  for(int j=0;j<numLights;j++){
   const Light *l=&lights[j];float dx=l->x-s->x,dy=l->y-s->y,dz=l->z-s->z,d2=dx*dx+dy*dy+dz*dz;
   if(d2>=l->radius*l->radius)continue;
   float d=sqrtf(d2)+.01f,lambert=clampf((s->nx*dx+s->ny*dy+s->nz*dz)/(127*d),0,1);
   float attenuation=1-d/l->radius;
   float e=attenuation*attenuation*l->power*flicker[j]*2.1f*(.18f+.82f*lambert);
   if(s->kind!=4)e*=shadow(s,j)*(.75f+.25f*ao);
   energy[0]+=l->r*e;energy[1]+=l->g*e;energy[2]+=l->b*e;
  }
  uint32_t out=0xff000000u;
  float depth=(s->x-renderer->viewX)*fx+(s->y-renderer->viewY)*fy;
  float haze=s->kind==4?0:.12f*clampf((depth-128)/384,0,1)*(fadeLevel/255.f),mist[3]={.012f,.022f,.035f};
  for(int ch=0;ch<3;ch++){
   float v=((c>>(ch*8))&255)/255.f,linear=v*v*energy[ch];
   linear=mixf(linear/(1+fmaxf(0,linear-1)*.7f),mist[ch],haze);
   out|=(uint32_t)(clampf(sqrtf(linear),0,1)*255+.5f)<<(ch*8);
  }
  return out;
}
int BrewLight_weaponBottom(void){
 int bottom=-1;for(int i=0;i<width*height;i++)if(surfaces[i].kind==4)bottom=i/width;
 return bottom;
}
static int staffShift(void){
 if(!weaponCopied||!g_app||g_app->player->ce.weapon!=1||g_app->player->isFamiliar||g_app->player->statusEffects[9].turns)return 0;
 int bottom=BrewLight_weaponBottom();return bottom>=0?height-1-bottom:0;
}
static const uint32_t *present(const uint32_t *original,int w,int h,int lighting){
 if(!renderer||w!=width||h!=height)return original;
 int shift=staffShift();if(!lighting&&!shift)return original;
 float flicker[8];
 if(lighting){memset(cornerCache,0,sizeof(cornerCache));gather(renderer);for(int j=0;j<numLights;j++)flicker[j]=lights[j].flicker?(.92f+.06f*sinf(g_app->time*.021f+j*2)+.04f*sinf(g_app->time*.047f+j)):1;}
 for(int i=0,x=0;i<w*h;i++){
  const Surface *s=&surfaces[i];uint32_t c=original[i];
  if(shift&&s->kind==4){s=&underWeapon[i];c=weaponBackground[i];}
  lit[i]=lighting?shadePixel(s,c,flicker,x):c;
  if(++x==w)x=0;
 }
 if(lighting)for(int j=0;j<numLights;j++)glow(&lights[j],flicker[j]);
 if(shift)for(int y=0;y<h-shift;y++)for(int x=0;x<w;x++){
  int i=y*w+x;if(surfaces[i].kind==4)lit[(y+shift)*w+x]=lighting?shadePixel(&surfaces[i],original[i],flicker,x):original[i];
 }
 return lit;
}
const uint32_t *BrewLight_render(const uint32_t *original,int w,int h){return present(original,w,h,1);}
const uint32_t *BrewLight_classic(const uint32_t *original,int w,int h){return present(original,w,h,0);}
