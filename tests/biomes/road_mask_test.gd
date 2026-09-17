extends GdUnitTestSuite

## RoadMask (D72): la guarda compartida que decide dónde NO se siembra. Sin ella cada
## constructor tenía su propio criterio y salían matas y árboles sobre el asfalto.

const DATA: String = "res://data/b0_requinoa.json"


func test_the_axis_is_roadway_and_the_field_is_free() -> void:
	var data: OsmMapData = OsmMapData.load_from(DATA)
	assert_object(data).is_not_null()
	if data == null:
		return
	var mask: RoadMask = RoadMask.new()
	mask.build(data)
	assert_int(mask.paved_cells()).is_greater(1000)
	# el eje mismo es calzada en todo el recorrido
	var on_axis: int = 0
	for i: int in range(0, data.axis.size(), 17):
		if mask.is_roadway(data.axis[i]):
			on_axis += 1
	assert_int(on_axis).is_greater(data.axis.size() / 17 - 4)
	# fuera del pueblo, pasado el borde del mapa, no hay nada pavimentado
	var hi: Vector3 = data.axis[0]
	for p: Vector3 in data.axis:
		hi = hi.max(p)
	assert_bool(mask.is_paved(hi + Vector3(35.0, 0.0, 35.0))).is_false()


func test_the_sidewalk_is_paved_but_is_not_roadway() -> void:
	var data: OsmMapData = OsmMapData.load_from(DATA)
	if data == null:
		return
	var mask: RoadMask = RoadMask.new()
	mask.build(data)
	# un punto en la vereda: no se siembra pasto, pero el árbol de vereda SÍ va ahí
	var s: float = data.length * 0.25
	var walk: Vector3 = data.lateral_point(s, data.curb_at(s) + 2.0)
	assert_bool(mask.is_paved(walk)).is_true()
	assert_bool(mask.is_roadway(walk)).is_false()


func test_a_point_outside_the_grid_is_never_paved() -> void:
	var data: OsmMapData = OsmMapData.load_from(DATA)
	if data == null:
		return
	var mask: RoadMask = RoadMask.new()
	mask.build(data)
	assert_bool(mask.is_paved(Vector3(90000.0, 0.0, 90000.0), 5.0)).is_false()
