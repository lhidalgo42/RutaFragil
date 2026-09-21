extends SceneTree

## Asset preview with screenshot (M-ART paso 4/5): instances ONE scene, frames
## it with a camera and a sun, and saves a PNG after a few frames. Windowed
## run only (the screenshot reads the viewport texture). quit() on every path;
## run under an outer `timeout`.
##
##   godot --path . -s res://src/tooling/asset_preview.gd ++ \
##       scene=res://src/cargo/package.tscn out=user://package_preview.png \
##       [frames=30] [distance=1.2] [yaw=35] [pitch=22]
##
## Same two constraints as run_demo: the scene loads on the first
## process_frame (autoloads are not registered in _init) and nothing here
## references a game class statically.

var _scene_path: String = ""
var _out_path: String = ""
var _frames_wait: int = 30
var _distance: float = 1.2
var _yaw_deg: float = 35.0
var _pitch_deg: float = 22.0
var _frames: int = 0
var _started: bool = false


func _init() -> void:
	for arg: String in OS.get_cmdline_user_args():
		var parts: PackedStringArray = arg.split("=", true, 1)
		if parts.size() != 2:
			continue
		match parts[0]:
			"scene":
				_scene_path = parts[1]
			"out":
				_out_path = parts[1]
			"frames":
				_frames_wait = maxi(1, parts[1].to_int())
			"distance":
				_distance = maxf(0.05, parts[1].to_float())
			"yaw":
				_yaw_deg = parts[1].to_float()
			"pitch":
				_pitch_deg = parts[1].to_float()
	if _scene_path == "" or _out_path == "":
		push_error("asset_preview: scene=<res path> and out=<png path> are required")
		quit(1)


func _process(_delta: float) -> bool:
	if not _started:
		_started = true
		if not _setup():
			quit(1)
			return true
		return false
	_frames += 1
	if _frames >= _frames_wait:
		var image: Image = root.get_texture().get_image()
		var err: Error = image.save_png(_out_path)
		if err != OK:
			push_error("asset_preview: save_png failed with %d" % err)
			quit(1)
			return true
		print("PREVIEW saved=%s size=%dx%d" % [_out_path, image.get_width(), image.get_height()])
		quit(0)
		return true
	return false


func _setup() -> bool:
	var packed: Resource = load(_scene_path)
	if not (packed is PackedScene):
		push_error("asset_preview: %s did not load as a PackedScene" % _scene_path)
		return false
	var scene: PackedScene = packed
	var world: Node3D = Node3D.new()
	world.name = "PreviewWorld"
	root.add_child(world)

	var subject: Node = scene.instantiate()
	if subject is RigidBody3D:
		# A physics body would fall through nothing: hold it still for the photo.
		var body: RigidBody3D = subject
		body.freeze = true
	world.add_child(subject)

	var env: WorldEnvironment = WorldEnvironment.new()
	var environment: Environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.82, 0.83, 0.86)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.9, 0.9, 0.95)
	environment.ambient_light_energy = 0.6
	env.environment = environment
	world.add_child(env)

	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.light_energy = 2.0
	sun.rotation_degrees = Vector3(-50.0, 35.0, 0.0)
	sun.shadow_enabled = true
	world.add_child(sun)

	var floor_mesh: MeshInstance3D = MeshInstance3D.new()
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(4.0, 4.0)
	floor_mesh.mesh = plane
	floor_mesh.position = Vector3(0.0, -0.2, 0.0)
	var floor_material: StandardMaterial3D = StandardMaterial3D.new()
	floor_material.albedo_color = Color(0.55, 0.56, 0.6)
	floor_mesh.material_override = floor_material
	world.add_child(floor_mesh)

	var camera: Camera3D = Camera3D.new()
	var yaw: float = deg_to_rad(_yaw_deg)
	var pitch: float = deg_to_rad(_pitch_deg)
	camera.position = Vector3(
		_distance * cos(pitch) * sin(yaw),
		_distance * sin(pitch),
		_distance * cos(pitch) * cos(yaw))
	world.add_child(camera)
	camera.look_at(Vector3.ZERO, Vector3.UP)
	camera.current = true
	return true
