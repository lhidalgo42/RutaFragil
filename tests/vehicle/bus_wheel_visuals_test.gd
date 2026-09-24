extends GdUnitTestSuite


func test_spin_step_tracks_forward_and_reverse_signed_speed() -> void:
	assert_float(BusExteriorVisual.spin_step(-6.0, 0.5, 0.25)).is_equal_approx(3.0, 0.0001)
	assert_float(BusExteriorVisual.spin_step(6.0, 0.5, 0.25)).is_equal_approx(-3.0, 0.0001)


func test_front_steers_and_rear_stays_straight() -> void:
	assert_float(BusExteriorVisual.wheel_steer_deg(Vector3(0.0, 0.0, -2.0), 15.0)).is_equal_approx(15.0, 0.0001)
	assert_float(BusExteriorVisual.wheel_steer_deg(Vector3(0.0, 0.0, 2.0), 15.0)).is_equal_approx(0.0, 0.0001)


func test_visual_center_keeps_tire_on_hit_plane_and_clamps_droop() -> void:
	var marker: Vector3 = Vector3(1.0, 0.0, -2.0)
	# Hit 0.1 m below the anchor, closer than the radius: the tire bottom must
	# sit ON the hit plane, never below it (a radius floor would sink it 0.4 m).
	var close: Vector3 = Bus.visual_wheel_center_for(marker, 0.1, 0.5, 0.4)
	assert_vector(close).is_equal_approx(Vector3(1.0, 0.4, -2.0), Vector3.ONE * 0.0001)
	assert_float(close.y - 0.5).is_equal_approx(-0.1, 0.0001)
	# Beyond the ray (no contact) the wheel hangs at full extension only.
	var droop: Vector3 = Bus.visual_wheel_center_for(marker, 5.0, 0.5, 0.4)
	assert_float(droop.y).is_equal_approx(-0.4, 0.0001)
	var negative: Vector3 = Bus.visual_wheel_center_for(marker, -1.0, 0.5, 0.4)
	assert_float(negative.y).is_equal_approx(0.5, 0.0001)


func test_bus_queries_default_to_full_extension_without_contact() -> void:
	var bus: Bus = auto_free(Bus.new())
	bus.freeze = true
	_add_markers(bus)
	add_child(bus)
	var radius: float = bus.wheel_radius_m()
	var rest: float = bus.suspension_rest_m()
	assert_float(radius).is_greater(0.0)
	assert_bool(bus.has_wheel_contact("WheelFL")).is_false()
	assert_float(bus.last_suspension_distance("WheelFL")).is_equal_approx(rest + radius, 0.0001)
	var marker: Marker3D = bus.get_node("WheelFL") as Marker3D
	assert_vector(bus.visual_wheel_center("WheelFL")).is_equal_approx(
		marker.position + Vector3.DOWN * rest, Vector3.ONE * 0.0001)


func test_frozen_replica_uses_snapshot_steer_and_velocity() -> void:
	var bus: Bus = auto_free(Bus.new())
	bus.freeze = true
	_add_markers(bus)
	add_child(bus)
	var sync: NetBusSync = NetBusSync.new()
	sync.bus = bus
	sync.interpolation_delay_s = 0.0
	bus.add_child(sync)
	sync.set_physics_process(false)
	var visual: BusExteriorVisual = BusExteriorVisual.new()
	_add_visual_pivots(visual)
	bus.add_child(visual)
	visual.set_physics_process(false)
	sync.accept_snapshot(Transform3D.IDENTITY, 0.0, Vector3(0.0, 0.0, -10.0), Vector3.ZERO, 0, 0.75)
	sync.advance(0.0)
	visual.update_visuals(0.1)
	var front_steer: Node3D = visual.get_node("WheelFL/SteerPivot") as Node3D
	var rear_steer: Node3D = visual.get_node("WheelRL/SteerPivot") as Node3D
	var front_spin: Node3D = visual.get_node("WheelFL/SteerPivot/SpinPivot") as Node3D
	assert_float(rad_to_deg(front_steer.rotation.y)).is_greater(0.0)
	assert_float(rad_to_deg(front_steer.rotation.y)).is_less_equal(30.0)
	assert_float(rear_steer.rotation.y).is_equal_approx(0.0, 0.0001)
	assert_float(front_spin.rotation.x).is_less(0.0)
	assert_float(bus.linear_velocity.length()).is_equal_approx(0.0, 0.0001)


func _add_markers(bus: Bus) -> void:
	for wheel_name: String in ["WheelFL", "WheelFR", "WheelRL", "WheelRR"]:
		var marker: Marker3D = Marker3D.new()
		marker.name = wheel_name
		marker.position = Vector3(-1.0 if wheel_name.ends_with("L") else 1.0, 0.0,
			-2.0 if wheel_name.contains("F") else 2.0)
		bus.add_child(marker)


func _add_visual_pivots(visual: BusExteriorVisual) -> void:
	for wheel_name: String in ["WheelFL", "WheelFR", "WheelRL", "WheelRR"]:
		var wheel: Node3D = Node3D.new()
		wheel.name = wheel_name
		var steer: Node3D = Node3D.new()
		steer.name = "SteerPivot"
		var spin: Node3D = Node3D.new()
		spin.name = "SpinPivot"
		steer.add_child(spin)
		wheel.add_child(steer)
		visual.add_child(wheel)
