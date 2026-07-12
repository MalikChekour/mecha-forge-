shader_type canvas_item;
render_mode unshaded;
// Samples a seamless Blender-baked GROUND tile, repeated over world space so it scrolls
// with the camera and stays sharp at any zoom (unlike one big arena image).
uniform sampler2D ground : repeat_enable, filter_linear_mipmap;
uniform vec2 world_offset = vec2(0.0);
uniform vec2 vp_size = vec2(1280.0, 720.0);
uniform float tile = 560.0;   // world px covered by one tile

void fragment() {
	vec2 world = (UV - 0.5) * vp_size + world_offset;
	vec4 c = texture(ground, world / tile);
	float vig = smoothstep(1.25, 0.3, length(UV - 0.5) * 1.45);
	COLOR = vec4(c.rgb * mix(0.6, 1.12, vig), 1.0);
}
