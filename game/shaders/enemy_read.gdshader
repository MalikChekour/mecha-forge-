shader_type canvas_item;
// LEGIBILITY pass for premium (dark, high-detail) enemy sprites on busy corrupted
// terrain. Three jobs, all mobile / gl_compatibility safe:
//   1. a bright OUTER OUTLINE seals the silhouette so the threat reads on ANY biome
//      (dark jungle/swamp/volcanic where near-black bodies used to vanish).
//   2. a shadow LIFT + brightness BOOST keeps near-black chassis (crusher, eyedrone)
//      from melting into dark ground.
//   3. the hit-flash (flash uniform, pushed by Enemy.gd) is preserved.
uniform float flash : hint_range(0.0, 1.0) = 0.0;
// TELEGRAPHE d'attaque, distinct du flash de coup recu.
// 🚨 Les deux passaient par le meme uniforme `flash` (= blanc). Consequence relevee en test :
// « sept ennemis virant au blanc en meme temps transforment un pan de l'ecran en taches
// indifferenciees », et le signal de charge du taureau, lui aussi blanc/rouge sur un mecha deja
// magenta, se perdait dans la foule. Le telegraphe a maintenant SA couleur, et il prime.
uniform float warn : hint_range(0.0, 1.0) = 0.0;
// 🚨 tente le 26/09 : "instance uniform" pour partager UN materiau entre tous les ennemis
// (batching). Rejete : ce build Godot 4.3 rend "Uniform instances are not yet implemented for
// 'canvas_item' shaders" (echec de compilation) + Sprite2D n'a pas set_instance_shader_parameter.
// Fonctionnalite absente de cette version -> reste en uniform PLEIN, un ShaderMaterial par ennemi.
uniform vec4 warn_color : source_color = vec4(1.0, 0.13, 0.10, 1.0);
uniform vec4 outline_color : source_color = vec4(0.04, 0.05, 0.07, 0.50);  // subtle DARK edge (was a warm/yellow rim the patron disliked)
uniform float outline_w = 1.25;    // outline width in texels (thin ink edge)
uniform float lift = 0.10;         // raise shadows (added to opaque body)
uniform float boost = 1.12;        // brighten body
uniform float edge_min = 0.55;     // ignore faint/antialiased alpha -> no fuzzy specks

void fragment() {
	vec2 ps = TEXTURE_PIXEL_SIZE * outline_w;
	vec4 c = texture(TEXTURE, UV);
	float a = c.a;
	// 8-tap neighbour alpha for the outline test
	float na = max(
		max(max(texture(TEXTURE, UV + vec2(ps.x, 0.0)).a, texture(TEXTURE, UV + vec2(-ps.x, 0.0)).a),
			max(texture(TEXTURE, UV + vec2(0.0, ps.y)).a, texture(TEXTURE, UV + vec2(0.0, -ps.y)).a)),
		max(max(texture(TEXTURE, UV + vec2(ps.x, ps.y)).a, texture(TEXTURE, UV + vec2(-ps.x, -ps.y)).a),
			max(texture(TEXTURE, UV + vec2(ps.x, -ps.y)).a, texture(TEXTURE, UV + vec2(-ps.x, ps.y)).a)));
	if (a < 0.25 && na > edge_min) {
		// transparent pixel hugging a SOLID body edge -> paint the (thin, soft) outline
		vec3 oc = mix(outline_color.rgb, vec3(1.0), flash);
		oc = mix(oc, warn_color.rgb, warn);
		COLOR = vec4(oc, max(outline_color.a, warn));
	} else {
		vec3 body = c.rgb * boost + lift * step(0.02, a);
		body = mix(body, vec3(1.0), flash);
		body = mix(body, warn_color.rgb, warn);   // le telegraphe ecrase le flash de coup
		COLOR = vec4(clamp(body, 0.0, 1.0), c.a);
	}
}
