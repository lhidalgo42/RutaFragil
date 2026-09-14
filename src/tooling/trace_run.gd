extends SceneTree

## Temporary diagnostic: drives the route and prints where the bus goes, its speed, its lateral
## offset from the axis and what it touches, so a rollover can be traced to a place.
## ++ scene=<res> data=<res json> from=<waypoint> seconds=<max>

var _scene: String = "res://scenes/route_requinoa.tscn"
var _data: String = "res://data/b0_requinoa.json"
var _from: int = -1
var _seconds: float = 60.0
var _bus: Node = null
var _driver: Node = null
var _map: Variant = null
var _t: float = 0.0
var _last: float = -1.0
var _done: bool = false
var _reported: bool = false


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		var p: PackedStringArray = arg.split("=", true, 1)
		if p.size() != 2:
			continue
		match p[0]:
			"scene": _scene = p[1]
			"data": _data = p[1]
			"from": _from = p[1].to_int()
			"seconds": _seconds = p[1].to_float()
	process_frame.connect(_load, CONNECT_ONE_SHOT)


func _load() -> void:
	var packed: Resource = load(_scene)
	if not (packed is PackedScene):
		print("TRACE load_failed")
		quit(1)
		return
	var ps: PackedScene = packed
	var scene: Node = ps.instantiate()
	root.add_child(scene)
	_bus = scene.get_node_or_null("PlaceholderBus")
	_driver = scene.get_node_or_null("DemoDriver")
	_map = load("res://src/biomes/osm_map_data.gd").call("load_from", _data)
	if _from >= 0:
		var circuit: Variant = _driver.get("circuit")
		var here: Vector3 = circuit.call("waypoint_position", _from)
		var next: Vector3 = circuit.call("waypoint_position", (_from + 1) % int(circuit.call("waypoint_count")))
		_bus.set("global_position", here + Vector3.UP * 1.0)
		_bus.set("global_rotation", Vector3(0.0, atan2(-(next.x - here.x), -(next.z - here.z)), 0.0))
		_driver.set("current_index", (_from + 1) % int(circuit.call("waypoint_count")))
	_bus.connect("rolled_over", _on_roll)
	_driver.connect("stuck", _on_stuck)
	physics_frame.connect(_tick)


func _tick() -> void:
	if _done:
		return
	_t += 1.0 / 60.0
	var p: Vector3 = _bus.get("global_position")
	var pr: Vector2 = _map.call("project", p)
	var up: float = (_bus.get("global_basis") as Basis).y.dot(Vector3.UP)
	if _t - _last >= 0.5:
		_last = _t
		print("TRACE t=%5.1f wp=%3d pos=(%.0f,%.0f) s=%6.0f lat=%6.1f v=%5.1f km/h up=%.2f" % [
			_t, int(_driver.get("current_index")), p.x, p.z, pr.x, pr.y, float(_bus.call("speed_mps")) * 3.6, up])
	if up < 0.995 and not _reported:
		_reported = true
		var space: PhysicsDirectSpaceState3D = root.world_3d.direct_space_state
		for k: int in 8:
			var ang: float = TAU * float(k) / 8.0
			var dir: Vector3 = Vector3(cos(ang), 0.0, sin(ang))
			for h: float in [0.2, 0.8, 1.6]:
				var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(p + Vector3.UP * h, p + Vector3.UP * h + dir * 10.0)
				q.exclude = [_bus.get_rid()] if _bus is CollisionObject3D else []
				var hh: Dictionary = space.intersect_ray(q)
				if not hh.is_empty():
					print("TRACE  cerca: dir=%3.0f° h=%.1f -> %s a %.1f m" % [rad_to_deg(ang), h, str((hh.get("collider") as Node).name), p.distance_to(hh.get("position"))])
	if _t >= _seconds:
		print("TRACE fin")
		_done = true
		quit(0)


func _on_roll() -> void:
	var p: Vector3 = _bus.get("global_position")
	var pr: Vector2 = _map.call("project", p)
	print("TRACE VUELCO t=%.1f pos=(%.1f,%.1f) s=%.0f lat=%.1f v=%.1f" % [_t, p.x, p.z, pr.x, pr.y, float(_bus.call("speed_mps")) * 3.6])
	_done = true
	quit(0)


func _on_stuck() -> void:
	var p: Vector3 = _bus.get("global_position")
	var pr: Vector2 = _map.call("project", p)
	print("TRACE ATASCO t=%.1f pos=(%.1f,%.1f) s=%.0f lat=%.1f" % [_t, p.x, p.z, pr.x, pr.y])
	_done = true
	quit(0)
