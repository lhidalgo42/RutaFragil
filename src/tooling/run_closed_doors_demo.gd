extends SceneTree

## Reproducible D103 handling probe: same demo route as run_demo, both doors
## physically closed before the bus enters the tree. Never changes tuning.

const PLAYGROUND_SCENE: String = "res://scenes/playground.tscn"
const MAX_SECONDS: float = 120.0

var _bus: Node = null
var _ticks: int = 0
var _waypoints: int = 0
var _max_speed_mps: float = 0.0
var _min_upright: float = 1.0
var _done: bool = false


func _initialize() -> void:
	process_frame.connect(_load, CONNECT_ONE_SHOT)


func _load() -> void:
	var packed: Resource = load(PLAYGROUND_SCENE)
	if not (packed is PackedScene): _finish("load_failed"); return
	var scene: Node = (packed as PackedScene).instantiate()
	scene.set("demo_mode", true)
	var doors: Node = scene.get_node_or_null("Bus/BusDoors")
	if doors != null:
		doors.set("side_initially_open", false)
		doors.set("rear_initially_open", false)
	root.add_child(scene)
	var driver: Node = scene.get_node_or_null("DemoDriver")
	_bus = get_first_node_in_group("bus")
	if driver == null or _bus == null or doors == null: _finish("bad_scene"); return
	if int(doors.call("phase", &"side")) != 2 or int(doors.call("phase", &"rear")) != 2:
		_finish("doors_not_closed"); return
	driver.connect("waypoint_reached", _on_waypoint)
	driver.connect("lap_completed", _on_lap)
	driver.connect("stuck", func() -> void: _finish("stuck"))
	_bus.connect("rolled_over", func() -> void: _finish("rolled_over"))
	physics_frame.connect(_on_tick)


func _on_tick() -> void:
	if _done: return
	_ticks += 1
	var velocity: Variant = _bus.get("linear_velocity")
	if velocity is Vector3: _max_speed_mps = maxf(_max_speed_mps, (velocity as Vector3).length())
	var basis: Variant = _bus.get("global_basis")
	if basis is Basis: _min_upright = minf(_min_upright, (basis as Basis).y.dot(Vector3.UP))
	if float(_ticks) / Engine.physics_ticks_per_second >= MAX_SECONDS: _finish("timeout")


func _on_waypoint(_index: int) -> void:
	_waypoints += 1


func _on_lap(_lap: int) -> void:
	_finish("lap_completed")


func _finish(result: String) -> void:
	if _done: return
	_done = true
	print("DOORS_CLOSED result=%s t=%.1f waypoints=%d max_speed_kmh=%.1f min_upright=%.2f" % [
		result, float(_ticks) / Engine.physics_ticks_per_second, _waypoints,
		_max_speed_mps * 3.6, _min_upright])
	quit(0 if result == "lap_completed" else 1)
