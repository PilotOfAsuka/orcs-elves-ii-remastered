/* Offline filmmaking only. Not linked into the published browser game.
 * Uses the original renderer on a disposable, nonpersistent game instance. */
#include "game.h"
#include "../../host/lighting.h"
#include <emscripten.h>
#include <stdarg.h>
#include <stdio.h>
#include <math.h>
static char survey[262144];static size_t used;
static int savedPose[4],poseActive;
static double poseX,poseY,poseAngle;static float fracX,fracY;
float Film_offsetX(void){return poseActive?fracX:0;}
float Film_offsetY(void){return poseActive?fracY:0;}
void Film_offsetFloor(int *x,int *y){*x+=(int)lrintf(Film_offsetX()*65536);*y+=(int)lrintf(Film_offsetY()*65536);}
void Film_adjustView(Render *r){
 if(!poseActive)return;int index=(int)floor(poseAngle)&1023;double t=poseAngle-floor(poseAngle);
 int sine=(int)lrint(r->sinTable[index]*(1-t)+r->sinTable[(index+1)&1023]*t);
 int cosine=(int)lrint(r->sinTable[(index+256)&1023]*(1-t)+r->sinTable[(index+257)&1023]*t);
 double x=poseX-cosine/4096.0,y=poseY+sine/4096.0;r->viewX=(int)floor(x);r->viewY=(int)floor(y);fracX=(float)(x-r->viewX);fracY=(float)(y-r->viewY);
 r->viewSin=sine;r->viewCos=cosine;r->viewPlane[0]=cosine;r->viewPlane[1]=-sine;r->viewPlane[2]=(int)lrint(-cosine*x+sine*y);
 r->viewPlane[3]=sine;r->viewPlane[4]=cosine;r->viewPlane[5]=(int)lrint(-sine*x-cosine*y);
}
static void add(const char *format,...){va_list a;va_start(a,format);int n=vsnprintf(survey+used,sizeof(survey)-used,format,a);va_end(a);if(n>0){size_t available=sizeof(survey)-used;used+=(size_t)n<available?(size_t)n:available-1;}}
static void name(const String *s){
 add("\"");if(s&&s->buf)for(int i=0;i<s->len;i++){unsigned char c=s->buf[i];if(c=='"'||c=='\\')add("\\%c",c);else if(c>=32&&c<127)add("%c",c);}add("\"");
}
EMSCRIPTEN_KEEPALIVE const char *oe2_film_survey(void){
 used=0;Render *r=g_app->render;add("{\"map\":%d,\"floor\":[",g_app->canvas->mapId);
 for(int i=0;i<1024;i++)add("%s%d",i?",":"",r->floorTiles[i]!=NULL);
 add("],\"lines\":[");for(int i=0;i<r->numLines;i++){Line *l=&r->lines[i];add("%s[%d,%d,%d,%d,%u]",i?",":"",l->x1,l->y1,l->x2,l->y2,l->flags);}
 add("],\"sprites\":[");for(int i=0;i<r->numSprites;i++){
  Sprite *s=&r->sprites[i];EntityDef *d=s->ent?s->ent->def:NULL;
  add("%s{\"id\":%d,\"x\":%d,\"y\":%d,\"z\":%d,\"tile\":%u,\"info\":%u,\"type\":%d,\"name\":",i?",":"",i,s->x,s->y,s->z,s->info&255,s->info,d?d->eType:-1);name(d?&d->name:NULL);
  add(",\"health\":%d}",s->ent&&s->ent->monster?s->ent->monster->ce.health:-1);
 }
 add("]}");return survey;
}
EMSCRIPTEN_KEEPALIVE int oe2_film_clear(int ax,int ay,int bx,int by){return BrewLight_visible(g_app->render,ax,ay,32,bx,by,32);}
EMSCRIPTEN_KEEPALIVE void oe2_film_restore(void){
 if(!poseActive)return;Canvas *c=g_app->canvas;c->viewX=savedPose[0];c->viewY=savedPose[1];c->viewZ=savedPose[2];c->viewAngle=savedPose[3];poseActive=0;
}
EMSCRIPTEN_KEEPALIVE void oe2_film_view(double x,double y,int z,double angle){
 oe2_film_restore();Canvas *c=g_app->canvas;savedPose[0]=c->viewX;savedPose[1]=c->viewY;savedPose[2]=c->viewZ;savedPose[3]=c->viewAngle;poseActive=1;
 poseX=x;poseY=y;poseAngle=angle;
 c->viewX=(int)lrint(x);c->viewY=(int)lrint(y);c->viewZ=z;c->viewAngle=(int)lrint(angle)&1023;
 Canvas_renderView(c,c->viewX,c->viewY,c->viewAngle);
}
