class_name DemoDriver
extends Node

## Drives the placeholder bus around a Circuit with no human input (D49):
## every physics tick it computes throttle/steer/brake toward the current
## waypoint through DemoSteering and calls bus.set_drive. The signals are
## the hooks that run_demo and the T0.4 network script listen to.

signal waypoint_reached(index: int)
signal lap_completed(lap: int)
signal stuck

@export var bus: PlaceholderBus
@export var circuit: Circuit
@export var enabled: bool = false
@export var reach_radius_m: float = 4.0
@export var stuck_seconds: float = 8.0
## 0 means laps never stop.
@export var laps_target: int = 0

var current_index: int = 0
var laps: int = 0

var _best_distance_m: float = INF
var _stuck_time_s: float = 0.0
var _stuck_emitted: bool = false
var _config_warned: bool = false


func _physics_process(delta: float) -> void:
	if not enabled:
		return
	if bus == null or circuit == null:
		if not _config_warned:
			_config_warned = true
			push_error("DemoDriver: bus and circuit must be assigned while enabled")
		return
	var count: int = circuit.waypoint_count()
	if count == 0:
		return
	var target: Vector3 = circuit.waypoint_position(current_index)
	var pos: Vector3 = bus.global_position
	if DemoSteering.has_reached(pos, target, reach_radius_m):
		_on_waypoint_reached(count)
		return
	var forward: Vector3 = bus.forward()
	var to_target: Vector3 = target - pos
	var steer: float = DemoSteering.steer_for(forward, to_target)
	var abs_angle: float = absf(DemoSteering.signed_angle_for(forward, to_target))
	var throttle: float = DemoSteering.throttle_for(abs_angle)
	var brake: float = DemoSteering.brake_for(abs_angle, bus.speed_mps())
	bus.set_drive(throttle, steer, brake)
	_update_stuck(delta, pos, target)


func _on_waypoint_reached(count: int) -> void:
	var reached: int = current_index
	current_index = DemoSteering.next_index(current_index, count)
	waypoint_reached.emit(reached)
	_reset_stuck()
	if current_index == 0:
		laps += 1
		lap_completed.emit(laps)
		if laps_target > 0 and laps >= laps_target:
			enabled = false
			bus.set_drive(0.0, 0.0, 1.0)


func _update_stuck(delta: float, pos: Vector3, target: Vector3) -> void:
	var dx: float = target.x - pos.x
	var dz: float = target.z - pos.z
	var distance: float = sqrt(dx * dx + dz * dz)
	if distance < _best_distance_m - 0.05:
		_best_distance_m = distance
		_stuck_time_s = 0.0
		return
	_stuck_time_s += delta
	if not _stuck_emitted and _stuck_time_s >= stuck_seconds:
		_stuck_emitted = true
		stuck.emit()


func _reset_stuck() -> void:
	_best_distance_m = INF
	_stuck_time_s = 0.0
	_stuck_emitted = false
