shader_type canvas_item;

uniform vec2 vp_size;
uniform vec2 world_offset;
uniform float time;
uniform float tile = 1080.0;
uniform vec4 grid_color_1 : source_color = vec4(0.0, 1.0, 0.8, 1.0);
uniform vec4 grid_color_2 : source_color = vec4(0.6, 0.0, 1.0, 1.0);
uniform vec4 bg_color : source_color = vec4(0.02, 0.02, 0.05, 1.0);

void fragment() {
	vec2 world = (UV - 0.5) * vp_size + world_offset;
	
	// Create a grid pattern
	float grid_size = 150.0;
	vec2 grid = fract(world / grid_size);
	
	// Lines
	float line_width = 0.03;
	float line_x = step(1.0 - line_width, grid.x);
	float line_y = step(1.0 - line_width, grid.y);
	float line = clamp(line_x + line_y, 0.0, 1.0);
	
	// Animated scanning band
	float scan = fract(world.y / 1200.0 - time * 0.5);
	float scan_intensity = smoothstep(0.9, 1.0, scan);
	
	// Base grid color
	vec4 col = mix(bg_color, grid_color_1, line * 0.5);
	
	// Add scan color
	col += grid_color_2 * scan_intensity * line;
	
	// Add vignette
	float vig = smoothstep(1.25, 0.3, length(UV - 0.5) * 1.45);
	COLOR = vec4(col.rgb * vig, 1.0);
}
