extends SceneTree

## Headless demo runner (D51, plan M0-T0.3 step 8): loads the Playground, lets
## the DemoDriver lap the circuit and prints one DEMO line per event plus a
## closing report. Exit code 0 only on lap_completed; 1 on rolled_over, stuck,
## timeout or any setup failure. quit() is guaranteed on every path; always
## run under an outer `timeout`.
## User args after ++: seconds=<max game seconds, default 120>,
## screenshot=<path, windowed runs only>, screenshot_at=<game second, def. 10>.
## Two hard-won constraints (plan §3):
## - The scene is loaded on the first process_frame, never in _init: autoloads
##   (GameConfig) are only registered after SceneTree._init.
## - No static reference to game classes that reach the autoload (Bus/DemoDriver/...): the
##   -s script compiles before autoloads exist, and that chain reaches
##   GameConfig. The scene is inspected by node name, signal name and
##   Variant-safe property reads instead; its scripts compile lazily at
##   process_frame time, when GameConfig is already a global.

const PLAYGROUND_SCENE: String = "res://scenes/playground.tscn"
const DEFAULT_SECONDS: float = 120.0
const DEFAULT_SCREENSHOT_AT: float = 10.0

var _seconds_max: float = DEFAULT_SECONDS
var _screenshot_path: String = ""
var _screenshot_at: float = DEFAULT_SCREENSHOT_AT
var _camera: String = "chase"

var _bus: Node = null
var _ticks: int = 0
var _waypoints: int = 0
var _max_speed_mps: float = 0.0
var _min_upright: float = 1.0
var _done: bool = false
var _screenshot_taken: bool = false


func _initialize() -> void:
	_parse_user_args()
	process_frame.connect(_load_playground, CONNECT_ONE_SHOT)


func _parse_user_args() -> void:
	for arg: String in OS.get_cmdline_user_args():
		var parts: PackedStringArray = arg.split("=", true, 1)
		if parts.size() != 2:
			continue
		match parts[0]:
			"seconds":
				_seconds_max = maxf(1.0, parts[1].to_float())
			"screenshot":
				_screenshot_path = parts[1]
			"screenshot_at":
				_screenshot_at = maxf(0.0, parts[1].to_float())
			"camera":
				_camera = parts[1]


func _load_playground() -> void:
	var packed: Resource = load(PLAYGROUND_SCENE)
	if not (packed is PackedScene):
		_finish("load_failed")
		return
	var packed_scene: PackedScene = packed
	var scene: Node = packed_scene.instantiate()
	scene.set("demo_mode", true)
	root.add_child(scene)
	var driver: Node = scene.get_node_or_null("DemoDriver")
	# By group, never by node name (D59).
	var bus: Node = null
	var bus_group_node: Node = get_first_node_in_group("bus")
	if bus_group_node != null:
		bus = bus_group_node
	var water: Node = scene.get_node_or_null("WaterZone")
	if not _nodes_look_valid(driver, bus, water):
		_finish("bad_scene")
		return
	_bus = bus
	if _camera == "cabin":
		# M1-T1.1 evidence: the cabin camera view (D63). Camera input is not
		# delivered to scripted runs, so the toggle is scripted here.
		var cabin: Node = get_first_node_in_group("cabin_camera")
		var chase: Node = get_first_node_in_group("chase_camera")
		if cabin is Camera3D and chase is Camera3D:
			var chase_cam: Camera3D = chase
			var cabin_cam: Camera3D = cabin
			chase_cam.current = false
			cabin_cam.current = true
	driver.connect("waypoint_reached", _on_waypoint_reached)
	driver.connect("lap_completed", _on_lap_completed)
	driver.connect("stuck", _on_stuck)
	bus.connect("rolled_over", _on_rolled_over)
	water.connect("bus_entered", _on_water_entered)
	physics_frame.connect(_on_physics_frame)


func _nodes_look_valid(driver: Node, bus: Node, water: Node) -> bool:
	if driver == null or bus == null or water == null:
		return false
	return driver.has_signal("waypoint_reached") and driver.has_signal("lap_completed") \
		and driver.has_signal("stuck") and bus.has_signal("rolled_over") \
		and water.has_signal("bus_entered")


func _game_time_s() -> float:
	return _ticks / float(Engine.physics_ticks_per_second)


func _bus_speed_mps() -> float:
	var value: Variant = _bus.get("linear_velocity")
	if value is Vector3:
		var velocity: Vector3 = value
		return velocity.length()
	return 0.0


func _bus_upright_dot() -> float:
	var value: Variant = _bus.get("global_basis")
	if value is Basis:
		var basis: Basis = value
		return basis.y.dot(Vector3.UP)
	return 1.0


func _on_physics_frame() -> void:
	if _done:
		return
	_ticks += 1
	_max_speed_mps = maxf(_max_speed_mps, _bus_speed_mps())
	_min_upright = minf(_min_upright, _bus_upright_dot())
	if not _screenshot_taken and _screenshot_path != "" and _game_time_s() >= _screenshot_at:
		_take_screenshot()
	if _game_time_s() >= _seconds_max:
		_finish("timeout")


func _take_screenshot() -> void:
	_screenshot_taken = true
	var image: Image = root.get_texture().get_image()
	if image == null:
		print("DEMO screenshot_failed")
		return
	var err: Error = image.save_png(_screenshot_path)
	if err == OK:
		print("DEMO screenshot saved=%s" % _screenshot_path)
	else:
		print("DEMO screenshot_failed error=%d" % err)


func _on_waypoint_reached(index: int) -> void:
	_waypoints += 1
	print("DEMO waypoint %d t=%.1fs" % [index, _game_time_s()])


func _on_lap_completed(_lap: int) -> void:
	_finish("lap_completed")


func _on_stuck() -> void:
	_finish("stuck")


func _on_rolled_over() -> void:
	_finish("rolled_over")


func _on_water_entered(_body: Node3D) -> void:
	print("DEMO water_entered t=%.1fs" % _game_time_s())


func _finish(result: String) -> void:
	if _done:
		return
	_done = true
	print("DEMO result=%s t=%.1fs waypoints=%d max_speed_kmh=%.1f min_upright=%.2f" % [
		result, _game_time_s(), _waypoints, _max_speed_mps * 3.6, _min_upright])
	if result == "lap_completed":
		quit(0)
	else:
		quit(1)
