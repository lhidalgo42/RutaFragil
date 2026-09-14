extends GdUnitTestSuite

## AxisCircuit (D65): one Marker3D per data waypoint, in order, at the data
## positions; rebuilding replaces the previous markers.


func test_builds_markers_from_data() -> void:
	var data: OsmMapData = OsmMapData.load_from("res://data/b0_departamental.json")
	var circuit: AxisCircuit = auto_free(AxisCircuit.new())
	add_child(circuit)
	assert_int(circuit.waypoint_count()).is_equal(data.waypoints.size())
	assert_vector(circuit.waypoint_position(0)).is_equal_approx(data.waypoints[0], Vector3.ONE * 0.01)
	assert_vector(circuit.waypoint_position(data.waypoints.size() - 1)).is_equal_approx(data.waypoints[data.waypoints.size() - 1], Vector3.ONE * 0.01)
	circuit.build(data)
	assert_int(circuit.waypoint_count()).is_equal(data.waypoints.size())
