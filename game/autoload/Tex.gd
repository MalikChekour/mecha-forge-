extends Node
## Robust texture loader with graceful fallback (pattern proven in the reference
## project). If a rendered part/weapon sprite is missing or not yet imported, we
## synthesize a colored placeholder so the rig always assembles and the game runs.

var _cache: Dictionary = {}

func get_tex(path: String, fallback_color: Color = Color.WHITE, fallback_size: int = 128) -> Texture2D:
	if _cache.has(path):
		return _cache[path]
	var t: Texture2D = null
	if ResourceLoader.exists(path):
		var r: Variant = load(path)
		if r is Texture2D:
			t = r
	if t == null:
		t = _placeholder(fallback_color, fallback_size)
	_cache[path] = t
	return t

func _placeholder(c: Color, size: int) -> Texture2D:
	size = maxi(8, size)
	var img: Image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var cx: float = size / 2.0
	var rad: float = size * 0.42
	for y in size:
		for x in size:
			var d: float = Vector2(x - cx + 0.5, y - cx + 0.5).length()
			if d <= rad:
				var edge: float = clampf(1.0 - (d / rad), 0.0, 1.0)
				img.set_pixel(x, y, Color(c.r, c.g, c.b, 0.55 + 0.45 * edge))
	return ImageTexture.create_from_image(img)
