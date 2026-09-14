extends GdUnitTestSuite

## RouteCircuit: the waypoints of every BiomeSegment under segments_root, in
## tree order, concatenated into one lap; out of range is a push_error.


func test_concatenates_segments_in_tree_order() -> void:
	var root: Node3D = auto_free(Node3D.new())
	add_child(root)
	_add_segment(root, Vector3(0.0, 0.0, 0.0), 2)
	_add_segment(root, Vector3(0.0, 0.0, -100.0), 3)
	var route: RouteCircuit = auto_free(RouteCircuit.new())
	add_child(route)
	route.segments_root = root
	assert_int(route.waypoint_count()).is_equal(5)
	assert_vector(route.waypoint_position(0)).is_equal(Vector3(0.0, 1.0, 0.0))
	assert_vector(route.waypoint_position(1)).is_equal(Vector3(0.0, 1.0, -10.0))
	assert_vector(route.waypoint_position(2)).is_equal(Vector3(0.0, 1.0, -100.0))
	assert_vector(route.waypoint_position(4)).is_equal(Vector3(0.0, 1.0, -120.0))


func test_without_segments_root_has_zero_waypoints() -> void:
	var route: RouteCircuit = auto_free(RouteCircuit.new())
	add_child(route)
	assert_int(route.waypoint_count()).is_equal(0)


func test_out_of_range_index_push_error() -> void:
	var root: Node3D = auto_free(Node3D.new())
	add_child(root)
	_add_segment(root, Vector3.ZERO, 2)
	var route: RouteCircuit = auto_free(RouteCircuit.new())
	add_child(route)
	route.segments_root = root
	await assert_error(func() -> void: route.waypoint_position(2)).is_push_error(
		"RouteCircuit: waypoint index 2 out of range (count 2)")


func _add_segment(root: Node3D, origin: Vector3, waypoints: int) -> void:
	var segment: BiomeSegment = BiomeSegment.new()
	root.add_child(segment)
	segment.position = origin
	var circuit: Circuit = Circuit.new()
	circuit.name = "Circuit"
	segment.add_child(circuit)
	for i: int in waypoints:
		var marker: Marker3D = Marker3D.new()
		circuit.add_child(marker)
		marker.position = Vector3(0.0, 1.0, -10.0 * float(i))
