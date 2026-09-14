extends GdUnitTestSuite

## Seat physics on the REAL scene (M2-T2.2 round 4): flags are not
## consequences. Sitting must not move the bus; standing must leave the crew
## outside the geometry with the bus calm; standing WHILE DRIVING must keep
## the crew aboard (she inherits the bus-point velocity).
## Written BEFORE the fix: on the pre-fix code the sitting phase fails with
## the bus rising ~0.4 m and tilting (the reviewer's numbers), because the
## capsule was teleported INTO the hull with its collision shape active.
## Interior bounds (D67/D72): |x| <= 1.15, z in [-3.8, 3.8], y in [-0.6, 1.30].
## ROUND 5 note on _park_bus_input(): with the enabled-setter writing neutral
## on disable, parking now writes zeros — both round-4 tests park BEFORE their
## set_drive(1, 0, 0), because parking after commanding traction erases the
## command. The round-5 throttle test is the exception on purpose: it measures
## the real key path, so it never parks.


func test_sitting_does_not_move_the_bus_and_standing_is_clean() -> void:
	var runner: GdUnitSceneRunner = scene_runner("res://scenes/playground.tscn")
	runner.scene()
	await _wait_ticks(120)
	var bus: Bus = _group_bus()
	var crew: CrewMember = _group_crew()
	var seat: Seat = _group_seat()
	if bus == null or crew == null or seat == null:
		return
	_board_on_corridor(bus, crew)
	await _wait_ticks(45)
	assert_bool(crew.is_on_floor()).is_true()
	var saved_local: Vector3 = bus.global_transform.affine_inverse() * crew.global_position
	# Addition 1: the restore point falls inside the hull by construction.
	assert_float(saved_local.x).is_between(-1.15, 1.15)
	assert_float(saved_local.z).is_between(-3.8, 3.8)
	assert_float(saved_local.y).is_between(-0.65, 1.30)
	var rest_y: float = bus.global_position.y

	assert_bool(seat.occupy(crew)).is_true()
	assert_bool(crew.seated).is_true()
	# occupy() enables BusInput, which writes set_drive(0,0,0) every tick over
	# any direct drive command (the demo test documents the same wrinkle):
	# the drive phases here measure the BUS's physics, so BusInput is parked.
	_park_bus_input()
	var max_omega: float = 0.0
	var min_upright: float = 1.0
	var min_y: float = rest_y
	var max_y: float = rest_y
	for tick: int in range(60):
		await get_tree().physics_frame
		max_omega = maxf(max_omega, bus.angular_velocity.length())
		min_upright = minf(min_upright, Bus.upright_dot(bus.global_transform.basis))
		min_y = minf(min_y, bus.global_position.y)
		max_y = maxf(max_y, bus.global_position.y)
	print("SEATSIT max_omega=%.4f rad/s min_upright=%.5f y_range=%.4f m" % [max_omega, min_upright, max_y - min_y])
	assert_float(max_omega).override_failure_message("sitting kicked the bus: max angular velocity").is_less(0.05)
	assert_float(min_upright).override_failure_message("sitting tilted the bus: min upright dot").is_greater(0.999)
	assert_float(max_y - min_y).override_failure_message("sitting lifted/sank the bus: y range").is_less(0.05)

	# Driving seated goes straight and stays upright.
	var drive_start: Vector3 = bus.global_position
	var drive_forward: Vector3 = -bus.global_transform.basis.z
	drive_forward.y = 0.0
	drive_forward = drive_forward.normalized()
	bus.set_drive(1.0, 0.0, 0.0)
	var min_upright_drive: float = 1.0
	for tick: int in range(120):
		await get_tree().physics_frame
		min_upright_drive = minf(min_upright_drive, Bus.upright_dot(bus.global_transform.basis))
	bus.set_drive(0.0, 0.0, 1.0)
	var displacement: Vector3 = bus.global_position - drive_start
	var lateral: Vector3 = displacement - drive_forward * displacement.dot(drive_forward)
	print("SEATDRIVE min_upright=%.5f forward=%.2f m lateral=%.3f m" % [min_upright_drive, displacement.dot(drive_forward), lateral.length()])
	assert_float(min_upright_drive).override_failure_message("driving seated tilted the bus").is_greater(0.98)
	assert_float(displacement.dot(drive_forward)).override_failure_message("the bus did not advance").is_greater(4.0)
	assert_float(lateral.length()).override_failure_message("driving seated veered sideways").is_less(1.0)

	# Let the bus settle to calm, then stand: the crew lands at the saved
	# point (bus's CURRENT frame), and re-enabling the shape pushes nothing.
	await _wait_ticks(300)
	seat.vacate()
	var back_local: Vector3 = bus.global_transform.affine_inverse() * crew.global_position
	assert_vector(back_local).override_failure_message("standing did not return the saved point").is_equal_approx(saved_local, Vector3(0.1, 0.1, 0.1))
	await get_tree().physics_frame
	var pos0: Vector3 = crew.global_position
	await _wait_ticks(5)
	assert_float(crew.global_position.distance_to(pos0)).override_failure_message("re-enabling the shape pushed the crew (depenetration)").is_less_equal(0.05)
	assert_float(bus.angular_velocity.length()).override_failure_message("standing kicked the bus").is_less(0.05)
	await _wait_ticks(30)
	print("SEATSTAND back_local=%s (saved %s) push_after_enable=%.4f m bus_omega=%.4f on_floor=%s" % [str(back_local), str(saved_local), crew.global_position.distance_to(pos0), bus.angular_velocity.length(), crew.is_on_floor()])
	assert_bool(crew.is_on_floor()).override_failure_message("the crew is not on the floor after standing").is_true()


func test_standing_up_while_driving_keeps_the_crew_aboard() -> void:
	var runner: GdUnitSceneRunner = scene_runner("res://scenes/playground.tscn")
	runner.scene()
	await _wait_ticks(120)
	var bus: Bus = _group_bus()
	var crew: CrewMember = _group_crew()
	var seat: Seat = _group_seat()
	if bus == null or crew == null or seat == null:
		return
	_board_on_corridor(bus, crew)
	await _wait_ticks(45)
	assert_bool(seat.occupy(crew)).is_true()
	_park_bus_input()
	bus.set_drive(1.0, 0.0, 0.0)
	var reached: bool = false
	for tick: int in range(900):
		await get_tree().physics_frame
		if bus.speed_mps() * 3.6 >= 40.0:
			reached = true
			break
	assert_bool(reached).override_failure_message("the bus never reached 40 km/h").is_true()
	seat.vacate()
	var ejected: bool = false
	var floor_after_settle: bool = true
	for tick: int in range(60):
		await get_tree().physics_frame
		if tick > 10 and not crew.is_on_floor():
			floor_after_settle = false
		if not crew.aboard:
			ejected = true
		var local: Vector3 = bus.global_transform.affine_inverse() * crew.global_position
		if absf(local.x) > 1.30 or absf(local.z) > 4.0 or local.y < -0.70 or local.y > 0.60:
			ejected = true
	print("SEATDRIVE-STAND ejected=%s floor_ok=%s speed_kmh=%.1f" % [ejected, floor_after_settle, bus.speed_mps() * 3.6])
	assert_bool(ejected).override_failure_message("the crew was ejected or left the interior bounds after standing while driving").is_false()
	assert_bool(floor_after_settle).override_failure_message("the crew is not on the floor while the bus drives at 40 km/h").is_true()


func test_neutral_when_the_driver_stands() -> void:
	var runner: GdUnitSceneRunner = scene_runner("res://scenes/playground.tscn")
	runner.scene()
	await _wait_ticks(120)
	var bus: Bus = _group_bus()
	var crew: CrewMember = _group_crew()
	var seat: Seat = _group_seat()
	if bus == null or crew == null or seat == null:
		return
	_board_on_corridor(bus, crew)
	await _wait_ticks(45)
	assert_bool(seat.occupy(crew)).is_true()
	# The REAL key path (no parking): the player drives with the action.
	Input.action_press("drive_accelerate")
	await _wait_ticks(120)
	Input.action_release("drive_accelerate")
	var speed_before: float = bus.speed_mps()
	assert_float(speed_before).override_failure_message("the bus never moved with the key pressed").is_greater(2.0)
	# Release and stand in the SAME tick — the reviewer's exact sequence.
	seat.vacate()
	await get_tree().physics_frame
	print("NEUTRAL throttle_after=%.2f steer_after=%.2f speed_at_stand_kmh=%.1f" % [bus.drive_throttle, bus.drive_steer, speed_before * 3.6])
	assert_float(bus.drive_throttle).override_failure_message("throttle stuck after vacate").is_equal(0.0)
	assert_float(bus.drive_steer).override_failure_message("steer stuck after vacate").is_equal(0.0)
	await _wait_ticks(120)
	print("NEUTRAL speed_120_ticks_later_kmh=%.1f (was %.1f)" % [bus.speed_mps() * 3.6, speed_before * 3.6])
	assert_float(bus.speed_mps()).override_failure_message("the bus kept ACCELERATING with nobody at the wheel").is_less_equal(speed_before + 0.15)


func test_standing_restores_to_the_corridor_when_the_saved_point_is_invalid() -> void:
	var runner: GdUnitSceneRunner = scene_runner("res://scenes/playground.tscn")
	runner.scene()
	await _wait_ticks(120)
	var bus: Bus = _group_bus()
	var crew: CrewMember = _group_crew()
	var seat: Seat = _group_seat()
	if bus == null or crew == null or seat == null:
		return
	_board_on_corridor(bus, crew)
	await _wait_ticks(45)
	assert_bool(seat.occupy(crew)).is_true()
	# The roof, where the reviewer measured the 16 rad/s kick (r4.3).
	seat.saved_local_position = Vector3(0.0, 1.4, -1.4)
	seat.vacate()
	var local: Vector3 = bus.global_transform.affine_inverse() * crew.global_position
	print("FALLBACK landed_local=%s" % str(local))
	assert_vector(local).override_failure_message("standing with a poisoned point did not fall back to the corridor").is_equal_approx(Vector3(0.0, -0.55, -2.0), Vector3(0.1, 0.1, 0.1))
	var max_omega: float = 0.0
	for tick: int in range(30):
		await get_tree().physics_frame
		max_omega = maxf(max_omega, bus.angular_velocity.length())
	print("FALLBACK max_omega=%.4f on_floor=%s" % [max_omega, crew.is_on_floor()])
	assert_float(max_omega).override_failure_message("the fallback kicked the bus").is_less(0.05)
	assert_bool(crew.is_on_floor()).override_failure_message("the crew is not on the floor at the corridor fallback").is_true()


## Teleports the crew into the corridor center (a free point, position set
## before any collision happens) and marks her aboard as the door's plane
## test would (the plane only fires within the door gap's z range, so a
## direct teleport to the center sets no flag of its own).
func _board_on_corridor(bus: Bus, crew: CrewMember) -> void:
	crew.global_position = bus.global_transform * Vector3(0.0, -0.55, 0.0)
	crew.aboard = true


func _park_bus_input() -> void:
	var node: Node = get_tree().get_first_node_in_group("bus_input")
	if node != null:
		node.set("enabled", false)


func _group_bus() -> Bus:
	var node: Node = get_tree().get_first_node_in_group("bus")
	if node is Bus:
		return node
	assert_bool(false).override_failure_message("no bus in group 'bus'").is_true()
	return null


func _group_crew() -> CrewMember:
	var node: Node = get_tree().get_first_node_in_group("crew")
	if node is CrewMember:
		return node
	assert_bool(false).override_failure_message("no crew in group 'crew'").is_true()
	return null


func _group_seat() -> Seat:
	var node: Node = get_tree().get_first_node_in_group("seat")
	if node is Seat:
		return node
	assert_bool(false).override_failure_message("no seat in group 'seat'").is_true()
	return null


func _wait_ticks(count: int) -> void:
	for i: int in range(count):
		await get_tree().physics_frame
