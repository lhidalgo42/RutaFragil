extends GdUnitTestSuite

## B0 city greybox through the route scene: structure checks, then a demo
## drive that reaches waypoint 6 (station detour and speed bump behind it)
## without rolled_over. Same shape as playground_scene_test: time factor 4,
## signal waits with explicit timeouts, never process-frame counts.

const ROUTE_SCENE: String = "res://scenes/route_mvp.tscn"
const B0_WAYPOINTS: int = 30

var _rolled_over_count: int = 0


func test_scene_structure() -> void:
	var runner: GdUnitSceneRunner = scene_runner(ROUTE_SCENE)
	var scene: Node = runner.scene()
	assert_bool(scene is RouteGreybox).is_true()
	var segment_node: Node = scene.get_node_or_null("Segments/B0City")
	assert_bool(segment_node is BiomeSegment).is_true()
	if segment_node is BiomeSegment:
		var segment: BiomeSegment = segment_node
		assert_str(segment.biome_id).is_equal("b0_city")
		assert_object(segment.circuit()).is_not_null()
	var route_node: Node = scene.get_node_or_null("RouteCircuit")
	assert_bool(route_node is RouteCircuit).is_true()
	if route_node is RouteCircuit:
		var route: RouteCircuit = route_node
		assert_int(route.waypoint_count()).is_equal(B0_WAYPOINTS)
	var driver_node: Node = scene.get_node_or_null("DemoDriver")
	assert_bool(driver_node is DemoDriver).is_true()
	if driver_node is DemoDriver:
		var driver: DemoDriver = driver_node
		assert_bool(driver.enabled).is_true()
		assert_object(driver.bus).is_not_null()
		assert_object(driver.circuit).is_not_null()
	var bus_node: Node = scene.get_node_or_null("PlaceholderBus")
	assert_bool(bus_node is PlaceholderBus).is_true()
	if bus_node is PlaceholderBus and segment_node is BiomeSegment:
		var bus: PlaceholderBus = bus_node
		var segment: BiomeSegment = segment_node
		assert_bool(bus.is_in_group("bus")).is_true()
		assert_float(bus.global_position.distance_to(segment.entry_position())).is_less(1.0)
	var camera_node: Node = scene.get_node_or_null("ChaseCamera")
	assert_bool(camera_node is ChaseCamera).is_true()


func test_demo_passes_station_and_speed_bump_without_rolling_over() -> void:
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
	for index: int in 7:
		await await_signal_on(driver, "waypoint_reached", [index], 20000)
	assert_int(driver.current_index).is_equal(7)
	assert_int(_rolled_over_count).is_equal(0)


func _on_rolled_over() -> void:
	_rolled_over_count += 1
