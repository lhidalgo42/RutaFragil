extends GdUnitTestSuite

const BUS_SCENE: String = "res://src/vehicle/bus.tscn"
const CREW_SCENE: String = "res://src/crew/crew_member.tscn"
const PACKAGE_SCENE: String = "res://src/cargo/package.tscn"


func test_step_is_deterministic_and_reaches_terminal_poses() -> void:
	var half: Array = BusDoors.step(BusDoors.DoorPhase.CLOSING, 1.0, 0.35, 0.7)
	assert_int(int(half[0])).is_equal(BusDoors.DoorPhase.CLOSING)
	assert_float(float(half[1])).is_equal_approx(0.5, 0.0001)
	var closed: Array = BusDoors.step(BusDoors.DoorPhase.CLOSING, 0.1, 1.0, 0.7)
	assert_int(int(closed[0])).is_equal(BusDoors.DoorPhase.CLOSED)
	assert_float(float(closed[1])).is_equal(0.0)
	var opened: Array = BusDoors.step(BusDoors.DoorPhase.OPENING, 0.9, 1.0, 0.8)
	assert_int(int(opened[0])).is_equal(BusDoors.DoorPhase.OPEN)
	assert_float(float(opened[1])).is_equal(1.0)


func test_opening_and_closing_do_not_change_bus_inertia() -> void:
	var bus: Bus = await _spawn_dynamic_bus()
	var doors: BusDoors = bus.get_node("BusDoors") as BusDoors
	var before: Basis = PhysicsServer3D.body_get_direct_state(bus.get_rid()).inverse_inertia_tensor
	doors.apply_state(&"side", BusDoors.DoorPhase.CLOSED, 0.0)
	doors.apply_state(&"rear", BusDoors.DoorPhase.CLOSED, 0.0)
	await _ticks(2)
	var closed: Basis = PhysicsServer3D.body_get_direct_state(bus.get_rid()).inverse_inertia_tensor
	assert_bool(before.is_equal_approx(closed)).is_true()


func test_doors_start_open_with_disabled_blockers_and_public_ids() -> void:
	var bus: Bus = await _spawn_bus()
	var doors: BusDoors = bus.get_node("BusDoors") as BusDoors
	assert_bool(doors.is_in_group("bus_doors")).is_true()
	for door_id: StringName in [&"side", &"rear"]:
		assert_int(doors.phase(door_id)).is_equal(BusDoors.DoorPhase.OPEN)
		assert_float(doors.progress(door_id)).is_equal(1.0)
		assert_bool(_blocker(bus, door_id).disabled).is_true()
	assert_float(doors.progress(&"missing")).is_equal(1.0)


func test_clear_close_enables_only_at_end_and_open_disables_immediately() -> void:
	var bus: Bus = await _spawn_bus()
	var doors: BusDoors = bus.get_node("BusDoors") as BusDoors
	var crew: CrewMember = _crew(bus.global_transform * Vector3(0.0, -0.6, -1.75))
	await _ticks(2)
	assert_bool(doors.try_toggle(&"side", crew)).is_true()
	await _ticks(20)
	assert_int(doors.phase(&"side")).is_equal(BusDoors.DoorPhase.CLOSING)
	assert_bool(_blocker(bus, &"side").disabled).is_true()
	await _ticks(30)
	assert_int(doors.phase(&"side")).is_equal(BusDoors.DoorPhase.CLOSED)
	assert_bool(_blocker(bus, &"side").disabled).is_false()
	assert_bool(doors.try_toggle(&"side", crew)).is_true()
	assert_int(doors.phase(&"side")).is_equal(BusDoors.DoorPhase.OPENING)
	assert_bool(_blocker(bus, &"side").disabled).is_true()


func test_crew_in_side_gap_rejects_close_and_reopens_when_it_enters_mid_close() -> void:
	var bus: Bus = await _spawn_bus()
	var doors: BusDoors = bus.get_node("BusDoors") as BusDoors
	var crew: CrewMember = _crew(bus.global_transform * Vector3(1.2, -0.6, -1.75))
	await _ticks(3)
	assert_bool(doors.try_toggle(&"side", crew)).is_false()
	assert_int(doors.phase(&"side")).is_equal(BusDoors.DoorPhase.OPEN)
	crew.global_position = bus.global_transform * Vector3(0.0, -0.6, -1.75)
	await _ticks(2)
	assert_bool(doors.try_toggle(&"side", crew)).is_true()
	crew.global_position = bus.global_transform * Vector3(1.2, -0.6, -1.75)
	await _ticks(50)
	assert_int(doors.phase(&"side")).is_not_equal(BusDoors.DoorPhase.CLOSED)
	assert_bool(_blocker(bus, &"side").disabled).is_true()


func test_package_in_rear_gap_rejects_close() -> void:
	var bus: Bus = await _spawn_bus()
	var doors: BusDoors = bus.get_node("BusDoors") as BusDoors
	var package: Package = auto_free((load(PACKAGE_SCENE) as PackedScene).instantiate()) as Package
	package.position = bus.global_transform * Vector3(0.0, 0.35, 3.85)
	package.freeze = true
	add_child(package)
	await _ticks(3)
	assert_bool(doors.host_close(&"rear")).is_false()
	assert_int(doors.phase(&"rear")).is_equal(BusDoors.DoorPhase.OPEN)


func test_crew_entering_rear_swing_reverses_before_contact() -> void:
	var bus: Bus = await _spawn_bus()
	var doors: BusDoors = bus.get_node("BusDoors") as BusDoors
	var crew: CrewMember = _crew(bus.global_transform * Vector3(0.0, -0.6, 2.0))
	await _ticks(2)
	assert_bool(doors.host_close(&"rear")).is_true()
	crew.global_position = bus.global_transform * Vector3(-0.95, -0.6, 4.35)
	await _ticks(3)
	assert_int(doors.phase(&"rear")).is_not_equal(BusDoors.DoorPhase.CLOSED)
	assert_bool(_blocker(bus, &"rear").disabled).is_true()
	await _ticks(60)
	assert_int(doors.phase(&"rear")).is_equal(BusDoors.DoorPhase.OPEN)


func test_closed_rear_retains_package_and_open_rear_lets_it_out() -> void:
	assert_float(await _package_exit_z(false)).is_less(3.9)
	assert_float(await _package_exit_z(true)).is_greater(3.9)


func test_package_pushed_backwards_stops_at_closed_rear_blocker() -> void:
	var bus: Bus = await _spawn_bus()
	var doors: BusDoors = bus.get_node("BusDoors") as BusDoors
	doors.apply_state(&"rear", BusDoors.DoorPhase.CLOSED, 0.0)
	assert_bool(_blocker(bus, &"rear").disabled).is_false()
	var package: Package = (load(PACKAGE_SCENE) as PackedScene).instantiate() as Package
	package.position = bus.global_transform * Vector3(0.0, 0.35, 3.45)
	package.gravity_scale = 0.0
	add_child(auto_free(package))
	await _ticks(2)
	package.linear_velocity = bus.global_basis.z * 5.0
	await _ticks(45)
	var local_z: float = (bus.global_transform.affine_inverse() * package.global_position).z
	assert_float(local_z).is_greater(3.5)
	assert_float(local_z).is_less(4.0)


func test_request_validation_rejects_bad_id_motion_and_reach() -> void:
	var bus: Bus = await _spawn_bus()
	var doors: BusDoors = bus.get_node("BusDoors") as BusDoors
	var near: CrewMember = _crew(bus.global_transform * Vector3(0.0, -0.6, -1.75))
	var far: CrewMember = _crew(bus.global_transform * Vector3(20.0, -0.6, -1.75))
	await _ticks(2)
	assert_bool(doors.can_toggle(&"bad", near)).is_false()
	assert_bool(doors.can_toggle(&"side", far)).is_false()
	assert_bool(doors.try_toggle(&"side", near)).is_true()
	assert_bool(doors.can_toggle(&"side", near)).is_false()


func test_client_snapshot_applies_phase_progress_and_blocker() -> void:
	var bus: Bus = await _spawn_bus()
	var doors: BusDoors = bus.get_node("BusDoors") as BusDoors
	assert_bool(doors.apply_state(&"rear", BusDoors.DoorPhase.CLOSED, 0.0)).is_true()
	await _ticks(1)
	assert_int(doors.phase(&"rear")).is_equal(BusDoors.DoorPhase.CLOSED)
	assert_float(doors.progress(&"rear")).is_equal(0.0)
	assert_bool(_blocker(bus, &"rear").disabled).is_false()
	assert_bool(doors.apply_state(&"bad", BusDoors.DoorPhase.CLOSED, 0.0)).is_false()


func _package_exit_z(rear_open: bool) -> float:
	var bus: Bus = await _spawn_bus()
	if rear_open:
		bus.position.x = 10.0
	var doors: BusDoors = bus.get_node("BusDoors") as BusDoors
	if not rear_open:
		doors.apply_state(&"rear", BusDoors.DoorPhase.CLOSED, 0.0)
	var package: Package = (load(PACKAGE_SCENE) as PackedScene).instantiate() as Package
	package.position = bus.global_transform * Vector3(0.0, 0.35, 3.45)
	package.gravity_scale = 0.0
	add_child(auto_free(package))
	await _ticks(2)
	package.linear_velocity = bus.global_basis.z * 5.0
	await _ticks(45)
	return (bus.global_transform.affine_inverse() * package.global_position).z


func _spawn_bus() -> Bus:
	var bus: Bus = auto_free((load(BUS_SCENE) as PackedScene).instantiate()) as Bus
	bus.position = Vector3(0.0, 20.0, 0.0)
	bus.freeze = true
	add_child(bus)
	await _ticks(3)
	return bus


func _spawn_dynamic_bus() -> Bus:
	var bus: Bus = auto_free((load(BUS_SCENE) as PackedScene).instantiate()) as Bus
	bus.position = Vector3(0.0, 20.0, 0.0)
	add_child(bus)
	await _ticks(3)
	return bus


func _crew(at: Vector3) -> CrewMember:
	var crew: CrewMember = auto_free((load(CREW_SCENE) as PackedScene).instantiate()) as CrewMember
	crew.position = at
	crew.set_physics_process(false)
	add_child(crew)
	return crew


func _blocker(bus: Bus, door_id: StringName) -> CollisionShape3D:
	var name: String = "SideDoorBlocker" if door_id == &"side" else "RearDoorBlocker"
	return bus.get_node("BusDoors/Blockers/" + name) as CollisionShape3D


func _ticks(count: int) -> void:
	for index: int in range(count):
		await get_tree().physics_frame
