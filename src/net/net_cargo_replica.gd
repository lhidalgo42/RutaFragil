class_name NetCargoReplica
extends RefCounted

## Stable identity survives strap's reparent. State is reliable; a pose may
## only move a package whose state revision is already known locally.
var scene: Node = null
var bus: Bus = null
var host_mode: bool = false
var revisions: Dictionary = {}
var _buffers: Dictionary = {}
var motion_samples: Dictionary = {}


func packages() -> Array[Package]:
	var result: Array[Package] = []
	if not is_instance_valid(scene) or not scene.is_inside_tree():
		return result
	for node: Node in scene.get_tree().get_nodes_in_group("package"):
		if node is Package and scene.is_ancestor_of(node) and not node.is_queued_for_deletion():
			result.append(node)
	return result


func package_named(package_name: StringName) -> Package:
	for package: Package in packages():
		if package.name == package_name:
			return package
	return null


func anchor_named(anchor_name: StringName) -> RestraintAnchor:
	for node: Node in scene.get_tree().get_nodes_in_group("restraint_anchor"):
		if node is RestraintAnchor and node.name == anchor_name and bus.is_ancestor_of(node):
			return node
	return null


func prepare_packages() -> void:
	for package: Package in packages():
		if not package.network_enabled:
			package.configure_replication(bus, not host_mode)
		if not revisions.has(package.name):
			revisions[package.name] = 0


func state_row(package: Package) -> Dictionary:
	var at: Transform3D = bus.global_transform.affine_inverse() * package.global_transform
	var relative: Vector3 = package.linear_velocity - Package.rigid_point_velocity(
		bus.linear_velocity, bus.angular_velocity, package.global_position - bus.global_position)
	return {"name": package.name, "state": NetCargoReplica.as_int(package.restraint), "at": at,
		"velocity": bus.global_basis.inverse() * relative,
		"anchor": package.strapped_to.name if is_instance_valid(package.strapped_to) else &"",
		"holder": package.holder_peer_id, "revision": NetCargoReplica.as_int(revisions.get(package.name, 0))}


func manifest() -> Array[Dictionary]:
	prepare_packages()
	var rows: Array[Dictionary] = []
	for package: Package in packages():
		rows.append(state_row(package))
	return rows


func apply_state(row: Dictionary, allow_spawn: bool = false) -> bool:
	var package_name: StringName = row["name"]
	var revision: int = NetCargoReplica.as_int(row["revision"])
	if revision < NetCargoReplica.as_int(revisions.get(package_name, -1)):
		return false
	var package: Package = package_named(package_name)
	if package != null and revision == NetCargoReplica.as_int(revisions.get(package_name, -1)):
		return true
	if package == null and allow_spawn:
		package = _spawn(row)
	if package == null:
		return false
	var state: Package.Restraint = NetCargoReplica.as_int(row["state"]) as Package.Restraint
	var at: Transform3D = row["at"]
	var velocity: Vector3 = row["velocity"]
	var anchor: StringName = row["anchor"]
	var holder: int = NetCargoReplica.as_int(row["holder"])
	package.apply_replicated_state(state, at, velocity, anchor, holder)
	revisions[package_name] = revision
	_buffers.erase(package_name)
	motion_samples.erase(package_name)
	# Reliable FREE precedes its first unreliable pose. An aboard replica must
	# keep its bus frame during that gap, rather than become a world obstacle.
	if not host_mode and state == Package.Restraint.FREE and BusInterior.is_inside_local(at.origin):
		_buffers[package_name] = {"previous": at, "latest": at, "elapsed": 0.0}
	update_hands()
	return true


func accept_pose(row: Dictionary) -> bool:
	var package_name: StringName = row["name"]
	var package: Package = package_named(package_name)
	if package == null or NetCargoReplica.as_int(row["revision"]) != NetCargoReplica.as_int(revisions.get(package_name, -1)):
		return false
	if package.restraint == Package.Restraint.STRAPPED:
		return false
	if package.restraint == Package.Restraint.HELD and package.is_multiplayer_authority():
		return false
	var at: Transform3D = row["at"]
	var previous: Transform3D = bus.global_transform.affine_inverse() * package.global_transform
	if _buffers.has(package_name):
		var old: Dictionary = _buffers[package_name]
		previous = old["latest"]
	_buffers[package_name] = {"previous": previous, "latest": at, "elapsed": 0.0,
		"received_frame": Engine.get_physics_frames()}
	return true


func advance(delta: float, snapshot_hz: float) -> void:
	for package: Package in packages():
		package.refresh_replicated_holder()
		if not _buffers.has(package.name):
			continue
		if package.restraint == Package.Restraint.STRAPPED \
				or (package.restraint == Package.Restraint.FREE and host_mode) \
				or (package.restraint == Package.Restraint.HELD and package.is_multiplayer_authority()):
			continue
		var buffer: Dictionary = _buffers[package.name]
		var previous: Transform3D = buffer["previous"]
		var latest: Transform3D = buffer["latest"]
		var elapsed: float = NetCargoReplica.as_float(buffer["elapsed"]) + delta
		buffer["elapsed"] = elapsed
		var alpha: float = clampf(elapsed * snapshot_hz, 0.0, 1.0)
		var target_local: Transform3D = previous.interpolate_with(latest, alpha)
		var target: Transform3D = bus.global_transform * target_local
		motion_samples[package.name] = {"physics_frame": Engine.get_physics_frames(),
			"received_frame": buffer.get("received_frame", -1), "alpha": alpha,
			"previous_local": GateMetricsUtil.vector_array(previous.origin),
			"latest_local": GateMetricsUtil.vector_array(latest.origin),
			"target_local": GateMetricsUtil.vector_array(target_local.origin),
			"target_world": GateMetricsUtil.vector_array(target.origin),
			"before_write_world": GateMetricsUtil.vector_array(package.global_position)}
		package.global_transform = target
	update_hands()


func update_hands() -> void:
	var all_packages: Array[Package] = packages()
	for node: Node in scene.get_tree().get_nodes_in_group("crew_hands"):
		if not (node is CrewHands) or not scene.is_ancestor_of(node):
			continue
		var hands: CrewHands = node
		var member: Node = hands.get_parent()
		while member != null and not (member is CrewMember):
			member = member.get_parent()
		if not (member is CrewMember):
			continue
		var crew: CrewMember = member
		hands.held = null
		if not NetAuthority.is_local(crew):
			continue
		for package: Package in all_packages:
			if package.restraint == Package.Restraint.HELD \
					and package.held_by == crew:
				hands.held = package
				break


func _spawn(row: Dictionary) -> Package:
	var cargo: Node = scene.get_node_or_null("Cargo")
	if cargo == null:
		cargo = Node3D.new()
		cargo.name = "Cargo"
		scene.add_child(cargo)
	var packed: PackedScene = load("res://src/cargo/package.tscn") as PackedScene
	var package: Package = packed.instantiate() as Package
	package.name = row["name"]
	package.configure_replication(bus, true)
	var at: Transform3D = row["at"]
	var cargo_3d: Node3D = cargo as Node3D
	package.transform = cargo_3d.global_transform.affine_inverse() * bus.global_transform * at
	cargo.add_child(package, true)
	return package


static func as_int(raw: Variant) -> int:
	if raw is int:
		return raw
	return 0


static func as_float(raw: Variant) -> float:
	if raw is float:
		return raw
	if raw is int:
		var integer: int = raw
		return float(integer)
	return 0.0
