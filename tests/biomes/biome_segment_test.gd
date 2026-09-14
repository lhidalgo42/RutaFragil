extends GdUnitTestSuite

## BiomeSegment: Entry/Exit markers and the child Circuit are found by name;
## a missing marker is a push_error and falls back to the segment origin.


func test_entry_exit_and_circuit_are_found() -> void:
	var segment: BiomeSegment = _make_segment(true)
	assert_vector(segment.entry_position()).is_equal(Vector3(1.0, 0.0, 10.0))
	assert_vector(segment.exit_position()).is_equal(Vector3(1.0, 0.0, -10.0))
	var circuit: Circuit = segment.circuit()
	assert_object(circuit).is_not_null()
	if circuit != null:
		assert_int(circuit.waypoint_count()).is_equal(2)


func test_missing_marker_falls_back_to_origin_with_push_error() -> void:
	var segment: BiomeSegment = _make_segment(false)
	var result: Array[Vector3] = []
	await assert_error(func() -> void: result.append(segment.entry_position())).is_push_error(
		"BiomeSegment Segment: missing Entry marker")
	assert_int(result.size()).is_equal(1)
	if result.size() == 1:
		assert_vector(result[0]).is_equal(Vector3(1.0, 0.0, 0.0))


func _make_segment(with_markers: bool) -> BiomeSegment:
	var segment: BiomeSegment = auto_free(BiomeSegment.new())
	segment.name = "Segment"
	add_child(segment)
	segment.global_position = Vector3(1.0, 0.0, 0.0)
	if with_markers:
		var entry: Marker3D = Marker3D.new()
		entry.name = "Entry"
		segment.add_child(entry)
		entry.position = Vector3(0.0, 0.0, 10.0)
		var exit_marker: Marker3D = Marker3D.new()
		exit_marker.name = "Exit"
		segment.add_child(exit_marker)
		exit_marker.position = Vector3(0.0, 0.0, -10.0)
	var circuit: Circuit = Circuit.new()
	circuit.name = "Circuit"
	segment.add_child(circuit)
	for i: int in 2:
		var marker: Marker3D = Marker3D.new()
		circuit.add_child(marker)
		marker.position = Vector3(float(i), 0.0, 0.0)
	return segment
