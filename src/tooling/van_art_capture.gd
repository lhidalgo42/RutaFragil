extends SceneTree

## M-ART-VAN evidence capture. Loads the real bus scene, freezes it, and takes
## a fixed review set without changing gameplay geometry. User args: out=<prefix>.
## Views are chosen to expose defects against the D100 canon, not to hide them:
## true profiles use a long lens from outside the hull, and the light is kept
## below clipping so the albedo reads as authored.

const SETTLE_FRAMES: int = 6

var _prefix: String = "res://docs/evidencia/M-ART-VAN/integracion/van"
var _world: Node3D = null
var _camera: Camera3D = null
var _bus: Node3D = null
var _doors: Node = null
var _interior_fill: OmniLight3D = null
var _shot: int = 0
var _frames: int = 0


func _init() -> void:
	for arg: String in OS.get_cmdline_user_args():
		var parts: PackedStringArray = arg.split("=", true, 1)
		if parts.size() == 2 and parts[0] == "out": _prefix = parts[1]


static func views() -> Array[Dictionary]:
	# Bus frame: -Z front, +X right, floor top y=-0.6, roof top y=1.5.
	return [
		{"name":"exterior_front3q", "pos":Vector3(7.5, 1.4, -10.5), "at":Vector3(0.3, 0.3, -1.6), "fov":38.0},
		{"name":"exterior_rear3q", "pos":Vector3(-7.0, 1.3, 11.0), "at":Vector3(-0.2, 0.3, 1.8), "fov":38.0},
		{"name":"exterior_side_right", "pos":Vector3(22.0, 0.35, 0.0), "at":Vector3(0.0, 0.35, 0.0), "fov":24.0},
		{"name":"exterior_side_left", "pos":Vector3(-22.0, 0.35, 0.0), "at":Vector3(0.0, 0.35, 0.0), "fov":24.0},
		{"name":"exterior_rear", "pos":Vector3(0.0, 0.45, 14.0), "at":Vector3(0.0, 0.35, 0.0), "fov":24.0},
		{"name":"exterior_front", "pos":Vector3(0.0, 0.45, -14.0), "at":Vector3(0.0, 0.35, 0.0), "fov":24.0},
		{"name":"side_door", "pos":Vector3(5.5, 0.4, -2.4), "at":Vector3(1.2, 0.2, -1.75), "fov":40.0},
		{"name":"side_door_half", "pos":Vector3(5.5, 0.4, -2.4), "at":Vector3(1.2, 0.2, -1.75), "fov":40.0, "side_t":0.5, "rear_t":0.5},
		{"name":"side_door_closed", "pos":Vector3(5.5, 0.4, -2.4), "at":Vector3(1.2, 0.2, -1.75), "fov":40.0, "side_t":0.0, "rear_t":0.0},
		{"name":"rear_doors_closed", "pos":Vector3(0.0, 0.45, 14.0), "at":Vector3(0.0, 0.35, 0.0), "fov":24.0, "side_t":0.0, "rear_t":0.0},
		{"name":"seats_close", "pos":Vector3(0.0, 0.55, -1.35), "at":Vector3(0.0, -0.05, -2.9), "fov":42.0, "interior":true},
		{"name":"wheel_close", "pos":Vector3(3.6, -0.45, -2.75), "at":Vector3(1.1, -0.5, -2.75), "fov":34.0},
		{"name":"cab", "camera":"CabinCamera"},
		{"name":"cab_seats", "pos":Vector3(0.0, 0.85, -1.2), "at":Vector3(0.0, 0.1, -3.4), "fov":70.0},
		{"name":"interior", "pos":Vector3(0.0, 0.65, 3.2), "at":Vector3(0.0, 0.2, 0.0), "fov":70.0},
		{"name":"interior_to_rear", "pos":Vector3(0.0, 0.65, -2.2), "at":Vector3(0.0, 0.3, 3.5), "fov":70.0},
	]


func _process(_delta: float) -> bool:
	if _world == null:
		if not _setup(): quit(1)
		return false
	var all_views: Array[Dictionary] = views()
	if _shot >= all_views.size(): quit(0); return true
	var view: Dictionary = all_views[_shot]
	_frames += 1
	if _frames == 1:
		_apply_view(view)
		_set_door_pose(view)
		return false
	if _frames < SETTLE_FRAMES: return false
	var path: String = "%s_%s.png" % [_prefix, view["name"]]
	var err: Error = root.get_texture().get_image().save_png(path)
	if err != OK: push_error("van_art_capture: save failed %d" % err); quit(1); return true
	print("VAN_CAPTURE saved=", path)
	_shot += 1
	_frames = 0
	return false


func _apply_view(view: Dictionary) -> void:
	var cabin: Camera3D = _bus.get_node_or_null("CabinCamera")
	var name: String = String(view["name"])
	var is_interior: bool = view.has("camera") or view.get("interior", false) or name.begins_with("cab_") or name.begins_with("interior") or name == "seats_close"
	_interior_fill.visible = is_interior
	if view.has("camera"):
		_camera.current = false
		if cabin == null: push_error("van_art_capture: camera missing"); quit(1); return
		_interior_fill.global_position = cabin.global_position
		cabin.current = true
		return
	if cabin != null: cabin.current = false
	_camera.fov = float(view["fov"])
	_camera.position = view["pos"]
	_camera.look_at(view["at"], Vector3.UP)
	_interior_fill.global_position = _camera.global_position
	_camera.current = true


func _set_door_pose(view: Dictionary) -> void:
	if _doors == null:
		return
	for door_id: StringName in [&"side", &"rear"]:
		var key: String = "side_t" if door_id == &"side" else "rear_t"
		var progress: float = float(view.get(key, 1.0))
		_doors.call("apply_state", door_id, 0, progress)
	var visual: Node = _bus.get_node_or_null("BusExteriorVisual")
	if visual != null and visual.has_method("update_doors"):
		visual.call("update_doors")


func _setup() -> bool:
	var packed: Resource = load("res://src/vehicle/bus.tscn")
	if not (packed is PackedScene): return false
	_world = Node3D.new(); root.add_child(_world)
	var scene: PackedScene = packed
	_bus = scene.instantiate()
	_doors = _bus.get_node_or_null("BusDoors")
	if _bus is RigidBody3D:
		var body: RigidBody3D = _bus
		body.freeze = true
	_world.add_child(_bus)
	var ground: MeshInstance3D = MeshInstance3D.new()
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(80.0, 80.0)
	var ground_mat: StandardMaterial3D = StandardMaterial3D.new()
	ground_mat.albedo_color = Color(0.36, 0.37, 0.36)
	ground_mat.roughness = 0.95
	plane.material = ground_mat
	ground.mesh = plane
	ground.position = Vector3(0.0, -1.1, 0.0)
	_world.add_child(ground)
	var env_node: WorldEnvironment = WorldEnvironment.new()
	var environment: Environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.58, 0.62, 0.68)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(1.0, 1.0, 1.0)
	environment.ambient_light_energy = 0.85
	environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env_node.environment = environment; _world.add_child(env_node)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50.0, -35.0, 0.0)
	sun.light_energy = 0.55
	sun.shadow_enabled = true
	_world.add_child(sun)
	# Camera-local fill for enclosed views only; the exterior hull is lit by sun + ambient.
	_interior_fill = OmniLight3D.new()
	_interior_fill.omni_range = 3.5
	_interior_fill.omni_attenuation = 0.6
	_interior_fill.light_energy = 0.9
	_interior_fill.light_specular = 0.0
	_interior_fill.visible = false
	_world.add_child(_interior_fill)
	_camera = Camera3D.new(); _world.add_child(_camera); _camera.current = true
	return true
