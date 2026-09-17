class_name NetCargoSync
extends Node

## RPCs live here, never on Package: straps change the package's NodePath.
## Only state replies assign authority; 20 Hz poses cannot change ownership.
signal packages_ready(count: int)

var bus: Bus = null
var network_enabled: bool = true
var snapshot_hz: float = 20.0
var _replica: NetCargoReplica = NetCargoReplica.new()
var _rules: NetCargoRules = NetCargoRules.new()
var _send_elapsed: float = 0.0
var _started: bool = false
var _requests: Array[Dictionary] = []


func _ready() -> void:
	add_to_group("net_cargo_sync")
	_replica.scene = get_parent()
	_replica.bus = bus
	_replica.host_mode = multiplayer.is_server() if multiplayer.has_multiplayer_peer() else true
	_rules.replica = _replica
	# Bus snapshots write at -100; free cargo must use that same bus pose.
	process_physics_priority = -90


func ready_count() -> int:
	return _replica.packages().size()


func motion_samples() -> Dictionary:
	return _replica.motion_samples.duplicate(true)


func publish_manifest() -> void:
	if not _is_host() or not is_instance_valid(bus):
		return
	var rows: Array[Dictionary] = _replica.manifest()
	_started = true
	if _has_peers():
		_receive_manifest.rpc(rows)
	packages_ready.emit(rows.size())


func activity_for_peer(peer_id: int) -> Dictionary:
	return _rules.activity_for_peer(peer_id)


func send_hold(package_name: StringName) -> void:
	if not network_enabled:
		return
	if _is_host():
		request_hold.call_deferred(package_name)
	else:
		request_hold.rpc_id(1, package_name)


func send_release(package_name: StringName, at_world: Transform3D, velocity_world: Vector3) -> void:
	if not network_enabled or not is_instance_valid(bus):
		return
	var at: Transform3D = bus.global_transform.affine_inverse() * at_world
	var velocity: Vector3 = NetCargoRules.velocity_to_bus(bus, at_world.origin, velocity_world)
	if _is_host():
		request_release.call_deferred(package_name, at, velocity)
	else:
		request_release.rpc_id(1, package_name, at, velocity)


func send_strap(package_name: StringName, anchor_name: StringName) -> void:
	if not network_enabled:
		return
	if _is_host():
		request_strap.call_deferred(package_name, anchor_name)
	else:
		request_strap.rpc_id(1, package_name, anchor_name)


func send_unstrap(package_name: StringName) -> void:
	if not network_enabled:
		return
	if _is_host():
		request_unstrap.call_deferred(package_name)
	else:
		request_unstrap.rpc_id(1, package_name)


@rpc("any_peer", "call_remote", "reliable")
func request_hold(package_name: StringName) -> void:
	if not _is_host():
		return
	_requests.append({"operation": "hold", "peer": _request_peer(), "name": package_name})


@rpc("any_peer", "call_remote", "reliable")
func request_release(package_name: StringName, at_bus_local: Transform3D, velocity_bus_local: Vector3) -> void:
	if not _is_host():
		return
	# Idle RPC polling follows the physics step but precedes rigid node sync.
	# Capture sender now; validate and release after sync on the next physics tick.
	_requests.append({"operation": "release", "peer": _request_peer(), "name": package_name,
		"at": at_bus_local, "velocity": velocity_bus_local})


@rpc("any_peer", "call_remote", "reliable")
func request_strap(package_name: StringName, anchor_name: StringName) -> void:
	if not _is_host():
		return
	_requests.append({"operation": "strap", "peer": _request_peer(), "name": package_name, "anchor": anchor_name})


@rpc("any_peer", "call_remote", "reliable")
func request_unstrap(package_name: StringName) -> void:
	if not _is_host():
		return
	_requests.append({"operation": "unstrap", "peer": _request_peer(), "name": package_name})


func _finish_request(peer_id: int, row: Dictionary) -> void:
	if not _has_peers():
		return
	if not row.is_empty():
		_receive_state.rpc(row)
	_receive_activity.rpc(peer_id, _rules.activity_for_peer(peer_id))


@rpc("authority", "call_remote", "reliable")
func _receive_manifest(rows: Array[Dictionary]) -> void:
	for row: Dictionary in rows:
		_replica.apply_state(row, true)
	_started = true
	packages_ready.emit(ready_count())


@rpc("authority", "call_remote", "reliable")
func _receive_state(row: Dictionary) -> void:
	_replica.apply_state(row)


@rpc("authority", "call_remote", "reliable")
func _receive_activity(peer_id: int, counts: Dictionary) -> void:
	_rules.accept_activity(peer_id, counts)


@rpc("authority", "call_remote", "unreliable_ordered")
func _receive_poses(rows: Array[Dictionary]) -> void:
	for row: Dictionary in rows:
		_replica.accept_pose(row)


@rpc("any_peer", "call_remote", "unreliable_ordered")
func _receive_held_poses(rows: Array[Dictionary]) -> void:
	if not _is_host():
		return
	var peer_id: int = multiplayer.get_remote_sender_id()
	for row: Dictionary in rows:
		_rules.accept_held_pose(peer_id, row)


func _physics_process(delta: float) -> void:
	if not network_enabled or not is_instance_valid(bus):
		return
	if _is_host():
		_apply_requests()
	_replica.prepare_packages()
	_replica.advance(delta, snapshot_hz)
	_send_elapsed += delta
	if not _started or _send_elapsed < 1.0 / snapshot_hz or not _has_peers():
		return
	_send_elapsed = fmod(_send_elapsed, 1.0 / snapshot_hz)
	var rows: Array[Dictionary] = []
	for package: Package in _replica.packages():
		if _is_host() or (package.restraint == Package.Restraint.HELD and package.is_multiplayer_authority()):
			rows.append(_replica.state_row(package))
	if _is_host():
		_receive_poses.rpc(rows)
	elif not rows.is_empty():
		_receive_held_poses.rpc_id(1, rows)


func _apply_requests() -> void:
	# One FIFO preserves reliable operation order across the deferred release.
	for request: Dictionary in _requests:
		var peer_id: int = request["peer"]
		var package_name: StringName = request["name"]
		var row: Dictionary = {}
		match request["operation"]:
			"hold": row = _rules.hold(peer_id, package_name)
			"unstrap": row = _rules.unstrap(peer_id, package_name)
			"strap":
				var anchor: StringName = request["anchor"]
				row = _rules.strap(peer_id, package_name, anchor)
			"release":
				var at: Transform3D = request["at"]
				var velocity: Vector3 = request["velocity"]
				row = _rules.release(peer_id, package_name, at, velocity)
		_finish_request(peer_id, row)
	_requests.clear()


func _is_host() -> bool:
	return network_enabled and _replica.host_mode


func _has_peers() -> bool:
	return multiplayer.has_multiplayer_peer() and not multiplayer.get_peers().is_empty()


func _request_peer() -> int:
	if not multiplayer.has_multiplayer_peer():
		return 1
	var remote: int = multiplayer.get_remote_sender_id()
	return remote if remote > 0 else multiplayer.get_unique_id()
