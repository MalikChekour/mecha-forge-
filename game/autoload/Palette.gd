extends Node
## Shared color palette (mirror of the bpy render palette in tools/build_mecha.py).
## Used as tints for procedural placeholders when a rendered sprite is missing.

const STEEL: Color = Color(0.34, 0.40, 0.52)
const STEEL_DK: Color = Color(0.17, 0.21, 0.30)
const ACCENT: Color = Color(0.10, 0.55, 0.95)
const CYAN: Color = Color(0.10, 0.85, 1.00)
const GUNMETAL: Color = Color(0.14, 0.15, 0.19)
const ARENA_BG: Color = Color(0.06, 0.055, 0.10)
const BONUS: Color = Color(1.0, 0.82, 0.30)   # gold — bonus caches / their pickups

## Per-biome decor tint. The 3D decor bakes are grey; multiplying a sprite by its
## biome tint "paints" props and scenery into the environment (harmonised) instead of
## leaving them default grey, while staying bright enough not to camouflage.
const BIOME_TINT: Dictionary = {
	"tech":      Color(0.72, 0.83, 1.00),
	"earth":     Color(1.00, 0.83, 0.58),
	"spaceship": Color(0.87, 0.91, 0.99),
	"volcanic":  Color(1.00, 0.60, 0.46),
	"desert":    Color(1.00, 0.86, 0.56),
	"ice":       Color(0.80, 0.93, 1.00),
	"jungle":    Color(0.70, 0.94, 0.62),
	"swamp":     Color(0.76, 0.84, 0.54),
}

static func biome_tint(name: String) -> Color:
	return BIOME_TINT.get(name, Color(0.86, 0.89, 0.96))
