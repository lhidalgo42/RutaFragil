extends GdUnitTestSuite

## Requínoa town loop (D69): a closed route with alternating asphalt and dirt, a
## roundabout, the bridge over the Ruta 5 cutting, real level crossing and station,
## Plaza de Armas, vineyards, houses only inside the built-up land use and the
## delivery on the unpaved villa street. Plus: the route scene spawns at Entry and
## drives its first waypoints without rolling over.

const DATA: String = "res://data/b0_requinoa.json"
const ROUTE_SCENE: String = "res://scenes/route_requinoa.tscn"

var _rolled_over_count: int = 0


func test_closed_loop_alternates_asphalt_and_dirt() -> void:
	var data: OsmMapData = OsmMapData.load_from(DATA)
	assert_object(data).is_not_null()
	if data == null:
		return
	assert_float(data.length).is_greater(4500.0)
	var kinds: Array[String] = []
	for sec: Dictionary in data.sections:
		kinds.append(str(sec.get("type", "")))
	assert_array(kinds).contains(["street", "bridge", "gravel"])
	# at least three dirt stretches with asphalt in between (the user's "que no sea todo constante")
	var dirt_runs: int = 0
	for i: int in kinds.size():
		if kinds[i] == "gravel":
			dirt_runs += 1
	assert_int(dirt_runs).is_greater_equal(3)
	assert_int(data.gravel_zones.size()).is_greater_equal(2)
	# closed: the exit sits on the entry, and the last waypoint leads back to the first
	assert_float(data.entry.origin.distance_to(data.waypoints[0])).is_less(20.0)
	assert_float(data.waypoints[data.waypoints.size() - 1].distance_to(data.waypoints[0])).is_less(60.0)


func test_waypoint_chain_is_drivable() -> void:
	var data: OsmMapData = OsmMapData.load_from(DATA)
	if data == null:
		return
	var count: int = data.waypoints.size()
	assert_int(count).is_greater(150)
	var worst_turn: float = 0.0
	var shortest: float = INF
	for i: int in count:
		var a: Vector3 = data.waypoints[(i + count - 1) % count]
		var b: Vector3 = data.waypoints[i]
		var c: Vector3 = data.waypoints[(i + 1) % count]
		shortest = minf(shortest, a.distance_to(b))
		var in_dir: Vector2 = Vector2(b.x - a.x, b.z - a.z)
		var out_dir: Vector2 = Vector2(c.x - b.x, c.z - b.z)
		if in_dir.length() > 0.01 and out_dir.length() > 0.01:
			worst_turn = maxf(worst_turn, absf(rad_to_deg(in_dir.angle_to(out_dir))))
	# 9 m apart at least (reach radius is 9) and no hairpin: every corner is a brake pair
	assert_float(shortest).is_greater(8.9)
	assert_float(worst_turn).is_less(70.0)


func test_town_features_are_in_the_data() -> void:
	var data: OsmMapData = OsmMapData.load_from(DATA)
	if data == null:
		return
	assert_bool(data.roundabout.has("island_radius")).is_true()
	assert_int(data.bridges.size()).is_greater_equal(1)
	assert_float(float(data.trench.get("depth", 0.0))).is_greater(2.0)
	assert_int(data.motorway.size()).is_greater(0)
	assert_int(data.rail_lines.size()).is_greater(0)
	assert_int(data.crossings.size()).is_greater_equal(1)
	assert_str(str(data.rail_station.get("name", ""))).contains("Requ")
	assert_str(str(data.plaza.get("name", ""))).contains("Plaza")
	assert_int(data.churches.size()).is_greater_equal(1)
	assert_int(data.vine_rows.size()).is_greater(50)
	assert_int(data.orchards.size()).is_greater(100)
	assert_int(data.humps.size()).is_greater_equal(5)
	for h: Dictionary in data.humps:
		# every hump is rounded: the 15 cm flat one flips the placeholder at town speed
		assert_str(str(h.get("kind", ""))).is_equal("round")


func test_houses_cluster_in_town_and_the_delivery_is_off_the_asphalt() -> void:
	var data: OsmMapData = OsmMapData.load_from(DATA)
	if data == null:
		return
	var delivery: Dictionary = {}
	var styles: Dictionary = {}
	for b: Dictionary in data.buildings:
		styles[str(b.get("style", ""))] = true
		if bool(b.get("delivery", false)):
			delivery = b
	assert_bool(styles.has("adobe") and styles.has("poblacion") and styles.has("parcela")).is_true()
	assert_bool(delivery.is_empty()).is_false()
	assert_str(data.section_at(float(delivery.get("s", 0.0)))).is_equal("gravel")
	# no building's footprint intrudes on any pass of the corridor
	for b: Dictionary in data.buildings:
		if bool(b.get("collapsed", false)):
			continue
		var centre: Vector3 = Vector3(float(b.get("x", 0.0)), 0.0, float(b.get("z", 0.0)))
		var yaw: float = float(b.get("yaw", 0.0))
		var half: Vector2 = Vector2(float(b.get("w", 8.0)), float(b.get("d", 8.0))) * 0.5
		for sx: float in [-1.0, 1.0]:
			for sz: float in [-1.0, 1.0]:
				var corner: Vector3 = centre + Vector3(cos(yaw) * sx * half.x + sin(yaw) * sz * half.y, 0.0, -sin(yaw) * sx * half.x + cos(yaw) * sz * half.y)
				var pr: Vector2 = data.project(corner)
				assert_float(absf(pr.y)).override_failure_message("building at %s intrudes on the corridor" % corner).is_greater(data.property_at(pr.x) - 0.5)


func test_town_builder_draws_rail_plaza_and_vines() -> void:
	var town: OsmTown = auto_free(OsmTown.new())
	town.data_path = DATA
	add_child(town)
	assert_object(town.data).is_not_null()
	assert_int(town.batch_count("rail")).is_greater(50)
	assert_int(town.batch_count("sleeper")).is_greater(100)
	assert_int(town.batch_count("platform")).is_greater_equal(2)
	assert_int(town.batch_count("paving")).is_greater_equal(1)
	assert_int(town.batch_count("vine")).is_greater(50)
	assert_int(town.batch_count("motorway")).is_greater_equal(4)
	assert_int(town.batch_count("barrier_red")).is_greater_equal(2)


func test_road_opens_the_cutting_and_keeps_the_crossing_solid() -> void:
	var road: OsmRoad = auto_free(OsmRoad.new())
	road.data_path = DATA
	add_child(road)
	var data: OsmMapData = road.data
	assert_object(data).is_not_null()
	if data == null:
		return
	# seven ground slabs: the crossing band plus the four quadrants and the two cutting ends
	var ground: Node = road.get_node_or_null("Ground")
	assert_bool(ground is StaticBody3D).is_true()
	assert_int(ground.get_child_count()).is_equal(8)
	# the bridge deck itself carries no collision: the crossing band is the surface
	assert_object(road.get_node_or_null("Deck")).is_null()
	assert_int(road.batch_count("parapet")).is_greater_equal(4)
	assert_int(road.batch_count("island")).is_equal(1)


func test_route_spawns_at_entry_and_reaches_first_waypoints() -> void:
	var runner: GdUnitSceneRunner = scene_runner(ROUTE_SCENE)
	runner.set_time_factor(4.0)
	var scene: Node = runner.scene()
	assert_bool(scene is RouteGreybox).is_true()
	var segment_node: Node = scene.get_node_or_null("Segments/B0Requinoa")
	assert_bool(segment_node is BiomeSegment).is_true()
	for piece: String in ["Road", "Gravel", "Buildings", "Furniture", "Town", "Backdrop", "Circuit", "CityStation"]:
		assert_object(scene.get_node_or_null("Segments/B0Requinoa/" + piece)).override_failure_message("missing " + piece).is_not_null()
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
