extends GdUnitTestSuite

## OsmBuildings (D65): one facade and one collision box per building, a roof
## only for low houses, and the delivery pad in front of the marked house.


func test_one_facade_and_one_collider_per_building() -> void:
	var buildings: OsmBuildings = auto_free(OsmBuildings.new())
	add_child(buildings)
	assert_object(buildings.data).is_not_null()
	var n: int = buildings.data.buildings.size()
	assert_int(buildings.facade_count()).is_equal(n)
	assert_int(buildings.collision_count()).is_equal(n)
	var roofs: MultiMeshInstance3D = buildings.get_node("Roofs") as MultiMeshInstance3D
	assert_int(roofs.multimesh.instance_count).is_greater(0)
	assert_int(roofs.multimesh.instance_count).is_less(n)
	var fills: int = 0
	for b: Dictionary in buildings.data.buildings:
		if str(b.get("type", "")) == "fill":
			fills += 1
	assert_int(fills).is_greater_equal(20)
	assert_int(buildings.fence_count()).is_equal(fills)
	var facades: MultiMeshInstance3D = buildings.get_node("Facades") as MultiMeshInstance3D
	assert_bool(facades.multimesh.mesh.surface_get_material(0) is ShaderMaterial).is_true()


func test_delivery_pad_sits_between_house_and_avenue() -> void:
	var buildings: OsmBuildings = auto_free(OsmBuildings.new())
	add_child(buildings)
	var pad: Vector3 = buildings.delivery_position()
	assert_bool(pad != Vector3.ZERO).is_true()
	var proj: Vector2 = buildings.data.project(pad)
	var house: Dictionary = {}
	for b: Dictionary in buildings.data.buildings:
		if bool(b.get("delivery", false)):
			house = b
	assert_bool(not house.is_empty()).is_true()
	if not house.is_empty():
		var house_lat: float = float(house.get("lat", 0.0))
		assert_float(absf(proj.y)).is_less(absf(house_lat))
		assert_float(absf(proj.y)).is_greater(buildings.data.sidewalk_lateral)
