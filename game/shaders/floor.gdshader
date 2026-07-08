shader_type canvas_item;
render_mode unshaded;
// Procedural sci-fi deck: metal panels, glowing seams, rivet grid, vignette.
// Pattern is anchored in WORLD space via world_offset so it scrolls under the
// player. gl_compatibility / mobile safe (no fwidth, no derivatives).

uniform vec2 world_offset = vec2(0.0);
uniform vec2 vp_size = vec2(1280.0, 720.0);
uniform vec4 base_col : source_color = vec4(0.065, 0.08, 0.12, 1.0);
uniform vec4 seam_col : source_color = vec4(0.12, 0.62, 0.82, 1.0);

float linegrid(vec2 world, float cell, float thick) {
	vec2 f = abs(fract(world / cell + 0.5) - 0.5) * cell;
	float d = min(f.x, f.y);
	return 1.0 - smoothstep(0.0, thick, d);
}
float rnd(vec2 p) {
	return fract(sin(dot(floor(p), vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 world = (UV - 0.5) * vp_size + world_offset;
	vec3 col = base_col.rgb;
	col *= 0.85 + rnd(world / 256.0) * 0.5;                  // per-panel value variation
	col = mix(col, base_col.rgb * 0.6, linegrid(world, 64.0, 1.5) * 0.45);  // fine rivet grid
	float seam = linegrid(world, 256.0, 3.0);
	col = mix(col, base_col.rgb * 0.3, seam * 0.7);         // panel groove
	col += seam_col.rgb * linegrid(world, 256.0, 1.4) * 0.4;                // glowing seam
	float vig = smoothstep(1.22, 0.28, length(UV - 0.5) * 1.42);
	col *= mix(0.62, 1.1, vig);
	COLOR = vec4(col, 1.0);
}
