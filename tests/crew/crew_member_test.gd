extends GdUnitTestSuite

## CrewMember (D73, D74): pure movement math without physics, plus the ride
## test that D74 was decided by (paso 1). All bodies are positioned BEFORE
## add_child (the reviewer's rule); waits are physics ticks.

const WALK: float = 4.0
const SPRINT: float = 6.0


func test_jump_velocity_for_height() -> void:
	assert_float(CrewMember.jump_velocity_for(1.0)).is_equal_approx(4.43, 0.01)
	assert_float(CrewMember.jump_velocity_for(0.0)).is_equal_approx(0.0, 0.0001)


func test_horizontal_speed_selects_sprint() -> void:
	assert_float(CrewMember.horizontal_speed(WALK, SPRINT, false)).is_equal_approx(WALK, 0.001)
	assert_float(CrewMember.horizontal_speed(WALK, SPRINT, true)).is_equal_approx(SPRINT, 0.001)


func test_wish_direction_forward_and_normalized() -> void:
	var forward: Vector3 = CrewMember.wish_direction(Vector2(0.0, -1.0), Basis.IDENTITY)
	assert_vector(forward).is_equal_approx(Vector3(0.0, 0.0, -1.0), Vector3(0.001, 0.001, 0.001))
	var diagonal: Vector3 = CrewMember.wish_direction(Vector2(1.0, -1.0), Basis.IDENTITY)
	assert_float(diagonal.length()).is_less_equal(1.001)
	assert_float(diagonal.y).is_equal_approx(0.0, 0.0001)


func test_crew_settles_and_walks_with_drive_move() -> void:
	_make_ground()
	var crew: CrewMember = await _spawn_crew(Vector3(0.0, 1.0, 0.0))
	if crew == null:
		return
	await _wait_ticks(90)
	assert_bool(crew.is_on_floor()).is_true()
	var start: Vector3 = crew.global_position
	crew.drive_move(Vector2(0.0, -1.0), false, false, Basis.IDENTITY)
	await _wait_ticks(60)
	assert_float(crew.global_position.z - start.z).is_less(-1.0)


func test_crew_rides_the_bus_without_drifting() -> void:
	_make_ground()
	var bus: Bus = await _spawn_bus(Vector3(0.0, 1.6, 0.0))
	if bus == null:
		return
	await _wait_ticks(60)
	var crew: CrewMember = await _spawn_crew(bus.global_transform * Vector3(0.0, 0.35, 0.0))
	if crew == null:
		return
	await _wait_ticks(60)
	var base_local: Vector3 = bus.global_transform.affine_inverse() * crew.global_position
	bus.set_drive(1.0, 0.0, 0.0)
	await _wait_ticks(300)
	# D74 measured the engine carries the rider: millimetres of lateral drift
	# while the bus accelerates. This test pins that contract.
	var local_after: Vector3 = bus.global_transform.affine_inverse() * crew.global_position
	var drift: Vector3 = local_after - base_local
	assert_float(absf(drift.x)).is_less(0.15)
	assert_float(absf(drift.z)).is_less(0.15)
	assert_bool(crew.is_on_floor()).is_true()


func _make_ground() -> StaticBody3D:
	var ground: StaticBody3D = auto_free(StaticBody3D.new())
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(200.0, 1.0, 200.0)
	shape.shape = box
	ground.add_child(shape)
	add_child(ground)
	ground.global_position = Vector3(0.0, -0.5, 0.0)
	return ground


func _spawn_crew(pos: Vector3) -> CrewMember:
	var packed: Resource = load("res://src/crew/crew_member.tscn")
	if packed is PackedScene:
		var scene: PackedScene = packed
		var crew: CrewMember = scene.instantiate()
		crew.global_position = pos
		add_child(crew)
		return crew
	assert_bool(false).override_failure_message("crew_member.tscn did not load").is_true()
	return null


func _spawn_bus(pos: Vector3) -> Bus:
	var runner: GdUnitSceneRunner = scene_runner("res://src/vehicle/bus.tscn")
	var node: Node = runner.scene()
	if node is Bus:
		var bus: Bus = node
		bus.global_position = pos
		return bus
	return null


func _wait_ticks(count: int) -> void:
	for i: int in range(count):
		await get_tree().physics_frame
