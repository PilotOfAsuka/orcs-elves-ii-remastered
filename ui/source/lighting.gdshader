shader_type canvas_item;
render_mode unshaded;

// All inputs are byte textures; mobile WebGL needs no float render targets.
uniform sampler2D surface_xy : filter_nearest, repeat_disable;
uniform sampler2D surface_zna : filter_nearest, repeat_disable;
uniform sampler2D shadow_field : filter_nearest, repeat_disable;
uniform sampler2D contact_field : filter_nearest, repeat_disable;
uniform vec4 camera; // xyz and fade
uniform vec2 forward_axis;
uniform vec3 processing; // player xy and circular reach
uniform vec2 raster_size;
uniform vec2 floor_ceiling;
uniform int light_count;
uniform vec4 source_position[8];
uniform vec4 source_colour[8];
uniform vec4 source_halo[8];

uvec4 bytes(vec4 value) { return uvec4(floor(value*255.0+0.5)); }
vec3 normal_vector(uint code) {
	if (code == 248u) return vec3(0.0,0.0,1.0);
	if (code == 249u) return vec3(0.0,0.0,-1.0);
	if (code == 251u) return vec3(-forward_axis,0.0);
	if (code == 0u) return vec3(1.0,0.0,0.0);
	if (code == 62u) return vec3(0.0,1.0,0.0);
	if (code == 124u) return vec3(-1.0,0.0,0.0);
	if (code == 186u) return vec3(0.0,-1.0,0.0);
	if (code%62u == 31u) return vec3((code==31u || code==217u) ? 0.70710678118 : -0.70710678118,code<124u ? 0.70710678118 : -0.70710678118,0.0);
	float a=float(code)*(6.28318530718/248.0);
	return vec3(cos(a),sin(a),0.0);
}
float visibility_at(ivec3 cell,int light,bool sprites) {
	if (any(lessThan(cell,ivec3(0))) || any(greaterThanEqual(cell,ivec3(128,128,24)))) return 1.0;
	int index=(cell.z*128+cell.y)*128+cell.x;
	uvec4 v=bytes(texelFetch(shadow_field,ivec2(index&1023,index>>10),0));
	uint bits=sprites ? v.r+(v.g<<8u) : v.b+(v.a<<8u);
	return float((bits>>uint(light*2))&3u)/3.0;
}
float shadow(vec3 position,vec3 normal,int light,bool sprites,bool axis_x,int plane_delta) {
	vec3 p=(position+normal*2.0)/vec3(16.0,16.0,8.0);
	ivec3 i=ivec3(floor(p));
	vec2 uv;
	ivec3 base,du,dv;
	if (normal.z!=0.0) {
		uv=p.xy-vec2(0.5);base=ivec3(ivec2(floor(uv)),i.z);du=ivec3(1,0,0);dv=ivec3(0,1,0);
	} else if (axis_x) {
		uv=p.yz-vec2(0.5);base=ivec3(i.x+plane_delta,int(floor(uv.x)),int(floor(uv.y)));du=ivec3(0,1,0);dv=ivec3(0,0,1);
	} else {
		uv=p.xz-vec2(0.5);base=ivec3(int(floor(uv.x)),i.y+plane_delta,int(floor(uv.y)));du=ivec3(1,0,0);dv=ivec3(0,0,1);
	}
	vec2 t=fract(uv);
	return mix(mix(visibility_at(base,light,sprites),visibility_at(base+du,light,sprites),t.x),mix(visibility_at(base+dv,light,sprites),visibility_at(base+du+dv,light,sprites),t.x),t.y);
}
float contact_distance(ivec2 cell,int layer,int axis) {
	if (any(lessThan(cell,ivec2(0))) || any(greaterThan(cell,ivec2(128)))) return 40.0;
	uvec4 b=bytes(texelFetch(contact_field,ivec2(cell.x,layer*129+cell.y),0));
	uint value=b.r+(b.g<<8u)+(b.b<<16u)+(b.a<<24u);
	return float((value>>uint(axis*9))&511u)*(40.0/511.0);
}
float contact_shade(vec3 position,uint code,bool sprites,bool axis_x) {
	if (code==251u) return 1.0;
	float distance=min(abs(position.z-floor_ceiling.x),abs(floor_ceiling.y-position.z));
	if (code>=248u || sprites) {
		int layer=code>=248u ? (code==248u ? 0 : 1) : 2;
		int axis=code>=248u ? 2 : (axis_x ? 1 : 0);
		vec2 p=position.xy/16.0,t=fract(p);ivec2 cell=ivec2(floor(p));
		float room=mix(mix(contact_distance(cell,layer,axis),contact_distance(cell+ivec2(1,0),layer,axis),t.x),mix(contact_distance(cell+ivec2(0,1),layer,axis),contact_distance(cell+ivec2(1,1),layer,axis),t.x),t.y);
		distance=code>=248u ? room : min(room,distance);
	}
	float t=clamp(distance/20.0,0.0,1.0);return 0.35+0.65*t*t*(3.0-2.0*t);
}
void fragment() {
	vec4 original=texture(TEXTURE,UV);
	uvec4 xy=bytes(texture(surface_xy,UV)),meta=bytes(texture(surface_zna,UV));
	uint code=meta.b;
	vec3 result=original.rgb;
	vec3 position=vec3(float(xy.r+(xy.g<<8u)),float(xy.b+(xy.a<<8u)),float(meta.r+(meta.g<<8u)))/16.0-vec3(1024.0);
	if ((meta.a&32u)!=0u) {
		int source=int((meta.a>>2u)&7u);
		position=source_position[source].xyz+vec3(float(xy.r+(xy.g<<8u)),float(xy.b+(xy.a<<8u)),float(meta.r+(meta.g<<8u)))/16384.0-vec3(2.0);
	}
	vec3 normal=normal_vector(code);
	bool weapon=code==251u,receiver=code!=250u,sprites=(meta.a&128u)==0u;
	bool axis_x=(meta.a&64u)!=0u;int plane_delta=int(meta.a&3u)-1;
	float depth=dot(position.xy-camera.xy,forward_axis);
	if (receiver) {
		float ao=contact_shade(position,code,sprites,axis_x);
		vec3 energy=vec3(0.17,0.20,0.27)*ao;
		float distance_to_player=length(position.xy-processing.xy);
		float t=clamp((processing.z-distance_to_player)/64.0,0.0,1.0);
		float weight=weapon ? 1.0 : t*t*(3.0-2.0*t);
		if (weight>0.0) for (int j=0;j<8;j++) {
			if (j>=light_count) break;
			vec3 delta=source_position[j].xyz-position;
			float d2=dot(delta,delta),radius=source_position[j].w;
			if (d2>=radius*radius) continue;
			float d=sqrt(d2)+0.01,lambert=clamp(dot(normal,delta)/d,0.0,1.0),attenuation=1.0-d/radius;
			float e=weight*attenuation*attenuation*source_colour[j].a*(0.18+0.82*lambert);
			if (!weapon) e*=shadow(position,normal,j,sprites,axis_x,plane_delta)*(0.75+0.25*ao);
			energy+=source_colour[j].rgb*e;
		}
		vec3 linear=original.rgb*original.rgb*energy;
		linear=linear/(vec3(1.0)+max(vec3(0.0),linear-vec3(1.0))*0.7);
		float haze=weapon ? 0.0 : 0.12*clamp((depth-128.0)/384.0,0.0,1.0)*camera.w;
		result=clamp(sqrt(mix(linear,vec3(0.012,0.022,0.035),haze)),vec3(0.0),vec3(1.0));
		// Match the original byte output before the additive halo pass.
		result=floor(result*255.0+0.5)/255.0;
	}
	for (int j=0;j<8;j++) {
		if (j>=light_count) break;
		vec4 halo=source_halo[j];
		if (halo.w<=0.0 || weapon) continue;
		float source_depth=dot(source_position[j].xy-camera.xy,forward_axis);
		if (receiver && depth+12.0<source_depth) continue;
		vec2 pixel=floor(UV*raster_size);
		vec2 offset=(pixel-halo.xy)/halo.z;float r2=dot(offset,offset);
		if (r2>1.0) continue;
		result=sqrt(min(vec3(1.0),result*result+source_colour[j].rgb*halo.w*exp(-r2*4.0)));
		result=floor(result*255.0+0.5)/255.0;
	}
	COLOR=vec4(result,1.0);
}
