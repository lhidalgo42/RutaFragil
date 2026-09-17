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
	# D76: cada árbol es un tronco con corteza y varios mechones de hojas, más helechos al pie;
	# las copas ya no son esferas ("Mickey", dijo el dueño)
	assert_int(furniture.batch_count("crown")).is_greater(furniture.batch_count("trunk"))
	assert_int(furniture.batch_count("fern")).is_greater(0)
	assert_int(furniture.batch_count("crown_b")).is_equal(0)
	assert_object(MeshBatcher.canopy_texture()).override_failure_message("los árboles no dejaron máscara de copas").is_not_null()
