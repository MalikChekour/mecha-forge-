shader_type canvas_item;
// Flash-to-white on hit, tinted glow otherwise. Cheap, mobile/gl_compatibility safe.
uniform float flash : hint_range(0.0, 1.0) = 0.0;
uniform float warn : hint_range(0.0, 1.0) = 0.0;                        // telegraphe d'attaque
uniform vec4 warn_color : source_color = vec4(1.0, 0.13, 0.10, 1.0);

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	c.rgb = mix(c.rgb, vec3(1.0, 1.0, 1.0), flash);
	c.rgb = mix(c.rgb, warn_color.rgb, warn);
	COLOR = c;
}
