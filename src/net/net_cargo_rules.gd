class_name NetCargoRules
extends RefCounted

## The server uses these same validators for local and RPC requests. Counts
## describe accepted transitions, not input events or optimistic client state.
var replica: NetCargoReplica = null
var _activity: Dictionary = {}
var _cycles: Dictionary = {}


func activity_for_peer(peer_id: int) -> Dictionary:
	if not _activity.has(peer_id):
		_activity[peer_id] = {"hold_requested": 0, "hold_granted": 0, "hold_denied": 0,
			"release": 0, "strap_ok": 0, "strap_denied": 0, "unstrap": 0,
			"authority_transfers": 0, "complete_cycles": 0}
	var counts: Dictionary = _activity[peer_id]
	return counts.duplicate()


func accept_activity(peer_id: int, counts: Dictionary) -> void:
	_activity[peer_id] = counts.duplicate()


func hold(peer_id: int, package_name: StringName) -> Dictionary:
	_bump(peer_id, "hold_requested")
	var package: Package = replica.package_named(package_name)
	if package == null or package.restraint != Package.Restraint.FREE \
			or not _empty_hand(peer_id) or not _in_reach(peer_id, package.global_position):
		_bump(peer_id, "hold_denied")
		return {}
	_bump(peer_id, "hold_granted")
	_cycles[package_name] = {"peer": peer_id, "stage": 1}
	return _change(peer_id, package, Package.Restraint.HELD,
		replica.bus.global_transform.affine_inverse() * _hand_transform(peer_id),
		Vector3.ZERO, &"", peer_id)


func release(peer_id: int, package_name: StringName, at: Transform3D, velocity: Vector3) -> Dictionary:
	var package: Package = replica.package_named(package_name)
	if not _owns_held(peer_id, package) or not at.is_finite() or not velocity.is_finite():
		return {}
	var world_at: Transform3D = replica.bus.global_transform * at
	if not _in_reach(peer_id, world_at.origin) or not NetCargoPlacement.fits(package, world_at):
		return {}
	var tuning: TuningTable = GameConfig.tuning
	var max_speed: float = tuning.package_throw_speed_mps + tuning.player_sprint_speed_mps
	var world_velocity: Vector3 = replica.bus.global_basis * velocity \
		+ Package.rigid_point_velocity(replica.bus.linear_velocity,
			replica.bus.angular_velocity, world_at.origin - replica.bus.global_position)
	# A ground drop has zero world speed, even beside a moving bus.
	if velocity.length() > max_speed \
			and (BusInterior.is_inside_local(at.origin) or world_velocity.length() > max_speed):
		return {}
	_bump(peer_id, "release")
	if _cycle_stage(peer_id, package_name) == 3:
		_bump(peer_id, "complete_cycles")
	_cycles.erase(package_name)
	return _change(peer_id, package, Package.Restraint.FREE, at, velocity, &"", 0)


func strap(peer_id: int, package_name: StringName, anchor_name: StringName) -> Dictionary:
	var package: Package = replica.package_named(package_name)
	var anchor: RestraintAnchor = replica.anchor_named(anchor_name)
	if not _owns_held(peer_id, package) or anchor == null or not anchor.is_free() \
			or not _in_reach(peer_id, anchor.global_position):
		_bump(peer_id, "strap_denied")
		return {}
	_bump(peer_id, "strap_ok")
	if _cycle_stage(peer_id, package_name) == 1:
		_cycles[package_name] = {"peer": peer_id, "stage": 2}
	return _change(peer_id, package, Package.Restraint.STRAPPED,
		replica.bus.global_transform.affine_inverse() * anchor.global_transform,
		Vector3.ZERO, anchor_name, 0)


func unstrap(peer_id: int, package_name: StringName) -> Dictionary:
	var package: Package = replica.package_named(package_name)
	if package == null or package.restraint != Package.Restraint.STRAPPED \
			or not _empty_hand(peer_id) or not _in_reach(peer_id, package.global_position):
		return {}
	_bump(peer_id, "unstrap")
	if _cycle_stage(peer_id, package_name) == 2:
		_cycles[package_name] = {"peer": peer_id, "stage": 3}
	else:
		_cycles.erase(package_name)
	return _change(peer_id, package, Package.Restraint.HELD,
		replica.bus.global_transform.affine_inverse() * _hand_transform(peer_id),
		Vector3.ZERO, &"", peer_id)


func accept_held_pose(peer_id: int, row: Dictionary) -> bool:
	var raw_name: Variant = row.get("name")
	var raw_at: Variant = row.get("at")
	var raw_revision: Variant = row.get("revision")
	var package_name: StringName = &""
	if raw_name is StringName:
		package_name = raw_name
	elif raw_name is String:
		var name_text: String = raw_name
		package_name = StringName(name_text)
	else:
		return false
	if not (raw_at is Transform3D) or not (raw_revision is int):
		return false
	var at: Transform3D = raw_at
	var revision: int = raw_revision
	var package: Package = replica.package_named(package_name)
	if not _owns_held(peer_id, package) or not at.is_finite() \
			or revision != NetCargoReplica.as_int(replica.revisions.get(package_name, -1)):
		return false
	if not _in_reach(peer_id, replica.bus.global_transform * at.origin):
		return false
	return replica.accept_pose(row)


static func velocity_to_bus(bus: Bus, point: Vector3, world_velocity: Vector3) -> Vector3:
	var point_velocity: Vector3 = NetBusSync.point_velocity(bus, point)
	return bus.global_basis.inverse() * (world_velocity - point_velocity)


func _change(peer_id: int, package: Package, state: Package.Restraint,
		at: Transform3D, velocity: Vector3, anchor: StringName, holder: int) -> Dictionary:
	var old_authority: int = package.get_multiplayer_authority()
	var revision: int = NetCargoReplica.as_int(replica.revisions.get(package.name, 0)) + 1
	var row: Dictionary = {"name": package.name, "state": NetCargoReplica.as_int(state), "at": at,
		"velocity": velocity, "anchor": anchor, "holder": holder, "revision": revision}
	if not replica.apply_state(row):
		return {}
	if old_authority != package.get_multiplayer_authority():
		_bump(peer_id, "authority_transfers")
	return row


func _hand(peer_id: int) -> Node3D:
	var member: CrewMember = NetAuthority.crew_for_peer(replica.scene.get_tree(), peer_id)
	if member == null or not replica.scene.is_ancestor_of(member):
		return null
	var eye: Camera3D = NetAuthority.scoped_eye(member)
	return eye.get_node_or_null("HandAnchor") as Node3D if eye != null else null


func _in_reach(peer_id: int, point: Vector3) -> bool:
	var hand: Node3D = _hand(peer_id)
	return hand != null and _hand_transform(peer_id).origin.distance_to(point) <= GameConfig.tuning.interaction_reach_m


func _hand_transform(peer_id: int) -> Transform3D:
	for node: Node in replica.scene.get_tree().get_nodes_in_group("net_crew_sync"):
		if node is NetCrewSync and replica.scene.is_ancestor_of(node):
			var sync: NetCrewSync = node
			if sync.has_interaction_hand(peer_id):
				return sync.interaction_hand_world(peer_id)
	return _hand(peer_id).global_transform


func _empty_hand(peer_id: int) -> bool:
	if _hand(peer_id) == null:
		return false
	for package: Package in replica.packages():
		if package.restraint == Package.Restraint.HELD and package.holder_peer_id == peer_id:
			return false
	return true


func _owns_held(peer_id: int, package: Package) -> bool:
	return package != null and package.restraint == Package.Restraint.HELD \
		and package.holder_peer_id == peer_id and package.get_multiplayer_authority() == peer_id \
		and _hand(peer_id) != null


func _bump(peer_id: int, field: String) -> void:
	var counts: Dictionary = activity_for_peer(peer_id)
	counts[field] = NetCargoReplica.as_int(counts[field]) + 1
	_activity[peer_id] = counts


func _cycle_stage(peer_id: int, package_name: StringName) -> int:
	var cycle: Dictionary = _cycles.get(package_name, {})
	return NetCargoReplica.as_int(cycle.get("stage", 0)) if NetCargoReplica.as_int(cycle.get("peer", 0)) == peer_id else 0
