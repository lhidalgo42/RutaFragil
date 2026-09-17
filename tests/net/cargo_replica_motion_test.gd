extends GdUnitTestSuite


class Writer extends Node:
	var bus: Bus
	var replica: NetCargoReplica = null
	func _ready() -> void:
		process_physics_priority = -100
	func _physics_process(_delta: float) -> void:
		bus.position.x += 0.3
		bus.rotation.y += 0.005
		if replica != null:
			replica.advance(1.0 / 60.0, 20.0)


class Observer extends Node:
	var package: Package
	var anchor: Node3D
	var previous: Transform3D
	var have_previous: bool = false
	var max_physical_error: float = 0.0
	var max_node_error: float = 0.0
	var max_angle_error: float = 0.0
	func _ready() -> void:
		process_physics_priority = 1000
		get_tree().physics_frame.connect(_read_completed_step)
	func _physics_process(_delta: float) -> void:
		previous = anchor.global_transform
		have_previous = true
		max_node_error = maxf(max_node_error, package.global_position.distance_to(previous.origin))
	func _read_completed_step() -> void:
		if not have_previous:
			return
		var raw: Variant = PhysicsServer3D.body_get_state(package.get_rid(), PhysicsServer3D.BODY_STATE_TRANSFORM)
		if raw is Transform3D:
			var physical: Transform3D = raw
			max_physical_error = maxf(max_physical_error, physical.origin.distance_to(previous.origin))
			max_angle_error = maxf(max_angle_error, physical.basis.get_rotation_quaternion().angle_to(previous.basis.get_rotation_quaternion()))


func test_client_strapped_collider_follows_bus_after_a_completed_physics_step() -> void:
	var world: Node3D = auto_free(Node3D.new())
	add_child(world)
	var bus: Bus = Bus.new()
	bus.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	bus.freeze = true
	world.add_child(bus)
	var anchor: RestraintAnchor = RestraintAnchor.new()
	anchor.name = "MovingAnchor"
	anchor.position = Vector3(0.8, 1.0, 0.0)
	bus.add_child(anchor)
	anchor.add_to_group("restraint_anchor")
	var packed: PackedScene = load("res://src/cargo/package.tscn") as PackedScene
	var package: Package = packed.instantiate() as Package
	package.configure_replication(bus, true)
	world.add_child(package)
	package.apply_replicated_state(Package.Restraint.STRAPPED, anchor.transform, Vector3.ZERO, anchor.name, 0)
	var writer: Writer = Writer.new()
	writer.bus = bus
	world.add_child(writer)
	var observer: Observer = Observer.new()
	observer.package = package
	observer.anchor = anchor
	world.add_child(observer)
	for tick: int in range(60):
		await get_tree().physics_frame
	writer.set_physics_process(false)
	await get_tree().physics_frame
	print("STRAPPED_CLIENT node_error=%.6f physical_error=%.6f angle=%.6f" % [observer.max_node_error, observer.max_physical_error, observer.max_angle_error])
	assert_float(observer.max_node_error).is_less(0.002)
	assert_float(observer.max_physical_error).is_less(0.002)
	assert_float(observer.max_angle_error).is_less(0.001)
	assert_float(package.global_position.x).is_greater(1.0)
	assert_int(package.physics_simulation_ticks).is_equal(0)
	assert_int(package.freeze_mode).is_equal(RigidBody3D.FREEZE_MODE_KINEMATIC)


func test_free_state_follows_bus_before_first_unreliable_pose_arrives() -> void:
	var world: Node3D = auto_free(Node3D.new())
	add_child(world)
	var bus: Bus = Bus.new()
	bus.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	bus.freeze = true
	world.add_child(bus)
	var reference: Marker3D = Marker3D.new()
	reference.position = Vector3(0.8, 1.0, 0.0)
	bus.add_child(reference)
	var packed: PackedScene = load("res://src/cargo/package.tscn") as PackedScene
	var package: Package = packed.instantiate() as Package
	package.name = "WaitingForPose"
	package.configure_replication(bus, true)
	world.add_child(package)
	var replica: NetCargoReplica = NetCargoReplica.new()
	replica.scene = world
	replica.bus = bus
	assert_bool(replica.apply_state({"name": package.name, "revision": 1,
		"state": Package.Restraint.FREE, "at": reference.transform, "velocity": Vector3.ZERO,
		"anchor": &"", "holder": 0})).is_true()
	var writer: Writer = Writer.new()
	writer.bus = bus
	writer.replica = replica
	world.add_child(writer)
	var observer: Observer = Observer.new()
	observer.package = package
	observer.anchor = reference
	world.add_child(observer)
	for tick: int in range(6):
		await get_tree().physics_frame
	writer.set_physics_process(false)
	await get_tree().physics_frame
	print("FREE_WAIT node_error=%.6f physical_error=%.6f" % [observer.max_node_error, observer.max_physical_error])
	assert_float(observer.max_node_error).is_less(0.002)
	assert_float(observer.max_physical_error).is_less(0.002)
	assert_int(package.physics_simulation_ticks).is_equal(0)


func test_outside_free_state_waits_in_world_before_first_pose() -> void:
	var world: Node3D = auto_free(Node3D.new())
	add_child(world)
	var bus: Bus = Bus.new()
	bus.freeze = true
	world.add_child(bus)
	var packed: PackedScene = load("res://src/cargo/package.tscn") as PackedScene
	var package: Package = packed.instantiate() as Package
	package.name = "OutsideWaiting"
	package.configure_replication(bus, true)
	world.add_child(package)
	var replica: NetCargoReplica = NetCargoReplica.new()
	replica.scene = world
	replica.bus = bus
	var at: Transform3D = Transform3D(Basis.IDENTITY, Vector3(4.0, 0.22, 0.0))
	assert_bool(replica.apply_state({"name": package.name, "revision": 1,
		"state": Package.Restraint.FREE, "at": at, "velocity": Vector3.ZERO,
		"anchor": &"", "holder": 0})).is_true()
	for tick: int in range(5):
		bus.position.z += 0.3
		replica.advance(1.0 / 60.0, 20.0)
		assert_vector(package.global_position).is_equal_approx(at.origin, Vector3.ONE * 0.002)
