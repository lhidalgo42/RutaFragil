extends GdUnitTestSuite


func after_test() -> void:
	Input.action_release("walk_forward")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func test_local_lookup_skips_remote_first_and_resolves_each_peer_eye() -> void:
	var remote: CrewMember = _spawn_crew(23, Vector3(10.0, 0.0, 0.0))
	var local: CrewMember = _spawn_crew(1, Vector3.ZERO)
	assert_object(NetAuthority.local_crew(get_tree())).is_same(local)
	assert_object(NetAuthority.crew_for_peer(get_tree(), 23)).is_same(remote)
	assert_object(NetAuthority.crew_for_peer(get_tree(), 999)).is_null()
	assert_object(NetAuthority.scoped_eye(local)).is_same(local.get_node("EyeCamera"))
	assert_object(NetAuthority.scoped_eye(remote)).is_same(remote.get_node("EyeCamera"))
	assert_object(NetAuthority.scoped_eye(null)).is_null()


func test_input_created_before_spawn_moves_only_the_late_local_crew() -> void:
	var input: CrewInput = auto_free(CrewInput.new())
	input.enabled = true
	add_child(input)
	await _ticks(3)
	var remote: CrewMember = _spawn_crew(23, Vector3(10.0, 0.0, 0.0))
	await _ticks(3)
	var local: CrewMember = _spawn_crew(1, Vector3.ZERO)
	Input.action_press("walk_forward")
	await _ticks(20)
	Input.action_release("walk_forward")
	assert_float(local.position.z).is_less(-0.5)
	assert_float(remote.position.z).is_equal(0.0)


func test_null_network_peer_keeps_local_input_and_door_working() -> void:
	var saved_peer: MultiplayerPeer = multiplayer.multiplayer_peer
	multiplayer.multiplayer_peer = null
	var input: CrewInput = auto_free(CrewInput.new())
	input.enabled = true
	add_child(input)
	var transit: DoorTransit = auto_free(DoorTransit.new())
	add_child(transit)
	var bus: RigidBody3D = auto_free(RigidBody3D.new())
	bus.freeze = true
	bus.add_to_group("bus")
	add_child(bus)
	var remote: CrewMember = _spawn_crew(23, Vector3(10.0, 0.0, -1.75))
	var local: CrewMember = _spawn_crew(1, Vector3(0.0, 0.0, -1.75))
	await _ticks(3)
	var boarded: bool = local.aboard
	Input.action_press("walk_forward")
	await _ticks(20)
	Input.action_release("walk_forward")
	multiplayer.multiplayer_peer = saved_peer
	assert_bool(boarded).is_true()
	assert_bool(remote.aboard).is_false()
	assert_float(local.position.z).is_less(-2.25)
	assert_float(remote.position.z).is_equal(-1.75)


func test_mouse_look_and_hands_belong_to_local_crew_when_remote_is_first() -> void:
	var remote: CrewMember = _spawn_crew(23, Vector3(10.0, 0.0, 0.0))
	var local: CrewMember = _spawn_crew(1, Vector3.ZERO)
	var input: CrewInput = auto_free(CrewInput.new())
	input.enabled = true
	add_child(input)
	await _ticks(3)
	input.set_mouse_captured(true)
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.screen_relative = Vector2(40.0, 20.0)
	input._unhandled_input(motion)
	assert_float(local.rotation.y).is_not_equal(0.0)
	assert_float(NetAuthority.scoped_eye(local).rotation.x).is_not_equal(0.0)
	assert_float(remote.rotation.y).is_equal(0.0)
	assert_float(NetAuthority.scoped_eye(remote).rotation.x).is_equal(0.0)
	assert_object(input._hands_node()).is_same(local.get_node("CrewHands"))
	input.set_mouse_captured(false)


func test_door_transit_created_before_spawn_boards_only_late_local_crew() -> void:
	var transit: DoorTransit = auto_free(DoorTransit.new())
	add_child(transit)
	await _ticks(3)
	var bus: RigidBody3D = auto_free(RigidBody3D.new())
	bus.freeze = true
	bus.add_to_group("bus")
	add_child(bus)
	var remote: CrewMember = _spawn_crew(23, Vector3(0.0, 0.0, -1.75))
	remote.set_physics_process(false)
	await _ticks(3)
	var local: CrewMember = _spawn_crew(1, Vector3(0.0, 0.0, -1.75))
	local.set_physics_process(false)
	await _ticks(3)
	assert_bool(local.aboard).is_true()
	assert_bool(remote.aboard).is_false()
	local.position.x = 1.5
	await _ticks(3)
	assert_bool(local.aboard).is_false()


func test_package_joins_stable_identity_group_on_ready() -> void:
	var packed: PackedScene = load("res://src/cargo/package.tscn") as PackedScene
	var package: Package = auto_free(packed.instantiate())
	package.freeze = true
	add_child(package)
	assert_bool(package.is_in_group("package")).is_true()


func _spawn_crew(peer_id: int, at: Vector3) -> CrewMember:
	var crew: CrewMember = auto_free(CrewMember.new())
	crew.position = at
	var eye: Camera3D = Camera3D.new()
	eye.name = "EyeCamera"
	var hand: Marker3D = Marker3D.new()
	hand.name = "HandAnchor"
	eye.add_child(hand)
	crew.add_child(eye)
	var hands: CrewHands = CrewHands.new()
	hands.name = "CrewHands"
	crew.add_child(hands)
	crew.set_multiplayer_authority(peer_id)
	add_child(crew)
	return crew


func _ticks(count: int) -> void:
	for index: int in range(count):
		await get_tree().physics_frame
