extends GdUnitTestSuite

var _scene: Node3D = null
var _bus: Bus = null
var _cargo: Node3D = null
var _replica: NetCargoReplica = null
var _rules: NetCargoRules = null


func before_test() -> void:
	_scene = auto_free(Node3D.new())
	add_child(_scene)
	_bus = Bus.new()
	_bus.position = Vector3(100.0, 20.0, -100.0)
	_bus.freeze = true
	_scene.add_child(_bus)
	_bus.add_to_group("bus")
	_cargo = Node3D.new()
	_cargo.name = "Cargo"
	_scene.add_child(_cargo)
	_replica = NetCargoReplica.new()
	_replica.scene = _scene
	_replica.bus = _bus
	_replica.host_mode = true
	_rules = NetCargoRules.new()
	_rules.replica = _replica


func test_client_impulse_never_simulates_but_host_free_box_does() -> void:
	var client: Package = _package(&"Replica", Vector3(0.0, 5.0, 0.0), true)
	var host: Package = _package(&"Host", Vector3(5.0, 5.0, 0.0))
	var client_before: Vector3 = client.global_position
	var host_before: Vector3 = host.global_position
	client.apply_central_impulse(Vector3(80.0, 30.0, 0.0))
	await _ticks(15)
	assert_vector(client.global_position).is_equal_approx(client_before, Vector3.ONE * 0.0001)
	assert_bool(client.freeze).is_true()
	assert_int(client.freeze_mode).is_equal(RigidBody3D.FREEZE_MODE_KINEMATIC)
	assert_int(client.physics_simulation_ticks).is_equal(0)
	assert_int(client.integration_callback_ticks).is_greater(0)
	assert_int(client.unauthorized_simulation_ticks).is_equal(0)
	assert_int(host.physics_simulation_ticks).is_greater(0)
	assert_float(host.global_position.y).is_less(host_before.y)
	assert_int(host.unauthorized_simulation_ticks).is_equal(0)


func test_host_grant_and_release_transfer_authority_to_holder_and_back() -> void:
	var member: CrewMember = _crew(23, Vector3(0.0, 2.0, 0.0))
	var package: Package = _package(&"CargoA", Vector3(0.0, 2.0, 0.0))
	assert_bool(_rules.hold(23, package.name).is_empty()).is_false()
	assert_int(package.get_multiplayer_authority()).is_equal(23)
	assert_object(package.held_by).is_same(member)
	assert_bool(package.freeze).is_true()
	var at: Transform3D = Transform3D(Basis.IDENTITY, Vector3(0.0, 2.0, -0.5))
	assert_bool(_rules.release(23, package.name, at, Vector3.FORWARD).is_empty()).is_false()
	assert_int(package.get_multiplayer_authority()).is_equal(1)
	assert_int(package.holder_peer_id).is_equal(0)
	assert_object(package.held_by).is_null()
	assert_bool(package.freeze).is_false()
	assert_vector(package.global_position).is_equal_approx(_bus.global_transform * at.origin, Vector3.ONE * 0.001)


func test_unknown_peer_distance_and_occupied_hand_deny_hold() -> void:
	_crew(1, Vector3(0.0, 2.0, 0.0))
	_crew(23, Vector3(20.0, 2.0, 0.0))
	var first: Package = _package(&"First", Vector3(0.0, 2.0, 0.0))
	var second: Package = _package(&"Second", Vector3(0.5, 2.0, 0.0))
	assert_bool(_rules.hold(999, first.name).is_empty()).is_true()
	assert_bool(_rules.hold(23, first.name).is_empty()).is_true()
	assert_bool(_rules.hold(1, first.name).is_empty()).is_false()
	assert_bool(_rules.hold(1, second.name).is_empty()).is_true()
	assert_int(NetCargoReplica.as_int(_rules.activity_for_peer(1)["hold_requested"])).is_equal(2)
	assert_int(NetCargoReplica.as_int(_rules.activity_for_peer(1)["hold_denied"])).is_equal(1)
	assert_int(NetCargoReplica.as_int(_rules.activity_for_peer(23)["hold_granted"])).is_equal(0)
	assert_int(second.restraint).is_equal(Package.Restraint.FREE)


func test_reach_validation_uses_remote_hand_in_the_same_bus_frame() -> void:
	var sync: NetCrewSync = NetCrewSync.new()
	sync.bus = _bus
	sync.network_enabled = false
	_scene.add_child(sync)
	sync.spawn_crews([1, 23])
	await _ticks(2)
	var source_bus: Transform3D = _bus.global_transform
	source_bus.origin.x -= 10.0
	var crew_at: Transform3D = source_bus * Transform3D(Basis.IDENTITY, Vector3(0.0, -0.6, 0.0))
	var remote: CrewMember = NetAuthority.crew_for_peer(get_tree(), 23)
	remote.global_transform = crew_at
	sync.accept_interaction_frame(23, crew_at, 0.0, source_bus)
	var package: Package = _package(&"ReachOnBus", Vector3(0.0, 0.85, -0.7))
	assert_bool(_rules.hold(23, package.name).is_empty()).is_false()
	assert_object(package.held_by).is_same(remote)
	var too_far: Transform3D = Transform3D(Basis.IDENTITY, Vector3(20.0, 0.85, -0.7))
	assert_bool(_rules.release(23, package.name, too_far, Vector3.ZERO).is_empty()).is_true()


func test_nonholder_and_occupied_anchor_cannot_change_restraint() -> void:
	_crew(1, Vector3(0.0, 2.0, 0.0))
	_crew(23, Vector3(0.0, 2.0, 0.0))
	var package: Package = _package(&"Held", Vector3(0.0, 2.0, 0.0))
	var blocker: Package = _package(&"Blocker", Vector3(1.0, 2.0, 0.0))
	var anchor: RestraintAnchor = _anchor(&"Anchor", Vector3(0.5, 2.0, 0.0))
	_rules.hold(23, package.name)
	assert_bool(_rules.release(1, package.name, Transform3D.IDENTITY, Vector3.ZERO).is_empty()).is_true()
	assert_bool(_rules.strap(1, package.name, anchor.name).is_empty()).is_true()
	anchor.occupant = blocker
	assert_bool(_rules.strap(23, package.name, anchor.name).is_empty()).is_true()
	assert_int(package.restraint).is_equal(Package.Restraint.HELD)
	assert_int(package.holder_peer_id).is_equal(23)
	assert_object(anchor.occupant).is_same(blocker)
	assert_int(NetCargoReplica.as_int(_rules.activity_for_peer(23)["strap_denied"])).is_equal(1)


func test_only_full_confirmed_sequence_counts_a_cycle() -> void:
	_crew(23, Vector3(0.0, 2.0, 0.0))
	var package: Package = _package(&"Cycle", Vector3(0.0, 2.0, 0.0))
	var anchor: RestraintAnchor = _anchor(&"Anchor", Vector3(0.5, 2.0, 0.0))
	_rules.hold(23, package.name)
	_rules.strap(23, package.name, anchor.name)
	assert_int(NetCargoReplica.as_int(_rules.activity_for_peer(23)["complete_cycles"])).is_equal(0)
	_rules.unstrap(23, package.name)
	var at: Transform3D = Transform3D(Basis.IDENTITY, Vector3(0.0, 2.0, 0.0))
	_rules.release(23, package.name, at, Vector3.ZERO)
	var counts: Dictionary = _rules.activity_for_peer(23)
	for field: String in ["hold_granted", "strap_ok", "unstrap", "release", "complete_cycles"]:
		assert_int(NetCargoReplica.as_int(counts[field])).override_failure_message(field).is_equal(1)
	assert_int(NetCargoReplica.as_int(counts["authority_transfers"])).is_equal(4)
	_rules.hold(23, package.name)
	_rules.release(23, package.name, at, Vector3.ZERO)
	assert_int(NetCargoReplica.as_int(_rules.activity_for_peer(23)["complete_cycles"])).is_equal(1)


func test_replicated_strapped_to_free_clears_anchor_and_restores_cargo_parent() -> void:
	var package: Package = _package(&"Replica", Vector3(0.0, 2.0, 0.0), true)
	var anchor: RestraintAnchor = _anchor(&"Anchor", Vector3(0.5, 2.0, 0.0))
	package.apply_replicated_state(Package.Restraint.STRAPPED, anchor.transform, Vector3.ZERO, anchor.name, 0)
	assert_object(package.get_parent()).is_same(_bus)
	assert_object(anchor.occupant).is_same(package)
	var at: Transform3D = Transform3D(Basis.IDENTITY, Vector3(0.0, 2.0, -1.0))
	package.apply_replicated_state(Package.Restraint.FREE, at, Vector3.ONE, &"", 0)
	await _ticks(2)
	assert_object(package.get_parent()).is_same(_cargo)
	assert_object(anchor.occupant).is_null()
	assert_object(package.strapped_to).is_null()
	assert_object(package.held_by).is_null()
	assert_bool(package.freeze).is_true()
	var shape: CollisionShape3D = package.get_node("Shape") as CollisionShape3D
	assert_bool(shape.disabled).is_false()
	assert_vector(package.global_position).is_equal_approx(_bus.global_transform * at.origin, Vector3.ONE * 0.001)


func test_late_holder_resolves_exact_peer_and_updates_only_local_hands() -> void:
	var local: CrewMember = _crew(1, Vector3(0.0, 2.0, 0.0))
	var package: Package = _package(&"Late", Vector3(0.0, 2.0, 0.0), true)
	var at: Transform3D = Transform3D(Basis.IDENTITY, Vector3(0.0, 2.0, 0.0))
	package.apply_replicated_state(Package.Restraint.HELD, at, Vector3.ZERO, &"", 23)
	assert_object(package.held_by).is_null()
	var remote: CrewMember = _crew(23, Vector3(0.0, 2.0, 0.0))
	package.refresh_replicated_holder()
	_replica.update_hands()
	assert_object(package.held_by).is_same(remote)
	var hands: CrewHands = local.get_node("CrewHands") as CrewHands
	assert_object(hands.held).is_null()
	package.apply_replicated_state(Package.Restraint.HELD, at, Vector3.ZERO, &"", 1)
	_replica.update_hands()
	assert_object(package.held_by).is_same(local)
	assert_object(hands.held).is_same(package)
	package.apply_replicated_state(Package.Restraint.FREE, at, Vector3.ZERO, &"", 0)
	_replica.update_hands()
	assert_object(hands.held).is_null()


func test_repeated_state_is_idempotent_and_holder_change_is_observable() -> void:
	var package: Package = _package(&"Idempotent", Vector3(0.0, 2.0, 0.0), true)
	var changes: Array[int] = []
	package.restraint_changed.connect(func(_from: Package.Restraint, to: Package.Restraint) -> void: changes.append(to))
	var at: Transform3D = Transform3D(Basis.IDENTITY, Vector3(0.0, 2.0, 0.0))
	package.apply_replicated_state(Package.Restraint.HELD, at, Vector3.ZERO, &"", 23)
	package.apply_replicated_state(Package.Restraint.HELD, at, Vector3.ZERO, &"", 23)
	assert_int(changes.size()).is_equal(1)
	package.apply_replicated_state(Package.Restraint.HELD, at, Vector3.ZERO, &"", 42)
	assert_int(changes.size()).is_equal(2)
	assert_int(package.get_multiplayer_authority()).is_equal(42)


func test_interpolation_rejects_pose_from_previous_state_revision() -> void:
	_replica.host_mode = false
	var package: Package = _package(&"Replica", Vector3(0.0, 2.0, 0.0), true)
	var row: Dictionary = _replica.state_row(package)
	row["revision"] = 3
	_replica.apply_state(row)
	var next: Dictionary = row.duplicate()
	next["at"] = Transform3D(Basis.IDENTITY, Vector3(3.0, 2.0, 0.0))
	assert_bool(_replica.accept_pose(next)).is_true()
	_replica.advance(0.025, 20.0)
	assert_float((_bus.global_transform.affine_inverse() * package.global_position).x).is_equal_approx(1.5, 0.001)
	next["revision"] = 2
	assert_bool(_replica.accept_pose(next)).is_false()
	row["revision"] = 4
	row["state"] = Package.Restraint.HELD
	row["holder"] = 23
	_replica.apply_state(row)
	next["revision"] = 3
	assert_bool(_replica.accept_pose(next)).is_false()
	assert_int(package.restraint).is_equal(Package.Restraint.HELD)


func test_release_uses_current_bus_frame_and_point_velocity_after_bus_moves() -> void:
	_bus.global_basis = Basis(Vector3.UP, 0.3)
	_bus.linear_velocity = Vector3(18.5, 0.0, 0.0)
	_bus.angular_velocity = Vector3(0.0, 0.5, 0.0)
	var member: CrewMember = _crew(1, Vector3(0.0, 2.0, 0.0))
	var package: Package = _package(&"Release", Vector3(0.0, 2.0, 0.0))
	_rules.hold(1, package.name)
	var at: Transform3D = Transform3D(Basis.IDENTITY, Vector3(0.0, 2.0, -0.5))
	var point: Vector3 = _bus.global_transform * at.origin
	var relative: Vector3 = Vector3(0.0, 1.0, -3.0)
	var world_velocity: Vector3 = _bus.global_basis * relative + Package.rigid_point_velocity(
		_bus.linear_velocity, _bus.angular_velocity, point - _bus.global_position)
	var sent: Vector3 = NetCargoRules.velocity_to_bus(_bus, point, world_velocity)
	_bus.global_position += Vector3(10.0, 0.0, -4.0)
	_bus.global_basis = Basis(Vector3.UP, 0.8)
	member.global_position = _bus.global_transform * Vector3(0.0, 2.0, 0.0)
	assert_bool(_rules.release(1, package.name, at, sent).is_empty()).is_false()
	var expected_point: Vector3 = _bus.global_transform * at.origin
	var expected_velocity: Vector3 = _bus.global_basis * relative + Package.rigid_point_velocity(
		_bus.linear_velocity, _bus.angular_velocity, expected_point - _bus.global_position)
	assert_vector(package.global_position).is_equal_approx(expected_point, Vector3.ONE * 0.001)
	assert_vector(package.linear_velocity).is_equal_approx(expected_velocity, Vector3.ONE * 0.001)


func test_held_snapshots_reject_other_peer_and_obsolete_revision() -> void:
	_crew(23, Vector3(0.0, 2.0, 0.0))
	var package: Package = _package(&"Held", Vector3(0.0, 2.0, 0.0))
	_rules.hold(23, package.name)
	var row: Dictionary = _replica.state_row(package)
	row["at"] = Transform3D(Basis.IDENTITY, Vector3(0.5, 2.0, 0.0))
	assert_bool(_rules.accept_held_pose(42, row)).is_false()
	assert_bool(_rules.accept_held_pose(23, row)).is_true()
	row["revision"] = NetCargoReplica.as_int(row["revision"]) - 1
	assert_bool(_rules.accept_held_pose(23, row)).is_false()


func test_host_rejects_release_inside_real_crew_capsule_before_authority_transfer() -> void:
	var member: CrewMember = _crew(23, Vector3(0.0, 2.0, 0.0))
	var collision: CollisionShape3D = CollisionShape3D.new()
	var capsule: CapsuleShape3D = CapsuleShape3D.new()
	capsule.radius = 0.3
	capsule.height = 1.75
	collision.shape = capsule
	member.collision_layer = 4
	member.add_child(collision)
	var package: Package = _package(&"UnsafeDrop", Vector3(0.0, 2.0, 0.0))
	assert_bool(_rules.hold(23, package.name).is_empty()).is_false()
	await _ticks(2)
	assert_bool(_rules.release(23, package.name,
		Transform3D(Basis.IDENTITY, Vector3(0.0, 2.0, 0.0)), Vector3.ZERO).is_empty()).is_true()
	assert_int(package.restraint).is_equal(Package.Restraint.HELD)
	assert_int(package.get_multiplayer_authority()).is_equal(23)
	assert_int(NetCargoReplica.as_int(_rules.activity_for_peer(23)["release"])).is_equal(0)


func _package(package_name: StringName, local: Vector3, replica_only: bool = false) -> Package:
	var packed: PackedScene = load("res://src/cargo/package.tscn") as PackedScene
	var package: Package = packed.instantiate() as Package
	package.name = package_name
	package.position = _bus.global_transform * local
	package.configure_replication(_bus, replica_only)
	_cargo.add_child(package)
	return package


func _crew(peer_id: int, local: Vector3) -> CrewMember:
	var member: CrewMember = CrewMember.new()
	member.position = _bus.global_transform * local
	member.set_multiplayer_authority(peer_id)
	var eye: Camera3D = Camera3D.new()
	eye.name = "EyeCamera"
	var hand: Marker3D = Marker3D.new()
	hand.name = "HandAnchor"
	eye.add_child(hand)
	member.add_child(eye)
	var hands: CrewHands = CrewHands.new()
	hands.name = "CrewHands"
	member.add_child(hands)
	_scene.add_child(member)
	member.set_physics_process(false)
	return member


func _anchor(anchor_name: StringName, local: Vector3) -> RestraintAnchor:
	var anchor: RestraintAnchor = RestraintAnchor.new()
	anchor.name = anchor_name
	anchor.position = local
	_bus.add_child(anchor)
	anchor.add_to_group("restraint_anchor")
	return anchor


func _ticks(count: int) -> void:
	for tick: int in range(count):
		await get_tree().physics_frame


func test_host_strapped_box_follows_a_dynamic_bus() -> void:
	var package: Package = _package(&"Strapped", Vector3(0.0, 2.0, 0.0))
	var anchor: RestraintAnchor = _anchor(&"Anchor", Vector3(0.5, 2.0, 0.0))
	package.apply_replicated_state(Package.Restraint.STRAPPED,
		anchor.transform, Vector3.ZERO, anchor.name, 0)
	_bus.gravity_scale = 0.0
	_bus.freeze = false
	_bus.linear_velocity = Vector3(0.0, 0.0, -18.5)
	var start: Vector3 = _bus.global_position
	var max_error: float = 0.0
	for tick: int in range(30):
		await get_tree().physics_frame
		await get_tree().process_frame
		max_error = maxf(max_error,
			package.global_position.distance_to(anchor.global_position))
	assert_float(_bus.global_position.distance_to(start)).is_greater(1.0)
	assert_float(max_error).is_less(0.002)
	assert_int(package.freeze_mode).is_equal(RigidBody3D.FREEZE_MODE_STATIC)
	assert_int(package.physics_simulation_ticks).is_equal(0)


func test_outside_drop_accepts_zero_world_velocity_beside_moving_bus() -> void:
	_bus.linear_velocity = Vector3(18.5, 0.0, 0.0)
	var local: Vector3 = Vector3(4.0, 2.0, 0.0)
	_crew(23, local)
	var package: Package = _package(&"Outside", local)
	var at: Transform3D = Transform3D(Basis.IDENTITY, local)
	var point: Vector3 = _bus.global_transform * local
	_rules.hold(23, package.name)
	var relative: Vector3 = NetCargoRules.velocity_to_bus(_bus, point, Vector3.ZERO)
	assert_bool(_rules.release(23, package.name, at, relative).is_empty()).is_false()
	assert_vector(package.linear_velocity).is_equal_approx(Vector3.ZERO, Vector3.ONE * 0.001)
	assert_int(package.get_multiplayer_authority()).is_equal(1)
	_rules.hold(23, package.name)
	var excessive: Vector3 = NetCargoRules.velocity_to_bus(_bus, point, Vector3.UP * 100.0)
	assert_bool(_rules.release(23, package.name, at, excessive).is_empty()).is_true()
	assert_int(package.restraint).is_equal(Package.Restraint.HELD)


func test_malformed_held_pose_is_rejected_without_changing_package() -> void:
	_crew(23, Vector3(0.0, 2.0, 0.0))
	var package: Package = _package(&"Held", Vector3(0.0, 2.0, 0.0))
	_rules.hold(23, package.name)
	var before: Transform3D = package.global_transform
	assert_bool(_rules.accept_held_pose(23, {})).is_false()
	var row: Dictionary = _replica.state_row(package)
	row["name"] = 23
	assert_bool(_rules.accept_held_pose(23, row)).is_false()
	row = _replica.state_row(package)
	row["at"] = "invalid"
	assert_bool(_rules.accept_held_pose(23, row)).is_false()
	row = _replica.state_row(package)
	row["revision"] = "invalid"
	assert_bool(_rules.accept_held_pose(23, row)).is_false()
	assert_bool(package.global_transform.is_equal_approx(before)).is_true()
	assert_int(package.get_multiplayer_authority()).is_equal(23)


func test_release_with_frozen_client_and_moving_host_preserves_velocity_frame() -> void:
	var client_bus: Bus = Bus.new()
	client_bus.transform = _bus.transform
	client_bus.freeze = true
	_scene.add_child(client_bus)
	var receiver: NetBusSync = NetBusSync.new()
	receiver.bus = client_bus
	_scene.add_child(receiver)
	receiver.set_physics_process(false)
	receiver.accept_snapshot(client_bus.transform, 0.0, Vector3(18.5, 0.0, 0.0))
	receiver.advance(1.0 / 60.0)
	_bus.linear_velocity = Vector3(18.5, 0.0, 0.0)
	var local: Vector3 = Vector3(4.0, 2.0, 0.0)
	_crew(23, local)
	var package: Package = _package(&"DifferentReferences", local)
	_rules.hold(23, package.name)
	var at: Transform3D = Transform3D(Basis.IDENTITY, local)
	var point: Vector3 = client_bus.global_transform * local
	var relative: Vector3 = NetCargoRules.velocity_to_bus(client_bus, point, Vector3.ZERO)
	assert_bool(_rules.release(23, package.name, at, relative).is_empty()).is_false()
	assert_vector(package.linear_velocity).is_equal_approx(Vector3.ZERO, Vector3.ONE * 0.001)
	_bus.linear_velocity = Vector3(20.0, 0.0, 0.0)
	for impulse: Vector3 in [Vector3.ZERO, Vector3.FORWARD * 3.0]:
		_rules.hold(23, package.name)
		var world: Vector3 = NetBusSync.point_velocity(client_bus, point) + impulse
		relative = NetCargoRules.velocity_to_bus(client_bus, point, world)
		assert_bool(_rules.release(23, package.name, at, relative).is_empty()).is_false()
		assert_vector(package.linear_velocity).is_equal_approx(_bus.linear_velocity + impulse, Vector3.ONE * 0.001)
	assert_vector(client_bus.linear_velocity).is_equal(Vector3.ZERO)
