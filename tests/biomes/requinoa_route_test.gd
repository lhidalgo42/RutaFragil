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
	# La red de calles del pueblo: el recorrido no puede ser un listón suelto (ronda 7)
	assert_int(data.streets.size()).is_greater(100)
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
	# D79: dos vías RECTAS de punta a punta (N–S y E–O por la estación), de bioma a bioma.
	# Cada vía son dos rieles enteros → 4, más los del cruce a nivel. Antes eran cientos de
	# tramos siguiendo la curva de OSM; si vuelven, esto falla.
	assert_int(town.batch_count("rail")).is_between(4, 12)
	assert_int(town.batch_count("sleeper")).is_greater(1000)
	var rail_origins: PackedVector3Array = town.positions_of("rail")
	var station: Vector3 = Vector3(float(town.data.rail_station.get("x", 0.0)), 0.0, float(town.data.rail_station.get("z", 0.0)))
	var long_ns: int = 0
	for o: Vector3 in rail_origins:
		# los rieles de vía están centrados en la estación (between() centra la caja)
		if o.distance_to(Vector3(station.x, o.y, station.z)) < 2.0:
			long_ns += 1
	assert_int(long_ns).override_failure_message("las vías no pasan por la estación en línea recta").is_greater_equal(4)
	assert_int(town.batch_count("platform")).is_greater_equal(2)
	# D79: el pavimento de la plaza es una losa con la forma del polígono, no una caja
	assert_object(town.get_node_or_null("Slab_paving")).override_failure_message("falta la losa de la plaza").is_not_null()
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
	# D76: la bencinera la arma OsmRoad en un lote junto a la ruta, retirada del cordón
	assert_int(road.batch_count("canopy")).is_greater_equal(1)
	assert_int(road.batch_count("pump")).is_greater_equal(4)
	for p: Vector3 in road.positions_of("pump"):
		var pr: Vector2 = data.project(p)
		assert_float(absf(pr.y)).override_failure_message("un surtidor cayó sobre la calzada en %s" % p).is_greater(data.curb_at(pr.x) + 3.0)


func test_route_spawns_at_entry_and_reaches_first_waypoints() -> void:
	var runner: GdUnitSceneRunner = scene_runner(ROUTE_SCENE)
	runner.set_time_factor(4.0)
	var scene: Node = runner.scene()
	assert_bool(scene is RouteGreybox).is_true()
	var segment_node: Node = scene.get_node_or_null("Segments/B0Requinoa")
	assert_bool(segment_node is BiomeSegment).is_true()
	# D76: la escena CityStation de la ronda 1 salió del pueblo; la bencinera la arma OsmRoad
	# en un lote junto a la ruta (_build_station_lot), así que ya no es un nodo aparte.
	for piece: String in ["Road", "Gravel", "Buildings", "Furniture", "Town", "Backdrop", "Circuit"]:
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


## Poda y salidas (D78): las calles de campo sin casas no se dibujan, quedan cuatro salidas
## —una por cuadrante— y al final de tres de ellas hay una silueta de bioma (la cordillera
## del este ya la pone CityBackdrop).
func test_streets_without_houses_are_pruned_and_four_exits_remain() -> void:
	var data: OsmMapData = OsmMapData.load_from(DATA)
	if data == null:
		return
	var kept: int = 0
	for item: Variant in data.streets:
		if item is Dictionary and data.street_is_inhabited(item):
			kept += 1
	assert_int(kept).override_failure_message("la poda dejó demasiado poco pueblo").is_greater(20)
	assert_int(kept).override_failure_message("la poda no quitó nada").is_less(data.streets.size() * 3 / 4)
	var exits: Array[Dictionary] = data.exit_streets()
	assert_int(exits.size()).is_equal(4)
	var centre: Vector2 = data.axis_centre()
	var quadrants: Dictionary = {}
	for e: Dictionary in exits:
		var far: Vector3 = BiomeHints._far_end(e, Vector3(centre.x, 0.0, centre.y))
		quadrants[OsmMapData.exit_quadrant(Vector2(far.x - centre.x, far.z - centre.y))] = true
		assert_bool(data.is_exit_street(e)).is_true()
	assert_int(quadrants.size()).override_failure_message("las salidas no cubren los cuatro cuadrantes").is_equal(4)
	var hints: BiomeHints = auto_free(BiomeHints.new())
	hints.data_path = DATA
	add_child(hints)
	assert_int(hints.batch_count("dune")).is_greater(3)
	assert_int(hints.batch_count("dead_trunk")).is_greater(50)
	assert_int(hints.batch_count("sea")).is_equal(1)
	assert_object(hints.get_node_or_null("Ribbon_street")).override_failure_message("las salidas no se prolongan").is_not_null()


func _on_rolled_over() -> void:
	_rolled_over_count += 1
