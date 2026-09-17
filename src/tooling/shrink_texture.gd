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

var _in: String = ""
var _out: String = ""
var _alpha_from: String = ""
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
