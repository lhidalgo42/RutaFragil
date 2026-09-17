extends GdUnitTestSuite

## Real capsules and kinematic replicas reproduce the release collision from
## revision 04; the RPC boundary applies the same confirmed package state.
class ReleaseConfirmation extends Node:
	var package: Package
	var releases: int = 0

	func send_release(_package_name: StringName, at: Transform3D, velocity: Vector3) -> void:
		releases += 1
		package.apply_replicated_state(Package.Restraint.FREE, at, velocity, &"", 0)
		var hands: CrewHands = package.get_tree().get_first_node_in_group("crew_hands") as CrewHands
		hands.held = null

var _crew: CrewMember
var _package: Package
var _hands: CrewHands
var _confirmation: ReleaseConfirmation


func before_test() -> void:
	_box(Vector3(0.0, -0.5, 0.0), Vector3(20.0, 1.0, 20.0))
	var bus: Bus = auto_free(Bus.new())
	bus.freeze = true
	add_child(bus)
	var scene: PackedScene = load("res://src/crew/crew_member.tscn") as PackedScene
	_crew = auto_free(scene.instantiate())
	_crew.position = Vector3(0.0, 0.1, 0.0)
	add_child(_crew)
	await _ticks(30)
	assert_bool(_crew.is_on_floor()).is_true()
	scene = load("res://src/cargo/package.tscn") as PackedScene
	_package = auto_free(scene.instantiate())
	_package.configure_replication(bus, true)
	_package.position = Vector3(0.0, 0.5, -1.0)
	add_child(_package)
	_confirmation = auto_free(ReleaseConfirmation.new())
	_confirmation.package = _package
	_confirmation.add_to_group("net_cargo_sync")
	add_child(_confirmation)
	_crew.network_member = true
	_crew.network_ready = true
	_hands = _crew.get_node("CrewHands") as CrewHands
	_package.apply_replicated_state(Package.Restraint.HELD,
		Transform3D(Basis.IDENTITY, Vector3(0.0, 1.0, -1.0)), Vector3.ZERO, &"", 1)
	_hands.held = _package
	await _ticks(3)


func test_blocked_hand_drop_does_not_place_kinematic_cargo_inside_crew() -> void:
	var hand: Marker3D = _crew.get_node("EyeCamera/HandAnchor") as Marker3D
	_box(hand.global_position, Vector3.ONE * 0.45)
	await _ticks(2)
	var start_y: float = _crew.global_position.y
	_hands.drop()
	assert_int(_confirmation.releases).is_equal(1)
	var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	var shape: CollisionShape3D = _package.get_node("Shape") as CollisionShape3D
	query.shape = shape.shape
	query.transform = _package.global_transform * shape.transform
	query.collision_mask = 4
	query.exclude = [_package.get_rid()]
	assert_array(_package.get_world_3d().direct_space_state.intersect_shape(query)).is_empty()
	var rise: float = 0.0
	for tick: int in range(12):
		await _ticks(1)
		rise = maxf(rise, _crew.global_position.y - start_y)
	print("RELEASE_REPLICA rise_m=%.6f package=%s" % [rise, _package.global_position])
	assert_float(rise).is_less(0.05)
	assert_bool(_crew.is_on_floor()).is_true()


func test_drop_without_free_space_retains_holder_and_sends_no_release() -> void:
	_box(_crew.global_position + Vector3.UP, Vector3.ONE * 12.0)
	await get_tree().physics_frame
	_hands.drop()
	assert_int(_confirmation.releases).is_equal(0)
	assert_int(_package.restraint).is_equal(Package.Restraint.HELD)
	assert_object(_hands.held).is_same(_package)


func test_throw_from_blocked_hand_retains_holder_and_sends_no_release() -> void:
	var hand: Marker3D = _crew.get_node("EyeCamera/HandAnchor") as Marker3D
	_box(hand.global_position, Vector3.ONE * 0.45)
	await _ticks(2)
	_hands.throw()
	assert_int(_confirmation.releases).is_equal(0)
	assert_int(_package.restraint).is_equal(Package.Restraint.HELD)
	assert_object(_hands.held).is_same(_package)


func test_confirmed_release_does_not_turn_teleport_into_platform_velocity() -> void:
	_hands.set_physics_process(false)
	var destination: Transform3D = Transform3D(Basis.IDENTITY, Vector3(0.8, 0.22, 0.0))
	_package.apply_replicated_state(Package.Restraint.FREE, destination, Vector3.ZERO, &"", 0)
	var peak: float = 0.0
	for tick: int in range(4):
		await _ticks(1)
		var state: PhysicsDirectBodyState3D = PhysicsServer3D.body_get_direct_state(_package.get_rid())
		peak = maxf(peak, state.linear_velocity.length())
	print("RELEASE_PLATFORM peak_mps=%.6f" % peak)
	assert_float(peak).is_less(0.01)
	assert_bool(_package.freeze).is_true()
	assert_int(_package.physics_simulation_ticks).is_equal(0)
	assert_int(_package.freeze_mode).is_equal(RigidBody3D.FREEZE_MODE_KINEMATIC)
	_package.global_position += Vector3.RIGHT * 0.1
	_package.force_update_transform()
	peak = 0.0
	for tick: int in range(3):
		await _ticks(1)
		var state: PhysicsDirectBodyState3D = PhysicsServer3D.body_get_direct_state(_package.get_rid())
		peak = maxf(peak, state.linear_velocity.length())
	assert_float(peak).is_greater(1.0)


func test_drop_does_not_choose_free_space_across_a_thin_wall() -> void:
	var hand: Marker3D = _crew.get_node("EyeCamera/HandAnchor") as Marker3D
	_box(hand.global_position, Vector3.ONE * 0.45)
	_box(Vector3(-0.36, 1.0, 0.0), Vector3(0.05, 2.0, 4.0))
	await _ticks(2)
	_hands.drop()
	assert_int(_confirmation.releases).is_equal(1)
	assert_float(_package.global_position.x).is_greater(-0.335)


func _box(at: Vector3, size: Vector3) -> void:
	var body: StaticBody3D = auto_free(StaticBody3D.new())
	body.position = at
	var collision: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	add_child(body)


func _ticks(count: int) -> void:
	for tick: int in range(count):
		await get_tree().physics_frame
