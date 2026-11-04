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
static float wallDistance[128*128];
static unsigned char wallChecked[128*128];
static Light lights[8];
static int width,height,numLights,fadeLevel=255;
static Render *renderer;
static float fx,fy,rx,ry;
static float clampf(float x,float a,float b){return x<a?a:x>b?b:x;}
static uint32_t hashWord(uint32_t h,uint32_t n){return (h^n)*16777619u;}
static const Source *sourceForSprite(const Sprite *s){
 if(s->info&(0x10000u|0x40000u))return NULL;
 int tile=s->info&255;
 /* Native tile 116 draws its flaming meat only while this entity bit is set. */
 if(tile==116&&(!s->ent||!(s->ent->info&0x4000000u)))return NULL;
 for(unsigned i=0;i<sizeof(sources)/sizeof(sources[0]);i++)if(tile==sources[i].tile)return &sources[i];
 return NULL;
}
int BrewLight_spriteEmits(const Sprite *s){return sourceForSprite(s)!=NULL;}
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
 if(r!=renderer||projection<=0||r->shade>=4)return;
 float t=(float)(sprite?r->projH:r->projW)/projection;
 float lateral=(2*x+1.f-width)/width;
 float px=r->viewX+(fx+rx*lateral)*t,py=r->viewY+(fy+ry*lateral)*t;
 float nx=-fx,ny=-fy;
 if(r->curLineIdx>=0&&r->curLineIdx<r->numLines){
  Line *l=&r->lines[r->curLineIdx];nx=(float)(l->y2-l->y1);ny=(float)(l->x1-l->x2);
  float n=sqrtf(nx*nx+ny*ny);if(n>0){nx/=n;ny/=n;}
  if(nx*(r->viewX-px)+ny*(r->viewY-py)<0){nx=-nx;ny=-ny;}
 }
 for(int i=0;i<count;i++){
  float z=r->viewZ+(height-2*(y+i)-1.f)*t/width;
  put(x,y+i,px,py,z,nx,ny,0,sprite?3:2);
 }
}
void BrewLight_weapon(Render *r,int x,int y,int count){
 if(r!=renderer||count<=0)return;
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
   float z=az+(bz-az)*t,top=(l->flags&0x10000u)?r->effCeil:64;
   if(z>r->effFloor-.5f&&z<top+.5f)return 0;
  }
 }
 return 1;
}
static void candidate(Light value,float cx,float cy){
 float d=(value.x-cx)*(value.x-cx)+(value.y-cy)*(value.y-cy);
 if(d>value.radius*value.radius*2.25f)return;
 if(numLights<7){lights[numLights++]=value;return;}
 int worst=0;float far=-1;
 for(int i=0;i<7;i++){float a=lights[i].x-cx,b=lights[i].y-cy,n=a*a+b*b;if(n>far){far=n;worst=i;}}
 if(d<far)lights[worst]=value;
}
static void gather(Render *r){
 numLights=0;
 for(int i=0;i<r->numSprites&&i<800;i++){
  Sprite *s=&r->sprites[i];const Source *p=sourceForSprite(s);if(!p)continue;
  Light l={(float)s->x,(float)s->y,s->z+p->height,p->r,p->g,p->b,p->radius,p->power,p->flicker,i};candidate(l,r->viewX,r->viewY);
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
 if(p->weapons&&(p->ce.weapon==0||p->ce.weapon>=8)){
  int w=p->ce.weapon;float a=(c->viewAngle&1023)*(6.28318530718f/1024);
  Light l={c->viewX+cosf(a)*14,c->viewY-sinf(a)*14,c->viewZ-5.f,1,.62f,.28f,210,1.15f,0,2000};
  if(w==8||w==9){l.r=.28f;l.g=1;l.b=.37f;}else if(w==10){l.r=.4f;l.g=.65f;l.b=1;}
  lights[numLights++]=l;
 }
 uint32_t h=2166136261u;
 for(int i=0;i<r->numLines;i++){
  Line *l=&r->lines[i];h=hashWord(h,(uint32_t)l->x1);h=hashWord(h,(uint32_t)l->y1);h=hashWord(h,(uint32_t)l->x2);h=hashWord(h,(uint32_t)l->y2);h=hashWord(h,l->flags&(HIDDEN|NO_DEPTH|0x10000u));
 }
 h=hashWord(h,(uint32_t)r->effFloor);h=hashWord(h,(uint32_t)r->effCeil);
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
static float wallDistanceAt(int x,int y){
 if(x<0||y<0||x>=128||y>=128)return 40;
 int cell=y*128+x;
 if(!wallChecked[cell]){
  float px=x*16+8.f,py=y*16+8.f,best=40*40;
  for(int i=0;i<renderer->numLines;i++){
   const Line *l=&renderer->lines[i];if(l->flags&(HIDDEN|NO_DEPTH))continue;
   float dx=l->x2-l->x1,dy=l->y2-l->y1,den=dx*dx+dy*dy;
   if(den<1)continue;
   float t=clampf(((px-l->x1)*dx+(py-l->y1)*dy)/den,0,1);
   float qx=px-l->x1-dx*t,qy=py-l->y1-dy*t,d=qx*qx+qy*qy;
   if(d<best)best=d;
  }
  wallDistance[cell]=sqrtf(best);wallChecked[cell]=1;
 }
 return wallDistance[cell];
}
static float contactShade(const Surface *s){
 if(s->kind==4)return 1;
 float distance;
 if(s->nz){
  float x=s->x/16-.5f,y=s->y/16-.5f;int ix=(int)floorf(x),iy=(int)floorf(y);
  distance=mixf(mixf(wallDistanceAt(ix,iy),wallDistanceAt(ix+1,iy),x-ix),mixf(wallDistanceAt(ix,iy+1),wallDistanceAt(ix+1,iy+1),x-ix),y-iy);
 }else distance=fminf(fabsf(s->z-renderer->effFloor),fabsf(renderer->effCeil-s->z))*2;
 return .78f+.22f*clampf(distance/32,0,1);
}
static void glow(const Light *l,float flicker){
 /* Screen-space halo is depth-tested against real walls. Held light is lit
  * in weapon space instead, avoiding a floating glow in the camera centre. */
 if(l->key==2000)return;
 float dx=l->x-renderer->viewX,dy=l->y-renderer->viewY,d=dx*fx+dy*fy;
 if(d<12||!BrewLight_visible(renderer,renderer->viewX,renderer->viewY,renderer->viewZ,l->x,l->y,l->z))return;
 float cx=width*.5f+(dx*rx+dy*ry)*width/(2*d),cy=height*.5f-(l->z-renderer->viewZ)*width/(2*d);
 float radius=clampf(width*12.f/d,5,28),colour[3]={l->r,l->g,l->b};
 int x0=(int)fmaxf(0,cx-radius),x1=(int)fminf(width-1,cx+radius),y0=(int)fmaxf(0,cy-radius),y1=(int)fminf(height-1,cy+radius);
 for(int y=y0;y<=y1;y++)for(int x=x0;x<=x1;x++){
  float ax=(x-cx)/radius,ay=(y-cy)/radius,r2=ax*ax+ay*ay;if(r2>1)continue;
  const Surface *s=&surfaces[y*width+x];
  float receiver=(s->x-renderer->viewX)*fx+(s->y-renderer->viewY)*fy;
  if(s->kind==4||(s->kind&&receiver+12<d))continue;
  float strength=.018f*l->power*flicker*expf(-r2*4)*(fadeLevel/255.f)*(fadeLevel/255.f),out=0;
  uint32_t c=lit[y*width+x],pixel=0xff000000u;
  for(int ch=0;ch<3;ch++){float v=((c>>(ch*8))&255)/255.f;out=sqrtf(fminf(1,v*v+colour[ch]*strength));pixel|=(uint32_t)(out*255+.5f)<<(ch*8);}
  lit[y*width+x]=pixel;
 }
}
static uint32_t shadePixel(const Surface *s,uint32_t c,const float *flicker){
  if(!s->kind)return c;
  float ao=contactShade(s),energy[3]={.60f*ao,.62f*ao,.68f*ao};
  for(int j=0;j<numLights;j++){
   const Light *l=&lights[j];float dx=l->x-s->x,dy=l->y-s->y,dz=l->z-s->z,d2=dx*dx+dy*dy+dz*dz;
   if(d2>=l->radius*l->radius)continue;
   float d=sqrtf(d2)+.01f,lambert=clampf((s->nx*dx+s->ny*dy+s->nz*dz)/(127*d),0,1);
   float attenuation=1-d/l->radius;
   float e=attenuation*attenuation*l->power*flicker[j]*(.18f+.82f*lambert);
   if(s->kind!=4)e*=shadow(s,j);
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
 if(lighting){gather(renderer);for(int j=0;j<numLights;j++)flicker[j]=lights[j].flicker?(.92f+.06f*sinf(g_app->time*.021f+j*2)+.04f*sinf(g_app->time*.047f+j)):1;}
 for(int i=0;i<w*h;i++){
  const Surface *s=&surfaces[i];uint32_t c=original[i];
  if(shift&&s->kind==4){s=&underWeapon[i];c=weaponBackground[i];}
  lit[i]=lighting?shadePixel(s,c,flicker):c;
 }
 if(lighting)for(int j=0;j<numLights;j++)glow(&lights[j],flicker[j]);
 if(shift)for(int y=0;y<h-shift;y++)for(int x=0;x<w;x++){
  int i=y*w+x;if(surfaces[i].kind==4)lit[(y+shift)*w+x]=lighting?shadePixel(&surfaces[i],original[i],flicker):original[i];
 }
 return lit;
}
const uint32_t *BrewLight_render(const uint32_t *original,int w,int h){return present(original,w,h,1);}
const uint32_t *BrewLight_classic(const uint32_t *original,int w,int h){return present(original,w,h,0);}
