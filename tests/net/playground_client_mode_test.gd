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
		get_tree().root.add_child(scene)
		return scene
	assert_bool(false).override_failure_message("playground.tscn did not load").is_true()
	return null


func test_client_role_disables_demo_and_freezes_bus() -> void:
	var scene: Node = _instantiate("client")
	if scene == null:
		return
	assert_bool(scene.get("demo_mode")).is_false()
	var driver: Node = scene.get_node("DemoDriver")
	assert_bool(driver.get("enabled")).is_false()
	var bus_node: Node = scene.get_node("PlaceholderBus")
	if bus_node is RigidBody3D:
		var bus: RigidBody3D = bus_node
		assert_bool(bus.freeze).is_true()
	scene.queue_free()


func test_single_role_keeps_demo_running() -> void:
	var scene: Node = _instantiate("single")
	if scene == null:
		return
	assert_bool(scene.get("demo_mode")).is_true()
	var driver: Node = scene.get_node("DemoDriver")
	assert_bool(driver.get("enabled")).is_true()
	var bus_node: Node = scene.get_node("PlaceholderBus")
	if bus_node is RigidBody3D:
		var bus: RigidBody3D = bus_node
		assert_bool(bus.freeze).is_false()
	scene.queue_free()
