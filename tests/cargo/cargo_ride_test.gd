extends GdUnitTestSuite

## The T2.3 single-player cargo criterion (plan §6 paso 5, D88): ONE full lap
## on the real playground with two packages STRAPPED to anchors, two FREE on
## the aisle floor, and the crew WALKING the corridor — sampled every physics
## tick: zero packages under the floor plate, zero out through walls,
## windshield or roof (door exits are latched, counted and printed, never
## asserted zero), strapped drift 0.000, and the crew stays aboard and on the
## floor through the bumps. The bus itself must also drive (the demo lap
## completes).

const MAX_LAP_TICKS: int = 60 * 150

var _below_floor: int = 0
var _hard_exits: int = 0
var _door_exits: int = 0
var _max_strap_drift: float = 0.0
var _crew_off_floor_ticks: int = 0


func test_lap_with_strapped_free_and_a_walking_crew() -> void:
	var runner: GdUnitSceneRunner = scene_runner("res://scenes/playground.tscn")
	runner.set_time_factor(2.0)
	var scene: Node = runner.scene()
	await _wait(scene, 90)
	var bus: Bus = _bus(scene)
	var crew: CrewMember = _crew(scene)
	if bus == null or crew == null:
		return
	# Board the crew by hand (the door's plane only fires within its gap).
	crew.global_position = bus.global_transform * Vector3(0.0, -0.55, 0.0)
	crew.aboard = true
	await _wait(scene, 45)
	assert_bool(crew.is_on_floor()).is_true()
	# The scene's four spawned packages (paso 4): strap the two on the racks,
	# leave the two on the aisle floor.
	var cargo_node: Node = scene.get_node_or_null("Cargo")
	assert_object(cargo_node).is_not_null()
	var packages: Array[Package] = []
	for child: Node in cargo_node.get_children():
		if child is Package:
			packages.append(child)
	assert_int(packages.size()).is_equal(4)
	var anchors: Array[RestraintAnchor] = [_anchor(scene, "Bus/BusInterior/Restraints/restraint_left_5"), _anchor(scene, "Bus/BusInterior/Restraints/restraint_right_0")]
	assert_object(anchors[0]).is_not_null()
	assert_object(anchors[1]).is_not_null()
	# r1.2 precision: no anchor's footprint may overlap a spawned package —
	# a strap born inside a resting box would depenetrate it. Assert the
	# z-distance between every spawned package on a rack top and every used
	# anchor (same top) is >= 0.4 m (spawns at z=-/+0.4, used anchors at
	# z=+1.0/-1.0: 1.4 m).
	for pkg: Package in packages:
		var pkg_local: Vector3 = bus.global_transform.affine_inverse() * pkg.global_position
		for anchor: RestraintAnchor in anchors:
			var anchor_local: Vector3 = bus.global_transform.affine_inverse() * anchor.global_position
			if absf(anchor_local.y - pkg_local.y) < 0.3:
				assert_float(absf(anchor_local.z - pkg_local.z)).override_failure_message("anchor footprint overlaps a spawned package").is_greater_equal(0.4)
	assert_bool(packages[0].hold(crew)).is_true()
	assert_bool(packages[0].strap(anchors[0])).is_true()
	assert_bool(packages[1].hold(crew)).is_true()
	assert_bool(packages[1].strap(anchors[1])).is_true()
	# Drive the lap with the demo driver; the crew walks the corridor.
	scene.set("demo_mode", true)
	scene.get_node("DemoDriver").set("enabled", true)
	var bus_for_drive: Bus = bus
	var ticks: int = 0
	var lap_done: bool = false
	while ticks < MAX_LAP_TICKS and not lap_done:
		await scene.get_tree().physics_frame
		ticks += 1
		if ticks % 60 == 0:
			var dir: float = 1.0 if (ticks / 60) % 2 == 0 else -1.0
			crew.drive_move(Vector2(0.0, dir * -1.0), false, false, crew.global_basis)
		_sample(bus, crew, packages, anchors)
		var driver: Node = scene.get_node("DemoDriver")
		var idx: Variant = driver.get("current_index")
		if idx is int:
			var index: int = idx
			if index >= 16:
				lap_done = true
	print("CRITERION ticks=%d lap_done=%s below_floor=%d hard_exits=%d door_exits=%d strap_drift=%.6f crew_off_floor=%d" % [ticks, lap_done, _below_floor, _hard_exits, _door_exits, _max_strap_drift, _crew_off_floor_ticks])
	assert_bool(lap_done).override_failure_message("the demo lap did not complete with cargo").is_true()
	assert_int(_below_floor).override_failure_message("a package went under the floor plate").is_equal(0)
	assert_int(_hard_exits).override_failure_message("a package left the hull through walls/windshield/roof").is_equal(0)
	assert_float(_max_strap_drift).override_failure_message("a strapped package drifted from its anchor").is_less_equal(0.0005)
	assert_int(_crew_off_floor_ticks).override_failure_message("the crew was ejected while walking with cargo").is_less(30)


func _sample(bus: Bus, crew: CrewMember, packages: Array[Package], anchors: Array[RestraintAnchor]) -> void:
	var inverse: Transform3D = bus.global_transform.affine_inverse()
	for i: int in range(packages.size()):
		var local: Vector3 = inverse * packages[i].global_position
		if local.y < -0.45 and packages[i].restraint == Package.Restraint.FREE:
			_below_floor += 1
		var outside: bool = absf(local.x) > 1.30 or absf(local.z) > 4.05 or local.y > 2.50
		if outside:
			# Door exits (side gap or open rear) are counted, never asserted.
			if (local.x > 1.15 and local.z > -2.2 and local.z < -1.3) or local.z > 3.9:
				_door_exits += 1
			else:
				_hard_exits += 1
	for i: int in range(anchors.size()):
		var anchor: RestraintAnchor = anchors[i]
		if anchor.occupant != null:
			_max_strap_drift = maxf(_max_strap_drift, anchor.occupant.global_position.distance_to(anchor.global_position))
	if not crew.is_on_floor():
		_crew_off_floor_ticks += 1


func _bus(scene: Node) -> Bus:
	var node: Node = scene.get_tree().get_first_node_in_group("bus")
	if node is Bus:
		return node
	assert_bool(false).override_failure_message("no bus").is_true()
	return null


func _crew(scene: Node) -> CrewMember:
	var node: Node = scene.get_tree().get_first_node_in_group("crew")
	if node is CrewMember:
		return node
	assert_bool(false).override_failure_message("no crew").is_true()
	return null


func _anchor(scene: Node, path: String) -> RestraintAnchor:
	var node: Node = scene.get_node_or_null(path)
	if node is RestraintAnchor:
		return node
	assert_bool(false).override_failure_message("missing anchor " + path).is_true()
	return null


func _wait(scene: Node, ticks: int) -> void:
	for i: int in range(ticks):
		await scene.get_tree().physics_frame
