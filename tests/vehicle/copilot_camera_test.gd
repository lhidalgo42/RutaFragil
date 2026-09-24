extends GdUnitTestSuite

## Copilot free look (r8): the passenger camera turns with the captured mouse,
## yaw unbounded (all directions), pitch clamped to ±89°, and it never turns
## while it is not the active camera or the pointer is free. Motion events
## coalesce headless, so wiring asserts only that the yaw CHANGED (or did NOT);
## the range tests call the camera's pure step directly.


func after_test() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func test_copilot_camera_turns_with_captured_mouse_when_current() -> void:
	var cam: CopilotCamera = _make_copilot()
	var owner: CrewInput = _make_capture_owner()
	owner.set_mouse_captured(true)
	cam.current = true
	var yaw_before: float = cam.rotation.y
	_send_mouse_motion(Vector2(40.0, 0.0))
	await get_tree().process_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_float(cam.rotation.y).is_not_equal(yaw_before)


func test_copilot_yaw_accumulates_past_pi() -> void:
	var cam: CopilotCamera = _make_copilot()
	for i: int in 4:
		cam.look(Vector2(-600.0, 0.0), 0.0025)
	assert_float(cam.rotation.y).is_greater(PI)


func test_copilot_pitch_clamps_to_89_degrees() -> void:
	var cam: CopilotCamera = _make_copilot()
	cam.look(Vector2(0.0, -100000.0), 0.0025)
	assert_float(cam.rotation.x).is_equal_approx(deg_to_rad(89.0), 0.0001)
	cam.look(Vector2(0.0, 100000.0), 0.0025)
	assert_float(cam.rotation.x).is_equal_approx(-deg_to_rad(89.0), 0.0001)


func test_copilot_parks_when_not_current_or_pointer_free() -> void:
	var cam: CopilotCamera = _make_copilot()
	var owner: CrewInput = _make_capture_owner()
	owner.set_mouse_captured(true)
	cam.current = false
	_send_mouse_motion(Vector2(40.0, 0.0))
	await get_tree().process_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_float(cam.rotation.y).is_equal(0.0)
	cam.current = true
	owner.set_mouse_captured(false)
	_send_mouse_motion(Vector2(40.0, 0.0))
	await get_tree().process_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_float(cam.rotation.y).is_equal(0.0)


func _make_copilot() -> CopilotCamera:
	var cam: CopilotCamera = auto_free(CopilotCamera.new())
	add_child(cam)
	return cam


func _make_capture_owner() -> CrewInput:
	var input: CrewInput = auto_free(CrewInput.new())
	add_child(input)
	return input


func _send_mouse_motion(delta_px: Vector2) -> void:
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.screen_relative = delta_px
	Input.parse_input_event(motion)
