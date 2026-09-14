class_name FreeCamera
extends Camera3D

## Viewing tool for the owner (not part of the game): fly over a biome with no bus.
## W A S D move, Q/E down/up, Shift faster, Ctrl slower, hold the RIGHT mouse
## button to look around. Raw keys on purpose, so the tool does not depend on the
## project's input actions.

@export var speed_mps: float = 40.0
@export var fast_multiplier: float = 6.0
@export var mouse_sensitivity: float = 0.0035

var _looking: bool = false


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var button: InputEventMouseButton = event
		if button.button_index == MOUSE_BUTTON_RIGHT:
			_looking = button.pressed
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if _looking else Input.MOUSE_MODE_VISIBLE
		return
	if not _looking or not (event is InputEventMouseMotion):
		return
	var motion: InputEventMouseMotion = event
	rotation.y -= motion.screen_relative.x * mouse_sensitivity
	rotation.x = clampf(rotation.x - motion.screen_relative.y * mouse_sensitivity, -PI * 0.49, PI * 0.49)
	rotation.z = 0.0


func _process(delta: float) -> void:
	var move: Vector3 = Vector3.ZERO
	if Input.is_key_pressed(KEY_W):
		move -= basis.z
	if Input.is_key_pressed(KEY_S):
		move += basis.z
	if Input.is_key_pressed(KEY_A):
		move -= basis.x
	if Input.is_key_pressed(KEY_D):
		move += basis.x
	if Input.is_key_pressed(KEY_E):
		move += Vector3.UP
	if Input.is_key_pressed(KEY_Q):
		move += Vector3.DOWN
	if move == Vector3.ZERO:
		return
	var speed: float = speed_mps
	if Input.is_key_pressed(KEY_SHIFT):
		speed *= fast_multiplier
	if Input.is_key_pressed(KEY_CTRL):
		speed *= 0.25
	global_position += move.normalized() * speed * delta
