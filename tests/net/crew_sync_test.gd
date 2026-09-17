extends GdUnitTestSuite

const CREW_SCENE: PackedScene = preload("res://src/crew/crew_member.tscn")
const BUS_SCENE: PackedScene = preload("res://src/vehicle/bus.tscn")


func after_test() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func test_network_remote_does_not_simulate_while_local_falls() -> void:
	var remote: CrewMember = _member(23, Vector3(5.0, 4.0, 0.0))
	var local: CrewMember = _member(1, Vector3(0.0, 4.0, 0.0))
	remote.velocity = Vector3(8.0, -3.0, 0.0)
	await _ticks(12)
	assert_int(remote.physics_simulation_ticks).is_equal(0)
	assert_vector(remote.position).is_equal(Vector3(5.0, 4.0, 0.0))
	assert_int(remote.collision_layer).is_equal(4)
	assert_int(local.physics_simulation_ticks).is_greater(0)
	assert_float(local.position.y).is_less(4.0)


func test_spawner_builds_named_crews_with_distinct_authorities_and_one_local_camera() -> void:
	var sync: NetCrewSync = _sync()
	sync.spawn_crews([23, 1])
	await _ticks(2)
	assert_int(sync.ready_count()).is_equal(2)
	var crews: Node = sync.get_parent().get_node("Crews")
	assert_int(crews.get_child_count()).is_equal(2)
	var remote: CrewMember = crews.get_node("Crew_23") as CrewMember
	var local: CrewMember = crews.get_node("Crew_1") as CrewMember
	assert_int(remote.get_multiplayer_authority()).is_equal(23)
	assert_int(local.get_multiplayer_authority()).is_equal(1)
	assert_bool(local.aboard).is_true()
	assert_bool(local.position.distance_to(remote.position) > 1.0).is_true()
	CameraArbiter.apply(get_tree(), CameraArbiter.Mode.ON_FOOT)
	assert_bool(NetAuthority.scoped_eye(local).current).is_true()
	assert_bool(NetAuthority.scoped_eye(remote).current).is_false()
	assert_int(_camera_count()).is_equal(1)


func test_remote_snapshots_interpolate_without_advancing_physics() -> void:
	var sync: NetCrewSync = _sync()
	sync.spawn_crews([1, 23])
	await _ticks(2)
	sync.set_physics_process(false)
	var remote: CrewMember = NetAuthority.crew_for_peer(get_tree(), 23)
	sync.accept_snapshot(23, Transform3D(Basis.IDENTITY, Vector3(4.0, 4.0, 0.0)), 0.0)
	sync.accept_snapshot(23, Transform3D(Basis.IDENTITY, Vector3(6.0, 4.0, 0.0)), 0.4)
	sync.advance(1.0 / 60.0)
	sync.advance(1.0 / 60.0)
	assert_float(remote.global_position.x).is_equal_approx(5.0, 0.001)
	assert_float(NetAuthority.scoped_eye(remote).rotation.x).is_equal_approx(0.2, 0.001)
	await _ticks(3)
	assert_int(remote.physics_simulation_ticks).is_equal(0)
	assert_int(sync.snapshots_received).is_equal(2)


func test_remote_hands_cannot_grab_and_bind_to_their_own_eye() -> void:
	var local: CrewMember = _member(1, Vector3.ZERO)
	var remote: CrewMember = _member(23, Vector3(5.0, 4.0, 0.0))
	await _ticks(2)
	var hands: CrewHands = remote.get_node("CrewHands") as CrewHands
	assert_object(hands.get("_crew")).is_same(remote)
	assert_object(hands.get("_eye")).is_same(NetAuthority.scoped_eye(remote))
	assert_bool(hands.try_grab()).is_false()
	assert_object((local.get_node("CrewHands") as CrewHands).held).is_null()


func test_client_replaces_authored_crew_and_activates_local_view_after_spawn() -> void:
	var packed: PackedScene = load("res://scenes/playground.tscn") as PackedScene
	var scene: Playground = auto_free(packed.instantiate())
	scene.network_role = "client"
	scene.cargo_spawn = false
	add_child(scene)
	assert_object(scene.get_node_or_null("CrewMember")).is_null()
	var sync: NetCrewSync = NetCrewSync.new()
	sync.name = "NetCrewSync"
	sync.bus = NetScenarioUtil.find_bus(scene) as Bus
	sync.network_enabled = false
	scene.add_child(sync)
	sync.spawn_crews([23, 1])
	await _ticks(3)
	await get_tree().process_frame
	var local: CrewMember = NetAuthority.local_crew(get_tree())
	assert_bool(NetAuthority.scoped_eye(local).current).is_true()
	assert_bool((scene.get_node("CrewInput") as CrewInput).enabled).is_true()
	assert_int(_camera_count()).is_equal(1)
	scene.set_network_player_mode(false)
	assert_bool((scene.get_node("CrewInput") as CrewInput).enabled).is_false()
	assert_int(_camera_count()).is_equal(1)


func _member(peer_id: int, at: Vector3) -> CrewMember:
	var member: CrewMember = auto_free(CREW_SCENE.instantiate())
	member.name = "Crew_%d" % peer_id
	member.position = at
	add_child(member)
	member.network_ready = true
	member.set_collision_disabled(false)
	return member


func test_interaction_hand_uses_source_bus_frame_while_ground_hand_stays_in_world() -> void:
	var sync: NetCrewSync = _sync()
	sync.spawn_crews([1, 23])
	await _ticks(2)
	var old_bus: Transform3D = sync.bus.global_transform
	var at: Transform3D = old_bus * Transform3D(Basis.IDENTITY, Vector3(0.0, -0.6, 0.0))
	sync.accept_interaction_frame(23, at, 0.0, old_bus)
	assert_bool(sync.has_interaction_hand(23)).is_true()
	var before: Vector3 = sync.interaction_hand_world(23).origin
	sync.bus.position.x += 18.5 * 0.1
	assert_vector(sync.interaction_hand_world(23).origin).is_equal_approx(before + Vector3(1.85, 0.0, 0.0), Vector3.ONE * 0.0001)
	at.origin.x += 20.0
	sync.accept_interaction_frame(23, at, 0.0, old_bus)
	before = sync.interaction_hand_world(23).origin
	sync.bus.position.x += 10.0
	assert_vector(sync.interaction_hand_world(23).origin).is_equal(before)
	sync.accept_interaction_frame(999, at, 0.0, old_bus)
	assert_bool(sync.has_interaction_hand(999)).is_false()


func _sync() -> NetCrewSync:
	var world: Node3D = auto_free(Node3D.new())
	add_child(world)
	var bus: Bus = BUS_SCENE.instantiate()
	bus.freeze = true
	bus.position.y = 1.0
	world.add_child(bus)
	var sync: NetCrewSync = NetCrewSync.new()
	sync.name = "NetCrewSync"
	sync.bus = bus
	sync.network_enabled = false
	world.add_child(sync)
	return sync


func _camera_count() -> int:
	var count: int = 0
	for group: String in ["eye_camera", "cabin_camera", "chase_camera"]:
		for node: Node in get_tree().get_nodes_in_group(group):
			if node is Camera3D:
				var camera: Camera3D = node
				if camera.current:
					count += 1
	return count


func _ticks(count: int) -> void:
	for index: int in range(count):
		await get_tree().physics_frame
