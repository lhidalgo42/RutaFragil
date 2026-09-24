class_name BusDoors
extends Node3D

## Host-authoritative physical doors. Animation advances only on physics ticks;
## the visual model reads progress without owning gameplay state.
enum DoorPhase { OPEN, CLOSING, CLOSED, OPENING }

const SIDE: StringName = &"side"
const REAR: StringName = &"rear"
const IDS: Array[StringName] = [SIDE, REAR]
const SIDE_HANDLE: Vector3 = Vector3(1.2, 0.35, -1.75)
const REAR_HANDLE: Vector3 = Vector3(0.0, 0.35, 3.85)
const OCCUPANT_MASK: int = 0b110
## Closing checks every volume the moving leaf can reach, not only the final
## blocker: a person stepping into the swing must reverse it before contact.
const SIDE_SWEEP_CENTER: Vector3 = Vector3(1.29, 0.35, -1.27)
const SIDE_SWEEP_SIZE: Vector3 = Vector3(0.18, 1.9, 1.86)
const REAR_SWEEP_CENTER: Vector3 = Vector3(0.0, 0.35, 4.28)
const REAR_SWEEP_SIZE: Vector3 = Vector3(2.64, 1.9, 0.86)

@export_range(0.01, 10.0, 0.01) var side_duration_s: float = 0.7
@export_range(0.01, 10.0, 0.01) var rear_duration_s: float = 0.8
@export var side_initially_open: bool = true
@export var rear_initially_open: bool = true

var _side_phase: int = DoorPhase.OPEN
var _rear_phase: int = DoorPhase.OPEN
var _side_progress: float = 1.0
var _rear_progress: float = 1.0


func _ready() -> void:
	add_to_group("bus_doors")
	_set_initial(SIDE, side_initially_open)
	_set_initial(REAR, rear_initially_open)
	_sync_blockers.call_deferred()
	var backend: Node = get_tree().root.get_node_or_null("NetworkBackend")
	if backend != null and backend.has_signal("peer_ready") \
			and not backend.is_connected("peer_ready", _on_peer_ready):
		backend.connect("peer_ready", _on_peer_ready)
	_doors_connected.call_deferred()


func _exit_tree() -> void:
	var backend: Node = get_tree().root.get_node_or_null("NetworkBackend")
	if backend != null and backend.has_signal("peer_ready") \
			and backend.is_connected("peer_ready", _on_peer_ready):
		backend.disconnect("peer_ready", _on_peer_ready)


static func step(current_phase: int, current_progress: float, delta: float, duration: float) -> Array:
	var next_phase: int = current_phase
	var next_progress: float = clampf(current_progress, 0.0, 1.0)
	var amount: float = maxf(delta, 0.0) / maxf(duration, 0.000001)
	if current_phase == DoorPhase.CLOSING:
		next_progress = maxf(0.0, next_progress - amount)
		if is_zero_approx(next_progress):
			next_phase = DoorPhase.CLOSED
	elif current_phase == DoorPhase.OPENING:
		next_progress = minf(1.0, next_progress + amount)
		if is_equal_approx(next_progress, 1.0):
			next_phase = DoorPhase.OPEN
	return [next_phase, next_progress]


func phase(door_id: StringName) -> int:
	return _side_phase if door_id == SIDE else _rear_phase if door_id == REAR else -1


func progress(door_id: StringName) -> float:
	return _side_progress if door_id == SIDE else _rear_progress if door_id == REAR else 1.0


func handle_position(door_id: StringName) -> Vector3:
	var local: Vector3 = SIDE_HANDLE if door_id == SIDE else REAR_HANDLE
	return global_transform * local


func nearest_handle(from: Vector3, reach_m: float) -> StringName:
	var best: StringName = &""
	var best_distance: float = reach_m
	for door_id: StringName in IDS:
		var distance: float = from.distance_to(handle_position(door_id))
		if distance <= best_distance:
			best = door_id
			best_distance = distance
	return best


func can_toggle(door_id: StringName, crew: CrewMember) -> bool:
	if not IDS.has(door_id) or not is_instance_valid(crew):
		return false
	if phase(door_id) != DoorPhase.OPEN and phase(door_id) != DoorPhase.CLOSED:
		return false
	var tuning: TuningTable = GameConfig.tuning
	return tuning != null \
		and crew.global_position.distance_to(handle_position(door_id)) <= tuning.interaction_reach_m


func send_toggle(door_id: StringName) -> void:
	if _is_host():
		_toggle_for_peer(door_id, _request_peer())
	else:
		request_toggle.rpc_id(1, door_id)


func try_toggle(door_id: StringName, crew: CrewMember) -> bool:
	if not _is_host() or not can_toggle(door_id, crew):
		return false
	if phase(door_id) == DoorPhase.OPEN:
		return host_close(door_id)
	_set_blocker(door_id, false)
	_set_state(door_id, DoorPhase.OPENING, 0.0)
	_publish_state(door_id)
	return true


func host_close(door_id: StringName) -> bool:
	if not _is_host() or not IDS.has(door_id) or phase(door_id) != DoorPhase.OPEN \
			or _obstructed(door_id) or _sweep_obstructed(door_id):
		return false
	_set_state(door_id, DoorPhase.CLOSING, 1.0)
	_publish_state(door_id)
	return true


func publish_snapshot() -> void:
	if not _is_host() or not multiplayer.has_multiplayer_peer():
		return
	for peer_id: int in multiplayer.get_peers():
		_send_snapshot(peer_id)


@rpc("any_peer", "call_remote", "reliable")
func request_toggle(door_id: StringName) -> void:
	if _is_host():
		_toggle_for_peer(door_id, _request_peer())


@rpc("authority", "call_remote", "reliable")
func _receive_state(door_id: StringName, new_phase: int, new_progress: float) -> void:
	apply_state(door_id, new_phase, new_progress)


func apply_state(door_id: StringName, new_phase: int, new_progress: float) -> bool:
	if not IDS.has(door_id) or new_phase < DoorPhase.OPEN or new_phase > DoorPhase.OPENING:
		return false
	_set_state(door_id, new_phase, clampf(new_progress, 0.0, 1.0))
	return true


func _physics_process(delta: float) -> void:
	_advance(SIDE, delta)
	_advance(REAR, delta)


func _advance(door_id: StringName, delta: float) -> void:
	var old_phase: int = phase(door_id)
	if old_phase != DoorPhase.CLOSING and old_phase != DoorPhase.OPENING:
		return
	var result: Array = step(old_phase, progress(door_id), delta, _duration(door_id))
	var next_phase: int = int(result[0])
	var next_progress: float = float(result[1])
	if old_phase == DoorPhase.CLOSING and _is_host() \
			and (_sweep_obstructed(door_id) or next_phase == DoorPhase.CLOSED and _obstructed(door_id)):
		_set_state(door_id, DoorPhase.OPENING, next_progress)
		_publish_state(door_id)
		return
	_set_state(door_id, next_phase, next_progress)
	if next_phase != old_phase:
		_publish_state(door_id)


func _toggle_for_peer(door_id: StringName, peer_id: int) -> void:
	var crew: CrewMember = NetAuthority.crew_for_peer(get_tree(), peer_id)
	try_toggle(door_id, crew)


func _set_initial(door_id: StringName, open: bool) -> void:
	_set_state(door_id, DoorPhase.OPEN if open else DoorPhase.CLOSED, 1.0 if open else 0.0)


func _set_state(door_id: StringName, new_phase: int, new_progress: float) -> void:
	if door_id == SIDE:
		_side_phase = new_phase
		_side_progress = new_progress
	elif door_id == REAR:
		_rear_phase = new_phase
		_rear_progress = new_progress
	_set_blocker(door_id, new_phase == DoorPhase.CLOSED)


func _duration(door_id: StringName) -> float:
	return side_duration_s if door_id == SIDE else rear_duration_s


func _blocker(door_id: StringName) -> CollisionShape3D:
	var name: String = "SideDoorBlocker" if door_id == SIDE else "RearDoorBlocker"
	return get_node_or_null(NodePath("Blockers/" + name)) as CollisionShape3D


func _set_blocker(door_id: StringName, enabled: bool) -> void:
	var blocker: CollisionShape3D = _blocker(door_id)
	if blocker == null:
		return
	# Enabling is immediate: the CLOSED phase and its collision must appear in
	# the same physics step, never one deferred frame apart.
	blocker.disabled = not enabled


func _obstructed(door_id: StringName) -> bool:
	var blocker: CollisionShape3D = _blocker(door_id)
	if blocker == null or blocker.shape == null or not is_inside_tree():
		return true
	return _shape_occupied(blocker.shape, blocker.global_transform)


func _sweep_obstructed(door_id: StringName) -> bool:
	if not is_inside_tree():
		return true
	var box: BoxShape3D = BoxShape3D.new()
	box.size = SIDE_SWEEP_SIZE if door_id == SIDE else REAR_SWEEP_SIZE
	var center: Vector3 = SIDE_SWEEP_CENTER if door_id == SIDE else REAR_SWEEP_CENTER
	return _shape_occupied(box, global_transform * Transform3D(Basis.IDENTITY, center))


func _shape_occupied(shape: Shape3D, at: Transform3D) -> bool:
	var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = at
	query.collision_mask = OCCUPANT_MASK
	return not get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()


func _sync_blockers() -> void:
	_set_blocker(SIDE, phase(SIDE) == DoorPhase.CLOSED)
	_set_blocker(REAR, phase(REAR) == DoorPhase.CLOSED)


func _publish_state(door_id: StringName) -> void:
	if _is_host() and _has_peers():
		_receive_state.rpc(door_id, phase(door_id), progress(door_id))


func _send_snapshot(peer_id: int) -> void:
	if not _is_host() or not multiplayer.has_multiplayer_peer():
		return
	for door_id: StringName in IDS:
		_receive_state.rpc_id(peer_id, door_id, phase(door_id), progress(door_id))


func _on_peer_ready(peer_id: int) -> void:
	_send_snapshot(peer_id)


func _sync_existing_peers() -> void:
	publish_snapshot()


func _doors_connected() -> void:
	publish_snapshot()
	var backend: Node = get_tree().root.get_node_or_null("NetworkBackend")
	if backend != null and backend.has_signal("peer_ready"):
		# Ready state is host-owned. poll instead of peer_ready: a rejoined peer
		# id is already present in ready_peers, so the signal may never fire.
		var ready_v: Variant = backend.get("ready_peers")
		if ready_v is Array:
			for id_v: Variant in ready_v:
				if id_v is int and multiplayer.get_peers().has(int(id_v)):
					_send_snapshot(int(id_v))


func _is_host() -> bool:
	return not multiplayer.has_multiplayer_peer() or multiplayer.is_server()


func _has_peers() -> bool:
	return multiplayer.has_multiplayer_peer() and not multiplayer.get_peers().is_empty()


func _request_peer() -> int:
	if not multiplayer.has_multiplayer_peer():
		return 1
	var remote: int = multiplayer.get_remote_sender_id()
	return remote if remote > 0 else multiplayer.get_unique_id()
