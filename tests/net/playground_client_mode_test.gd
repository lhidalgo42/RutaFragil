extends GdUnitTestSuite

## Playground network_role (D55, plan M0-T0.4 step 3): "client" disables the
## demo and freezes the bus so local physics never fights the host's
## MultiplayerSynchronizer; the default "single" keeps T0.3 behavior intact.


func _instantiate(role: String) -> Node:
	var packed: Resource = load("res://scenes/playground.tscn")
	if packed is PackedScene:
		var packed_scene: PackedScene = packed
		var scene: Node = packed_scene.instantiate()
		scene.set("network_role", role)
		scene.set("cargo_spawn", false)
		get_tree().root.add_child(scene)
		return scene
	assert_bool(false).override_failure_message("playground.tscn did not load").is_true()
	return null


func _bus_in(scene: Node) -> Node:
	for member: Node in scene.get_tree().get_nodes_in_group("bus"):
		if scene.is_ancestor_of(member):
			return member
	return null


func test_client_role_disables_demo_and_freezes_bus() -> void:
	var scene: Node = _instantiate("client")
	if scene == null:
		return
	assert_bool(scene.get("demo_mode")).is_false()
	var driver: Node = scene.get_node("DemoDriver")
	assert_bool(driver.get("enabled")).is_false()
	# Scope the group lookup to THIS scene: a sibling scene's bus (queued for
	# deletion by the previous test but not yet freed) is also in the group.
	var bus_node: Node = _bus_in(scene)
	if bus_node is RigidBody3D:
		var bus: RigidBody3D = bus_node
		assert_bool(bus.freeze).is_true()
		assert_int(bus.freeze_mode).is_equal(RigidBody3D.FREEZE_MODE_KINEMATIC)
	scene.queue_free()
	await get_tree().physics_frame


func test_single_role_keeps_demo_running() -> void:
	# Since M1-T1.1 the authored default is demo_mode=false: "single" hands
	# the bus to the owner via BusInput (F5 is the driving gate), the demo
	# driver stays off and the bus is never frozen.
	var scene: Node = _instantiate("single")
	if scene == null:
		return
	assert_bool(scene.get("demo_mode")).is_false()
	var driver: Node = scene.get_node("DemoDriver")
	assert_bool(driver.get("enabled")).is_false()
	# Since M2-T2.2 the owner's F5 is ON FOOT: the crew input is enabled and
	# the bus input stays off until the Seat (D76) is occupied.
	var input_node: Node = scene.get_node("BusInput")
	assert_bool(input_node.get("enabled")).is_false()
	var crew_input: Node = scene.get_node("CrewInput")
	assert_bool(crew_input.get("enabled")).is_true()
	var bus_node: Node = _bus_in(scene)
	if bus_node is RigidBody3D:
		var bus: RigidBody3D = bus_node
		assert_bool(bus.freeze).is_false()
	scene.queue_free()
	await get_tree().physics_frame
