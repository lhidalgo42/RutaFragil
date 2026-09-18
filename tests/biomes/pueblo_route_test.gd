extends GdUnitTestSuite

## Pueblo Quenlobo (D80): el pueblo DISEÑADO, no el extracto de OSM. Un anillo de avenida
## con esquinas redondeadas, avenida E–O y calle N–S rectas que salen por los cuatro
## bordes, cuadrícula de casas, plaza, iglesia, parque, dos vías de tren rectas, bencinera.
## Generado por tools/design_town.py; estas pruebas fijan lo que el diseño promete.

const DATA: String = "res://data/b0_pueblo.json"
const ROUTE_SCENE: String = "res://scenes/route_pueblo.tscn"

var _rolled_over_count: int = 0


func test_the_ring_is_a_closed_drivable_loop() -> void:
	var data: OsmMapData = OsmMapData.load_from(DATA)
	assert_object(data).is_not_null()
	if data == null:
		return
	# cerrado: el último punto del eje vuelve al primero
	assert_float(data.axis[0].distance_to(data.axis[data.axis.size() - 1])).is_less(1.0)
	assert_float(data.length).is_between(1900.0, 2200.0)
	assert_str(data.section_at(data.length * 0.5)).is_equal("avenue")
	var count: int = data.waypoints.size()
	assert_int(count).is_greater(100)
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
	assert_float(shortest).is_greater(8.9)
	assert_float(worst_turn).is_less(70.0)


func test_streets_are_straight_and_leave_by_the_four_edges() -> void:
	var data: OsmMapData = OsmMapData.load_from(DATA)
	if data == null:
		return
	# ninguna calle tiene curva: todas son dos puntos
	for item: Variant in data.streets:
		var street: Dictionary = item
		assert_int((street.get("pts", []) as Array).size()).override_failure_message("una calle del pueblo diseñado tiene curva").is_equal(2)
	var exits: Array[Dictionary] = data.exit_streets()
	assert_int(exits.size()).is_equal(4)
	var quadrants: Dictionary = {}
	var centre: Vector2 = data.axis_centre()
	for e: Dictionary in exits:
		var far: Vector3 = BiomeHints._far_end(e, Vector3(centre.x, 0.0, centre.y))
		quadrants[OsmMapData.exit_quadrant(Vector2(far.x - centre.x, far.z - centre.y))] = true
		# cada salida llega hasta 1500 m: lo demás lo pone BiomeHints
		assert_float(far.distance_to(Vector3(centre.x, 0.0, centre.y))).is_greater(1400.0)
	assert_int(quadrants.size()).is_equal(4)
	# ninguna calle se poda: todas tienen casas o son salida
	for item2: Variant in data.streets:
		var st: Dictionary = item2
		assert_bool(data.street_is_inhabited(st) or data.is_exit_street(st)).override_failure_message("la poda se llevó una calle del diseño").is_true()


func test_the_railway_is_two_straight_lines_crossing_at_the_station() -> void:
	var data: OsmMapData = OsmMapData.load_from(DATA)
	if data == null:
		return
	assert_int(data.rail_lines.size()).is_equal(2)
	for line: Variant in data.rail_lines:
		assert_int((line as Array).size()).is_equal(2)
	assert_int(data.crossings.size()).is_equal(4)
	var town: OsmTown = auto_free(OsmTown.new())
	town.data_path = DATA
	add_child(town)
	assert_int(town.batch_count("rail")).is_between(4, 14)
	assert_int(town.batch_count("sleeper")).is_greater(1000)
	assert_object(town.get_node_or_null("Slab_paving")).is_not_null()
	assert_int(town.batch_count("crown_core")).override_failure_message("las copas no tienen núcleo sólido").is_greater(0)


func test_houses_face_their_street_and_keep_off_the_ring() -> void:
	var data: OsmMapData = OsmMapData.load_from(DATA)
	if data == null:
		return
	assert_int(data.buildings.size()).is_greater(150)
	var delivery: int = 0
	for b: Dictionary in data.buildings:
		if bool(b.get("delivery", false)):
			delivery += 1
		var centre: Vector3 = Vector3(float(b.get("x", 0.0)), 0.0, float(b.get("z", 0.0)))
		var yaw: float = float(b.get("yaw", 0.0))
		var half: Vector2 = Vector2(float(b.get("w", 8.0)), float(b.get("d", 8.0))) * 0.5
		for sx: float in [-1.0, 1.0]:
			for sz: float in [-1.0, 1.0]:
				var corner: Vector3 = centre + Vector3(cos(yaw) * sx * half.x + sin(yaw) * sz * half.y, 0.0, -sin(yaw) * sx * half.x + cos(yaw) * sz * half.y)
				var pr: Vector2 = data.project(corner)
				assert_float(absf(pr.y)).override_failure_message("casa en %s invade el anillo" % corner).is_greater(data.property_at(pr.x) - 0.5)
	assert_int(delivery).is_equal(1)
	# la bencinera queda fuera de la calzada, en su lote
	var road: OsmRoad = auto_free(OsmRoad.new())
	road.data_path = DATA
	add_child(road)
	assert_int(road.batch_count("pump")).is_greater_equal(4)
	for p: Vector3 in road.positions_of("pump"):
		var pr2: Vector2 = data.project(p)
		assert_float(absf(pr2.y)).is_greater(data.curb_at(pr2.x) + 3.0)
	assert_int(road.field_tuft_count()).override_failure_message("sin pasto de campo").is_greater(20000)


func test_route_spawns_at_entry_and_reaches_first_waypoints() -> void:
	var runner: GdUnitSceneRunner = scene_runner(ROUTE_SCENE)
	runner.set_time_factor(4.0)
	var scene: Node = runner.scene()
	assert_bool(scene is RouteGreybox).is_true()
	var segment_node: Node = scene.get_node_or_null("Segments/B0Pueblo")
	assert_bool(segment_node is BiomeSegment).is_true()
	var bus_node: Node = scene.get_node_or_null("PlaceholderBus")
	var driver_node: Node = scene.get_node_or_null("DemoDriver")
	if not (bus_node is PlaceholderBus) or not (driver_node is DemoDriver):
		assert_bool(false).override_failure_message("bus or driver missing").is_true()
		return
	var bus: PlaceholderBus = bus_node
	var driver: DemoDriver = driver_node
	_rolled_over_count = 0
	bus.rolled_over.connect(_on_rolled_over)
	for index: int in 6:
		await await_signal_on(driver, "waypoint_reached", [index], 25000)
	assert_int(driver.current_index).is_equal(6)
	assert_int(_rolled_over_count).is_equal(0)


func _on_rolled_over() -> void:
	_rolled_over_count += 1
