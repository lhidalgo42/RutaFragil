class_name OverviewCamera
extends Camera3D

## Top-down orthographic map camera for the greybox route. Press M in a
## windowed run to switch between this camera and the chase camera. Not a
## game feature: a viewing aid for the owner and for map screenshots.

## Camera whose place this one takes when toggled on.
@export var chase: Camera3D
## Vertical extent of the view in metres (the width follows the aspect).
@export var size_m: float = 340.0
@export var center: Vector3 = Vector3(5.0, 250.0, 12.0)
@export var toggle_key: Key = KEY_M


func _ready() -> void:
	projection = PROJECTION_ORTHOGONAL
	size = size_m
	global_position = center
	rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	current = false


func _unhandled_key_input(event: InputEvent) -> void:
	var key_event: InputEventKey = event as InputEventKey
	if key_event != null and key_event.pressed and not key_event.echo and key_event.keycode == toggle_key:
		toggle()


func toggle() -> void:
	show_overview(not current)


func show_overview(on: bool) -> void:
	if on:
		make_current()
	elif chase != null:
		chase.make_current()
	else:
		current = false
