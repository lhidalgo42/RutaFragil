extends GdUnitTestSuite

## Seat (D76): occupy hides and freezes the member and hands the wheel to the
## bus input; vacate returns control to the crew. A second occupy fails.


func test_occupy_hides_and_vacate_restores() -> void:
	var crew: CrewMember = auto_free(CrewMember.new())
	add_child(crew)
	var marker: Marker3D = Marker3D.new()
	add_child(marker)
	marker.global_position = Vector3(1.0, 0.5, 2.0)
	var seat: Seat = auto_free(Seat.new())
	seat.seat_marker = marker
	add_child(seat)
	var occupied_log: Array[String] = []
	seat.occupied.connect(func(seat_name: String) -> void: occupied_log.append(seat_name))
	assert_bool(seat.occupy(crew)).is_true()
	assert_bool(crew.seated).is_true()
	assert_bool(crew.visible).is_false()
	assert_array(occupied_log).is_equal(["driver"])
	assert_bool(seat.occupy(crew)).is_false()
	seat.vacate()
	assert_bool(crew.seated).is_false()
	assert_bool(crew.visible).is_true()
	assert_object(seat.occupied_by).is_null()
