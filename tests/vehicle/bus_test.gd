extends GdUnitTestSuite

## Bus (ADR-007, D59/D60/D61/D64): pure suspension/steering/grip math without
## physics, plus integration on a code-built track. Waits are physics_frame
## ticks, never process frames. No input simulation (headless has none).

const TICKS_PER_SECOND: int = 60


func test_suspension_force_spring_plus_damper() -> void:
	assert_float(Bus.suspension_force(0.1, 0.0, 60000.0, 6000.0)).is_equal_approx(6000.0, 0.01)
	assert_float(Bus.suspension_force(0.1, 1.0, 60000.0, 6000.0)).is_equal_approx(12000.0, 0.01)
	assert_float(Bus.suspension_force(0.1, -1.0, 60000.0, 6000.0)).is_equal_approx(0.0, 0.01)
	assert_float(Bus.suspension_force(0.0, -1.0, 60000.0, 6000.0)).is_equal_approx(0.0, 0.01)


func test_compression_rate_sign_and_zero_delta() -> void:
	assert_float(Bus.compression_rate(1.0, 0.9, 1.0 / 60.0)).is_equal_approx(6.0, 0.01)
	assert_float(Bus.compression_rate(0.9, 1.0, 1.0 / 60.0)).is_equal_approx(-6.0, 0.01)
	assert_float(Bus.compression_rate(1.0, 0.5, 0.0)).is_equal_approx(0.0, 0.0001)


func test_lateral_grip_force_opposes_slide() -> void:
	assert_float(Bus.lateral_grip_force(2.0, 10.0, 750.0)).is_equal_approx(-15000.0, 0.01)
	assert_float(Bus.lateral_grip_force(-2.0, 10.0, 750.0)).is_equal_approx(15000.0, 0.01)


func test_steer_angle_deg_for_falloff_and_sign() -> void:
	assert_float(Bus.steer_angle_deg_for(0.0, 1.0, 30.0, 25.0, 0.6)).is_equal_approx(30.0, 0.01)
	assert_float(Bus.steer_angle_deg_for(25.0, 1.0, 30.0, 25.0, 0.6)).is_equal_approx(12.0, 0.01)
	assert_float(Bus.steer_angle_deg_for(0.0, -1.0, 30.0, 25.0, 0.6)).is_equal_approx(-30.0, 0.01)
	assert_float(Bus.steer_angle_deg_for(0.0, 2.0, 30.0, 25.0, 0.6)).is_equal_approx(30.0, 0.01)


func test_traction_force_per_wheel() -> void:
	assert_float(Bus.traction_force_per_wheel(1.0, 10000.0, 4)).is_equal_approx(2500.0, 0.01)
	assert_float(Bus.traction_force_per_wheel(2.0, 10000.0, 4)).is_equal_approx(2500.0, 0.01)
	assert_float(Bus.traction_force_per_wheel(1.0, 10000.0, 0)).is_equal_approx(0.0, 0.0001)


func test_set_drive_clamps_inputs() -> void:
	var bus: Bus = await _spawn_bus(Vector3(0.0, 1.6, 0.0))
	if bus == null:
		return
	bus.set_drive(1.5, -2.0, 1.2)
	assert_float(bus.drive_throttle).is_equal_approx(1.0, 0.0001)
	assert_float(bus.drive_steer).is_equal_approx(-1.0, 0.0001)
	assert_float(bus.drive_brake).is_equal_approx(1.0, 0.0001)


func test_upright_dot_reference_orientations() -> void:
	assert_float(Bus.upright_dot(Basis.IDENTITY)).is_equal_approx(1.0, 0.0001)
	var flipped: Basis = Basis(Vector3(1.0, 0.0, 0.0), PI)
	assert_float(Bus.upright_dot(flipped)).is_equal_approx(-1.0, 0.01)
	var tilted: Basis = Basis(Vector3(0.0, 0.0, 1.0), PI / 2.0)
	assert_float(Bus.upright_dot(tilted)).is_equal_approx(0.0, 0.01)


func test_bus_settles_at_rest_height_and_stays_still() -> void:
	_make_track()
	var bus: Bus = await _spawn_bus(Vector3(0.0, 2.0, 0.0))
	if bus == null:
		return
	await _wait_physics_ticks(120)
	var speed: float = bus.speed_mps()
	assert_float(speed).is_less(0.5)
	var height: float = bus.global_position.y
	assert_float(height).is_greater(0.5)
	assert_float(height).is_less(1.8)
	assert_bool(bus.is_grounded()).is_true()


func test_bus_accelerates_straight() -> void:
	_make_track()
	var bus: Bus = await _spawn_bus(Vector3(0.0, 1.6, 0.0))
	if bus == null:
		return
	var settled: bool = await _wait_until_settled(bus, 120)
	assert_bool(settled).is_true()
	if not settled:
		return
	var start: Vector3 = bus.global_position
	bus.set_drive(1.0, 0.0, 0.0)
	await _wait_physics_ticks(240)
	var travel: Vector3 = bus.global_position - start
	assert_float(travel.z).is_less(-10.0)
	assert_float(absf(travel.x)).is_less(1.0)
	# 34 km/h at 4 s, not a spec readout: the interior's added inertia changes
	# the first second slightly (the 0-60 figure is the one T1.1 pinned).
	assert_float(bus.speed_mps() * 3.6).is_greater(34.0)


func test_bus_brakes_and_loses_most_of_its_speed() -> void:
	_make_track()
	var bus: Bus = await _spawn_bus(Vector3(0.0, 1.6, 0.0))
	if bus == null:
		return
	await _wait_until_settled(bus, 120)
	bus.set_drive(1.0, 0.0, 0.0)
	await _wait_physics_ticks(240)
	var speed_before: float = bus.speed_mps()
	bus.set_drive(0.0, 0.0, 1.0)
	await _wait_physics_ticks(120)
	assert_float(bus.speed_mps()).is_less(speed_before * 0.5)


func test_bus_steer_turns_left_with_positive_steer() -> void:
	_make_track()
	var bus: Bus = await _spawn_bus(Vector3(0.0, 1.6, 0.0))
	if bus == null:
		return
	await _wait_until_settled(bus, 120)
	var yaw_before: float = bus.global_basis.get_euler().y
	bus.set_drive(0.5, 1.0, 0.0)
	await _wait_physics_ticks(180)
	# D49: steer > 0 must turn left (yaw grows in Godot's right-handed Y-up).
	var yaw_after: float = bus.global_basis.get_euler().y
	var turned: float = wrapf(yaw_after - yaw_before, -PI, PI)
	assert_float(turned).is_greater(0.05)


func test_handbrake_increases_lateral_slip() -> void:
	# The same maneuver from the same state, twice: steer hard at speed with
	# the handbrake held vs with grip. The drift signature (D64), measured:
	# with the rear grip cut the tail swings and the bus ROTATES more for the
	# same steer input (oversteer): 73 deg vs 47 deg on 2026-09-12. Neither
	# lateral speed nor slip angle separates the two (measured and discarded).
	_make_track()
	var bus: Bus = await _spawn_bus(Vector3(0.0, 1.6, 0.0))
	if bus == null:
		return
	var yaw_with: float = await _drift_maneuver(bus, true)
	var yaw_without: float = await _drift_maneuver(bus, false)
	assert_float(yaw_with).is_greater(yaw_without)


func _drift_maneuver(bus: Bus, handbrake: bool) -> float:
	await _reset_bus(bus)
	bus.set_drive(1.0, 0.0, 0.0)
	await _wait_physics_ticks(180)
	var yaw_before: float = bus.global_basis.get_euler().y
	bus.set_drive(0.0, 1.0, 0.0)
	bus.set_handbrake(handbrake)
	await _wait_physics_ticks(90)
	bus.set_handbrake(false)
	bus.set_drive(0.0, 0.0, 0.0)
	return absf(wrapf(bus.global_basis.get_euler().y - yaw_before, -PI, PI))


func _reset_bus(bus: Bus) -> void:
	bus.global_position = Vector3(0.0, 1.6, 0.0)
	bus.global_basis = Basis.IDENTITY
	bus.linear_velocity = Vector3.ZERO
	bus.angular_velocity = Vector3.ZERO
	bus.set_drive(0.0, 0.0, 0.0)
	bus.set_handbrake(false)
	await _wait_physics_ticks(30)


func test_rolled_over_emitted_once_when_flipped() -> void:
	var bus: Bus = await _spawn_bus(Vector3(0.0, 1.6, 0.0))
	if bus == null:
		return
	bus.global_basis = Basis(Vector3(1.0, 0.0, 0.0), PI)
	var count: Array = [0]
	bus.rolled_over.connect(func() -> void: count[0] += 1)
	await await_signal_on(bus, "rolled_over", [], 5000)
	await _wait_physics_ticks(60)
	assert_int(count[0]).is_equal(1)


func test_one_wheel_off_the_edge_tilts_the_bus() -> void:
	_make_track()
	# Bus parked with the left wheels off the platform edge: the left side
	# must drop (roll), not float — per-wheel suspension, not a hovercraft.
	var bus: Bus = await _spawn_bus(Vector3(-49.4, 1.8, 0.0))
	if bus == null:
		return
	await _wait_physics_ticks(180)
	var roll: float = absf(bus.global_basis.get_euler().x)
	var roll_z: float = absf(bus.global_basis.get_euler().z)
	var tilt: float = maxf(roll, roll_z)
	assert_float(tilt).is_greater(0.02)
	assert_float(tilt).is_less(0.5)


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


func _spawn_bus(pos: Vector3) -> Bus:
	var runner: GdUnitSceneRunner = scene_runner("res://src/vehicle/bus.tscn")
	var node: Node = runner.scene()
	assert_bool(node is Bus).is_true()
	if node is Bus:
		var bus: Bus = node
		bus.global_position = pos
		return bus
	return null


func _wait_physics_ticks(count: int) -> void:
	for i: int in range(count):
		await get_tree().physics_frame


func _wait_until_settled(bus: Bus, max_ticks: int) -> bool:
	for i: int in range(max_ticks):
		await get_tree().physics_frame
		if bus.is_grounded() and bus.speed_mps() < 0.5:
			return true
	return false
