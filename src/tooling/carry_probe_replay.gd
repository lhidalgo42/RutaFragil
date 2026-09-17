extends Node

## Controlled 30 Hz hold/interpolation writers for comparison in the same rig.
## A separate read-only node samples after both this writer and the crew.

var bus: RigidBody3D = null
var recording: Array[Transform3D] = []
var interp: bool = false
var write_phase: String = "physics_frame"
var index: int = 0
var _active: bool = true


func _ready() -> void:
	set_physics_process(write_phase == "physics_process")
	if write_phase == "physics_frame":
		get_tree().physics_frame.connect(_write_tick)


func stop() -> void:
	_active = false
	set_physics_process(false)
	if get_tree().physics_frame.is_connected(_write_tick):
		get_tree().physics_frame.disconnect(_write_tick)


func _physics_process(_delta: float) -> void:
	_write_tick()


func _write_tick() -> void:
	if not _active or bus == null or recording.is_empty():
		return
	var latest: int = index - (index % 2)
	var target: Transform3D = recording[mini(latest, recording.size() - 1)]
	if interp:
		var previous: int = maxi(0, latest - 2)
		var alpha: float = float(index - latest) / 2.0
		target = recording[previous].interpolate_with(target, alpha)
	bus.global_transform = target
	index += 1
