extends GdUnitTestSuite


func test_irregular_delivery_preserves_uniform_motion_after_buffer_warmup() -> void:
	var body: RigidBody3D = auto_free(RigidBody3D.new())
	body.freeze = true
	add_child(body)
	var receiver: NetBusSync = auto_free(NetBusSync.new())
	receiver.bus = body
	# Do not add the receiver: this test advances its clock explicitly.
	var snapshot: int = 0
	var previous: float = 0.0
	var maximum_step: float = 0.0
	var minimum_step: float = INF
	for tick: int in range(120):
		# 30 Hz source, delivered alternately after one and three ticks.
		if tick % 4 == 0 or tick % 4 == 1:
			receiver.accept_snapshot(Transform3D(Basis.IDENTITY, Vector3(float(snapshot) * 18.5 / 30.0, 0.0, 0.0)))
			snapshot += 1
		receiver.advance(1.0 / 60.0)
		if tick > 10:
			var step: float = body.position.x - previous
			maximum_step = maxf(maximum_step, step)
			minimum_step = minf(minimum_step, step)
		previous = body.position.x
	print("BUS_DELIVERY alternating_1_3 min_step=%.6f max_step=%.6f expected=%.6f" % [minimum_step, maximum_step, 18.5 / 60.0])
	assert_float(maximum_step).is_less_equal(18.5 / 60.0 + 0.0001)
	assert_float(minimum_step).is_greater_equal(18.5 / 60.0 - 0.0001)


func test_batched_snapshots_follow_the_source_clock_without_skipping_history() -> void:
	var body: RigidBody3D = auto_free(RigidBody3D.new())
	body.freeze = true
	add_child(body)
	var receiver: NetBusSync = auto_free(NetBusSync.new())
	receiver.bus = body
	receiver.accept_snapshot(Transform3D.IDENTITY, 0.0)
	for tick: int in range(120):
		if tick > 0 and tick % 4 == 0:
			for source_tick: int in [tick - 2, tick]:
				var time: float = float(source_tick) / 60.0
				receiver.accept_snapshot(Transform3D(Basis.IDENTITY, Vector3(time * 18.5, 0.0, 0.0)), time)
		receiver.advance(1.0 / 60.0)
		var expected: float = 18.5 * maxf(0.0, float(tick - 4) / 60.0)
		assert_float(body.position.x).is_equal_approx(expected, 0.0001)


func test_stale_packets_are_rejected_and_loss_holds_the_last_known_pose() -> void:
	var body: RigidBody3D = auto_free(RigidBody3D.new())
	body.freeze = true
	add_child(body)
	var receiver: NetBusSync = auto_free(NetBusSync.new())
	receiver.bus = body
	receiver.accept_snapshot(Transform3D.IDENTITY, 0.0)
	receiver.accept_snapshot(Transform3D(Basis.IDENTITY, Vector3.RIGHT), 1.0 / 30.0)
	receiver.accept_snapshot(Transform3D(Basis.IDENTITY, Vector3.LEFT * 100.0), 0.0)
	for tick: int in range(60):
		receiver.advance(1.0 / 60.0)
	assert_int(receiver.rejected_count).is_equal(1)
	assert_int(receiver.received_count).is_equal(2)
	assert_float(body.position.x).is_equal_approx(1.0, 0.00001)
	receiver.interpolate = false
	receiver.accept_snapshot(Transform3D(Basis.IDENTITY, Vector3.RIGHT * 5.0), 2.0)
	receiver.advance(1.0 / 60.0)
	assert_float(body.position.x).is_equal_approx(5.0, 0.00001)


func test_point_velocity_uses_interpolated_snapshot_without_simulating_the_bus() -> void:
	var body: RigidBody3D = auto_free(RigidBody3D.new())
	body.freeze = true
	add_child(body)
	var receiver: NetBusSync = auto_free(NetBusSync.new())
	receiver.bus = body
	add_child(receiver)
	receiver.set_physics_process(false)
	receiver.interpolation_delay_s = 0.0
	receiver.accept_snapshot(Transform3D.IDENTITY, 0.0, Vector3(18.5, 0.0, 0.0), Vector3.UP)
	receiver.accept_snapshot(Transform3D(Basis.IDENTITY, Vector3.RIGHT), 1.0 / 30.0, Vector3(20.5, 0.0, 0.0), Vector3.UP * 3.0)
	receiver.advance(1.0 / 60.0)
	receiver.advance(1.0 / 60.0)
	var point: Vector3 = body.global_position + Vector3.FORWARD
	assert_vector(NetBusSync.point_velocity(body, point)).is_equal_approx(Vector3(17.5, 0.0, 0.0), Vector3.ONE * 0.0001)
	assert_vector(body.linear_velocity).is_equal(Vector3.ZERO)
	assert_vector(body.angular_velocity).is_equal(Vector3.ZERO)
	receiver.accept_snapshot(Transform3D.IDENTITY, 1.0, Vector3(INF, 0.0, 0.0))
	assert_int(receiver.rejected_count).is_equal(1)


func test_steer_is_clamped_interpolated_and_never_writes_client_physics() -> void:
	var body: RigidBody3D = auto_free(RigidBody3D.new())
	body.freeze = true
	add_child(body)
	var receiver: NetBusSync = auto_free(NetBusSync.new())
	receiver.bus = body
	receiver.interpolation_delay_s = 0.0
	receiver.accept_snapshot(Transform3D.IDENTITY, 0.0,
		Vector3(10.0, 0.0, 0.0), Vector3.UP, 0, -2.0)
	receiver.accept_snapshot(Transform3D(Basis.IDENTITY, Vector3.RIGHT), 1.0,
		Vector3(20.0, 0.0, 0.0), Vector3.UP * 3.0, 0, 2.0)
	receiver.advance(0.5)
	receiver.advance(0.0)
	assert_float(receiver.replicated_steer_input()).is_equal_approx(0.0, 0.0001)
	assert_vector(receiver.replicated_linear_velocity()).is_equal_approx(
		Vector3(15.0, 0.0, 0.0), Vector3.ONE * 0.0001)
	assert_vector(body.linear_velocity).is_equal(Vector3.ZERO)
	assert_vector(body.angular_velocity).is_equal(Vector3.ZERO)
	var accepted: int = receiver.received_count
	receiver.accept_snapshot(Transform3D.IDENTITY, 2.0,
		Vector3.ZERO, Vector3.ZERO, 0, NAN)
	assert_int(receiver.received_count).is_equal(accepted)
	assert_int(receiver.rejected_count).is_equal(1)
