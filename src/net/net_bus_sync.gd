class_name NetBusSync
extends Node

## RPC reception only buffers; this node writes before crew physics callbacks.
## A source clock prevents irregular arrivals from restarting interpolation.
var bus: RigidBody3D = null
var interpolate: bool = true
var network_enabled: bool = false
var snapshot_hz: float = 30.0
var _latest: Transform3D = Transform3D.IDENTITY
var interpolation_delay_s: float = 2.0 / 30.0
var received_count: int = 0
var rejected_count: int = 0
var last_write_distance_m: float = 0.0
var buffer_underrun_ticks: int = 0
var _replicated_linear: Vector3 = Vector3.ZERO
var _replicated_angular: Vector3 = Vector3.ZERO
var _poses: Array[Transform3D] = []
var _times: Array[float] = []
var _linear: Array[Vector3] = []
var _angular: Array[Vector3] = []
var _playback_s: float = 0.0
var _last_source_s: float = -INF
var _source_s: float = 0.0
var _send_elapsed: float = 0.0
var capture_snapshots: bool = false
var snapshot_trace: Array[Dictionary] = []
var last_arrival_utc_us: int = 0
var last_transport_s: float = 0.0
var last_write_playback_s: float = 0.0


func _ready() -> void:
	add_to_group("net_bus_sync")
	process_physics_priority = -100


func _physics_process(delta: float) -> void:
	advance(delta)


func accept_snapshot(at: Transform3D, source_s: float = -1.0,
		linear: Vector3 = Vector3.ZERO, angular: Vector3 = Vector3.ZERO, sent_utc_us: int = 0) -> void:
	if source_s < 0.0:
		source_s = 0.0 if _times.is_empty() else _last_source_s + 1.0 / snapshot_hz
	if not is_finite(source_s) or not at.is_finite() or source_s <= _last_source_s \
			or not linear.is_finite() or not angular.is_finite():
		rejected_count += 1
		return
	if _times.is_empty():
		_playback_s = source_s - interpolation_delay_s
	_times.append(source_s)
	_poses.append(at)
	_linear.append(linear)
	_angular.append(angular)
	_last_source_s = source_s
	_latest = at
	received_count += 1
	last_arrival_utc_us = int(Time.get_unix_time_from_system() * 1000000.0)
	last_transport_s = float(last_arrival_utc_us - sent_utc_us) / 1000000.0 if sent_utc_us > 0 else 0.0
	if capture_snapshots:
		var orientation: Quaternion = at.basis.get_rotation_quaternion()
		snapshot_trace.append({"arrival_physics_frame": Engine.get_physics_frames(),
			"arrival_utc_us": last_arrival_utc_us, "source_s": source_s, "sent_utc_us": sent_utc_us,
			"position": [at.origin.x, at.origin.y, at.origin.z],
			"quaternion": [orientation.x, orientation.y, orientation.z, orientation.w],
			"linear": [linear.x, linear.y, linear.z], "angular": [angular.x, angular.y, angular.z]})
	# Bound retained history even if the receiver is paused by its caller.
	while _times.size() > 32:
		_times.pop_front()
		_poses.pop_front()
		_linear.pop_front()
		_angular.pop_front()


func advance(delta: float) -> void:
	if not is_instance_valid(bus):
		return
	if network_enabled and multiplayer.is_server():
		_source_s += delta
		_send_elapsed += delta
		if _send_elapsed + 0.000001 >= 1.0 / snapshot_hz:
			_send_elapsed = maxf(0.0, _send_elapsed - 1.0 / snapshot_hz)
			_receive.rpc(bus.global_transform, _source_s, bus.linear_velocity, bus.angular_velocity,
				int(Time.get_unix_time_from_system() * 1000000.0))
		return
	if _times.is_empty():
		return
	while _times.size() > 2 and _times[1] <= _playback_s:
		_times.pop_front()
		_poses.pop_front()
		_linear.pop_front()
		_angular.pop_front()
	var target: Transform3D = _latest
	_replicated_linear = _linear.back()
	_replicated_angular = _angular.back()
	if interpolate:
		if _playback_s > _last_source_s + 0.000001:
			buffer_underrun_ticks += 1
		target = _poses[0]
		_replicated_linear = _linear[0]
		_replicated_angular = _angular[0]
		if _times.size() > 1:
			var weight: float = clampf((_playback_s - _times[0]) / (_times[1] - _times[0]), 0.0, 1.0)
			target = _poses[0].interpolate_with(_poses[1], weight)
			_replicated_linear = _linear[0].lerp(_linear[1], weight)
			_replicated_angular = _angular[0].lerp(_angular[1], weight)
	last_write_distance_m = bus.global_position.distance_to(target.origin)
	last_write_playback_s = _playback_s
	bus.global_transform = target
	_playback_s += delta


func timing_sample() -> Array[float]:
	return [float(received_count), _last_source_s if received_count > 0 else _source_s, _playback_s, last_write_distance_m]


@rpc("authority", "call_remote", "unreliable_ordered")
func _receive(at: Transform3D, source_s: float, linear: Vector3, angular: Vector3, sent_utc_us: int) -> void:
	accept_snapshot(at, source_s, linear, angular, sent_utc_us)


static func point_velocity(body: RigidBody3D, point: Vector3) -> Vector3:
	var linear: Vector3 = body.linear_velocity
	var angular: Vector3 = body.angular_velocity
	if body.is_inside_tree():
		for node: Node in body.get_tree().get_nodes_in_group("net_bus_sync"):
			if node is NetBusSync:
				var sync: NetBusSync = node
				if sync.bus == body and sync.received_count > 0:
					linear = sync._replicated_linear
					angular = sync._replicated_angular
					break
	return linear + angular.cross(point - body.global_position)
