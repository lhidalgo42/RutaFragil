extends GdUnitTestSuite

## Rancagua chained route (D68): sections, gravel and lots in the data; the
## gravel builder's zone and washboard; buildings by style with light damage;
## the route scene spawns at Entry and drives its first waypoints.

const DATA: String = "res://data/b0_rancagua.json"
const ROUTE_SCENE: String = "res://scenes/route_rancagua.tscn"

var _rolled_over_count: int = 0


func test_data_has_three_sections_and_gravel() -> void:
	var data: OsmMapData = OsmMapData.load_from(DATA)
	assert_object(data).is_not_null()
	if data == null:
		return
	var kinds: Array[String] = []
	for sec: Dictionary in data.sections:
		kinds.append(str(sec.get("type", "")))
	assert_array(kinds).contains(["avenue", "street", "gravel"])
	assert_int(data.gravel_zones.size()).is_greater_equal(1)
	var s_gravel: float = float(data.gravel_zones[0].get("s0", 0.0)) + 5.0
	assert_str(data.section_at(s_gravel)).is_equal("gravel")
	assert_bool(data.in_gravel(s_gravel)).is_true()
	assert_float(data.lane_at(s_gravel)).is_less(data.lane_offset)
	assert_int(data.lots.size()).is_greater_equal(4)
	assert_bool(bool(data.station.get("real", false))).is_true()


func test_gravel_builder_covers_the_unpaved_stretch() -> void:
	var gravel: OsmGravel = auto_free(OsmGravel.new())
	add_child(gravel)
	assert_object(gravel.data).is_not_null()
	assert_int(gravel.zone_shape_count()).is_greater(30)
	assert_int(gravel.washboard_shape_count()).is_greater(200)
	var pebbles: MultiMeshInstance3D = gravel.get_node("Batch_pebble") as MultiMeshInstance3D
	# D72: a propósito hay muchas menos piedras y más chicas — antes eran 1,1 por metro
	# cuadrado de 14 cm y el camino se leía como un suelo sembrado de piedrecillas. La
	# textura ahora la da el material; las piedras solo la acompañan.
	assert_int(pebbles.multimesh.instance_count).is_greater(400)
	# y la tierra ya no es una cadena de cajas de 10 m: es una cinta continua
	assert_object(gravel.get_node_or_null("Ribbon_dirt")).is_not_null()


func test_gravel_zone_reports_only_the_bus() -> void:
	var zone: GravelZone = auto_free(GravelZone.new())
	var shape_node: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(10.0, 4.0, 10.0)
	shape_node.shape = box
	zone.add_child(shape_node)
	add_child(zone)
	zone.global_position = Vector3(0.0, 2.0, 0.0)
	var emitter: Object = monitor_signals(zone)
	var body: RigidBody3D = auto_free(RigidBody3D.new())
	var body_shape: CollisionShape3D = CollisionShape3D.new()
	var small: BoxShape3D = BoxShape3D.new()
	small.size = Vector3.ONE
	body_shape.shape = small
	body.add_child(body_shape)
	body.add_to_group("bus")
	add_child(body)
	body.global_position = Vector3(0.0, 6.0, 0.0)
	await assert_signal(emitter).wait_until(5000).is_emitted("bus_entered", any())


func test_buildings_styles_damage_and_lots() -> void:
	var buildings: OsmBuildings = auto_free(OsmBuildings.new())
	buildings.data_path = DATA
	add_child(buildings)
	var data: OsmMapData = buildings.data
	var standing: int = 0
	var damaged: int = 0
	var collapsed: int = 0
	var styles: Dictionary = {}
	for b: Dictionary in data.buildings:
		if bool(b.get("collapsed", false)):
			collapsed += 1
		else:
			standing += 1
		if int(b.get("damage", 0)) > 0:
			damaged += 1
		styles[str(b.get("style", ""))] = true
	assert_int(buildings.facade_count()).is_equal(standing)
	assert_int(buildings.collision_count()).is_equal(standing)
	assert_int(collapsed).is_equal(2)
	assert_int(buildings.rubble_count()).is_equal(28)
	assert_float(float(damaged) / float(data.buildings.size())).is_between(0.12, 0.3)
	assert_bool(styles.has("adobe") and styles.has("poblacion") and styles.has("parcela")).is_true()
	assert_int(buildings.lot_count()).is_equal(data.lots.size())
	assert_bool(buildings.delivery_position() != Vector3.ZERO).is_true()


func test_route_spawns_at_entry_and_reaches_first_waypoints() -> void:
	var runner: GdUnitSceneRunner = scene_runner(ROUTE_SCENE)
	runner.set_time_factor(4.0)
	var scene: Node = runner.scene()
	assert_bool(scene is RouteGreybox).is_true()
	var segment_node: Node = scene.get_node_or_null("Segments/B0Rancagua")
	assert_bool(segment_node is BiomeSegment).is_true()
	for piece: String in ["Road", "Gravel", "Buildings", "Furniture", "Backdrop", "Circuit", "CityStation"]:
		assert_object(scene.get_node_or_null("Segments/B0Rancagua/" + piece)).override_failure_message("missing " + piece).is_not_null()
	var bus_node: Node = scene.get_node_or_null("PlaceholderBus")
	var driver_node: Node = scene.get_node_or_null("DemoDriver")
	if not (bus_node is PlaceholderBus) or not (driver_node is DemoDriver):
		assert_bool(false).override_failure_message("bus or driver missing").is_true()
		return
	var bus: PlaceholderBus = bus_node
	var driver: DemoDriver = driver_node
	if segment_node is BiomeSegment:
		var segment: BiomeSegment = segment_node
		assert_float(bus.global_position.distance_to(segment.entry_position())).is_less(1.0)
	_rolled_over_count = 0
	bus.rolled_over.connect(_on_rolled_over)
	for index: int in 6:
		await await_signal_on(driver, "waypoint_reached", [index], 25000)
	assert_int(driver.current_index).is_equal(6)
	assert_int(_rolled_over_count).is_equal(0)


func _on_rolled_over() -> void:
	_rolled_over_count += 1
