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
	assert_object(road.get_node_or_null("Batch_asphalt")).is_not_null()
	assert_int(road.batch_count("paint_white")).is_greater(300)
	assert_int(road.batch_count("paint_yellow")).is_greater(50)


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
