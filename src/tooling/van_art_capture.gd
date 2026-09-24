extends SceneTree

## M-ART-VAN evidence capture. Loads the real bus scene, freezes it, and takes
## three views without changing gameplay geometry. User args: out=<prefix>.

var _prefix: String = "res://docs/evidencia/M-ART-VAN/integracion/van"
var _world: Node3D = null
var _camera: Camera3D = null
var _bus: Node3D = null
var _shot: int = 0
var _frames: int = 0


func _init() -> void:
	for arg: String in OS.get_cmdline_user_args():
		var parts: PackedStringArray = arg.split("=", true, 1)
		if parts.size() == 2 and parts[0] == "out": _prefix = parts[1]


func _process(_delta: float) -> bool:
	if _world == null:
		if not _setup(): quit(1)
		return false
	_frames += 1
	var views: Array[Dictionary] = [
		{"name":"exterior", "pos":Vector3(8.5, 4.0, 9.0), "at":Vector3(0, 0.2, 0)},
		{"name":"cab", "pos":Vector3(0, 0.65, -2.0), "at":Vector3(0, 0.4, -3.5)},
		{"name":"interior", "pos":Vector3(0, 0.65, 3.2), "at":Vector3(0, 0.2, 0)},
	]
	if _shot >= views.size(): quit(0); return true
	var view: Dictionary = views[_shot]
	if _frames == 20:
		_camera.position = view["pos"]
		_camera.look_at(view["at"], Vector3.UP)
		return false
	if _frames < 22: return false
	var path: String = "%s_%s.png" % [_prefix, view["name"]]
	var err: Error = root.get_texture().get_image().save_png(path)
	if err != OK: push_error("van_art_capture: save failed %d" % err); quit(1); return true
	print("VAN_CAPTURE saved=", path)
	_shot += 1
	_frames = 0
	return false


func _setup() -> bool:
	var packed: Resource = load("res://src/vehicle/bus.tscn")
	if not (packed is PackedScene): return false
	_world = Node3D.new(); root.add_child(_world)
	var scene: PackedScene = packed
	_bus = scene.instantiate()
	if _bus is RigidBody3D:
		var body: RigidBody3D = _bus
		body.freeze = true
	_world.add_child(_bus)
	var env_node: WorldEnvironment = WorldEnvironment.new()
	var environment: Environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.12,0.14,0.18)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.75,0.78,0.82)
	environment.ambient_light_energy = 1.0
	env_node.environment = environment; _world.add_child(env_node)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45,-30,0); sun.light_energy = 2.0; _world.add_child(sun)
	_camera = Camera3D.new(); _world.add_child(_camera); _camera.current = true
	return true
