extends GdUnitTestSuite

## Bioma B2 Pantano (D71): el humedal del río Cruces. La ruta A->B por la Ruta T-360
## y Pasaje Los Esteros, con asfalto, ripio, barro, el puente real, el vado del río
## San Ramón, la pasarela de tablas y el muelle de la entrega. Y la regla que hace que
## el pantano se vea sin cortes: el agua es una malla sobre el suelo, a un solo nivel.

const DATA: String = "res://data/b2_pantano.json"
const ROUTE_SCENE: String = "res://scenes/route_pantano.tscn"


func test_la_ruta_alterna_asfalto_ripio_y_barro() -> void:
	var data: OsmMapData = OsmMapData.load_from(DATA)
	assert_object(data).is_not_null()
	if data == null:
		return
	assert_float(data.length).is_greater(5500.0)
	var metros: Dictionary = {}
	for sec: Dictionary in data.sections:
		var k: String = str(sec.get("type", ""))
		metros[k] = float(metros.get(k, 0.0)) + float(sec.get("s1", 0.0)) - float(sec.get("s0", 0.0))
	for tipo: String in ["street", "gravel", "mud", "bridge", "ford", "causeway"]:
		assert_bool(metros.has(tipo)).override_failure_message("falta el tipo de tramo '%s'" % tipo).is_true()
	assert_float(float(metros.get("mud", 0.0))).override_failure_message("el barro tiene que ser la marca del bioma").is_greater(1200.0)
	assert_bool(bool(data.swamp.get("water_y", -1.0)) if false else float(data.swamp.get("water_y", -1.0)) > 0.0) \
		.override_failure_message("el agua va SOBRE el suelo: bajo el suelo queda escondida en la caja del terreno").is_true()


func test_el_pantano_tiene_sus_piezas() -> void:
	var data: OsmMapData = OsmMapData.load_from(DATA)
	if data == null:
		return
	var swamp: Dictionary = data.swamp
	var cuerpos: Array = swamp.get("bodies", [])
	var inundadas: int = 0
	for item: Variant in cuerpos:
		if item is Dictionary and str((item as Dictionary).get("kind", "")) == "flood":
			inundadas += 1
	assert_int(cuerpos.size()).is_greater(50)
	assert_int(inundadas).override_failure_message("sin orilla inundada el pantano no se ve desde el camino").is_greater(8)
	assert_int((swamp.get("marsh", []) as Array).size()).is_greater(5000)
	assert_int((swamp.get("snags", []) as Array).size()).is_greater(100)
	assert_int((swamp.get("hualve", []) as Array).size()).is_greater(1500)
	assert_int((swamp.get("fords", []) as Array).size()).is_greater_equal(1)
	assert_int((swamp.get("lianas", []) as Array).size()).is_greater_equal(3)
	assert_bool((swamp.get("causeway", {}) as Dictionary).is_empty()).is_false()
	assert_bool((swamp.get("pier", {}) as Dictionary).is_empty()).is_false()
	var entrega: int = 0
	for b: Dictionary in data.buildings:
		if bool(b.get("delivery", false)):
			entrega += 1
	assert_int(entrega).override_failure_message("tiene que haber una entrega").is_equal(1)


func test_nada_con_colision_invade_el_corredor() -> void:
	# La lección del pueblo (D69): una cara vertical en la pista atasca al camión.
	var data: OsmMapData = OsmMapData.load_from(DATA)
	if data == null:
		return
	for b: Dictionary in data.buildings:
		var centre: Vector3 = Vector3(float(b.get("x", 0.0)), 0.0, float(b.get("z", 0.0)))
		var yaw: float = float(b.get("yaw", 0.0))
		var half: Vector2 = Vector2(float(b.get("w", 6.0)), float(b.get("d", 6.0))) * 0.5
		for sx: float in [-1.0, 1.0]:
			for sz: float in [-1.0, 1.0]:
				var corner: Vector3 = centre + Vector3(cos(yaw) * sx * half.x + sin(yaw) * sz * half.y, 0.0, -sin(yaw) * sx * half.x + cos(yaw) * sz * half.y)
				var pr: Vector2 = data.project(corner)
				assert_float(absf(pr.y)).override_failure_message("un edificio invade la huella en %s" % corner).is_greater(data.property_at(pr.x) - 0.5)


func test_el_agua_se_construye_en_una_sola_cota() -> void:
	var water: SwampWater = auto_free(SwampWater.new())
	water.data_path = DATA
	add_child(water)
	assert_object(water.data).is_not_null()
	# Menos superficies que paños: los que se pisaban se fundieron en uno para que la
	# juntura no se oscurezca. Siguen siendo varias, y todas a la misma cota.
	var panos: int = int(water.data.swamp.get("bodies", []).size())
	assert_int(water.water_surface_count()).override_failure_message("no se trianguló el agua").is_greater(8)
	assert_int(water.water_surface_count()).override_failure_message("no se fundió ningún paño solapado").is_less(panos)
	var root: Node = water.get_node_or_null("Water")
	var y: float = INF
	for child: Node in root.get_children():
		if child is MeshInstance3D:
			var inst: MeshInstance3D = child
			if y == INF:
				y = inst.position.y
			assert_float(inst.position.y).override_failure_message("dos paños a distinta altura dejan costura visible").is_equal_approx(y, 0.001)
	assert_int(water.batch_count("reed")).is_greater(3000)
	assert_int(water.batch_count("snag")).is_greater(50)
	assert_int(water.batch_count("crown")).is_greater(1000)


func test_el_barro_avisa_y_la_pasarela_es_una_sola_caja() -> void:
	var road: SwampRoad = auto_free(SwampRoad.new())
	road.data_path = DATA
	add_child(road)
	assert_object(road.data).is_not_null()
	assert_int(road.zone_shape_count()).override_failure_message("el barro tiene que avisarle al camión").is_greater(50)
	var causeway: Node = road.get_node_or_null("Causeway")
	assert_object(causeway).is_not_null()
	if causeway != null:
		var formas: int = 0
		for child: Node in causeway.get_children():
			if child is CollisionShape3D:
				formas += 1
		assert_int(formas).override_failure_message("la pasarela va con UNA caja: dos dejan junta y el bus tropieza").is_equal(1)
	assert_int(road.batch_count("plank")).is_greater(50)
	assert_int(road.batch_count("mud")).is_greater(200)
	assert_int(road.batch_count("liana")).is_greater(20)


func test_la_escena_arranca_y_el_bus_recorre_los_primeros_puntos() -> void:
	var runner: GdUnitSceneRunner = scene_runner(ROUTE_SCENE)
	runner.set_time_factor(4.0)
	var scene: Node = runner.scene()
	assert_bool(scene is RouteGreybox).is_true()
	var segment: Node = scene.get_node_or_null("Segments/B2Pantano")
	assert_bool(segment is BiomeSegment).is_true()
	for pieza: String in ["Road", "Gravel", "SwampWater", "SwampRoad", "Buildings", "Circuit"]:
		assert_object(scene.get_node_or_null("Segments/B2Pantano/" + pieza)).override_failure_message("falta " + pieza).is_not_null()
	var driver: Node = scene.get_node_or_null("DemoDriver")
	for index: int in 5:
		await await_signal_on(driver, "waypoint_reached", [index], 25000)
	assert_int(int(driver.get("current_index"))).is_equal(5)


## El agua sobre la calzada solo se acepta donde es a propósito: bajo el puente, en el
## vado y al pie del muelle. En cualquier otra parte era un paño de OSM dibujado encima
## del camino, que es exactamente el "corte" que este bioma no puede tener.
func test_el_agua_no_pisa_la_calzada() -> void:
	var data: OsmMapData = OsmMapData.load_from(DATA)
	if data == null:
		return
	# Donde el agua SÍ toca la calzada a propósito: bajo el puente, en el vado, en la
	# pasarela (la pasarela existe porque el suelo está inundado) y al pie del muelle.
	var permitido: Array[Vector2] = []
	for sec: Dictionary in data.sections:
		if str(sec.get("type", "")) in ["bridge", "ford", "causeway"]:
			permitido.append(Vector2(float(sec.get("s0", 0.0)) - 60.0, float(sec.get("s1", 0.0)) + 60.0))
	var pier: Dictionary = data.swamp.get("pier", {})
	if not pier.is_empty():
		var sp: float = float(pier.get("s", 0.0))
		permitido.append(Vector2(sp - 45.0, sp + 45.0))
	var invasiones: int = 0
	var peor: String = ""
	for item: Variant in data.swamp.get("bodies", []):
		var poly: Array = (item as Dictionary).get("polygon", [])
		for i: int in poly.size():
			var a: Array = poly[i]
			var b: Array = poly[(i + 1) % poly.size()]
			var largo: float = Vector2(float(a[0]), float(a[1])).distance_to(Vector2(float(b[0]), float(b[1])))
			var pasos: int = maxi(2, int(largo / 3.0))
			for k: int in pasos + 1:
				var t: float = float(k) / float(pasos)
				var q: Vector3 = Vector3(lerpf(float(a[0]), float(b[0]), t), 0.0, lerpf(float(a[1]), float(b[1]), t))
				var pr: Vector2 = data.project(q)
				if absf(pr.y) >= data.curb_at(pr.x):
					continue
				var a_proposito: bool = false
				for rango: Vector2 in permitido:
					if pr.x >= rango.x and pr.x <= rango.y:
						a_proposito = true
				if not a_proposito:
					invasiones += 1
					peor = "s=%.0f a %.1f m del eje (%s)" % [pr.x, absf(pr.y), str((item as Dictionary).get("kind", ""))]
	assert_int(invasiones).override_failure_message("hay agua dibujada sobre la calzada: %s" % peor).is_equal(0)
