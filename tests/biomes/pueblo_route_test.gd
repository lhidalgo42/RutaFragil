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
	assert_float(data.length).is_between(1500.0, 2200.0)
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
	# D81: la red interior es irregular a propósito, pero las dos calles principales y las
	# cuatro salidas siguen rectas: son las que llevan a los otros biomas
	var exits: Array[Dictionary] = data.exit_streets()
	for e: Dictionary in exits:
		assert_int((e.get("pts", []) as Array).size()).override_failure_message("una salida tiene curva").is_equal(2)
	assert_int(exits.size()).is_equal(4)
	var quadrants: Dictionary = {}
	var centre: Vector2 = data.axis_centre()
	for e: Dictionary in exits:
		var far: Vector3 = BiomeHints._far_end(e, Vector3(centre.x, 0.0, centre.y))
		quadrants[OsmMapData.exit_quadrant(Vector2(far.x - centre.x, far.z - centre.y))] = true
		# cada salida llega hasta 1500 m: lo demás lo pone BiomeHints
		assert_float(far.distance_to(Vector3(centre.x, 0.0, centre.y))).is_greater(1400.0)
	assert_int(quadrants.size()).is_equal(4)
	# ninguna calle se poda: todas tienen casas, son salida o son el camino de tierra del fundo
	for item2: Variant in data.streets:
		var st: Dictionary = item2
		var kept: bool = data.street_is_inhabited(st) or data.is_exit_street(st) or str(st.get("surface", "")) == "gravel"
		assert_bool(kept).override_failure_message("la poda se llevó una calle del diseño").is_true()
		assert_int(data.inhabited_span(st).size()).override_failure_message("una calle quedó sin puntos tras la poda").is_greater_equal(2)


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
	# D81/D82: en el pueblo de palmeras la plaza lleva palmeras, el modelo real de Quaternius
	assert_str(data.street_trees).is_equal("palm")
	assert_int(town.batch_count("palm")).override_failure_message("la plaza no tiene palmeras").is_greater(0)
	var palm_batch: MultiMeshInstance3D = town.find_child("Batch_palm", true, false)
	assert_object(palm_batch).is_not_null()
	if palm_batch != null:
		assert_int(palm_batch.multimesh.mesh.get_surface_count()).override_failure_message("el modelo de palmera no cargó").is_greater_equal(2)
		assert_float(palm_batch.multimesh.mesh.get_aabb().size.y).is_between(0.98, 1.02)


## Bosque alrededor del pueblo (D81): lo rojo de la foto del dueño. Pinos gigantes densos,
## en losas que la cámara puede descartar, sin pisar ninguna calzada ni el fundo.
func test_the_forest_surrounds_the_town_with_giant_pines() -> void:
	var data: OsmMapData = OsmMapData.load_from(DATA)
	if data == null:
		return
	assert_int(data.forests.size()).is_greater_equal(4)
	var forest: OsmForest = auto_free(OsmForest.new())
	forest.data_path = DATA
	forest.density = 0.5   # la mitad, para que la prueba corra en segundos
	forest.progressive = false
	add_child(forest)
	assert_int(forest.pending_tiles()).is_equal(0)
	assert_int(forest.pine_count()).override_failure_message("el bosque quedó vacío").is_greater(3000)
	assert_int(forest.tile_count()).override_failure_message("el bosque no está en losas").is_greater(10)
	# D82: cada losa lleva el pino de cerca (modelo de Quaternius, con sombra, hasta el cambio
	# de detalle) y el de lejos (Kenney, sin sombra, desde el cambio), en el mismo lote
	var checked: int = 0
	for tile: Node in forest.get_children():
		var near: MultiMeshInstance3D = tile.get_node_or_null("Batch_pine")
		var far: MultiMeshInstance3D = tile.get_node_or_null("Batch_pine_far")
		if near == null:
			continue
		assert_object(far).is_not_null()
		if far == null:
			continue
		assert_int(near.multimesh.instance_count).is_equal(far.multimesh.instance_count)
		assert_float(near.visibility_range_end).is_equal(MeshBatcher.LOD_SWITCH_M)
		assert_float(far.visibility_range_begin).is_equal(MeshBatcher.LOD_SWITCH_M)
		assert_int(far.cast_shadow).is_equal(GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
		assert_int(near.multimesh.mesh.get_surface_count()).override_failure_message("el modelo de pino no cargó").is_greater_equal(2)
		checked += 1
		if checked > 6:
			break
	assert_int(checked).is_greater(0)
	# la orla: cerca del borde del polígono hay menos árboles que adentro (el bosque se deshace)
	var mask: RoadMask = RoadMask.shared(data, DATA)
	assert_object(mask).is_not_null()
	assert_object(MeshBatcher.canopy_texture()).override_failure_message("el bosque no dejó sombra en el suelo").is_not_null()
	# las palmeras del pueblo están en los datos, no en el bosque
	var palms: int = 0
	for t: Dictionary in data.trees:
		if str(t.get("kind", "")) == "palm":
			palms += 1
	assert_int(palms).is_greater(300)
	# la estación está en el recinto del centro-sur (el rectángulo celeste), en la vía N–S
	assert_float(float(data.rail_station.get("x", 0.0))).is_between(60.0, 100.0)
	assert_float(float(data.rail_station.get("z", 0.0))).is_between(30.0, 70.0)


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
	# D82: el marcador Entry de la escena tiene que ser la entrada de los datos. En D81 quedó
	# el de D80 y el camión nacía en un potrero a 200 m de la avenida, sin llegar a ningún waypoint.
	var data: OsmMapData = OsmMapData.load_from(DATA)
	if segment_node is BiomeSegment and data != null:
		var marker: Vector3 = (segment_node as BiomeSegment).entry_transform().origin
		assert_float(Vector2(marker.x, marker.z).distance_to(Vector2(data.entry.origin.x, data.entry.origin.z))).override_failure_message("el marcador Entry de la escena no es la entrada de los datos").is_less(1.0)
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
