extends GdUnitTestSuite

## Playground scene (D50/D51): structure checks plus a short demo drive on the
## real scene — three waypoints reached on a clock budget and no rolled_over.
## set_time_factor(4.0) multiplies the physics rate without changing the step
## (plan §3); every wait is signal-based with an explicit timeout, never a
## process-frame count.

var _rolled_over_count: int = 0


func test_scene_structure() -> void:
	var runner: GdUnitSceneRunner = scene_runner("res://scenes/playground.tscn")
	var scene: Node = runner.scene()
	assert_bool(scene is Playground).is_true()
	var circuit_node: Node = scene.get_node_or_null("Circuit")
	assert_bool(circuit_node is Circuit).is_true()
	if circuit_node is Circuit:
		var circuit: Circuit = circuit_node
		assert_int(circuit.waypoint_count()).is_greater_equal(8)
	var water_node: Node = scene.get_node_or_null("WaterZone")
	assert_bool(water_node is WaterZone).is_true()
	var driver_node: Node = scene.get_node_or_null("DemoDriver")
	assert_bool(driver_node is DemoDriver).is_true()
	if driver_node is DemoDriver:
		var driver: DemoDriver = driver_node
		# The authored default is demo_mode=false (M1-T1.1: F5 is the owner's
		# driving seat); the demo test below enables it explicitly.
		assert_bool(driver.enabled).is_false()
		assert_object(driver.circuit).is_not_null()
	# The bus is found by group, never by node name (D59).
	var bus_node: Node = scene.get_tree().get_first_node_in_group("bus")
	assert_bool(bus_node is Bus).is_true()
	if bus_node != null:
		assert_bool(bus_node.is_in_group("bus")).is_true()
	var camera_node: Node = scene.get_node_or_null("ChaseCamera")
	assert_bool(camera_node is ChaseCamera).is_true()
	if camera_node is ChaseCamera:
		var camera: ChaseCamera = camera_node
		assert_bool(camera.current).is_true()
		assert_object(camera.target).is_not_null()


func test_demo_reaches_three_waypoints_without_rolling_over() -> void:
	var runner: GdUnitSceneRunner = scene_runner("res://scenes/playground.tscn")
	runner.set_time_factor(4.0)
	var scene: Node = runner.scene()
	# demo_mode is enabled explicitly: the authored default is false (M1-T1.1).
	# The DemoDriver and BusInput never drive at once (BusInput would write
	# set_drive(0,0,0) over the driver's commands every tick).
	scene.set("demo_mode", true)
	scene.get_node("DemoDriver").set("enabled", true)
	scene.get_node("BusInput").set("enabled", false)
	var bus_node: Node = scene.get_tree().get_first_node_in_group("bus")
	var driver_node: Node = scene.get_node_or_null("DemoDriver")
	assert_bool(bus_node is Bus).is_true()
	assert_bool(driver_node is DemoDriver).is_true()
	if not (bus_node is Bus) or not (driver_node is DemoDriver):
		return
	var bus: Bus = bus_node
	var driver: DemoDriver = driver_node
	_rolled_over_count = 0
	bus.rolled_over.connect(_on_rolled_over)
	await await_signal_on(driver, "waypoint_reached", [0], 15000)
	await await_signal_on(driver, "waypoint_reached", [1], 15000)
	await await_signal_on(driver, "waypoint_reached", [2], 15000)
	assert_int(driver.current_index).is_equal(3)
	assert_int(_rolled_over_count).is_equal(0)


func _on_rolled_over() -> void:
	_rolled_over_count += 1
