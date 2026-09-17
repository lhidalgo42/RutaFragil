extends GdUnitTestSuite

## Restraint anchors — the MECHANICS suite (D69/D84, M2-T2.3): the twelve
## BusInterior/Restraints markers carry the RestraintAnchor script, the
## "restraint_anchor" group and their rack-top positions — pinned so an editor
## re-save fails HERE (round-3). strap()/unstrap() are Package's fixed phase-0
## contract; the HELD precondition is set directly on the public state so this
## suite does not depend on CrewHands. The integration half (lap drift, crew
## collision) lives in restraint_lap_test.gd (r2.2 split of M2-GATE).

const BUS_SCENE: String = "res://src/vehicle/bus.tscn"
const PACKAGE_SCENE: String = "res://src/cargo/package.tscn"
const BOX_SIZE_M: float = 0.4


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
