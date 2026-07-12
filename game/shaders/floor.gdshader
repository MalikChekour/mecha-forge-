shader_type canvas_item;
render_mode unshaded;

uniform vec2 world_offset = vec2(0.0);
uniform vec2 vp_size = vec2(1280.0, 720.0);
uniform vec4 base_col : source_color = vec4(0.065, 0.08, 0.12, 1.0);
uniform vec4 glow_col : source_color = vec4(0.12, 0.62, 0.82, 1.0);
uniform float biome = 0.0;

float hash12(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}
float hash21(vec2 p) {
	return fract(sin(dot(floor(p), vec2(127.1, 311.7))) * 43758.5453);
}
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash12(i + vec2(0,0)), hash12(i + vec2(1,0)), u.x),
	           mix(hash12(i + vec2(0,1)), hash12(i + vec2(1,1)), u.x), u.y);
}
float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 3; i++) {
		v += a * vnoise(p);
		p = p * 2.07 + vec2(13.1, 7.3);
		a *= 0.5;
	}
	return v;
}
float ridged(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 3; i++) {
		v += a * (1.0 - abs(vnoise(p) * 2.0 - 1.0));
		p = p * 2.03 + vec2(7.1, 3.3);
		a *= 0.5;
	}
	return v;
}

void fragment() {
	vec2 world = (UV - 0.5) * vp_size + world_offset;
	vec3 col = vec3(0.0);

	if (biome < 0.5) {
        // BIOME 0: TECH DECK
        float low = fbm(world * 0.004);
        float high = vnoise(world * 0.08);
        col = mix(vec3(0.02, 0.03, 0.05), vec3(0.09, 0.11, 0.16), low);
        float brush = smoothstep(-0.1, 0.1, sin(world.x * 0.05 + high * 5.0));
        col *= mix(0.85, 1.15, brush);
        float fine = vnoise(world * 0.3 + 50.0);
        col *= mix(0.9, 1.05, fine);
        float n1 = fbm(world * 0.006 + 10.0);
        float n2 = fbm(world * 0.006 + vec2(20.0, 0.0));
        float dist = abs(n1 - 0.5) + abs(n2 - 0.5);
        float filament = smoothstep(0.05, 0.0, dist);
        float pulse = sin(TIME * 1.2 + n1 * 6.28) * 0.5 + 0.5;
        col += glow_col.rgb * filament * (1.0 + pulse * 0.8);

    } else if (biome < 1.5) {
        // BIOME 1: EARTH
        float low = fbm(world * 0.005);
        float stone_mask = smoothstep(0.4, 0.55, fbm(world * 0.008 + 5.0));
        vec3 dirt_col = mix(vec3(0.14, 0.09, 0.05), vec3(0.28, 0.20, 0.11), low);
        vec3 stone_col = mix(vec3(0.35, 0.32, 0.26), vec3(0.48, 0.45, 0.38), fbm(world * 0.02));
        col = mix(dirt_col, stone_col, stone_mask);
        float moss_mask = smoothstep(0.6, 0.7, fbm(world * 0.01 + 12.0));
        vec3 moss_col = mix(vec3(0.08, 0.18, 0.06), vec3(0.14, 0.28, 0.10), fbm(world * 0.04));
        col = mix(col, moss_col, moss_mask);
        float fine = vnoise(world * 0.2);
        col *= mix(0.92, 1.08, fine);
        col += vec3(0.6, 0.4, 0.1) * 0.02;
        
    } else if (biome < 2.5) {
        // BIOME 2: SPACESHIP
        float low = fbm(world * 0.003);
        float med = fbm(world * 0.015);
        col = mix(vec3(0.70, 0.74, 0.80), vec3(0.92, 0.94, 0.98), low);
        float fine = vnoise(world * 0.1);
        col *= mix(0.96, 1.04, fine);
        float panel = smoothstep(0.3, 0.45, med) - smoothstep(0.55, 0.7, med);
        col -= vec3(0.05) * panel;
        float sheen = smoothstep(-0.1, 0.1, sin(world.y * 0.02 + low * 4.0));
        col += vec3(0.05, 0.12, 0.15) * sheen * 0.5;
        
    } else {
        // BIOME 3: VOLCANIC
        float low = fbm(world * 0.005);
        float high = vnoise(world * 0.05);
        col = mix(vec3(0.01, 0.01, 0.02), vec3(0.05, 0.04, 0.04), low);
        col *= mix(0.8, 1.2, high);
        float r1 = ridged(world * 0.008);
        float r2 = ridged(world * 0.008 + vec2(10.0, 10.0));
        float vein = smoothstep(0.72, 0.90, r1) + smoothstep(0.78, 0.94, r2);
        float pulse = pow(sin(TIME * 1.5 + low * 10.0) * 0.5 + 0.5, 1.5);
        vec3 lava_col = mix(vec3(0.9, 0.25, 0.02), vec3(1.0, 0.65, 0.12), pulse);
        col = mix(col, lava_col, clamp(vein, 0.0, 1.0) * (1.0 + pulse * 0.6));
        // ROUND embers (per-cell dot via radial falloff, never square)
        vec2 ec = world * 0.02 + vec2(TIME * 0.4, 0.0);
        vec2 cid = floor(ec);
        vec2 cf = fract(ec) - 0.5;
        float eh = hash12(cid);
        float ember = step(0.986, eh) * smoothstep(0.32, 0.0, length(cf)) * (0.5 + 0.5 * sin(TIME * 7.0 + eh * 40.0));
        col += vec3(1.0, 0.45, 0.12) * ember * 0.7;
    }

	// SOFT RADIAL VIGNETTE
	float vig = smoothstep(1.25, 0.3, length(UV - 0.5) * 1.45);
	col *= mix(0.55, 1.15, vig);

	COLOR = vec4(col, 1.0);
}
