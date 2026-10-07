extends Node
## Robust texture loader with graceful fallback (pattern proven in the reference
## project). If a rendered part/weapon sprite is missing or not yet imported, we
## synthesize a colored placeholder so the rig always assembles and the game runs.

var _cache: Dictionary = {}
var _glow_cache: Dictionary = {}

## THE additive material — one instance for the whole game. Two nodes holding distinct material
## instances can never batch, so handing out a fresh CanvasItemMaterial per FX node (the old
## behaviour) turned a busy frame into 800-1000+ draw calls. Nothing mutates it, so it is shared.
var _add_mat: CanvasItemMaterial = null
func add_mat() -> CanvasItemMaterial:
	if _add_mat == null:
		_add_mat = CanvasItemMaterial.new()
		_add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return _add_mat

## Soft radial glow (bright center -> transparent edge). Use with additive blend
## for cheap bloom-like FX on the gl_compatibility renderer (no WorldEnvironment glow).
func glow(c: Color, size: int = 64) -> Texture2D:
	var key: String = "%d_%d_%d_%d" % [int(c.r * 255), int(c.g * 255), int(c.b * 255), size]
	if _glow_cache.has(key):
		return _glow_cache[key]
	size = maxi(8, size)
	var img: Image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var cx: float = size / 2.0
	var rad: float = size * 0.5
	for y in size:
		for x in size:
			var d: float = Vector2(x - cx + 0.5, y - cx + 0.5).length() / rad
			if d < 1.0:
				img.set_pixel(x, y, Color(c.r, c.g, c.b, pow(1.0 - d, 2.2)))
	var t: Texture2D = ImageTexture.create_from_image(img)
	_glow_cache[key] = t
	return t

## Soft-edged SOLID disc — a proper ground contact shadow (glow() falls off far too fast to
## read as a shadow). Near-opaque in the middle, feathering to 0 only in the outer rim.
func shadow(size: int = 96) -> Texture2D:
	var key: String = "shadow_%d" % size
	if _glow_cache.has(key):
		return _glow_cache[key]
	size = maxi(8, size)
	var img: Image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var cx: float = size / 2.0
	var rad: float = size * 0.5
	for y in size:
		for x in size:
			var d: float = Vector2(x - cx + 0.5, y - cx + 0.5).length() / rad
			if d < 1.0:
				# solid until 62% of the radius, then a smooth feather to the edge
				var a: float = clampf((1.0 - d) / 0.38, 0.0, 1.0)
				img.set_pixel(x, y, Color(0, 0, 0, a * a))
	var t: Texture2D = ImageTexture.create_from_image(img)
	_glow_cache[key] = t
	return t

## Hollow ring (shockwave). alpha peaks near the rim; use additive + scale-up.
func ring(c: Color, size: int = 128) -> Texture2D:
	var key: String = "ring_%d_%d_%d_%d" % [int(c.r * 255), int(c.g * 255), int(c.b * 255), size]
	if _glow_cache.has(key):
		return _glow_cache[key]
	size = maxi(16, size)
	var img: Image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var cx: float = size / 2.0
	var rad: float = size * 0.5
	for y in size:
		for x in size:
			var d: float = Vector2(x - cx + 0.5, y - cx + 0.5).length() / rad
			if d < 1.0:
				var a: float = exp(-pow((d - 0.78) / 0.13, 2.0))
				img.set_pixel(x, y, Color(c.r, c.g, c.b, a))
	var t: Texture2D = ImageTexture.create_from_image(img)
	_glow_cache[key] = t
	return t

# =============================================================================================
# 04/10 (tour 2, patron : « encore bas de gamme ») — textures FX PREMIUM, toutes BLANCHES (la
# couleur vient du modulate / color_ramp) et generees UNE fois puis cachees. Les anciens debris
# etaient des carres sans texture, la fumee des carres gris : c'est ca qui faisait « cheap ».
# =============================================================================================

func _cached(key: String) -> Texture2D:
	return _glow_cache.get(key, null)

func _store(key: String, img: Image) -> Texture2D:
	var t: Texture2D = ImageTexture.create_from_image(img)
	_glow_cache[key] = t
	return t

func _noise(seed_v: int, freq: float) -> FastNoiseLite:
	var n: FastNoiseLite = FastNoiseLite.new()
	n.seed = seed_v
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.frequency = freq
	n.fractal_type = FastNoiseLite.FRACTAL_FBM
	n.fractal_octaves = 4
	return n

## Etincelle ETIREE (axe Y = sens de deplacement, pour particle_flag_align_y). Coeur dense,
## queue effilee : une vraie trainee d'etincelle de meulage, pas un pixel carre.
func spark_tex() -> Texture2D:
	var t: Texture2D = _cached("fx_spark")
	if t != null:
		return t
	var w: int = 16
	var h: int = 64
	var img: Image = Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in h:
		for x in w:
			var nx: float = (x + 0.5 - w * 0.5) / (w * 0.5)
			var ny: float = (y + 0.5 - h * 0.5) / (h * 0.5)
			var d: float = sqrt(nx * nx + ny * ny)
			if d < 1.0:
				var core: float = exp(-pow(nx / 0.28, 2.0)) * (1.0 - absf(ny))
				var a: float = clampf(pow(1.0 - d, 1.4) * 0.7 + core * 0.8, 0.0, 1.0)
				img.set_pixel(x, y, Color(1, 1, 1, a))
	return _store("fx_spark", img)

## Bouffee de fumee/vapeur : disque doux DECOUPE par un bruit fractal -> silhouette organique.
func puff_tex() -> Texture2D:
	var t: Texture2D = _cached("fx_puff")
	if t != null:
		return t
	var s: int = 128
	var n: FastNoiseLite = _noise(7, 0.035)
	var img: Image = Image.create(s, s, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c: float = s * 0.5
	for y in s:
		for x in s:
			var d: float = Vector2(x - c + 0.5, y - c + 0.5).length() / c
			if d < 1.0:
				var nv: float = n.get_noise_2d(x, y) * 0.5 + 0.5
				var a: float = clampf(pow(1.0 - d, 1.3) * (0.45 + 0.9 * nv) - 0.08, 0.0, 1.0)
				var shade: float = 0.78 + 0.22 * nv     # leger relief interne
				img.set_pixel(x, y, Color(shade, shade, shade, a))
	return _store("fx_puff", img)

## Eclat (glace / metal) : losange allonge a deux facettes (une claire, une sombre).
func shard_tex() -> Texture2D:
	var t: Texture2D = _cached("fx_shard")
	if t != null:
		return t
	var s: int = 32
	var img: Image = Image.create(s, s, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in s:
		for x in s:
			var nx: float = (x + 0.5 - s * 0.5) / (s * 0.5)
			var ny: float = (y + 0.5 - s * 0.5) / (s * 0.5)
			var k: float = absf(nx) / 0.42 + absf(ny)
			if k < 1.0:
				var facet: float = 1.0 if nx < 0.0 else 0.62
				var edge: float = clampf((1.0 - k) / 0.12, 0.0, 1.0)
				img.set_pixel(x, y, Color(facet, facet, facet, edge))
	return _store("fx_shard", img)

## Onde de choc NETTE : front exterieur tranchant + degrade qui s'eteint vers l'interieur.
## Remplace l'anneau gaussien mou (lisible mais « dessin ») par une vraie onde de pression.
func shock_tex() -> Texture2D:
	var t: Texture2D = _cached("fx_shock")
	if t != null:
		return t
	var s: int = 256
	var img: Image = Image.create(s, s, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c: float = s * 0.5
	for y in s:
		for x in s:
			var d: float = Vector2(x - c + 0.5, y - c + 0.5).length() / c
			if d < 1.0:
				var a: float
				if d <= 0.955:
					a = pow(d / 0.955, 7.0) * 0.85 + exp(-pow((d - 0.94) / 0.025, 2.0)) * 0.5
				else:
					a = clampf(1.0 - (d - 0.955) / 0.045, 0.0, 1.0)
				img.set_pixel(x, y, Color(1, 1, 1, clampf(a, 0.0, 1.0)))
	return _store("fx_shock", img)

## Eclair de coeur ANAMORPHIQUE (coeur blanc + longue raie horizontale + raie verticale courte) :
## le « flash cinema » qui signe une explosion haut de gamme.
func flare_tex() -> Texture2D:
	var t: Texture2D = _cached("fx_flare")
	if t != null:
		return t
	var s: int = 128
	var img: Image = Image.create(s, s, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in s:
		for x in s:
			var nx: float = (x + 0.5 - s * 0.5) / (s * 0.5)
			var ny: float = (y + 0.5 - s * 0.5) / (s * 0.5)
			var d: float = sqrt(nx * nx + ny * ny)
			var core: float = pow(clampf(1.0 - d, 0.0, 1.0), 3.0)
			var hstreak: float = exp(-pow(ny / 0.035, 2.0)) * pow(clampf(1.0 - absf(nx), 0.0, 1.0), 1.6)
			var vstreak: float = exp(-pow(nx / 0.03, 2.0)) * pow(clampf(1.0 - absf(ny), 0.0, 1.0), 3.0) * 0.55
			var a: float = clampf(core * 1.2 + hstreak * 0.9 + vstreak, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	return _store("fx_flare", img)

## Flamme directionnelle pour la bouche du canon (pointe vers +X).
func muzzle_tex() -> Texture2D:
	var t: Texture2D = _cached("fx_muzzle")
	if t != null:
		return t
	var s: int = 128
	var n: FastNoiseLite = _noise(42, 0.04)
	var img: Image = Image.create(s, s, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in s:
		for x in s:
			var nx: float = float(x) / float(s)
			var ny: float = (y - s * 0.5) / (s * 0.5)
			var width: float = 1.0 - pow(nx, 0.6)
			if abs(ny) < width:
				var nv: float = n.get_noise_2d(x, y) * 0.5 + 0.5
				var d_edge: float = abs(ny) / width
				var core: float = pow(1.0 - nx, 2.0) * pow(1.0 - d_edge, 2.0)
				var a: float = clampf((core * 1.5 + nv * 0.5) * (1.0 - nx) * (1.0 - d_edge), 0.0, 1.0)
				var shade: float = 0.7 + 0.3 * nv
				img.set_pixel(x, y, Color(shade, shade, shade, a))
	return _store("fx_muzzle", img)

## Disque plein a bord doux (remplissage progressif des zones telegraphiees).
func disc_tex() -> Texture2D:
	var t: Texture2D = _cached("fx_disc")
	if t != null:
		return t
	var s: int = 128
	var img: Image = Image.create(s, s, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c: float = s * 0.5
	for y in s:
		for x in s:
			var d: float = Vector2(x - c + 0.5, y - c + 0.5).length() / c
			if d < 1.0:
				var a: float = clampf((1.0 - d) / 0.06, 0.0, 1.0) * (0.55 + 0.45 * d * d)
				img.set_pixel(x, y, Color(1, 1, 1, a))
	return _store("fx_disc", img)

## Couronne SEGMENTEE + graduations (telegraphe « tactique » qui tourne) — fait instrument de
## visee militaire au lieu d'un simple cercle qui clignote.
func hazard_ring_tex() -> Texture2D:
	var t: Texture2D = _cached("fx_hazard")
	if t != null:
		return t
	var s: int = 256
	var img: Image = Image.create(s, s, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c: float = s * 0.5
	var segs: float = 12.0
	for y in s:
		for x in s:
			var v: Vector2 = Vector2(x - c + 0.5, y - c + 0.5)
			var d: float = v.length() / c
			if d < 1.0:
				var f: float = fposmod(v.angle() / TAU * segs, 1.0)
				var a: float = 0.0
				# bande segmentee (chevrons espaces)
				if d > 0.84 and d < 0.93 and f < 0.62:
					a = clampf(minf(d - 0.84, 0.93 - d) / 0.012, 0.0, 1.0)
				# graduations fines a l'interieur
				var g: float = fposmod(v.angle() / TAU * segs * 4.0, 1.0)
				if d > 0.76 and d < 0.81 and g < 0.18:
					a = maxf(a, 0.7)
				img.set_pixel(x, y, Color(1, 1, 1, a))
	return _store("fx_hazard", img)

## Trace au sol (brulure / givre / flaque) : tache irreguliere bruitee, opaque au centre.
func scorch_tex() -> Texture2D:
	var t: Texture2D = _cached("fx_scorch")
	if t != null:
		return t
	var s: int = 128
	var n: FastNoiseLite = _noise(31, 0.05)
	var img: Image = Image.create(s, s, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c: float = s * 0.5
	for y in s:
		for x in s:
			var v: Vector2 = Vector2(x - c + 0.5, y - c + 0.5)
			var d: float = v.length() / c
			if d < 1.0:
				var nv: float = n.get_noise_2d(x, y) * 0.5 + 0.5
				var edge: float = d + (nv - 0.5) * 0.45
				var a: float = clampf((0.88 - edge) / 0.3, 0.0, 1.0)
				var shade: float = 0.55 + 0.45 * nv
				img.set_pixel(x, y, Color(shade, shade, shade, a * (0.7 + 0.3 * nv)))
	return _store("fx_scorch", img)

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
