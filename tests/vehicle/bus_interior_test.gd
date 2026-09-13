extends GdUnitTestSuite

## Bus interior (D66, D67, D68, D69): the scene loads on the bus, the six
## positions and the twelve restraints exist with their exact names, and the
## corridor width / free height are MEASURED with raycasts over the physics
## shapes, not declared. Waits are physics ticks; the deferred shape
## reparenting (bus_interior.gd) is awaited before measuring.

const POSITION_NAMES: Array[String] = ["driver", "copilot", "bench", "shelf_left", "shelf_right", "stretcher"]


func test_interior_loads_on_the_bus_and_shapes_attach_to_the_body() -> void:
	var bus: Bus = await _spawn_settled_bus()
	if bus == null:
		return
	var interior: Node = bus.get_node_or_null("BusInterior")
	assert_object(interior).is_not_null()
	# The reparenting is deferred (bus_interior.gd): one process frame later
	# the 14 collision shapes must be DIRECT children of the bus body.
	await get_tree().process_frame
	await get_tree().process_frame
	var count: int = 0
	for child: Node in bus.get_children():
		if child is CollisionShape3D:
			count += 1
	assert_int(count).is_equal(15)


func test_six_positions_exist_with_exact_names() -> void:
	var bus: Bus = await _spawn_settled_bus()
	if bus == null:
		return
	var positions: Node = bus.get_node("BusInterior/Positions")
	for pos_name: String in POSITION_NAMES:
		var marker: Node = positions.get_node_or_null(pos_name)
		assert_object(marker).is_not_null()
		if marker != null:
			assert_bool(marker is Marker3D).is_true()


func test_restraints_exist_six_per_wall() -> void:
	var bus: Bus = await _spawn_settled_bus()
	if bus == null:
		return
	var restraints: Node = bus.get_node("BusInterior/Restraints")
	assert_int(restraints.get_child_count()).is_equal(12)
	for side: String in ["left", "right"]:
		for i: int in range(6):
			assert_object(restraints.get_node_or_null("restraint_%s_%d" % [side, i])).is_not_null()


func test_corridor_width_and_free_height_measured_on_the_shapes() -> void:
	var bus: Bus = await _spawn_settled_bus()
	if bus == null:
		return
	var xform: Transform3D = bus.global_transform
	var space: PhysicsDirectSpaceState3D = bus.get_world_3d().direct_space_state
	# Corridor: from the corridor center out to each rack face, along the
	# bus's own X axis (the racks bound the corridor, per D67 1.20 m free).
	var center: Vector3 = xform * Vector3(0.0, 0.35, 0.0)
	var width: float = 0.0
	for dir_sign: float in [-1.0, 1.0]:
		var dir: Vector3 = xform.basis.x * dir_sign
		var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
			center, center + dir * 3.0)
		query.exclude = []
		var hit: Dictionary = space.intersect_ray(query)
		if hit.is_empty():
			assert_object(hit).override_failure_message("no rack face hit measuring the corridor").is_not_null()
			return
		var hit_pos_v: Variant = hit["position"]
		if hit_pos_v is Vector3:
			var hit_pos: Vector3 = hit_pos_v
			width += center.distance_to(hit_pos)
	assert_float(width).is_greater_equal(1.20)
	# Free height: from the floor surface up to the ceiling (D67: 2.05 m).
	var from_floor: Vector3 = xform * Vector3(0.0, -0.40, 0.0)
	var up: Vector3 = xform.basis.y.normalized()
	var query_up: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		from_floor, from_floor + up * 3.0)
	var hit_up: Dictionary = space.intersect_ray(query_up)
	if hit_up.is_empty():
		assert_object(hit_up).override_failure_message("no ceiling hit measuring the free height").is_not_null()
		return
	var hit_up_pos_v: Variant = hit_up["position"]
	if hit_up_pos_v is Vector3:
		var hit_up_pos: Vector3 = hit_up_pos_v
		var free_height: float = from_floor.distance_to(hit_up_pos) + 0.05
		# Epsilon below the nominal 2.05: float32 raycast distances round to
		# 2.0499998 and a bare >= 2.05 fails on a correct measurement.
		assert_float(free_height).is_greater_equal(2.049)


func test_bus_with_interior_settles_at_rest_height() -> void:
	var bus: Bus = await _spawn_settled_bus()
	if bus == null:
		return
	var height: float = bus.global_position.y
	assert_float(height).is_greater(0.8)
	assert_float(height).is_less(1.2)
	assert_bool(bus.is_grounded()).is_true()
	assert_float(bus.speed_mps()).is_less(0.5)


func _spawn_settled_bus() -> Bus:
	var runner: GdUnitSceneRunner = scene_runner("res://src/vehicle/bus.tscn")
	var track: StaticBody3D = _make_track()
	var node: Node = runner.scene()
	assert_bool(node is Bus).is_true()
	if not (node is Bus):
		return null
	var bus: Bus = node
	bus.global_position = Vector3(0.0, 1.6, 0.0)
	track.set_meta("unused", true)
	for i: int in range(150):
		await get_tree().physics_frame
	return bus


func _make_track() -> StaticBody3D:
	var track: StaticBody3D = auto_free(StaticBody3D.new())
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(100.0, 1.0, 100.0)
	shape.shape = box
	track.add_child(shape)
	add_child(track)
	track.global_position = Vector3(0.0, -0.5, 0.0)
	return track
