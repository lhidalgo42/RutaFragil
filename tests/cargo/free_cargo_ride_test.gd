extends GdUnitTestSuite

## Free cargo on the demo lap (D81/D85 — the committed configuration of
## docs/evidencia/M2-T2.3/03_free_cargo_measurement.txt, c': default
## friction, k=160 vertical damper, CCD on): four packages ride ONE full lap
## on the real playground — two on the rack tops, two on the aisle floor —
## sampled EVERY physics tick: none below the floor plate, none out through
## walls, windshield, roof or floor. Exits through the DOORS (the side door
## and the open rear gap — D89 keeps them open) are latched per box, counted
## and printed, never asserted. The damper must show: boxes lift over the
## bumps but stay contained (undamped measured: 1.5 m and 2/4 escapes;
## damped k=160: 0.45 m and zero hard violations).

const PACKAGE_SCENE: String = "res://src/cargo/package.tscn"
## Rack top (0.8) plus half the box (0.2). The shelf markers sit INSIDE the
## rack volume, so the spawn height is the resting height on top of the rack.
const RACK_REST_Y: float = 1.0
## Floor plate top (-0.6) plus half the box (0.2).
const FLOOR_REST_Y: float = -0.4
## Sim-second budget for one lap; run_demo's own budget is 120 s fixed-fps.
const MAX_LAP_TICKS: int = 60 * 150

var _below_floor: int = 0
var _hard_exits: int = 0
var _door_exits: int = 0
var _max_lift: float = 0.0
var _max_rel_vy: float = 0.0
var _exit_state: Array[int] = []
var _first_hard_exit: String = ""


func test_free_packages_ride_the_lap_contained() -> void:
	var runner: GdUnitSceneRunner = scene_runner("res://scenes/playground.tscn")
	runner.set_time_factor(4.0)
	var scene: Node = runner.scene()
	# This suite spawns its own four packages: suppress the scene spawn.
	scene.set("cargo_spawn", false)
	# demo_mode is enabled explicitly: the authored default is false (M1-T1.1).
	scene.set("demo_mode", true)
	scene.get_node("DemoDriver").set("enabled", true)
	scene.get_node("BusInput").set("enabled", false)
	var bus_node: Node = scene.get_tree().get_first_node_in_group("bus")
	var driver_node: Node = scene.get_node_or_null("DemoDriver")
	assert_bool(bus_node is Bus).is_true()
	assert_bool(driver_node is DemoDriver).is_true()
	if not (bus_node is Bus) or not (driver_node is DemoDriver):
		return
	var bus: Bus = bus_node
	var driver: DemoDriver = driver_node
	var shelf_left: Vector3 = _position_of(scene, "Bus/BusInterior/Positions/shelf_left")
	var shelf_right: Vector3 = _position_of(scene, "Bus/BusInterior/Positions/shelf_right")
	# Bus-local spawn poses: on the rack tops (marker x/z, resting height) and
	# on the aisle floor between the racks.
	var locals: Array[Vector3] = [
		Vector3(shelf_left.x, RACK_REST_Y, shelf_left.z),
		Vector3(shelf_right.x, RACK_REST_Y, shelf_right.z),
		Vector3(-0.3, FLOOR_REST_Y, 0.5),
		Vector3(0.3, FLOOR_REST_Y, -1.0),
	]
	var rest_ys: Array[float] = []
	var packages: Array[Package] = []
	for local: Vector3 in locals:
		var package: Package = _spawn(scene, bus.global_transform * local)
		if package == null:
			return
		packages.append(package)
		rest_ys.append(local.y)
		_exit_state.append(0)
	# The bus is parked at spawn, so the first tick sampling is already valid.
	var start_laps: int = driver.laps
	var tick: int = 0
	while driver.laps == start_laps and tick < MAX_LAP_TICKS:
		await get_tree().physics_frame
		tick += 1
		_sample_tick(bus, packages, rest_ys)
	print("free cargo lap: ticks=%d below_floor=%d hard_exits=%d door_exits=%d max_lift=%.3f m max_rel_vy=%.2f m/s" % [
		tick, _below_floor, _hard_exits, _door_exits, _max_lift, _max_rel_vy])
	for i: int in range(packages.size()):
		var final_local: Vector3 = bus.global_transform.affine_inverse() * packages[i].global_position
		print("  box%d final bus-local %s" % [i, str(final_local)])
	assert_int(driver.laps).override_failure_message("the demo never completed the lap").is_greater(start_laps)
	assert_int(_below_floor).override_failure_message("packages under the floor plate").is_equal(0)
	assert_int(_hard_exits).override_failure_message("packages out through walls/windshield/roof/floor: " + _first_hard_exit).is_equal(0)
	assert_float(_max_lift).override_failure_message("no package ever lifted over the bumps; the lap did not exercise the damper").is_greater(0.05)
	assert_float(_max_lift).override_failure_message("damper not containing: undamped measured 1.5 m, damped k=160 0.45 m").is_less(1.0)


func test_wheel_ray_ignores_cargo_and_crew_in_its_column() -> void:
	# D90 (the authorized scope amendment): the suspension ray read CARGO as
	# ground — measured: a box in a wheel column launches the parked bus
	# (~54 kN in one corner, y=3.84 m; exit 100 without the fix). The FR
	# column (x=1.1, z=-2.75) sits in the side-door gap, where the crew steps
	# every boarding. This test parks a box AND the crew inside that column:
	# without the fix the bus flies; with it the ray only sees the WORLD and
	# the bus rests at its normal height (measured rest: 0.977 m).
	var runner: GdUnitSceneRunner = scene_runner("res://scenes/playground.tscn")
	var scene: Node = runner.scene()
	for i: int in range(120):
		await scene.get_tree().physics_frame
	var bus_node: Node = scene.get_tree().get_first_node_in_group("bus")
	var crew_node: Node = scene.get_tree().get_first_node_in_group("crew")
	assert_bool(bus_node is Bus).is_true()
	assert_bool(crew_node is CrewMember).is_true()
	if not (bus_node is Bus) or not (crew_node is CrewMember):
		return
	var bus: Bus = bus_node
	var crew: CrewMember = crew_node
	var rest_y: float = bus.global_position.y
	# The box covers the ray line (column x=1.1, the box spans 0.8-1.2);
	# positioned before add_child, inside the open doorway of the FR column.
	var box: Package = _spawn(scene, bus.global_transform * Vector3(1.0, -0.4, -2.75))
	assert_object(box).is_not_null()
	crew.global_position = bus.global_transform * Vector3(1.0, -0.55, -2.55)
	crew.aboard = true
	var max_omega: float = 0.0
	var min_y: float = rest_y
	var max_y: float = rest_y
	for tick: int in range(120):
		await scene.get_tree().physics_frame
		max_omega = maxf(max_omega, bus.angular_velocity.length())
		min_y = minf(min_y, bus.global_position.y)
		max_y = maxf(max_y, bus.global_position.y)
	var end_y: float = bus.global_position.y
	print("RAY-TEST max_omega=%.4f y_range=%.4f end_y=%.3f (rest %.3f)" % [max_omega, max_y - min_y, end_y, rest_y])
	assert_float(max_omega).override_failure_message("the wheel ray kicked the bus with cargo+crew in the column").is_less(0.05)
	assert_float(max_y - min_y).override_failure_message("the bus moved vertically with cargo+crew in the column").is_less(0.05)
	assert_float(absf(end_y - rest_y)).override_failure_message("the bus no longer rests at its normal height (the ray lost the ground)").is_less(0.05)


func _position_of(scene: Node, path: String) -> Vector3:
	var node: Node = scene.get_node_or_null(path)
	assert_bool(node is Marker3D).override_failure_message("missing " + path).is_true()
	if node is Marker3D:
		var marker: Marker3D = node
		return marker.position
	return Vector3.ZERO


func _spawn(scene: Node, at_global: Vector3) -> Package:
	var packed: Resource = load(PACKAGE_SCENE)
	assert_bool(packed is PackedScene).override_failure_message("package.tscn did not load").is_true()
	if not (packed is PackedScene):
		return null
	var packed_scene: PackedScene = packed
	var node: Node = packed_scene.instantiate()
	if not (node is Package):
		assert_bool(false).override_failure_message("package.tscn root must be a Package").is_true()
		return null
	var package: Package = node
	# Position BEFORE add_child (the measured rule). The playground root sits
	# at the identity, so the local position IS the world position.
	package.position = at_global
	scene.add_child(package)
	return package


func _sample_tick(bus: Bus, packages: Array[Package], rest_ys: Array[float]) -> void:
	var inverse: Transform3D = bus.global_transform.affine_inverse()
	var up: Vector3 = bus.global_transform.basis.y.normalized()
	for i: int in range(packages.size()):
		var package: Package = packages[i]
		var local: Vector3 = inverse * package.global_position
		if BusInterior.is_inside_local(local):
			_exit_state[i] = 0
			_max_lift = maxf(_max_lift, local.y - rest_ys[i])
			# The damper's domain metric: the box's vertical speed relative to
			# the bus point under it. Only meaningful inside the hull (outside,
			# the lever arm turns this into a number about the bus, not the box).
			var reference: Vector3 = Package.rigid_point_velocity(
				bus.linear_velocity, bus.angular_velocity, package.global_position - bus.global_position)
			var rel_vy: float = (package.linear_velocity - reference).dot(up)
			_max_rel_vy = maxf(_max_rel_vy, absf(rel_vy))
			# Floor plate top is -0.6, resting center -0.4; -0.5 means the box
			# bottom is 10 cm INTO the plate (the k=160 failure read -0.70).
			# Ordinary contact jitter is millimetres.
			if local.y < -0.5:
				_below_floor += 1
			continue
		if _exit_state[i] != 0:
			# Already out: the crossing tick latched the channel; relative
			# drift of a box riding the world is not a new exit.
			continue
		if _is_door_exit(local):
			_exit_state[i] = 1
			_door_exits += 1
		else:
			_exit_state[i] = 2
			_hard_exits += 1
			if _first_hard_exit.is_empty():
				_first_hard_exit = "box%d at bus-local %s" % [i, str(local)]


## The real openings (D89 pins): the rear gap (z=3.85, |x| < 0.7 between the
## rear wall posts) and the side door (x=+1.2, z in -3.2..-2.3 between the
## right wall segments). Walls, windshield, roof and floor are NOT doors.
func _is_door_exit(local: Vector3) -> bool:
	if local.z > 3.8 and absf(local.x) < 0.7:
		return true
	if local.x > 1.15 and local.z >= -3.2 and local.z <= -2.3:
		return true
	return false
