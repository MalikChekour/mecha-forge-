shader_type canvas_item;
render_mode unshaded;

uniform vec2 world_offset = vec2(0.0);
uniform vec2 vp_size = vec2(1280.0, 720.0);
uniform vec4 base_col : source_color = vec4(0.065, 0.08, 0.12, 1.0);
uniform vec4 glow_col : source_color = vec4(0.12, 0.62, 0.82, 1.0);

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
float line_g(vec2 world, float cell, float thick) {
	vec2 f = abs(fract(world / cell + 0.5) - 0.5) * cell;
	float d = min(f.x, f.y);
	return 1.0 - smoothstep(0.0, thick, d);
}
float voro_dist(vec2 world, float cell) {
	vec2 g = floor(world / cell);
	vec2 f = fract(world / cell);
	float md = 10.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 offset = vec2(float(x), float(y));
			float h = hash21(g + offset);
			if (h < 0.66) continue;
			vec2 point = offset + vec2(h, fract(h * 137.3)) - f;
			md = min(md, 0.5 * dot(point, point));
		}
	}
	return sqrt(max(md, 0.0));
}

void fragment() {
	vec2 world = (UV - 0.5) * vp_size + world_offset;
	vec3 col = base_col.rgb;

	// 1. Wear & Grime
	float grime = fbm(world * 0.008 + vec2(10.0));
	float scuffs = fbm(world * 0.02);
	col *= mix(0.75, 1.15, grime) * mix(0.9, 1.05, scuffs);

	// 2. Base Hex Tech Accents
	float hd = abs(dot(vec2(1.0, 0.577), fract(world * 0.04 + vec2(0.0, 0.288)) - 0.5) - 0.0);
	hd = min(hd, abs(dot(vec2(1.0, 0.577), fract(world * 0.04) - 0.5)));
	float hex_mask = smoothstep(0.02, 0.005, hd);
	col = mix(col, col * 1.4 + base_col.rgb * 0.05, hex_mask * 0.4);

	// 3. Large Panels (Different Sizes & Variations)
	float p128 = line_g(world, 128.0, 2.5);
	float p256 = line_g(world, 256.0, 3.5);
	float large_groove = max(p128, p256);
	col = mix(col, col * 0.45, large_groove * 0.8);

	// Faces variation
	float p_val = hash21(floor(world / 128.0));
	col *= mix(0.85, 1.15, p_val);

	// 4. Fine Rivets
	float riv = line_g(world, 32.0, 0.75);
	col = mix(col, col * 0.7, riv * 0.6);

	// 5. Glowing Energy Conduits (along seams)
	vec2 g_id = floor(world / 256.0);
	float g1 = hash21(g_id);
	float g2 = hash21(g_id + 0.123);

	float pulse = sin(TIME * 1.5 + (g_id.x + g_id.y) * 1.3) * 0.5 + 0.5;
	pulse = pow(pulse, 2.0);

	vec2 f256 = abs(fract(world / 256.0 + 0.5) - 0.5) * 256.0;

	float line_v = 0.0;
	if (g1 > 0.65) {
		float intensity = (g1 - 0.65) / 0.35;
		float d = f256.x;
		line_v += smoothstep(2.5, 0.0, d) * intensity;
	}
	if (g2 > 0.7) {
		float intensity = (g2 - 0.7) / 0.3;
		float d = f256.y;
		line_v += smoothstep(2.5, 0.0, d) * intensity;
	}

	float dot_h = hash21(floor(world / 128.0) + 0.5);
	float nodes = voro_dist(world, 128.0);
	if (dot_h > 0.9) {
		line_v += smoothstep(5.0, 0.0, nodes * 128.0) * ((dot_h - 0.9) / 0.1) * 2.0;
	}
	col += glow_col.rgb * line_v * (0.8 + pulse * 0.6);

	// 6. Soft Radial Vignette
	float vig = smoothstep(1.25, 0.3, length(UV - 0.5) * 1.45);
	col *= mix(0.55, 1.15, vig);

	COLOR = vec4(col, 1.0);
}
