extends GdUnitTestSuite


class IdleRelease extends Node:
	var bus: Bus
	var package: Package
	var sync: NetCargoSync
	var ticks: int = 0
	var requested: bool = false
	var server_gap_m: float = 0.0
	const LOCAL: Vector3 = Vector3(0.8, 2.0, 0.1664648)
	func _physics_process(_delta: float) -> void:
		ticks += 1
	func _process(_delta: float) -> void:
		if ticks < 12 or requested:
			return
		requested = true
		var raw: Variant = PhysicsServer3D.body_get_state(bus.get_rid(), PhysicsServer3D.BODY_STATE_TRANSFORM)
		if raw is Transform3D:
			var physical: Transform3D = raw
			server_gap_m = physical.origin.distance_to(bus.global_position)
		sync.request_release(package.name, Transform3D(Basis.IDENTITY, LOCAL), Vector3.ZERO)


func test_release_received_in_idle_keeps_confirmed_bus_local_pose_after_physics() -> void:
	var world: Node3D = auto_free(Node3D.new())
	add_child(world)
	var bus: Bus = Bus.new()
	bus.rotation.y = PI
	_prepare_body(bus)
	var shape: CollisionShape3D = CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	bus.add_child(shape)
	world.add_child(bus)
	bus.set_physics_process(false)
	bus.linear_velocity = Vector3(0.0, 0.0, 18.5)
	var crew: CrewMember = CrewMember.new()
	var eye: Camera3D = Camera3D.new()
	eye.name = "EyeCamera"
	eye.position.y = 1.65
	var hand: Marker3D = Marker3D.new()
	hand.name = "HandAnchor"
	eye.add_child(hand)
	crew.add_child(eye)
	bus.add_child(crew)
	crew.set_physics_process(false)
	var packed: PackedScene = load("res://src/cargo/package.tscn")
	var package: Package = packed.instantiate()
	package.name = "IdleReleaseBox"
	_prepare_body(package)
	package.configure_replication(bus, false)
	world.add_child(package)
	package.apply_replicated_state(Package.Restraint.HELD,
		Transform3D(Basis.IDENTITY, Vector3(0.8, 2.0, -1.0)), Vector3.ZERO, &"", 1)
	var sync: NetCargoSync = NetCargoSync.new()
	sync.bus = bus
	world.add_child(sync)
	var request: IdleRelease = IdleRelease.new()
	request.bus = bus
	request.package = package
	request.sync = sync
	world.add_child(request)
	var samples: int = 0
	var peak: float = 0.0
	for tick: int in range(30):
		await get_tree().physics_frame
		if request.requested and package.restraint == Package.Restraint.FREE:
			peak = maxf(peak, bus.to_local(package.global_position).distance_to(IdleRelease.LOCAL))
			samples += 1
	assert_int(samples).is_greater(5)
	print("IDLE_RELEASE bus_server_gap_m=%.6f free_local_error_m=%.6f" % [request.server_gap_m, peak])
	assert_float(request.server_gap_m).is_greater(0.25)
	assert_float(peak).is_less(0.002)
	assert_int(NetCargoReplica.as_int(sync.activity_for_peer(1)["release"])).is_equal(1)
	assert_int(package.unauthorized_simulation_ticks).is_equal(0)
	# Reliable operations received in one poll retain their order at application.
	sync.request_hold(package.name)
	sync.request_release(package.name, Transform3D(Basis.IDENTITY, IdleRelease.LOCAL), Vector3.ZERO)
	sync.request_hold(package.name)
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_int(package.restraint).is_equal(Package.Restraint.HELD)
	assert_int(NetCargoReplica.as_int(sync.activity_for_peer(1)["hold_granted"])).is_equal(2)


func _prepare_body(body: RigidBody3D) -> void:
	body.gravity_scale = 0.0
	body.linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	body.linear_damp = 0.0
	body.angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	body.angular_damp = 0.0
	body.can_sleep = false
	body.collision_layer = 0
	body.collision_mask = 0
