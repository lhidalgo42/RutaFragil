extends GdUnitTestSuite


class PostPhysics extends Node:
	signal sampled
	func _ready() -> void:
		process_physics_priority = 1000
	func _physics_process(_delta: float) -> void:
		sampled.emit()


class MovingFloor extends Node:
	var floor_body: RigidBody3D
	var crew: CrewMember
	var ticks: int = 0
	var jumping: bool = true
	var walk: Vector2 = Vector2.ZERO
	var descending: bool = false
	func _ready() -> void:
		process_physics_priority = -100
	func _physics_process(delta: float) -> void:
		floor_body.position.z += (80.0 / 3.6) * delta
		if descending:
			floor_body.position.y -= 0.001 * delta
		ticks += 1
		crew.drive_move(walk, false, jumping and ticks == 20, Basis.IDENTITY)


func test_jump_preserves_platform_inertia_through_landing_and_second_jump() -> void:
	var rig: MovingFloor = _rig()
	var observer: PostPhysics = auto_free(PostPhysics.new())
	add_child(observer)
	var air_ticks: int = 0
	var first_xz_error: float = 0.0
	var second_xz_error: float = 0.0
	var second_air_ticks: int = 0
	var initial_z: float = 0.0
	for tick: int in range(100):
		await observer.sampled
		if tick == 17:
			initial_z = rig.crew.global_position.z - rig.floor_body.global_position.z
		if tick > 19 and not rig.crew.is_on_floor():
			air_ticks += 1
			first_xz_error = maxf(first_xz_error, absf(rig.crew.velocity.z - 80.0 / 3.6))
	assert_int(air_ticks).is_greater(10)
	assert_bool(rig.crew.is_on_floor()).is_true()
	assert_float(first_xz_error).is_less(0.02)
	assert_float(absf(rig.crew.global_position.z - rig.floor_body.global_position.z - initial_z)).is_less(0.05)
	rig.ticks = 18
	for tick: int in range(100):
		await observer.sampled
		if tick > 2 and not rig.crew.is_on_floor():
			second_air_ticks += 1
			second_xz_error = maxf(second_xz_error, absf(rig.crew.velocity.z - 80.0 / 3.6))
	assert_int(second_air_ticks).is_greater(10)
	assert_float(second_xz_error).is_less(0.02)
	assert_bool(rig.crew.is_on_floor()).is_true()
	print("AIR_TEST first_error=%.6f second_error=%.6f air_ticks=%d" % [first_xz_error, second_xz_error, air_ticks])


func test_walk_input_in_air_adds_to_carry_and_seat_discards_it() -> void:
	var rig: MovingFloor = _rig()
	var observer: PostPhysics = auto_free(PostPhysics.new())
	add_child(observer)
	for tick: int in range(25):
		await observer.sampled
	assert_bool(rig.crew.is_on_floor()).is_false()
	rig.walk = Vector2(0.5, 0.0)
	await observer.sampled
	await observer.sampled
	assert_float(rig.crew.velocity.x).is_equal_approx(GameConfig.tuning.player_walk_speed_mps * 0.5, 0.001)
	assert_float(rig.crew.velocity.z).is_equal_approx(80.0 / 3.6, 0.02)
	rig.crew.set_seated(true)
	await observer.sampled
	assert_vector(rig.crew.velocity).is_equal(Vector3.ZERO)
	rig.crew.set_seated(false)
	rig.jumping = false
	rig.walk = Vector2.ZERO
	rig.crew.global_position = Vector3(100.0, 10.0, 0.0)
	await observer.sampled
	assert_float(rig.crew.velocity.z).is_equal_approx(0.0, 0.001)


func test_jump_under_moving_ceiling_keeps_horizontal_carry() -> void:
	var rig: MovingFloor = _rig(true)
	rig.descending = true
	var observer: PostPhysics = auto_free(PostPhysics.new())
	add_child(observer)
	var initial_z: float = 0.0
	var air_ticks: int = 0
	for tick: int in range(100):
		await observer.sampled
		if tick == 17:
			initial_z = rig.crew.global_position.z - rig.floor_body.global_position.z
		if not rig.crew.is_on_floor() and tick > 19:
			air_ticks += 1
	assert_int(air_ticks).is_greater(0)
	assert_bool(rig.crew.is_on_floor()).is_true()
	assert_float(absf(rig.crew.global_position.z - rig.floor_body.global_position.z - initial_z)).is_less(0.05)


func _rig(with_ceiling: bool = false) -> MovingFloor:
	var world: Node3D = auto_free(Node3D.new())
	add_child(world)
	var floor_body: RigidBody3D = RigidBody3D.new()
	floor_body.freeze = true
	floor_body.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(100.0, 0.1, 100.0)
	shape.shape = box
	floor_body.add_child(shape)
	if with_ceiling:
		var ceiling: CollisionShape3D = CollisionShape3D.new()
		ceiling.shape = box
		ceiling.position.y = 1.95
		floor_body.add_child(ceiling)
	world.add_child(floor_body)
	var packed: PackedScene = load("res://src/crew/crew_member.tscn")
	var crew: CrewMember = packed.instantiate()
	crew.position = Vector3(0.0, 0.051, 0.0)
	world.add_child(crew)
	var driver: MovingFloor = MovingFloor.new()
	driver.floor_body = floor_body
	driver.crew = crew
	world.add_child(driver)
	return driver
