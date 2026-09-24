class_name CopilotCamera
extends Camera3D

## Passenger camera at the copilot seat (r8): free look in every direction.
## CameraArbiter makes it `current` only for the local crew seated in the
## copilot seat, so `current` doubles as the ownership gate: a remote copilot
## never turns this peer's camera. Yaw is unbounded, pitch clamped to ±89°
## (same contract as on foot, MouseLook). The look is local, never replicated.
## Pointer capture is read from its owner, CrewInput (headless cannot hold
## Input.mouse_mode), with the engine flag as fallback.

const PITCH_LIMIT_DEG: float = 89.0


func _ready() -> void:
	add_to_group("copilot_camera")


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventMouseMotion) or not current or not _pointer_captured():
		return
	var tuning: TuningTable = GameConfig.tuning
	if tuning == null:
		push_error("CopilotCamera: GameConfig.tuning is null; look skipped")
		return
	var motion: InputEventMouseMotion = event
	# screen_relative, NEVER .relative: stretch mode scales .relative.
	look(motion.screen_relative, tuning.player_mouse_sensitivity)


## One look step; public so tests pin the range without input events.
func look(delta_px: Vector2, sensitivity: float) -> void:
	var next: Vector2 = MouseLook.next_yaw_pitch(rotation.y, rotation.x, delta_px,
		sensitivity, -1.0, deg_to_rad(PITCH_LIMIT_DEG))
	rotation.y = next.x
	rotation.x = next.y


func _pointer_captured() -> bool:
	var node: Node = get_tree().get_first_node_in_group("crew_input")
	if node is CrewInput:
		var crew_input: CrewInput = node
		return crew_input.is_pointer_captured()
	return Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
