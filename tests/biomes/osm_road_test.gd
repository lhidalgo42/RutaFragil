extends GdUnitTestSuite

## OsmRoad (D65): builds from the real data at _ready — curbs with collision
## along both sides (open at the gaps), two flat humps (3 shapes) and two rounded (2), the
## underpass deck plus two walls, a grass strip and the batched visuals.


func test_builds_collision_bodies_and_batches() -> void:
	var road: OsmRoad = auto_free(OsmRoad.new())
	add_child(road)
	assert_object(road.data).is_not_null()
	assert_int(road.curb_shape_count()).is_greater(60)
	assert_int(road.hump_shape_count()).is_equal(10)
	var underpass: Node = road.get_node_or_null("Underpass")
	assert_bool(underpass is StaticBody3D).is_true()
	if underpass != null:
		assert_int(underpass.get_child_count()).is_equal(3)
	var grass: Node = road.get_node_or_null("MedianGrass")
	assert_bool(grass is GrassStrip).is_true()
	if grass is GrassStrip:
		var strip: GrassStrip = grass
		assert_int(strip.multimesh.instance_count).is_greater(5000)
	# D72: la calzada, la mediana, el cordón y la vereda salen como cintas continuas;
	# la pintura sigue siendo cajas (los trazos son discontinuos de por sí).
	# D74: la avenida usa "asphalt_plain" (asfalto liso, sin la línea central de la textura).
	assert_object(road.get_node_or_null("Ribbon_asphalt_plain")).override_failure_message("falta la cinta de asfalto de la avenida").is_not_null()
	for ribbon: String in ["Ribbon_median", "Ribbon_curb", "Ribbon_sidewalk"]:
		assert_object(road.get_node_or_null(ribbon)).override_failure_message("falta " + ribbon).is_not_null()
	assert_int(road.batch_count("paint_white")).is_greater(300)
	assert_int(road.batch_count("paint_yellow")).is_greater(50)
	# El pasto de los costados va en tramos para que la cámara pueda descartarlos:
	# en un solo MultiMesh de 5 km se dibujarían las 190.000 matas en cada cuadro.
	assert_int(road.verge_tuft_count()).is_greater(20000)
	var verge_root: Node = road.get_node_or_null("Verge")
	assert_object(verge_root).is_not_null()
	if verge_root == null:
		return
	assert_int(verge_root.get_child_count()).is_greater_equal(2)
	# ningún tramo se queda con todo: si alguien vuelve a hacerlo de una sola pieza,
	# la caja envolvente vuelve a cubrir el mapa y esto falla
	var biggest: int = 0
	for child: Node in verge_root.get_children():
		if child is GrassStrip:
			var piece: GrassStrip = child
			if piece.multimesh != null:
				biggest = maxi(biggest, piece.multimesh.instance_count)
	assert_int(biggest).is_less(road.verge_tuft_count() * 3 / 4)


## El corte en las curvas (lo que se veía feo): dos tramos vecinos tienen que compartir
## la misma fila de vértices. Si alguien vuelve a armar la calzada con cajas sueltas,
## aparecen vértices de más en el codo y esto falla.
func test_the_carriageway_has_no_seam_at_a_corner() -> void:
	var points: PackedVector3Array = PackedVector3Array([Vector3(0.0, 0.0, 0.0), Vector3(20.0, 0.0, 0.0), Vector3(20.0, 0.0, 20.0)])
	var lefts: PackedVector3Array = RoadRibbon.lefts(points)
	# el vector del codo se alarga 1/cos(45°): sin eso la cinta se angosta justo ahí
	assert_float(lefts[1].length()).is_equal_approx(sqrt(2.0), 0.01)
	var ribbon: RoadRibbon = RoadRibbon.new()
	ribbon.band("asphalt", points, lefts, -5.0, 5.0, 0.0)
	var parent: Node3D = auto_free(Node3D.new())
	ribbon.flush(parent, {"asphalt": Color.BLACK})
	var node: Node = parent.get_node_or_null("Ribbon_asphalt")
	assert_bool(node is MeshInstance3D).is_true()
	if not (node is MeshInstance3D):
		return
	var mesh_node: MeshInstance3D = node
	var faces: PackedVector3Array = mesh_node.mesh.get_faces()
	assert_int(faces.size()).is_equal(12)
	# La cara mira hacia arriba SEGÚN GODOT, no según nuestro producto cruz. Godot toma como
	# frontal la cara horaria; con la cara emitida al revés las calles existían y no se
	# dibujaban (D75), y la versión anterior de esta prueba lo dio por bueno porque
	# comprobaba nuestra propia suposición. Aquí se le pregunta al motor.
	var arrays: Array = mesh_node.mesh.surface_get_arrays(0)
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	assert_int(normals.size()).is_equal(12)
	for n: Vector3 in normals:
		assert_float(n.y).override_failure_message("la calzada mira hacia abajo: Godot la descarta desde arriba").is_greater(0.9)
	# y trae tangentes, que el mapa de normales de la textura necesita
	assert_bool(arrays[Mesh.ARRAY_TANGENT] is PackedFloat32Array).is_true()
	# los dos cuadros del codo usan exactamente los mismos dos puntos del borde
	for edge: float in [-5.0, 5.0]:
		var corner: Vector3 = points[1] + lefts[1] * edge
		var hits: int = 0
		for v: Vector3 in faces:
			if v.distance_to(corner) < 0.001:
				hits += 1
		assert_int(hits).override_failure_message("el codo no comparte el borde %s" % edge).is_greater_equal(2)


func test_curbs_leave_the_station_gap_open() -> void:
	var road: OsmRoad = auto_free(OsmRoad.new())
	add_child(road)
	var s_station: float = float(road.data.station.get("s", 160.0))
	var gap_centre: Vector3 = road.data.lateral_point(s_station, -road.data.curb_lateral)
	var curbs: Node = road.get_node("Curbs")
	var nearest: float = INF
	for child: Node in curbs.get_children():
		var shape: CollisionShape3D = child as CollisionShape3D
		nearest = minf(nearest, shape.global_position.distance_to(gap_centre))
	assert_float(nearest).is_greater(20.0)
