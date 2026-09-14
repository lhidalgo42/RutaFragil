extends GdUnitTestSuite

## CityBackdrop (D67): the Andes stand far to the east, foothills in front of
## them, and every island hill keeps its distance from the corridor.


func test_ridge_is_east_and_hills_keep_distance() -> void:
	var backdrop: CityBackdrop = auto_free(CityBackdrop.new())
	backdrop.hills = 10
	add_child(backdrop)
	assert_int(backdrop.batch_count("andes")).is_equal(backdrop.peaks)
	assert_int(backdrop.batch_count("foothills")).is_equal(backdrop.peaks - 2)
	assert_int(backdrop.batch_count("hills")).is_equal(10)
	for o: Vector3 in backdrop.batch_positions("andes"):
		assert_float(o.x).is_greater(backdrop.ridge_distance_m - 600.0)
	var hill_positions: PackedVector3Array = backdrop.batch_positions("hills")
	assert_int(hill_positions.size()).is_equal(10)
	for o: Vector3 in hill_positions:
		assert_float(Vector2(o.x, o.z).length()).is_greater_equal(backdrop.hill_min_distance_m - 1.0)
