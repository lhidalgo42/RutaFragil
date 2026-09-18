extends SceneTree

## Foto de un punto concreto del mapa (D77): carga una escena, pone una cámara en `from`
## mirando a `to`, deja correr unos cuadros y guarda el PNG. Es la herramienta para ir a
## ver la fuente, un cruce o un árbol de cerca sin volar a mano. Con ventana, como toda
## captura; correr bajo `timeout`.
##
## "$GODOT_BIN" --path . --resolution 1600x900 -s res://src/tooling/look_at_shot.gd ++ \
##     scene=res://scenes/mapa_requinoa.tscn from=30,18,-40 to=8,0,-3 out=C:/.../fuente.png

var _scene_path: String = "res://scenes/mapa_requinoa.tscn"
var _from: Vector3 = Vector3(40.0, 25.0, 40.0)
var _to: Vector3 = Vector3.ZERO
var _out: String = "user://look.png"
var _fov: float = 60.0
var _wait_ticks: int = 40
var _ticks: int = 0
var _done: bool = false
var _camera: Camera3D


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		var parts: PackedStringArray = arg.split("=", true, 1)
		if parts.size() != 2:
			continue
		match parts[0]:
			"scene":
				_scene_path = parts[1]
			"from":
				_from = _vec(parts[1])
			"to":
				_to = _vec(parts[1])
			"out":
				_out = parts[1]
			"fov":
				_fov = float(parts[1])
			"ticks":
				# más cuadros antes de la foto: para medir fps en régimen, no en la compilación de shaders
				_wait_ticks = int(parts[1])


func _process(_delta: float) -> bool:
	if _done:
		return false
	_ticks += 1
	if _ticks == 1:
		var packed: PackedScene = load(_scene_path)
		if packed == null:
			print("LOOK error=scene_not_found path=", _scene_path)
			_done = true
			quit(1)
			return true
		var scene: Node = packed.instantiate()
		root.add_child(scene)
		# el bosque se siembra por cuadros en el juego; para la foto va entero de una vez
		for node: Node in scene.find_children("*", "Node3D", true, false):
			if node is OsmForest:
				(node as OsmForest).build()
		_camera = Camera3D.new()
		_camera.name = "LookCamera"
		_camera.far = 12000.0
		_camera.fov = _fov
		root.add_child(_camera)
		_camera.global_position = _from
		_camera.look_at(_to, Vector3.UP)
		_camera.make_current()
		return false
	# unos cuadros para que carguen texturas y sombras. Ojo: en un SceneTree devolver
	# `true` desde _process es PEDIR SALIR, así que mientras se espera va `false`.
	if _ticks < _wait_ticks:
		return false
	_done = true
	var image: Image = root.get_texture().get_image()
	if image == null:
		print("LOOK error=sin_imagen")
		quit(1)
		return true
	var err: int = image.save_png(_out)
	print("LOOK saved=%s error=%d from=%s to=%s fps=%.0f tris=%d objetos=%d" % [_out, err, _from, _to, Engine.get_frames_per_second(),
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME),
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME)])
	quit(0)
	return true


static func _vec(text: String) -> Vector3:
	var parts: PackedStringArray = text.split(",")
	if parts.size() != 3:
		return Vector3.ZERO
	return Vector3(float(parts[0]), float(parts[1]), float(parts[2]))
