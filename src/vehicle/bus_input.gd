class_name BusInput
extends Node

## Driving input → bus interface (D62, D63, D64): reads the driving actions
## and calls the same set_drive/set_handbrake the DemoDriver uses, so both
## paths share the bus code. The bus itself never reads input.
## Steer sign follows D49: positive steers left (drive_steer_left is A).
## toggle_camera goes through the CameraArbiter — THE single camera site —
## and the cabin mouse look (ADR-004 cone: ±120° yaw, ±45° pitch, so the
## driver can check mirrors and sides) rides _unhandled_input:
## Input.parse_input_event DOES reach it headless (measured by the reviewer),
## so the wiring is covered by a real test. The capture gate reads the truth
## from CrewInput, the capture OWNER (group "crew_input"), because headless
## does not retain Input.mouse_mode (measured 2026-09-14).

@export var enabled: bool = false:
	set(value):
		enabled = value
		if not enabled and _bus != null:
			# Neutral when the driver stops driving (M2-T2.2 r5, r4.6): without
			# this, the last set_drive stays latent in Bus.drive_throttle and
			# the bus keeps ACCELERATING with nobody at the wheel (measured:
			# 21.6 -> 33.9 km/h after vacate with the key released; control
			# without vacating decelerates). Idempotent — every assignment to
			# false writes it — and guarded on _bus because _find_bus lands
			# deferred (the bus starts in neutral, so skipping there is free).
			# No handbrake: a driverless bus coasts to a stop by its own
			# resistance; the concept wants that chaos.
			_bus.set_drive(0.0, 0.0, 0.0)

var _bus: Bus = null
var _cabin: Camera3D = null
var _cabin_missing_reported: bool = false


func _ready() -> void:
	# Found by group, never by node name (D59): the Seat toggles us.
	add_to_group("bus_input")
	_find_bus.call_deferred()


func _find_bus() -> void:
	var node: Node = get_tree().get_first_node_in_group("bus")
	if node is Bus:
		_bus = node
	if _bus == null:
		push_error("BusInput: no node in group 'bus'")


func _physics_process(_delta: float) -> void:
	if not enabled or _bus == null:
		return
	var throttle: float = Input.get_action_strength("drive_accelerate") \
		- Input.get_action_strength("drive_brake")
	var steer: float = Input.get_action_strength("drive_steer_left") \
		- Input.get_action_strength("drive_steer_right")
	_bus.set_drive(throttle, steer, 0.0)
	_bus.set_handbrake(Input.is_action_pressed("drive_handbrake"))
	if Input.is_action_just_pressed("toggle_camera"):
		_toggle_camera()


func _toggle_camera() -> void:
	# The arbiter is THE single site that decides cameras (M2-T2.2 r3).
	CameraArbiter.toggle_bus_view(get_tree())


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventMouseMotion):
		return
	if not enabled or not _pointer_captured():
		return
	if not CameraArbiter.bus_view_cabin:
		# Chase view: the cabin look stays parked.
		return
	var cabin: Camera3D = _cabin_camera()
	if cabin == null:
		return
	var tuning: TuningTable = GameConfig.tuning
	if tuning == null:
		push_error("BusInput: GameConfig.tuning is null; cabin look skipped")
		return
	var motion: InputEventMouseMotion = event
	# screen_relative, NEVER .relative: with window/stretch/mode="canvas_items"
	# the engine scales .relative by the stretch factor (measured: a (10, -4)
	# physical move arrives as (180, -72)), so the sensitivity would change
	# with the window size. screen_relative reaches the node intact.
	var next: Vector2 = MouseLook.next_yaw_pitch(
		cabin.rotation.y, cabin.rotation.x, motion.screen_relative,
		tuning.player_mouse_sensitivity, deg_to_rad(120.0), deg_to_rad(45.0))
	cabin.rotation.y = next.x
	cabin.rotation.x = next.y


## The pointer-capture truth, read from its OWNER (CrewInput, by group — D59).
## Headless cannot hold Input.mouse_mode (set CAPTURED, reads back VISIBLE —
## measured 2026-09-14), so the engine flag is only the fallback for scenes
## without a CrewInput.
func _pointer_captured() -> bool:
	var node: Node = get_tree().get_first_node_in_group("crew_input")
	if node is CrewInput:
		var crew_input: CrewInput = node
		return crew_input.is_pointer_captured()
	return Input.mouse_mode == Input.MOUSE_MODE_CAPTURED


## The cabin camera is found by GROUP (D59/D63), never by node path. Missing
## camera: one error, no crash, no look.
func _cabin_camera() -> Camera3D:
	if _cabin == null:
		var node: Node = get_tree().get_first_node_in_group("cabin_camera")
		if node is Camera3D:
			_cabin = node
		elif not _cabin_missing_reported:
			_cabin_missing_reported = true
			push_error("BusInput: no Camera3D in group 'cabin_camera'")
	return _cabin
