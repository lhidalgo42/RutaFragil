extends SceneTree

## Reduce una textura antes de meterla al repo. Las imágenes van por Git LFS (.gitattributes)
## y **los objetos LFS de GitHub son permanentes**: borrarlos después no libera cuota (nota de
## D36). Un set de ambientCG en 1K son 9 MB; a 512 px son 1,5 MB y el suelo de un pueblo visto
## desde la cabina no nota la diferencia.
##
## Una sola: ++ in=/ruta/color.jpg out=/ruta/salida.jpg size=512 quality=0.85
## Una carpeta entera: ++ dir_in=/ruta/origen dir_out=/ruta/destino size=512
## En una carpeta, cada `nombre_src.jpg` sale como `nombre.jpg`.
## Con alfa: ++ in=color.jpg alpha_from=opacity.jpg out=hojas.png — funde el mapa de
## opacidad en el canal alfa y guarda PNG (un JPG no tiene alfa). Así un atlas de hojas
## de ambientCG queda listo para recortarse con `alpha_scissor` en un material normal.

## Con `stamp=N` el archivo de entrada se toma como un atlas RGBA de hojas sueltas (2×2) y
## se estampa N veces, al azar y encimadas, sobre un lienzo transparente: sale una MATA
## densa con borde irregular. Un atlas de hojas sueltas repetido sobre una tarjeta se ve a
## través — «hojas separadas en un palo», dijo el dueño (D77); la mata no.
var _in: String = ""
var _out: String = ""
var _alpha_from: String = ""
var _stamp: int = 0
## Con `grass=N` no hace falta entrada: pinta N hojas de pasto curvas y tupidas en un lienzo
## transparente. El pasto del greybox eran triángulos recortados por shader — «el pasto se ve
## triangular», dijo el dueño (D78) —; una mata pintada con hojas finas y curvas es pasto.
var _grass: int = 0
## `crop=x,y,w,h` recorta esa región de `in` (y de `alpha_from`) antes de reducir: los atlas
## de Poly Haven son texturas de modelo desplegadas, y la parte útil para una tarjeta es
## una esquina. `whole=1` hace que `stamp=` estampe la imagen entera en vez de cuadrantes.
var _crop: Rect2i = Rect2i()
var _whole: bool = false
var _dir_in: String = ""
var _dir_out: String = ""
var _size: int = 512
var _quality: float = 0.85
var _done: bool = false


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		var parts: PackedStringArray = arg.split("=", true, 1)
		if parts.size() != 2:
			continue
		match parts[0]:
			"in":
				_in = parts[1]
			"out":
				_out = parts[1]
			"alpha_from":
				_alpha_from = parts[1]
			"stamp":
				_stamp = int(parts[1])
			"grass":
				_grass = int(parts[1])
			"crop":
				var c: PackedStringArray = parts[1].split(",")
				if c.size() == 4:
					_crop = Rect2i(int(c[0]), int(c[1]), int(c[2]), int(c[3]))
			"whole":
				_whole = parts[1] == "1"
			"dir_in":
				_dir_in = parts[1]
			"dir_out":
				_dir_out = parts[1]
			"size":
				_size = int(parts[1])
			"quality":
				_quality = float(parts[1])


func _process(_delta: float) -> bool:
	if _done:
		return false
	_done = true
	if not _dir_in.is_empty():
		quit(0 if _shrink_dir() else 1)
		return true
	if _stamp > 0:
		quit(0 if _stamp_clump() else 1)
		return true
	if _grass > 0:
		quit(0 if _paint_grass() else 1)
		return true
	if _in.is_empty() or _out.is_empty():
		print("SHRINK error=faltan in= y out= (o dir_in= y dir_out=)")
		quit(1)
		return true
	quit(0 if _shrink(_in, _out) else 1)
	return true


func _shrink_dir() -> bool:
	var dir: DirAccess = DirAccess.open(_dir_in)
	if dir == null:
		print("SHRINK error=no_se_pudo_abrir dir_in=", _dir_in)
		return false
	var names: PackedStringArray = dir.get_files()
	names.sort()
	var ok: bool = true
	for name: String in names:
		if not name.to_lower().ends_with(".jpg"):
			continue
		var out_name: String = name.replace("_src.jpg", ".jpg")
		ok = _shrink(_dir_in.path_join(name), _dir_out.path_join(out_name)) and ok
	return ok


## Mata densa a partir de un atlas 2×2 de hojas sueltas (RGBA): N estampas de cuadrantes al
## azar, con escala y volteo, encimadas en un lienzo transparente; más chicas y tupidas
## hacia el centro, más sueltas hacia el borde para que la silueta quede rota.
func _stamp_clump() -> bool:
	var atlas: Image = Image.load_from_file(_in)
	if atlas == null:
		print("SHRINK error=no_se_pudo_leer in=", _in)
		return false
	atlas.convert(Image.FORMAT_RGBA8)
	var half: int = atlas.get_width() / 2
	var canvas: Image = Image.create(_size, _size, false, Image.FORMAT_RGBA8)
	canvas.fill(Color(0.0, 0.0, 0.0, 0.0))
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 7
	var centre: Vector2 = Vector2(_size, _size) * 0.5
	for _k: int in _stamp:
		var q: int = rng.randi_range(0, 3)
		var leaf: Image = atlas.duplicate() if _whole else atlas.get_region(Rect2i((q % 2) * half, (q / 2) * half, half, half))
		var scale: float = rng.randf_range(0.28, 0.5)
		var side: int = maxi(8, int(float(_size) * scale))
		leaf.resize(side, side, Image.INTERPOLATE_BILINEAR)
		if rng.randf() < 0.5:
			leaf.flip_x()
		if rng.randf() < 0.5:
			leaf.flip_y()
		# posición: gaussiana burda hacia el centro (promedio de dos uniformes)
		var r: float = (rng.randf() + rng.randf()) * 0.5 * float(_size) * 0.42
		var ang: float = rng.randf() * TAU
		var pos: Vector2 = centre + Vector2(cos(ang), sin(ang)) * r - Vector2(side, side) * 0.5
		canvas.blend_rect(leaf, Rect2i(0, 0, side, side), Vector2i(int(pos.x), int(pos.y)))
	# Sombreado de volumen (D78): más oscuro abajo y hacia el centro, como una mata de
	# verdad que se ensombrece a sí misma. Sin esto la tarjeta se leía como una plancha plana.
	for y: int in _size:
		for x: int in _size:
			var c: Color = canvas.get_pixel(x, y)
			if c.a <= 0.01:
				continue
			var fy: float = float(y) / float(_size)
			var d: float = Vector2(x, y).distance_to(centre) / (float(_size) * 0.5)
			var shade: float = clampf(1.05 - fy * 0.45 - (1.0 - clampf(d, 0.0, 1.0)) * 0.2, 0.45, 1.05)
			canvas.set_pixel(x, y, Color(c.r * shade, c.g * shade, c.b * shade, c.a))
	var err: int = canvas.save_png(_out)
	if err != OK:
		print("SHRINK error=no_se_pudo_escribir out=%s codigo=%d" % [_out, err])
		return false
	var covered: int = 0
	for y: int in range(0, _size, 4):
		for x: int in range(0, _size, 4):
			if canvas.get_pixel(x, y).a > 0.5:
				covered += 1
	print("SHRINK mata ok estampas=%d cobertura=%.0f%% %s" % [_stamp, 100.0 * float(covered) / float((_size / 4) * (_size / 4)), _out])
	return true


## Mata de pasto pintada: N hojas que nacen abajo al centro, suben curvándose hacia un lado
## (Bézier cuadrática) y se afinan hasta la punta. Color oscuro en la base y claro arriba,
## con variación por hoja. Sale como PNG con alfa para recortar con `alpha_scissor`.
func _paint_grass() -> bool:
	var canvas: Image = Image.create(_size, _size, false, Image.FORMAT_RGBA8)
	canvas.fill(Color(0.0, 0.0, 0.0, 0.0))
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 11
	var w: float = float(_size)
	var h: float = float(_size)
	for _k: int in _grass:
		var base: Vector2 = Vector2(w * rng.randf_range(0.3, 0.7), h * rng.randf_range(0.96, 1.0))
		var height: float = h * rng.randf_range(0.45, 0.98)
		var drift: float = w * rng.randf_range(-0.28, 0.28)
		var tip: Vector2 = Vector2(base.x + drift, base.y - height)
		var ctrl: Vector2 = Vector2(base.x + drift * 0.15, base.y - height * 0.55)
		var half_w: float = w * rng.randf_range(0.012, 0.022)
		var dark: Color = Color(0.16, 0.3, 0.09).lerp(Color(0.22, 0.36, 0.12), rng.randf())
		var light: Color = Color(0.5, 0.68, 0.28).lerp(Color(0.62, 0.74, 0.34), rng.randf())
		var steps: int = int(height * 1.4)
		for i: int in steps:
			var t: float = float(i) / float(maxi(steps - 1, 1))
			var p: Vector2 = base.lerp(ctrl, t).lerp(ctrl.lerp(tip, t), t)
			var hw: float = half_w * (1.0 - t * t)
			var colour: Color = dark.lerp(light, t)
			var x0: int = int(floor(p.x - hw))
			var x1: int = int(ceil(p.x + hw))
			var y: int = int(round(p.y))
			if y < 0 or y >= _size:
				continue
			for x: int in range(maxi(x0, 0), mini(x1, _size - 1) + 1):
				canvas.set_pixel(x, y, colour)
	var err: int = canvas.save_png(_out)
	if err != OK:
		print("SHRINK error=no_se_pudo_escribir out=%s codigo=%d" % [_out, err])
		return false
	print("SHRINK pasto ok hojas=%d %s" % [_grass, _out])
	return true


func _shrink(from: String, to: String) -> bool:
	var image: Image = Image.load_from_file(from)
	if image == null:
		print("SHRINK error=no_se_pudo_leer in=", from)
		return false
	var before: Vector2i = image.get_size()
	if _crop.size.x > 0 and _crop.size.y > 0:
		image = image.get_region(_crop)
	image.resize(_size, _size, Image.INTERPOLATE_LANCZOS)
	if not _alpha_from.is_empty():
		var mask: Image = Image.load_from_file(_alpha_from)
		if mask == null:
			print("SHRINK error=no_se_pudo_leer alpha_from=", _alpha_from)
			return false
		if _crop.size.x > 0 and _crop.size.y > 0:
			mask = mask.get_region(_crop)
		mask.resize(_size, _size, Image.INTERPOLATE_LANCZOS)
		image.convert(Image.FORMAT_RGBA8)
		for y: int in _size:
			for x: int in _size:
				var c: Color = image.get_pixel(x, y)
				c.a = mask.get_pixel(x, y).get_luminance()
				image.set_pixel(x, y, c)
	var err: int = image.save_png(to) if to.to_lower().ends_with(".png") else image.save_jpg(to, _quality)
	if err != OK:
		print("SHRINK error=no_se_pudo_escribir out=%s codigo=%d" % [to, err])
		return false
	# El promedio sirve para saber de qué lado está una máscara (blanco = hay, negro = no hay)
	# sin tener que abrir la imagen: con una máscara invertida el suelo sale al revés.
	var sum: float = 0.0
	for y: int in range(0, _size, 8):
		for x: int in range(0, _size, 8):
			sum += image.get_pixel(x, y).get_luminance()
	var samples: float = float((_size / 8) * (_size / 8))
	print("SHRINK ok %dx%d -> %dx%d luz_media=%.3f %s" % [before.x, before.y, _size, _size, sum / samples, to])
	return true
