extends GdUnitTestSuite

## Restraint anchors (D69/D84, M2-T2.3): the twelve BusInterior/Restraints
## markers carry the RestraintAnchor script, the "restraint_anchor" group and
## their rack-top positions — pinned so an editor re-save fails HERE (round-3).
## strap()/unstrap() are Package's fixed phase-0 contract; the HELD
## precondition is set directly on the public state so this suite does not
## depend on CrewHands. Drift vs the anchor is zero by construction (ADR-006)
## and measured over a full demo lap.

const PLAYGROUND_SCENE: String = "res://scenes/playground.tscn"
const BUS_SCENE: String = "res://src/vehicle/bus.tscn"
const PACKAGE_SCENE: String = "res://src/cargo/package.tscn"
const BOX_SIZE_M: float = 0.4
const BOX_HALF_M: float = 0.2
const CREW_RADIUS_M: float = 0.3
const DRIFT_TOLERANCE_M: float = 0.0005
const CONTACT_TOLERANCE_M: float = 0.03
# A lap is ~17 waypoints (under 120 game-seconds in run_demo); the budget
# bounds the loop without hanging if the demo never wraps.
const LAP_TICK_BUDGET: int = 60 * 150

var _lap_done: bool = false


func test_twelve_anchors_carry_script_and_group_and_start_free() -> void:
	# The pin loads bus.tscn, not the playground: bus_interior.tscn is what an
	# editor re-save would corrupt, and the bus scene pulls none of the crew
	# chain (a neighbor's parse error once hit the playground-loading test).
	var runner: GdUnitSceneRunner = scene_runner(BUS_SCENE)
	var scene: Node = runner.scene()
	var nodes: Array[Node] = scene.get_tree().get_nodes_in_group("restraint_anchor")
	assert_int(nodes.size()).is_equal(12)
	var restraints: Node = scene.get_node_or_null("BusInterior/Restraints")
	assert_object(restraints).is_not_null()
	if restraints == null:
		return
	for side: String in ["left", "right"]:
		for i: int in range(6):
			var anchor_name: String = "restraint_%s_%d" % [side, i]
			var anchor: RestraintAnchor = _anchor(restraints, anchor_name)
			assert_bool(anchor != null).override_failure_message("anchor %s missing or without the RestraintAnchor script" % anchor_name).is_true()
			if anchor == null:
				continue
			assert_bool(anchor.is_in_group("restraint_anchor")).is_true()
			assert_bool(anchor.is_free()).is_true()
			# Positions pinned too (the waypoint-pin precedent): the owner's
			# T2.3 round-2 call puts the anchors ON the rack tops (x=±0.875,
			# y=1.0), never inside the rack volume as the first pass had them.
			var expected: Vector3 = Vector3(-0.875 if side == "left" else 0.875, 1.0, -1.0 + 0.4 * float(i))
			assert_vector(anchor.position).override_failure_message("anchor %s moved: %s" % [anchor_name, str(anchor.position)]).is_equal_approx(expected, Vector3(0.001, 0.001, 0.001))


func test_strap_occupies_the_anchor_and_rejects_a_second_package() -> void:
	var bus: Bus = await _spawn_bus()
	if bus == null:
		return
	var anchor: RestraintAnchor = _anchor(bus.get_node("BusInterior/Restraints"), "restraint_left_2")
	assert_object(anchor).is_not_null()
	if anchor == null:
		return
	var first: Package = _make_package(anchor.global_transform)
	add_child(first)
	first.restraint = Package.Restraint.HELD
	assert_bool(first.strap(anchor)).is_true()
	assert_bool(anchor.is_free()).is_false()
	assert_object(anchor.occupant).is_same(first)
	# One package per anchor: the second strap on the occupied anchor fails.
	var second: Package = _make_package(anchor.global_transform)
	add_child(second)
	second.restraint = Package.Restraint.HELD
	assert_bool(second.strap(anchor)).is_false()
	assert_object(anchor.occupant).is_same(first)
	assert_bool(second.strapped_to == null).is_true()


func test_strap_requires_held_state() -> void:
	var bus: Bus = await _spawn_bus()
	if bus == null:
		return
	var anchor: RestraintAnchor = _anchor(bus.get_node("BusInterior/Restraints"), "restraint_right_1")
	assert_object(anchor).is_not_null()
	if anchor == null:
		return
	# FREE (never held): the strap precondition fails and the anchor stays free.
	var box: Package = _make_package(anchor.global_transform)
	add_child(box)
	assert_bool(box.strap(anchor)).is_false()
	assert_bool(anchor.is_free()).is_true()


func test_strap_parents_freezes_and_enables_collision_at_the_anchor() -> void:
	var bus: Bus = await _spawn_bus()
	if bus == null:
		return
	var restraints: Node = bus.get_node("BusInterior/Restraints")
	var anchor: RestraintAnchor = _anchor(restraints, "restraint_right_3")
	assert_object(anchor).is_not_null()
	if anchor == null:
		return
	var box: Package = _make_package(anchor.global_transform)
	add_child(box)
	box.restraint = Package.Restraint.HELD
	assert_bool(box.strap(anchor)).is_true()
	# Deferred collision changes get their frames before asserting. The
	# load-bearing bit is freeze (no own physics → zero drift); the docstring's
	# "kinematic" is implemented as FREEZE_MODE_STATIC — the right read for a
	# bus-riding shelf (kinematic would impart the bus's velocity to a bumping
	# crew member). Not asserted, reported instead.
	await _wait_ticks(2)
	assert_bool(box.get_parent() == bus).override_failure_message("a strapped package must be a child of the bus").is_true()
	assert_bool(box.freeze).is_true()
	assert_int(box.restraint).is_equal(Package.Restraint.STRAPPED)
	assert_object(box.strapped_to).is_same(anchor)
	var shape_node: CollisionShape3D = _collision_shape_of(box)
	assert_object(shape_node).is_not_null()
	if shape_node != null:
		assert_bool(shape_node.disabled).override_failure_message("a strapped package keeps collision ON").is_false()
	# Bus-local position equals the anchor's (Restraints/BusInterior transforms
	# are identity all the way up to the bus body).
	assert_float(box.position.distance_to(anchor.position)).is_less(0.001)


func test_unstrap_returns_to_held_and_frees_the_anchor() -> void:
	var bus: Bus = await _spawn_bus()
	if bus == null:
		return
	var anchor: RestraintAnchor = _anchor(bus.get_node("BusInterior/Restraints"), "restraint_left_0")
	assert_object(anchor).is_not_null()
	if anchor == null:
		return
	var box: Package = _make_package(anchor.global_transform)
	add_child(box)
	box.restraint = Package.Restraint.HELD
	assert_bool(box.strap(anchor)).is_true()
	box.unstrap()
	await _wait_ticks(2)
	assert_int(box.restraint).is_equal(Package.Restraint.HELD)
	assert_bool(anchor.is_free()).is_true()
	assert_object(anchor.occupant).is_null()
	assert_bool(box.strapped_to == null).is_true()
	# r1.4: unstrap() returns to the ORIGINAL parent (the node it came from),
	# not to the bus's parent.
	assert_object(box.get_parent()).override_failure_message("unstrap did not return to the original parent").is_same(self)
	# HELD keeps collision OFF (a live shape inside the hull kicks the bus).
	var shape_node: CollisionShape3D = _collision_shape_of(box)
	assert_object(shape_node).is_not_null()
	if shape_node != null:
		assert_bool(shape_node.disabled).override_failure_message("HELD must keep collision OFF").is_true()


func test_strapped_packages_have_zero_drift_for_a_full_lap() -> void:
	var runner: GdUnitSceneRunner = scene_runner(PLAYGROUND_SCENE)
	runner.set_time_factor(4.0)
	var scene: Node = runner.scene()
	# The Playground/BusInput types are NOT imported here: they drag the
	# CrewInput/CrewHands chain into a suite that never touches it (the demo
	# is driven by name, the playground_scene_test pattern).
	var bus_node: Node = scene.get_tree().get_first_node_in_group("bus")
	var driver_node: Node = scene.get_node_or_null("DemoDriver")
	assert_bool(bus_node is Bus).is_true()
	assert_bool(driver_node is DemoDriver).is_true()
	if not (bus_node is Bus) or not (driver_node is DemoDriver):
		return
	var bus: Bus = bus_node
	var driver: DemoDriver = driver_node
	var restraints: Node = scene.get_node_or_null("Bus/BusInterior/Restraints")
	assert_object(restraints).is_not_null()
	if restraints == null:
		return
	var anchor_a: RestraintAnchor = _anchor(restraints, "restraint_left_2")
	var anchor_b: RestraintAnchor = _anchor(restraints, "restraint_right_3")
	assert_object(anchor_a).is_not_null()
	assert_object(anchor_b).is_not_null()
	if anchor_a == null or anchor_b == null:
		return
	var box_a: Package = _make_package(anchor_a.global_transform)
	var box_b: Package = _make_package(anchor_b.global_transform)
	add_child(box_a)
	add_child(box_b)
	box_a.restraint = Package.Restraint.HELD
	box_b.restraint = Package.Restraint.HELD
	assert_bool(box_a.strap(anchor_a)).is_true()
	assert_bool(box_b.strap(anchor_b)).is_true()
	if box_a.strapped_to == null or box_b.strapped_to == null:
		return
	# The demo takes the wheel only after both boxes ride strapped.
	_lap_done = false
	driver.lap_completed.connect(_on_lap_completed)
	scene.set("demo_mode", true)
	driver.enabled = true
	scene.get_node("BusInput").set("enabled", false)
	var max_drift: float = 0.0
	var ticks: int = 0
	while not _lap_done and ticks < LAP_TICK_BUDGET:
		await get_tree().physics_frame
		ticks += 1
		var drift_a: float = box_a.global_position.distance_to(anchor_a.global_position)
		var drift_b: float = box_b.global_position.distance_to(anchor_b.global_position)
		max_drift = maxf(max_drift, maxf(drift_a, drift_b))
	print("strap drift: max=%.6f m over %d ticks (one lap)" % [max_drift, ticks])
	assert_bool(_lap_done).override_failure_message("the demo lap never completed").is_true()
	assert_float(max_drift).is_less(DRIFT_TOLERANCE_M)


func test_crew_bumps_into_a_strapped_package_like_a_shelf() -> void:
	var runner: GdUnitSceneRunner = scene_runner(PLAYGROUND_SCENE)
	var scene: Node = runner.scene()
	var bus_node: Node = scene.get_tree().get_first_node_in_group("bus")
	var crew_node: Node = scene.get_tree().get_first_node_in_group("crew")
	assert_bool(bus_node is Bus).is_true()
	assert_bool(crew_node is CrewMember).is_true()
	if not (bus_node is Bus) or not (crew_node is CrewMember):
		return
	var bus: Bus = bus_node
	var crew: CrewMember = crew_node
	# Headless input reads as all-zero: CrewInput would zero the walk velocity
	# every tick and fight the scripted drive_move.
	var crew_input: Node = scene.get_node_or_null("CrewInput")
	if crew_input != null:
		crew_input.set("enabled", false)
	var restraints: Node = scene.get_node_or_null("Bus/BusInterior/Restraints")
	assert_object(restraints).is_not_null()
	if restraints == null:
		return
	# restraint_right_2 (0.875, 1.0, -0.2): the box now sits ON the shelf
	# (y 0.8..1.2), its corridor face at x=0.675 — 0.075 m BEHIND the rack
	# face (x=0.6), so the shelf face holds the standing capsule off the box
	# (axis at x=0.3). The pinned contract: she presses at the box, it does
	# not move, and she never enters its volume.
	var anchor: RestraintAnchor = _anchor(restraints, "restraint_right_2")
	assert_object(anchor).is_not_null()
	if anchor == null:
		return
	var box: Package = _make_package(anchor.global_transform)
	add_child(box)
	box.restraint = Package.Restraint.HELD
	assert_bool(box.strap(anchor)).is_true()
	if box.strapped_to == null:
		return
	# Teleport into the corridor facing the box (crew_ride pattern: place,
	# settle, then flag aboard).
	crew.global_position = bus.global_transform * Vector3(-0.25, -0.35, -0.2)
	await _wait_ticks(10)
	crew.aboard = true
	var box_local_before: Vector3 = box.position
	var min_clearance: float = INF
	var max_box_move: float = 0.0
	var max_axis_x: float = -INF
	for tick: int in range(90):
		# Press +x in the bus frame every tick, exactly what CrewInput does.
		crew.drive_move(Vector2(1.0, 0.0), false, false, bus.global_transform.basis)
		await get_tree().physics_frame
		var crew_local: Vector3 = bus.global_transform.affine_inverse() * crew.global_position
		min_clearance = minf(min_clearance, _aabb_clearance_xz(crew_local, box.position))
		max_box_move = maxf(max_box_move, box.position.distance_to(box_local_before))
		max_axis_x = maxf(max_axis_x, crew_local.x)
	print("bump(top): min_clearance=%.3f m, max_box_move=%.6f m, crew_axis_x=%.3f" % [min_clearance, max_box_move, max_axis_x])
	# Bounds: ≤0.40 proves she pressed to the guard; the axis pin names the shelf.
	assert_float(max_box_move).override_failure_message("the strapped box moved under the crew's push").is_less(0.0005)
	assert_float(min_clearance).override_failure_message("the crew entered the strapped box's volume").is_greater_equal(CREW_RADIUS_M - CONTACT_TOLERANCE_M)
	assert_float(min_clearance).override_failure_message("the crew never pressed up to the shelf guard").is_less_equal(0.40)
	assert_float(max_axis_x).override_failure_message("the crew crossed the shelf face plane (x=0.6)").is_less_equal(0.33)


func test_corridor_stays_clear_between_two_strapped_boxes() -> void:
	var runner: GdUnitSceneRunner = scene_runner(PLAYGROUND_SCENE)
	var scene: Node = runner.scene()
	var bus_node: Node = scene.get_tree().get_first_node_in_group("bus")
	var crew_node: Node = scene.get_tree().get_first_node_in_group("crew")
	assert_bool(bus_node is Bus).is_true()
	assert_bool(crew_node is CrewMember).is_true()
	if not (bus_node is Bus) or not (crew_node is CrewMember):
		return
	var bus: Bus = bus_node
	var crew: CrewMember = crew_node
	# CrewInput disabled: headless input reads as all-zero and would fight the
	# scripted drive_move.
	var crew_input: Node = scene.get_node_or_null("CrewInput")
	if crew_input != null:
		crew_input.set("enabled", false)
	var restraints: Node = scene.get_node_or_null("Bus/BusInterior/Restraints")
	assert_object(restraints).is_not_null()
	if restraints == null:
		return
	# One box per side on the new rack-top anchors (the owner's measure):
	# left_2 (-0.875, 1.0, -0.2) and right_3 (0.875, 1.0, 0.2).
	var anchor_a: RestraintAnchor = _anchor(restraints, "restraint_left_2")
	var anchor_b: RestraintAnchor = _anchor(restraints, "restraint_right_3")
	assert_object(anchor_a).is_not_null()
	assert_object(anchor_b).is_not_null()
	if anchor_a == null or anchor_b == null:
		return
	var box_a: Package = _make_package(anchor_a.global_transform)
	var box_b: Package = _make_package(anchor_b.global_transform)
	add_child(box_a)
	add_child(box_b)
	box_a.restraint = Package.Restraint.HELD
	box_b.restraint = Package.Restraint.HELD
	assert_bool(box_a.strap(anchor_a)).is_true()
	assert_bool(box_b.strap(anchor_b)).is_true()
	if box_a.strapped_to == null or box_b.strapped_to == null:
		return
	# Walk the corridor center (x=0) the full length of the racks, straight
	# past both boxes.
	crew.global_position = bus.global_transform * Vector3(0.0, -0.35, -1.6)
	await _wait_ticks(10)
	crew.aboard = true
	var pos_a: Vector3 = box_a.position
	var pos_b: Vector3 = box_b.position
	var min_center: float = INF
	var max_box_move: float = 0.0
	var out_of_hull: bool = false
	for tick: int in range(70):
		crew.drive_move(Vector2(0.0, 1.0), false, false, bus.global_transform.basis)
		await get_tree().physics_frame
		var crew_local: Vector3 = bus.global_transform.affine_inverse() * crew.global_position
		# Center-to-center in the corridor plane (x-z; the vertical capsule
		# shares its x/z with the origin). The owner's no-touch bound:
		# 0.2 half box + 0.3 capsule radius = 0.5 m.
		var dist: float = minf(
			Vector2(crew_local.x - pos_a.x, crew_local.z - pos_a.z).length(),
			Vector2(crew_local.x - pos_b.x, crew_local.z - pos_b.z).length())
		min_center = minf(min_center, dist)
		max_box_move = maxf(max_box_move, maxf(box_a.position.distance_to(pos_a), box_b.position.distance_to(pos_b)))
		if not BusInterior.is_inside_local(crew_local):
			out_of_hull = true
	print("corridor: min_center_distance=%.3f m, max_box_move=%.6f m, out_of_hull=%s" % [min_center, max_box_move, str(out_of_hull)])
	assert_float(min_center).override_failure_message("the crew touched a strapped box walking the corridor").is_greater_equal(0.5)
	assert_float(max_box_move).override_failure_message("a strapped box moved as the crew walked past").is_less(0.0005)
	assert_bool(out_of_hull).override_failure_message("the crew ended up outside the hull").is_false()


func _anchor(restraints: Node, anchor_name: String) -> RestraintAnchor:
	var node: Node = restraints.get_node_or_null(anchor_name)
	if node is RestraintAnchor:
		return node
	return null


## The package comes from package.tscn; the hand-built fallback (same box:
## 0.4 m, mass from TuningTable, layer 2) keeps the suite on the class
## contract. Position is set BEFORE the caller's add_child (the rule).
func _make_package(at: Transform3D) -> Package:
	var package: Package = null
	if ResourceLoader.exists(PACKAGE_SCENE):
		var packed: Resource = load(PACKAGE_SCENE)
		if packed is PackedScene:
			var packed_scene: PackedScene = packed
			var node: Node = packed_scene.instantiate()
			if node is Package:
				package = node
	if package == null:
		package = Package.new()
		var shape_node: CollisionShape3D = CollisionShape3D.new()
		var box: BoxShape3D = BoxShape3D.new()
		box.size = Vector3(BOX_SIZE_M, BOX_SIZE_M, BOX_SIZE_M)
		shape_node.shape = box
		package.add_child(shape_node)
		package.collision_layer = 2
		package.collision_mask = 1 | 2 | 4
		var tuning: TuningTable = GameConfig.tuning
		if tuning != null:
			package.mass = tuning.package_mass_kg
	package.global_transform = at
	return package


func _collision_shape_of(body: Node) -> CollisionShape3D:
	# By TYPE, never by node name (r4.2 of T2.2).
	for child: Node in body.get_children():
		if child is CollisionShape3D:
			return child
	return null


## Horizontal (x-z) clearance from a crew axis point to the box's bus-local
## AABB: 0 when the axis is inside the footprint, else the distance to it.
func _aabb_clearance_xz(point: Vector3, box_center: Vector3) -> float:
	var dx: float = maxf(maxf(box_center.x - BOX_HALF_M - point.x, 0.0), point.x - (box_center.x + BOX_HALF_M))
	var dz: float = maxf(maxf(box_center.z - BOX_HALF_M - point.z, 0.0), point.z - (box_center.z + BOX_HALF_M))
	return sqrt(dx * dx + dz * dz)


func _spawn_bus() -> Bus:
	var runner: GdUnitSceneRunner = scene_runner(BUS_SCENE)
	var node: Node = runner.scene()
	assert_bool(node is Bus).is_true()
	if not (node is Bus):
		return null
	return node


func _wait_ticks(count: int) -> void:
	for i: int in range(count):
		await get_tree().physics_frame


func _on_lap_completed(_lap: int) -> void:
	_lap_done = true
