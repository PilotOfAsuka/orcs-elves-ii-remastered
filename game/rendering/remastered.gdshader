shader_type canvas_item;
render_mode unshaded;

uniform vec4 world_rect = vec4(0.0, 0.0, 1.0, 1.0);
uniform bool world_active = false;

bool same(vec4 a, vec4 b) { return distance(a.rgb,b.rgb)<0.003; }

void fragment() {
    vec2 size = 1.0 / TEXTURE_PIXEL_SIZE;
    vec2 cell = floor(UV*size);
    vec2 center = (cell+0.5)/size;
    vec4 e = texture(TEXTURE,center);
    vec4 result = e;
    if (world_active && all(greaterThanEqual(UV,world_rect.xy)) && all(lessThan(UV,world_rect.zw))) {
        vec4 b = texture(TEXTURE,center+vec2(0.0,-TEXTURE_PIXEL_SIZE.y));
        vec4 d = texture(TEXTURE,center-vec2(TEXTURE_PIXEL_SIZE.x,0.0));
        vec4 f = texture(TEXTURE,center+vec2(TEXTURE_PIXEL_SIZE.x,0.0));
        vec4 h = texture(TEXTURE,center+vec2(0.0,TEXTURE_PIXEL_SIZE.y));
        vec2 part = fract(UV*size);
        if (!same(b,h) && !same(d,f)) {
            if (part.x<0.5 && part.y<0.5 && same(d,b)) result=d;
            if (part.x>=0.5 && part.y<0.5 && same(b,f)) result=f;
            if (part.x<0.5 && part.y>=0.5 && same(d,h)) result=d;
            if (part.x>=0.5 && part.y>=0.5 && same(h,f)) result=f;
        }
        vec2 pos=(UV-world_rect.xy)/(world_rect.zw-world_rect.xy);
        float edge=smoothstep(0.35,0.85,distance(pos,vec2(0.5)));
        result.rgb=mix(result.rgb,pow(max(result.rgb,vec3(0.0)),vec3(0.94)),0.4);
        result.rgb*=vec3(1.035,1.012,0.985)*(1.0-edge*0.075);
    }
    COLOR=result;
}
