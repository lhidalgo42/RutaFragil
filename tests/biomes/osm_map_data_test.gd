extends GdUnitTestSuite

## OsmMapData (D65): loads res://data/b0_departamental.json, exposes the axis
## frame helpers, and fails loudly on a missing file.

const PATH: String = "res://data/b0_departamental.json"


func test_loads_real_avenue_data() -> void:
	var data: OsmMapData = OsmMapData.load_from(PATH)
	assert_object(data).is_not_null()
	if data == null:
		return
	assert_float(data.length).is_greater(1000.0)
	assert_int(data.waypoints.size()).is_greater_equal(60)
	assert_int(data.buildings.size()).is_greater_equal(40)
	assert_int(data.humps.size()).is_equal(4)
	assert_str(data.source).contains("OpenStreetMap")


func test_sample_and_lateral_point_follow_the_axis() -> void:
	var data: OsmMapData = OsmMapData.load_from(PATH)
	var frame: Transform3D = data.sample(0.0)
	assert_vector(frame.origin).is_equal_approx(data.axis[0], Vector3.ONE * 0.01)
	var forward: Vector3 = -frame.basis.z
	var expected: Vector3 = (data.axis[1] - data.axis[0]).normalized()
	assert_float(forward.dot(expected)).is_greater(0.999)
	var left_pt: Vector3 = data.lateral_point(0.0, 10.0)
	assert_float(left_pt.distance_to(data.axis[0])).is_equal_approx(10.0, 0.01)
	var proj: Vector2 = data.project(left_pt)
	assert_float(proj.y).is_equal_approx(10.0, 0.05)
	assert_float(proj.x).is_equal_approx(0.0, 0.5)


func test_gap_lookup_uses_side() -> void:
	var data: OsmMapData = OsmMapData.load_from(PATH)
	var s_station: float = float(data.station.get("s", 160.0))
	assert_bool(data.in_gap(-1, s_station)).is_true()
	assert_bool(data.in_gap(1, s_station)).is_false()


func test_missing_file_returns_null_with_push_error() -> void:
	var result: Array[OsmMapData] = []
	await assert_error(func() -> void: result.append(OsmMapData.load_from("res://data/nope.json"))).is_push_error(
		"OsmMapData: cannot read res://data/nope.json")
	assert_int(result.size()).is_equal(1)
	if result.size() == 1:
		assert_object(result[0]).is_null()
