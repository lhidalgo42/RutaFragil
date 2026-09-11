extends GdUnitTestSuite

## PlaceholderBus (D48): set_drive clamping, upright_dot orientations and
## rolled_over are cheap; drive/steer/brake are physics integration on a
## code-built track. Physics waits are physics_frame ticks, never process
## frames (plan §3); scene_runner.set_time_factor(4) keeps the same physics
## step at 4x wall speed. Mass is never asserted: developer mods may change
## it through user://mods.

const BUS_SCENE: PackedScene = preload("res://src/vehicle/placeholder_bus.tscn")


func test_set_drive_clamps_inputs() -> void:
	var node: Node = auto_free(BUS_SCENE.instantiate())
	assert_bool(node is PlaceholderBus).is_true()
	if node is PlaceholderBus:
		var bus: PlaceholderBus = node
		bus.set_drive(2.0, -3.0, 7.0)
		assert_float(bus.drive_throttle).is_equal(1.0)
		assert_float(bus.drive_steer).is_equal(-1.0)
		assert_float(bus.drive_brake).is_equal(1.0)
		bus.set_drive(-2.0, 3.0, -1.0)
		assert_float(bus.drive_throttle).is_equal(-1.0)
		assert_float(bus.drive_steer).is_equal(1.0)
		assert_float(bus.drive_brake).is_equal(0.0)


func test_upright_dot_reference_orientations() -> void:
	assert_float(PlaceholderBus.upright_dot(Basis.IDENTITY)).is_equal_approx(1.0, 0.0001)
	var upside_down: Basis = Basis(Vector3(0.0, 0.0, 1.0), PI)
	assert_float(PlaceholderBus.upright_dot(upside_down)).is_equal_approx(-1.0, 0.0001)
	var on_side: Basis = Basis(Vector3(0.0, 0.0, 1.0), PI / 2.0)
	assert_float(PlaceholderBus.upright_dot(on_side)).is_equal_approx(0.0, 0.0001)


func test_rolled_over_emitted_once_when_flipped() -> void:
	var bus: PlaceholderBus = _spawn_bus(4.0)
	if bus == null:
		return
	# On its side from the first tick; falls forever, so the tilt holds.
	bus.rotation = Vector3(0.0, 0.0, PI / 2.0)
	await await_signal_on(bus, "rolled_over", [], 5000)
	# Latched: no second emission while the tilt keeps holding.
	var emitter: Object = monitor_signals(bus, false)
	await assert_signal(emitter).wait_until(1200).is_not_emitted("rolled_over")


func test_drive_forward_straight() -> void:
	var bus: PlaceholderBus = await _spawn_settled_bus()
	if bus == null:
		return
	var start: Vector3 = bus.global_position
	bus.set_drive(1.0, 0.0, 0.0)
	await _wait_physics_ticks(120)
	var end: Vector3 = bus.global_position
	assert_float(start.z - end.z).is_greater_equal(5.0)
	assert_float(absf(end.x - start.x)).is_less(1.0)


func test_steer_turns_left_with_positive_steer() -> void:
	var bus: PlaceholderBus = await _spawn_settled_bus()
	if bus == null:
		return
	bus.set_drive(1.0, 1.0, 0.0)
	await _wait_physics_ticks(120)
	# D49: steer > 0 turns left; facing -Z, left means forward drifts to -X.
	assert_float(bus.forward().x).is_less(-0.02)


func test_brake_drops_speed_fast() -> void:
	var bus: PlaceholderBus = await _spawn_settled_bus()
	if bus == null:
		return
	bus.set_drive(1.0, 0.0, 0.0)
	await _wait_physics_ticks(90)
	var speed_before: float = bus.speed_mps()
	assert_float(speed_before).is_greater(2.0)
	bus.set_drive(0.0, 0.0, 1.0)
	await _wait_physics_ticks(60)
	assert_float(bus.speed_mps()).is_less(speed_before * 0.5)


func _make_track() -> void:
	var track: StaticBody3D = auto_free(StaticBody3D.new())
	var shape_node: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(100.0, 1.0, 100.0)
	shape_node.shape = box
	track.add_child(shape_node)
	add_child(track)
	track.global_position = Vector3(0.0, -0.5, 0.0)


func _spawn_bus(time_factor: float) -> PlaceholderBus:
	var runner: GdUnitSceneRunner = scene_runner("res://src/vehicle/placeholder_bus.tscn")
	runner.set_time_factor(time_factor)
	var node: Node = runner.scene()
	assert_bool(node is PlaceholderBus).is_true()
	if node is PlaceholderBus:
		var bus: PlaceholderBus = node
		bus.global_position = Vector3(0.0, 1.6, 0.0)
		return bus
	return null


func _spawn_settled_bus() -> PlaceholderBus:
	_make_track()
	var bus: PlaceholderBus = _spawn_bus(4.0)
	if bus == null:
		return null
	var settled: bool = await _wait_until_grounded(bus, 60)
	assert_bool(settled).is_true()
	if settled:
		return bus
	return null


func _wait_physics_ticks(count: int) -> void:
	for i: int in count:
		await get_tree().physics_frame


func _wait_until_grounded(bus: PlaceholderBus, max_ticks: int) -> bool:
	for i: int in max_ticks:
		await get_tree().physics_frame
		if bus.is_grounded() and bus.speed_mps() < 0.5:
			return true
	return false
