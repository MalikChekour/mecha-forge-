shader_type canvas_item;
render_mode unshaded;
// Ground = a seamless Blender/Gemini tile repeated over WORLD space so it scrolls with
// the camera and stays sharp at any zoom. To hide the "collage" (the visible tile grid
// and the seams between tiles) we DE-TILE: each tile samples a randomly-offset crop of
// the texture and we blend the 4 neighbours smoothly -> boundaries become diffuse and the
// pattern never obviously repeats.
uniform sampler2D ground : repeat_enable, filter_linear_mipmap;
uniform vec2 world_offset = vec2(0.0);
uniform vec2 vp_size = vec2(1280.0, 720.0);
uniform float tile = 1080.0;   // world px covered by one tile

vec4 hash4(vec2 p) {
	return fract(sin(vec4(
		dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)),
		dot(p, vec2(419.2, 371.9)), dot(p, vec2(113.5, 271.9)))) * 43758.5453);
}

// smooth value noise for macro brightness variation (breaks per-tile uniformity)
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash4(i).x;
	float b = hash4(i + vec2(1.0, 0.0)).x;
	float c = hash4(i + vec2(0.0, 1.0)).x;
	float d = hash4(i + vec2(1.0, 1.0)).x;
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// blend 4 randomly-offset crops of the tile -> no visible repeat, seams become diffuse.
// CRITICAL: each crop is sampled with textureGrad using ONE shared gradient taken from the
// continuous coordinate. Plain texture() would let the GPU compute per-quad derivatives
// across the per-cell offset jump, pick a different mip on each side of a cell edge, and
// paint a visible grid of seams every tile. Shared gradients = coherent mip = no grid.
vec4 detile(vec2 uv) {
	vec2 ddx = dFdx(uv);
	vec2 ddy = dFdy(uv);
	// gentle domain-warp: breaks the repeat rhythm without visibly smearing the texture.
	// (textureGrad already kills the hard mip seam, so this only needs to be subtle.)
	vec2 w = vec2(vnoise(uv * 1.7), vnoise(uv * 1.7 + 41.3)) - 0.5;
	uv += w * 0.12;
	vec2 iuv = floor(uv);
	vec2 fuv = fract(uv);
	// NARROW blend band: tile interior stays a single crisp sample, only the cell edges
	// cross-fade. A full-tile gradient (0..1) ghosts all 4 offset copies everywhere.
	vec2 b = smoothstep(0.2, 0.8, fuv);
	vec2 o00 = hash4(iuv + vec2(0.0, 0.0)).xy;
	vec2 o10 = hash4(iuv + vec2(1.0, 0.0)).xy;
	vec2 o01 = hash4(iuv + vec2(0.0, 1.0)).xy;
	vec2 o11 = hash4(iuv + vec2(1.0, 1.0)).xy;
	vec4 c00 = textureGrad(ground, uv + o00, ddx, ddy);
	vec4 c10 = textureGrad(ground, uv + o10, ddx, ddy);
	vec4 c01 = textureGrad(ground, uv + o01, ddx, ddy);
	vec4 c11 = textureGrad(ground, uv + o11, ddx, ddy);
	return mix(mix(c00, c10, b.x), mix(c01, c11, b.x), b.y);
}

void fragment() {
	vec2 world = (UV - 0.5) * vp_size + world_offset;
	vec2 uv = world / tile;
	vec4 c = detile(uv);
	// large-scale, slow brightness drift so no region reads as a repeated stamp
	float macro = 0.82 + 0.28 * vnoise(world / (tile * 3.7));
	float vig = smoothstep(1.25, 0.3, length(UV - 0.5) * 1.45);
	COLOR = vec4(c.rgb * macro * mix(0.62, 1.12, vig), 1.0);
}
