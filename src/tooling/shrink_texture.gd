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
		var leaf: Image = atlas.get_region(Rect2i((q % 2) * half, (q / 2) * half, half, half))
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


func _shrink(from: String, to: String) -> bool:
	var image: Image = Image.load_from_file(from)
	if image == null:
		print("SHRINK error=no_se_pudo_leer in=", from)
		return false
	var before: Vector2i = image.get_size()
	image.resize(_size, _size, Image.INTERPOLATE_LANCZOS)
	if not _alpha_from.is_empty():
		var mask: Image = Image.load_from_file(_alpha_from)
		if mask == null:
			print("SHRINK error=no_se_pudo_leer alpha_from=", _alpha_from)
			return false
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
