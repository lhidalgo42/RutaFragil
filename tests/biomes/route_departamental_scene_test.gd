extends GdUnitTestSuite

## Real-avenue route (D65): structure, bus spawned at the segment Entry, and a
## demo drive through the station detour (waypoints 0..9) without rolled_over.

const ROUTE_SCENE: String = "res://scenes/route_departamental.tscn"

var _rolled_over_count: int = 0


func test_scene_structure_and_spawn() -> void:
	var runner: GdUnitSceneRunner = scene_runner(ROUTE_SCENE)
	var scene: Node = runner.scene()
	assert_bool(scene is RouteGreybox).is_true()
	var segment_node: Node = scene.get_node_or_null("Segments/B0Departamental")
	assert_bool(segment_node is BiomeSegment).is_true()
	var route_node: Node = scene.get_node_or_null("RouteCircuit")
	assert_bool(route_node is RouteCircuit).is_true()
	if route_node is RouteCircuit:
		var route: RouteCircuit = route_node
		assert_int(route.waypoint_count()).is_greater_equal(60)
	for piece: String in ["Road", "Buildings", "Circuit", "CityStation", "CityFuelBranch"]:
		assert_object(scene.get_node_or_null("Segments/B0Departamental/" + piece)).override_failure_message("missing " + piece).is_not_null()
	var bus_node: Node = scene.get_node_or_null("PlaceholderBus")
	assert_bool(bus_node is PlaceholderBus).is_true()
	if bus_node is PlaceholderBus and segment_node is BiomeSegment:
		var bus: PlaceholderBus = bus_node
		var segment: BiomeSegment = segment_node
		assert_float(bus.global_position.distance_to(segment.entry_position())).is_less(1.0)
		var forward: Vector3 = bus.forward()
		var entry_forward: Vector3 = -segment.entry_transform().basis.z
		assert_float(forward.dot(entry_forward)).is_greater(0.99)


func test_demo_passes_the_station_without_rolling_over() -> void:
	var runner: GdUnitSceneRunner = scene_runner(ROUTE_SCENE)
	runner.set_time_factor(4.0)
	var scene: Node = runner.scene()
	var bus_node: Node = scene.get_node_or_null("PlaceholderBus")
	var driver_node: Node = scene.get_node_or_null("DemoDriver")
	assert_bool(bus_node is PlaceholderBus).is_true()
	assert_bool(driver_node is DemoDriver).is_true()
	if not (bus_node is PlaceholderBus) or not (driver_node is DemoDriver):
		return
	var bus: PlaceholderBus = bus_node
	var driver: DemoDriver = driver_node
	_rolled_over_count = 0
	bus.rolled_over.connect(_on_rolled_over)
	for index: int in 10:
		await await_signal_on(driver, "waypoint_reached", [index], 25000)
	assert_int(driver.current_index).is_equal(10)
	assert_int(_rolled_over_count).is_equal(0)


func _on_rolled_over() -> void:
	_rolled_over_count += 1
