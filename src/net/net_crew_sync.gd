class_name NetCrewSync
extends Node

signal crew_ready(peer_id: int)

const CREW_SCENE_PATH: String = "res://src/crew/crew_member.tscn"

var bus: Bus = null
var network_enabled: bool = true
var snapshot_hz: float = 30.0
var snapshots_sent: int = 0
var snapshots_received: int = 0
var ready_peers: PackedInt32Array = []

var _crews: Node3D = null
var _spawner: MultiplayerSpawner = null
var _pending_initial: Dictionary[int, Transform3D] = {}
var _poses: Dictionary[int, NetCrewPose] = {}
var _interaction_hands: Dictionary[int, Transform3D] = {}
var _hand_in_bus: Dictionary[int, bool] = {}
var _send_elapsed: float = 0.0
var _expected_count: int = 0
var _ready_sent: bool = false


func _ready() -> void:
	add_to_group("net_crew_sync")
	process_physics_priority = 50
	_crews = Node3D.new()
	_crews.name = "Crews"
	get_parent().add_child.call_deferred(_crews)
	_finish_setup.call_deferred()


func _finish_setup() -> void:
	_spawner = MultiplayerSpawner.new()
	_spawner.name = "CrewSpawner"
	_spawner.spawn_limit = GameConfig.max_players
	add_child(_spawner)
	_spawner.spawn_path = _spawner.get_path_to(_crews)
	_spawner.add_spawnable_scene(CREW_SCENE_PATH)
	_spawner.spawned.connect(_on_spawned)


func is_setup_ready() -> bool:
	return _spawner != null


func spawn_crews(peer_ids: Array[int]) -> void:
	if not _is_host() or not is_instance_valid(bus):
		return
	# Setup is deferred only during the parent's _ready cascade.
	if _spawner == null:
		spawn_crews.call_deferred(peer_ids)
		return
	var ids: Array[int] = []
	for peer_id: int in peer_ids:
		if peer_id > 0 and peer_id not in ids and ids.size() < GameConfig.max_players:
			ids.append(peer_id)
	ids.sort()
	_expected_count = ids.size()
	var packed: PackedScene = load(CREW_SCENE_PATH) as PackedScene
	for index: int in range(ids.size()):
		var peer_id: int = ids[index]
		var member: CrewMember = packed.instantiate()
		member.name = "Crew_%d" % peer_id
		var span: float = 3.2 if ids.size() <= 2 else 5.6
		var z: float = -span * 0.5 + span * float(index) / float(maxi(1, ids.size() - 1))
		var at: Transform3D = Transform3D(Basis.IDENTITY, Vector3(0.0, -0.6, z))
		member.position = bus.global_transform * at.origin
		member.set_multiplayer_authority(peer_id)
		member.set_collision_disabled(true)
		_crews.add_child(member, true)
		_receive_initial(peer_id, at, _expected_count)
		if _network_live():
			_receive_initial.rpc(peer_id, at, _expected_count)


func ready_count() -> int:
	var count: int = 0
	if not is_instance_valid(_crews):
		return count
	for node: Node in _crews.get_children():
		if node is CrewMember:
			var member: CrewMember = node
			if member.network_ready:
				count += 1
	return count


func peers_ready_count() -> int:
	return ready_peers.size()


func _on_spawned(_node: Node) -> void:
	_apply_pending_initial()


func _physics_process(delta: float) -> void:
	advance(delta)


func advance(delta: float) -> void:
	_apply_pending_initial()
	for peer_id: int in _poses:
		var member: CrewMember = _member(peer_id)
		if member != null and member.network_ready and not NetAuthority.is_local(member):
			var pose: NetCrewPose = _poses[peer_id]
			pose.apply(member, delta, snapshot_hz)
	if not _network_live():
		return
	_send_elapsed += delta
	if _send_elapsed < 1.0 / snapshot_hz:
		return
	_send_elapsed = fmod(_send_elapsed, 1.0 / snapshot_hz)
	var local: CrewMember = NetAuthority.local_crew(get_tree())
	if local == null or not local.network_ready:
		return
	var eye: Camera3D = NetAuthority.scoped_eye(local)
	var pitch: float = eye.rotation.x if eye != null else 0.0
	_receive_pose.rpc(local.get_multiplayer_authority(), local.global_transform, pitch, bus.global_transform)
	snapshots_sent += 1


func accept_snapshot(peer_id: int, at: Transform3D, eye_pitch: float) -> void:
	var member: CrewMember = _member(peer_id)
	if member == null or NetAuthority.is_local(member):
		return
	if not _poses.has(peer_id):
		_poses[peer_id] = NetCrewPose.new()
	var pose: NetCrewPose = _poses[peer_id]
	pose.accept(at, eye_pitch)
	snapshots_received += 1


@rpc("authority", "call_remote", "reliable")
func _receive_initial(peer_id: int, at_bus_local: Transform3D, total: int) -> void:
	_expected_count = total
	_pending_initial[peer_id] = at_bus_local
	_apply_pending_initial()


func _apply_pending_initial() -> void:
	if not is_instance_valid(bus):
		return
	for peer_id: int in _pending_initial.keys():
		var member: CrewMember = _member(peer_id)
		if member == null or not member.is_node_ready():
			continue
		member.set_collision_disabled(true)
		var initial: Transform3D = _pending_initial[peer_id]
		member.global_transform = bus.global_transform * initial
		member.velocity = Vector3.ZERO
		member.aboard = true
		member.network_ready = true
		member.set_collision_disabled(false)
		_pending_initial.erase(peer_id)
		crew_ready.emit(peer_id)
	if _expected_count > 0 and ready_count() == _expected_count and not _ready_sent:
		_ready_sent = true
		if _is_host():
			ready_peers.append(1)
		elif _network_live():
			_ack_ready.rpc_id(1)


@rpc("any_peer", "call_remote", "reliable")
func _ack_ready() -> void:
	if not _is_host():
		return
	var peer_id: int = multiplayer.get_remote_sender_id()
	if _member(peer_id) != null and peer_id not in ready_peers:
		ready_peers.append(peer_id)


@rpc("any_peer", "call_remote", "unreliable_ordered")
func _receive_pose(peer_id: int, at: Transform3D, eye_pitch: float, source_bus: Transform3D) -> void:
	if multiplayer.get_remote_sender_id() == peer_id:
		accept_snapshot(peer_id, at, eye_pitch)
		accept_interaction_frame(peer_id, at, eye_pitch, source_bus)


func accept_interaction_frame(peer_id: int, at: Transform3D, pitch: float, source_bus: Transform3D) -> void:
	var member: CrewMember = _member(peer_id)
	if member == null or NetAuthority.is_local(member) or not at.is_finite() \
			or not source_bus.is_finite() or not is_finite(pitch) \
			or absf(source_bus.basis.determinant()) < 0.0001:
		return
	var eye: Camera3D = NetAuthority.scoped_eye(member)
	var hand: Node3D = eye.get_node_or_null("HandAnchor") as Node3D if eye != null else null
	if hand == null:
		return
	var hand_at: Transform3D = at * Transform3D(Basis(Vector3.RIGHT, pitch), eye.position) * hand.transform
	var inside: bool = BusInterior.is_inside_local(source_bus.affine_inverse() * at.origin)
	_interaction_hands[peer_id] = source_bus.affine_inverse() * hand_at if inside else hand_at
	_hand_in_bus[peer_id] = inside


func has_interaction_hand(peer_id: int) -> bool:
	return _interaction_hands.has(peer_id)


func interaction_hand_world(peer_id: int) -> Transform3D:
	var at: Transform3D = _interaction_hands[peer_id]
	# Rendering retains the world snapshot; reach checks follow its bus frame.
	return bus.global_transform * at if _hand_in_bus[peer_id] else at


func _member(peer_id: int) -> CrewMember:
	if not is_instance_valid(_crews):
		return null
	return _crews.get_node_or_null("Crew_%d" % peer_id) as CrewMember


func _is_host() -> bool:
	return not multiplayer.has_multiplayer_peer() or multiplayer.is_server()


func _network_live() -> bool:
	return network_enabled and multiplayer.has_multiplayer_peer() \
		and not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer) \
		and multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED
