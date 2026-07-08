shader_type canvas_item;
// Cinematic edge darkening over the whole scene (below the HUD).
uniform float strength : hint_range(0.0, 1.0) = 0.5;
void fragment() {
	float v = length(UV - 0.5) * 1.42;
	float a = smoothstep(0.5, 1.08, v) * strength;
	COLOR = vec4(0.01, 0.01, 0.03, a);
}
