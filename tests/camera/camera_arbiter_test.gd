extends GdUnitTestSuite

## CameraArbiter (M2-T2.2 round 3): the single site that decides the active
## camera. Exactly one Camera3D is current after every apply/toggle, and
## which one follows the crew's state (on foot / seated / demo). The seat
## integration proves the round's bug is closed: standing up from the wheel
## returns the crew member's own eyes instead of leaving the chase camera.

const CREW_SCENE: String = "res://src/crew/crew_member.tscn"


func before_test() -> void:
	CameraArbiter.bus_view_cabin = true


func test_apply_on_foot_activates_only_the_eye_camera() -> void:
	var eye: Camera3D = _make_camera("eye_camera")
	var cabin: Camera3D = _make_camera("cabin_camera")
	var chase: Camera3D = _make_camera("chase_camera")
	var copilot: Camera3D = _make_camera("copilot_camera")
	CameraArbiter.apply(get_tree(), CameraArbiter.Mode.ON_FOOT)
	var cams: Array[Camera3D] = [eye, cabin, chase]
	assert_bool(eye.current).is_true()
	assert_bool(cabin.current).is_false()
	assert_bool(chase.current).is_false()
	assert_int(_count_current(cams)).is_equal(1)


func test_apply_seated_prefers_the_cabin_camera() -> void:
	var eye: Camera3D = _make_camera("eye_camera")
	var cabin: Camera3D = _make_camera("cabin_camera")
	var chase: Camera3D = _make_camera("chase_camera")
	CameraArbiter.apply(get_tree(), CameraArbiter.Mode.SEATED)
	var cams: Array[Camera3D] = [eye, cabin, chase]
	assert_bool(cabin.current).is_true()
	assert_bool(eye.current).is_false()
	assert_bool(chase.current).is_false()
	assert_int(_count_current(cams)).is_equal(1)


func test_apply_passenger_activates_only_the_copilot_camera() -> void:
	var eye: Camera3D = _make_camera("eye_camera")
	var cabin: Camera3D = _make_camera("cabin_camera")
	var chase: Camera3D = _make_camera("chase_camera")
	var copilot: Camera3D = _make_camera("copilot_camera")
	CameraArbiter.apply(get_tree(), CameraArbiter.Mode.PASSENGER)
	var cams: Array[Camera3D] = [eye, cabin, chase, copilot]
	assert_bool(copilot.current).is_true()
	assert_bool(eye.current).is_false()
	assert_bool(cabin.current).is_false()
	assert_bool(chase.current).is_false()
	assert_int(_count_current(cams)).is_equal(1)


func test_apply_demo_activates_only_the_chase_camera() -> void:
	var eye: Camera3D = _make_camera("eye_camera")
	var cabin: Camera3D = _make_camera("cabin_camera")
	var chase: Camera3D = _make_camera("chase_camera")
	CameraArbiter.apply(get_tree(), CameraArbiter.Mode.DEMO)
	var cams: Array[Camera3D] = [eye, cabin, chase]
	assert_bool(chase.current).is_true()
	assert_bool(eye.current).is_false()
	assert_bool(cabin.current).is_false()
	assert_int(_count_current(cams)).is_equal(1)


func test_toggle_bus_view_switches_the_seated_camera_to_chase() -> void:
	var eye: Camera3D = _make_camera("eye_camera")
	var cabin: Camera3D = _make_camera("cabin_camera")
	var chase: Camera3D = _make_camera("chase_camera")
	CameraArbiter.apply(get_tree(), CameraArbiter.Mode.SEATED)
	assert_bool(cabin.current).is_true()
	CameraArbiter.toggle_bus_view(get_tree())
	var cams: Array[Camera3D] = [eye, cabin, chase]
	assert_bool(CameraArbiter.bus_view_cabin).is_false()
	assert_bool(chase.current).is_true()
	assert_bool(cabin.current).is_false()
	assert_bool(eye.current).is_false()
	assert_int(_count_current(cams)).is_equal(1)


func test_seat_occupy_and_vacate_switch_the_camera() -> void:
	var copilot: Camera3D = _make_camera("copilot_camera")
	var packed: Resource = load(CREW_SCENE)
	assert_bool(packed is PackedScene).override_failure_message("crew_member.tscn did not load").is_true()
	if not (packed is PackedScene):
		return
	var scene: PackedScene = packed
	var crew: CrewMember = auto_free(scene.instantiate())
	# Positioned before add_child (the reviewer's rule); the parent sits at
	# the origin.
	crew.position = Vector3(0.0, 1.0, 0.0)
	add_child(crew)
	var eye_node: Node = crew.get_node_or_null("EyeCamera")
	assert_bool(eye_node is Camera3D).override_failure_message("crew has no EyeCamera").is_true()
	if not (eye_node is Camera3D):
		return
	var eye: Camera3D = eye_node
	assert_bool(eye.is_in_group("eye_camera")).is_true()
	var cabin: Camera3D = _make_camera("cabin_camera")
	var chase: Camera3D = _make_camera("chase_camera")
	var marker: Marker3D = auto_free(Marker3D.new())
	add_child(marker)
	var seat: Seat = auto_free(Seat.new())
	seat.seat_marker = marker
	add_child(seat)
	assert_bool(seat.occupy(crew)).is_true()
	await get_tree().physics_frame
	var seated_cams: Array[Camera3D] = [eye, cabin, chase]
	assert_bool(cabin.current).is_true()
	assert_bool(eye.current).is_false()
	assert_bool(chase.current).is_false()
	assert_int(_count_current(seated_cams)).is_equal(1)
	seat.vacate()
	await get_tree().physics_frame
	var on_foot_cams: Array[Camera3D] = [eye, cabin, chase]
	assert_bool(eye.current).is_true()
	assert_bool(cabin.current).is_false()
	assert_bool(chase.current).is_false()
	assert_int(_count_current(on_foot_cams)).is_equal(1)


func _make_camera(group: String) -> Camera3D:
	var cam: Camera3D = auto_free(Camera3D.new())
	add_child(cam)
	cam.add_to_group(group)
	return cam


func _count_current(cams: Array[Camera3D]) -> int:
	var count: int = 0
	for cam: Camera3D in cams:
		if cam.current:
			count += 1
	return count
