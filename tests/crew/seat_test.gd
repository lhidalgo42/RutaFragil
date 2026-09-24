extends GdUnitTestSuite

## Seat (D76): occupy hides and freezes the member and hands the wheel to the
## bus input; vacate returns control to the crew. A second occupy fails.


class InputStub extends Node:
	var enabled: bool = false


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


func test_passenger_occupy_and_vacate_use_copilot_camera_and_disable_inputs() -> void:
	var packed: Resource = load("res://src/crew/crew_member.tscn")
	assert_bool(packed is PackedScene).is_true()
	if not (packed is PackedScene):
		return
	var scene: PackedScene = packed
	var crew: CrewMember = auto_free(scene.instantiate())
	add_child(crew)
	await get_tree().process_frame
	var marker: Marker3D = auto_free(Marker3D.new())
	add_child(marker)
	marker.global_position = Vector3(1.0, 0.5, 2.0)
	var eye_node: Node = crew.get_node_or_null("EyeCamera")
	assert_bool(eye_node is Camera3D).is_true()
	if not (eye_node is Camera3D):
		return
	var eye: Camera3D = eye_node
	var copilot: Camera3D = auto_free(Camera3D.new())
	add_child(copilot)
	copilot.add_to_group("copilot_camera")
	var bus_input: InputStub = auto_free(InputStub.new())
	add_child(bus_input)
	bus_input.add_to_group("bus_input")
	var crew_input: InputStub = auto_free(InputStub.new())
	add_child(crew_input)
	crew_input.add_to_group("crew_input")
	var seat: Seat = auto_free(Seat.new())
	seat.seat_name = "copilot"
	seat.drives_bus = false
	seat.seat_marker = marker
	add_child(seat)
	assert_bool(seat.occupy(crew)).is_true()
	assert_bool(crew.seated).is_true()
	assert_bool(copilot.current).is_true()
	assert_bool(eye.current).is_false()
	assert_bool(bus_input.enabled).is_false()
	assert_bool(crew_input.enabled).is_false()
	seat.vacate()
	await get_tree().process_frame
	assert_bool(crew.seated).is_false()
	assert_bool(eye.current).is_true()
	assert_bool(copilot.current).is_false()
	assert_bool(bus_input.enabled).is_false()
	assert_bool(crew_input.enabled).is_true()
