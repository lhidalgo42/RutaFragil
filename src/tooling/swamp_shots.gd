extends SceneTree

## Tanda de fotos del pantano (D71): carga la escena del mapa —que trae cielo, luz y
## niebla— y mueve una cámara propia por posiciones calculadas sobre el eje real, para
## que las fotos sean repetibles y no elegidas a ojo. La última es la cenital ortográfica,
## con la niebla apagada. Ventana, no headless: headless no dibuja.
## Args tras ++: out=<carpeta donde guardar los PNG, por defecto user://>.

const DIR_DEFAULT: String = "user://"

const SHOTS: Array = [
	{"n": "pt_mapa", "p": Vector3(-2250.0, 260.0, 2250.0), "t": Vector3(-3550.0, 40.0, 1600.0)},
	{"n": "pt_ripio", "p": Vector3(-1600.1, 5.0, 2083.5), "t": Vector3(-1617.7, 1.5, 2106.7)},
	{"n": "pt_potrero", "p": Vector3(-2010.4, 7.0, 2094.3), "t": Vector3(-2041.0, 1.5, 2106.8)},
	{"n": "pt_hualve", "p": Vector3(-3430.0, 6.5, 1650.0), "t": Vector3(-3417.7, 4.0, 1629.7)},
	{"n": "pt_barro", "p": Vector3(-3481.0, 5.5, 1984.2), "t": Vector3(-3491.3, 1.5, 2009.1)},
	{"n": "pt_puente", "p": Vector3(-3390.8, 6.0, 1872.0), "t": Vector3(-3405.8, 1.5, 1899.5)},
	{"n": "pt_liana", "p": Vector3(-4307.8, 3.2, 1580.0), "t": Vector3(-4316.9, 1.5, 1566.5)},
	{"n": "pt_muelle", "p": Vector3(-3469.0, 8.0, 1982.0), "t": Vector3(-3497.0, 1.0, 1984.0)},
	{"n": "pt_pasarela", "p": Vector3(-4389.4, 5.0, 1408.8), "t": Vector3(-4394.7, 1.5, 1384.1)},
	{"n": "pt_vado", "p": Vector3(-4257.0, 6.5, 1262.0), "t": Vector3(-4249.2, 1.0, 1231.9)},
]

var _n: int = 0
var _cam: Camera3D = null
var _dir: String = DIR_DEFAULT


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		var parts: PackedStringArray = arg.split("=", true, 1)
		if parts.size() == 2 and parts[0] == "out":
			_dir = parts[1] if parts[1].ends_with("/") else parts[1] + "/"
	process_frame.connect(_load, CONNECT_ONE_SHOT)


func _load() -> void:
	var ps: PackedScene = load("res://scenes/mapa_pantano.tscn")
	var scene: Node = ps.instantiate()
	root.add_child(scene)
	var ayuda: Node = scene.get_node_or_null("Ayuda")
	if ayuda != null:
		ayuda.set("visible", false)
	_cam = Camera3D.new()
	_cam.far = 9000.0
	root.add_child(_cam)
	_cam.current = true
	process_frame.connect(_tick)


func _tick() -> void:
	_n += 1
	if _n < 180:
		return
	process_frame.disconnect(_tick)
	for shot: Dictionary in SHOTS:
		_cam.projection = Camera3D.PROJECTION_PERSPECTIVE
		_cam.global_position = shot["p"]
		_cam.look_at(shot["t"], Vector3.UP)
		await _save(shot["n"])
	# la niebla a 2 km deja la cenital toda gris
	var we: Node = root.get_child(0).get_node_or_null("WorldEnvironment")
	if we is WorldEnvironment:
		var wenv: WorldEnvironment = we
		wenv.environment.fog_enabled = false
	_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	_cam.size = 2700.0
	_cam.global_position = Vector3(-3150.0, 2000.0, 1870.0)
	_cam.rotation = Vector3(-PI * 0.5, 0.0, 0.0)
	await _save("pt_cenital")
	quit(0)


func _save(shot_name: String) -> void:
	for i: int in 4:
		await process_frame
	var img: Image = root.get_texture().get_image()
	if img == null:
		print("FOTO fallo ", shot_name)
		return
	img.save_png(_dir + shot_name + ".png")
	print("FOTO ", shot_name)
