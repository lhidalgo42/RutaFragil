extends GdUnitTestSuite

## Cabin mouse-look wiring (M2-T2.2 r3): synthetic InputEventMouseMotion
## reaches BusInput._unhandled_input headless via Input.parse_input_event
## (measured by the reviewer). The events coalesce and their values are
## environment-dependent, so the tests assert only that the yaw CHANGED (or
## did NOT) — exactness lives in the pure MouseLook tests. The driver's cone
## is ±120° yaw / ±45° pitch (ADR-004). The bare frozen Bus exists only so
## _find_bus stays silent; the look needs no wheels. Capture is owned by
## CrewInput (headless cannot hold Input.mouse_mode — measured 2026-09-14),
## so the tests spawn the owner exactly like the playground scene does.

const CREW_SCENE: String = "res://src/crew/crew_member.tscn"


func before_test() -> void:
	CameraArbiter.bus_view_cabin = true


func after_test() -> void:
	# Static preference and global pointer state never leak into other suites.
	CameraArbiter.bus_view_cabin = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func test_cabin_camera_turns_with_the_mouse_in_cabin_view() -> void:
	var cabin: Camera3D = _make_cabin_camera()
	_make_frozen_bus()
	_make_bus_input()
	var owner: CrewInput = _make_capture_owner()
	owner.set_mouse_captured(true)
	var yaw_before: float = cabin.rotation.y
	_send_mouse_motion(Vector2(40.0, 0.0))
	# parse_input_event is delivered at the NEXT main-loop flush: one frame
	# is not enough (measured — the probe needed two).
	await get_tree().process_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_float(cabin.rotation.y).is_not_equal(yaw_before)


func test_chase_view_parks_the_cabin_look() -> void:
	var cabin: Camera3D = _make_cabin_camera()
	_make_frozen_bus()
	_make_bus_input()
	var owner: CrewInput = _make_capture_owner()
	owner.set_mouse_captured(true)
	CameraArbiter.bus_view_cabin = false
	var rotation_before: Vector3 = cabin.rotation
	_send_mouse_motion(Vector2(40.0, 0.0))
	await get_tree().process_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_vector(cabin.rotation).is_equal(rotation_before)


func _make_cabin_camera() -> Camera3D:
	var cabin: Camera3D = auto_free(Camera3D.new())
	cabin.add_to_group("cabin_camera")
	add_child(cabin)
	return cabin


func _make_frozen_bus() -> void:
	var bus: Bus = auto_free(Bus.new())
	bus.freeze = true
	bus.add_to_group("bus")
	add_child(bus)


func _make_bus_input() -> void:
	var input: BusInput = auto_free(BusInput.new())
	input.enabled = true
	add_child(input)


## The capture owner (and its crew, so _find_crew stays silent): the same
## wiring the playground scene has. The crew needs no ground — nothing here
## asserts on it.
func _make_capture_owner() -> CrewInput:
	var packed: Resource = load(CREW_SCENE)
	if packed is PackedScene:
		var scene: PackedScene = packed
		var crew: CrewMember = auto_free(scene.instantiate())
		crew.position = Vector3(0.0, 1.0, 0.0)
		add_child(crew)
	var input: CrewInput = auto_free(CrewInput.new())
	add_child(input)
	return input


func _send_mouse_motion(delta_px: Vector2) -> void:
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.screen_relative = delta_px
	Input.parse_input_event(motion)
