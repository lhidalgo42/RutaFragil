class_name BusInput
extends Node

## Driving input → bus interface (D62, D63, D64): reads the driving actions
## and calls the same set_drive/set_handbrake the DemoDriver uses, so both
## paths share the bus code. The bus itself never reads input.
## Steer sign follows D49: positive steers left (drive_steer_left is A).
## Headless delivers no InputEvent (plan §3), so this node is exercised from
## the windowed runs and its logic is covered indirectly; the bus tests never
## simulate input.

@export var enabled: bool = false

var _bus: Bus = null


func _ready() -> void:
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
	var cabin_v: Node = get_tree().get_first_node_in_group("cabin_camera")
	var chase: Camera3D = null
	var chase_v: Node = get_tree().get_first_node_in_group("chase_camera")
	if chase_v is ChaseCamera:
		chase = chase_v
	if cabin_v is Camera3D and chase != null:
		var cabin: Camera3D = cabin_v
		var to_cabin: bool = not cabin.current
		cabin.current = to_cabin
		chase.current = not to_cabin
