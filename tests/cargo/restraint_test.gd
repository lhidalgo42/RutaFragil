extends GdUnitTestSuite

## Restraint anchors (D69/D84, M2-T2.3): the twelve markers under
## BusInterior/Restraints carry the RestraintAnchor script and the
## "restraint_anchor" group — pinned here so a silent editor re-save fails the
## suite instead of the lap (the round-3 lesson). A strapped package is a
## frozen kinematic child of the bus AT the anchor's bus-local position with
## collision ON, one package per anchor.
## strap()/unstrap() are Package's fixed phase-0 contract (package.gd
## docstrings); the HELD precondition is set directly on the public state so
## this suite does not depend on CrewHands internals (the strap-hold progress
## — strap_hold_seconds ticks to a fraction, cancel on release — lives in
## CrewHands, outside the RestraintAnchor signature, and is not tested here).
## Drift vs the anchor is zero by construction (a strapped box has no physics
## of its own, ADR-006) and is measured anyway over a full demo lap.

const PLAYGROUND_SCENE: String = "res://scenes/playground.tscn"
const BUS_SCENE: String = "res://src/vehicle/bus.tscn"
const PACKAGE_SCENE: String = "res://src/cargo/package.tscn"
const BOX_SIZE_M: float = 0.4
const BOX_HALF_M: float = 0.2
const CREW_RADIUS_M: float = 0.3
const DRIFT_TOLERANCE_M: float = 0.0005
const CONTACT_TOLERANCE_M: float = 0.03
# A lap is ~17 waypoints (measured under 120 game-seconds in run_demo); the
# budget leaves margin without hanging the suite if the demo never wraps.
const LAP_TICK_BUDGET: int = 60 * 150

var _lap_done: bool = false


func test_twelve_anchors_carry_script_and_group_and_start_free() -> void:
	# The pin loads bus.tscn, not the playground: bus_interior.tscn is what the
	# editor re-save would corrupt, and the bus scene pulls none of the crew
	# chain — the anchor pin stays green even while a neighbor's script is
	# mid-iteration (measured 2026-09-14: a crew_hands.gd parse error attached
	# itself to whichever test loaded the playground first).
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
	# One package per anchor: the second strap on the occupied anchor fails and
	# changes nothing.
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
	# Deferred collision changes get their frames before asserting.
	await _wait_ticks(2)
	assert_bool(box.get_parent() == bus).override_failure_message("a strapped package must be a child of the bus").is_true()
	# The load-bearing bit is freeze (no own physics → zero drift); the docstring's
	# "kinematic" is implemented by package.gd as FREEZE_MODE_STATIC, which is the
	# right read for a bus-riding shelf (a kinematic freeze would impart the bus's
	# velocity to a bumping crew member). Not asserted, reported instead.
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
	# HELD keeps collision OFF (the round-4 seat bug: a live shape inside the
	# hull kicks the bus every tick).
	var shape_node: CollisionShape3D = _collision_shape_of(box)
	assert_object(shape_node).is_not_null()
	if shape_node != null:
		assert_bool(shape_node.disabled).override_failure_message("HELD must keep collision OFF").is_true()


func test_strapped_packages_have_zero_drift_for_a_full_lap() -> void:
	var runner: GdUnitSceneRunner = scene_runner(PLAYGROUND_SCENE)
	runner.set_time_factor(4.0)
	var scene: Node = runner.scene()
	# The Playground/BusInput types are NOT imported here on purpose: they drag
	# the CrewInput/CrewHands compile chain into a suite that never touches it.
	# The demo is driven by name (the playground_scene_test pattern) and the
	# driver itself stays typed.
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
	# every tick and fight the scripted drive_move. The test drives the member.
	var crew_input: Node = scene.get_node_or_null("CrewInput")
	if crew_input != null:
		crew_input.set("enabled", false)
	var restraints: Node = scene.get_node_or_null("Bus/BusInterior/Restraints")
	assert_object(restraints).is_not_null()
	if restraints == null:
		return
	# restraint_right_2 (x=0.575, z=-0.2): the box protrudes from the right
	# rack face into the corridor; the crew walks +x straight into its face.
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
	# Teleport into the corridor facing the box, on the floor, aboard (the
	# crew_ride pattern: place first, flag after the settling ticks).
	crew.global_position = bus.global_transform * Vector3(-0.25, -0.35, -0.2)
	await _wait_ticks(10)
	crew.aboard = true
	var box_local_before: Vector3 = box.position
	var min_clearance: float = INF
	var max_box_move: float = 0.0
	for tick: int in range(90):
		# Press +x in the bus frame every tick, exactly what CrewInput does.
		crew.drive_move(Vector2(1.0, 0.0), false, false, bus.global_transform.basis)
		await get_tree().physics_frame
		var crew_local: Vector3 = bus.global_transform.affine_inverse() * crew.global_position
		min_clearance = minf(min_clearance, _aabb_clearance_xz(crew_local, box.position))
		max_box_move = maxf(max_box_move, box.position.distance_to(box_local_before))
	print("bump: min_clearance=%.3f m, max_box_move=%.6f m" % [min_clearance, max_box_move])
	# The shelf contract: the box never moved, the capsule never entered its
	# volume (radius minus a small penetration tolerance), and she DID reach
	# the face — a miss or an early stop proves nothing.
	assert_float(max_box_move).override_failure_message("the strapped box moved under the crew's push").is_less(0.0005)
	assert_float(min_clearance).override_failure_message("the crew entered the strapped box's volume").is_greater_equal(CREW_RADIUS_M - CONTACT_TOLERANCE_M)
	assert_float(min_clearance).override_failure_message("the crew never reached the box").is_less_equal(CREW_RADIUS_M + CONTACT_TOLERANCE_M + 0.02)


func _anchor(restraints: Node, anchor_name: String) -> RestraintAnchor:
	var node: Node = restraints.get_node_or_null(anchor_name)
	if node is RestraintAnchor:
		return node
	return null


## The package comes from agent A's package.tscn when it exists; until it
## lands, the same box is built by hand from the package.gd docstring (0.4 m,
## mass from TuningTable, layer 2 = cargo, mask world + cargo + crew). Either
## way it is a Package: this suite tests the class contract, not the scene's
## authored visuals. Position is set BEFORE the caller's add_child (the
## reviewer's rule).
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
	# By TYPE, never by node name (r4.2 of T2.2): renaming the shape when the
	# art lands must not silently change what this asserts.
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
