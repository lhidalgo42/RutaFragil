extends GdUnitTestSuite

## OsmFurniture (D67): real stops, signals and trees, plus street lights on the
## median, power poles with cables on both sidewalks and sidewalk trees.


func test_builds_lights_poles_cables_and_trees() -> void:
	var furniture: OsmFurniture = auto_free(OsmFurniture.new())
	add_child(furniture)
	assert_object(furniture.data).is_not_null()
	assert_int(furniture.batch_count("stop")).is_equal(furniture.data.bus_stops.size())
	assert_int(furniture.batch_count("signal")).is_equal(furniture.data.traffic_signals.size())
	assert_int(furniture.batch_count("lamp")).is_greater(40)
	assert_int(furniture.batch_count("pole")).is_greater(80)
	assert_int(furniture.batch_count("cable")).is_greater(80)
	assert_int(furniture.batch_count("trunk")).is_greater(100)
