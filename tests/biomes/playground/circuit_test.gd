extends GdUnitTestSuite

## Circuit (D49): waypoint order follows the tree order of the Marker3D
## children; other children are ignored; an empty circuit reports zero.


func test_counts_only_marker3d_children() -> void:
	var circuit: Circuit = auto_free(Circuit.new())
	add_child(circuit)
	var plain_child: Node3D = Node3D.new()
	circuit.add_child(plain_child)
	for i: int in 3:
		var marker: Marker3D = Marker3D.new()
		circuit.add_child(marker)
		marker.position = Vector3(float(i) * 5.0, 1.0, -float(i))
	assert_int(circuit.waypoint_count()).is_equal(3)


func test_positions_follow_tree_order() -> void:
	var circuit: Circuit = auto_free(Circuit.new())
	add_child(circuit)
	for i: int in 3:
		var marker: Marker3D = Marker3D.new()
		circuit.add_child(marker)
		marker.position = Vector3(float(i) * 5.0, 1.0, -float(i))
	assert_vector(circuit.waypoint_position(0)).is_equal(Vector3(0.0, 1.0, 0.0))
	assert_vector(circuit.waypoint_position(1)).is_equal(Vector3(5.0, 1.0, -1.0))
	assert_vector(circuit.waypoint_position(2)).is_equal(Vector3(10.0, 1.0, -2.0))


func test_empty_circuit_has_zero_waypoints() -> void:
	var circuit: Circuit = auto_free(Circuit.new())
	add_child(circuit)
	assert_int(circuit.waypoint_count()).is_equal(0)


func test_out_of_range_index_push_error() -> void:
	var circuit: Circuit = auto_free(Circuit.new())
	add_child(circuit)
	await assert_error(func() -> void: circuit.waypoint_position(4)).is_push_error(
		"Circuit: waypoint index 4 out of range (count 0)"
	)
