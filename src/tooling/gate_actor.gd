class_name GateActor
extends Node

## Scripted participant uses the same reliable requests and confirmed state as input.
var bus: Bus = null
var crew: CrewMember = null
var cargo: Node = null
var package_name: StringName
var anchor_name: StringName
var enabled: bool = false
var walking_only: bool = false
var stage: int = 0
var aisle_end: float = 2.0
var _cooldown: float = 0.0
var _held_walk_done: bool = false
var _eye: Camera3D = null
var _hands: CrewHands = null


func _ready() -> void:
	process_physics_priority = -200


func _physics_process(delta: float) -> void:
	if not enabled or crew == null or bus == null:
		return
	if walking_only:
		var local: Vector3 = bus.to_local(crew.global_position)
		if absf(local.z - aisle_end) < 0.18:
			aisle_end = -aisle_end
		var offset: Vector2 = Vector2(-local.x, aisle_end - local.z)
		crew.drive_move(offset.normalized() * 0.5, false, false, bus.global_basis)
		return
	if _eye == null:
		_eye = NetAuthority.scoped_eye(crew)
		_hands = crew.get_node_or_null("CrewHands") as CrewHands
	var package: Package = _package()
	var anchor: RestraintAnchor = _anchor()
	if package == null or anchor == null or _hands == null or _eye == null:
		return
	_cooldown = maxf(0.0, _cooldown - delta)
	var target: Vector3 = bus.to_local(package.global_position)
	if stage == 1:
		target = Vector3(0.0, -0.6, aisle_end) if not _held_walk_done else bus.to_local(anchor.global_position)
	elif stage == 2 or stage == 3:
		target = bus.to_local(anchor.global_position)
	target.x = clampf(target.x, -0.25, 0.25)
	target.z = clampf(target.z, -2.5, 2.5)
	var local: Vector3 = bus.to_local(crew.global_position)
	var offset: Vector2 = Vector2(target.x - local.x, target.z - local.z)
	var movement: Vector2 = offset.normalized() * 0.5 if offset.length() > 0.18 else Vector2.ZERO
	crew.drive_move(movement, false, false, bus.global_basis)
	var look_point: Vector3 = anchor.global_position if stage > 0 else package.global_position
	if _eye.global_position.distance_to(look_point) > 0.05:
		var direction: Vector3 = look_point - _eye.global_position
		crew.rotation.y = atan2(-direction.x, -direction.z)
		_eye.rotation = Vector3(atan2(direction.y, Vector2(direction.x, direction.z).length()), 0.0, 0.0)
	match stage:
		0:
			if package.restraint == Package.Restraint.HELD and package.held_by == crew:
				stage = 1
				_held_walk_done = false
			elif package.restraint == Package.Restraint.FREE and _cooldown == 0.0:
				cargo.call("send_hold", package_name)
				_cooldown = 0.5
		1:
			if not _held_walk_done and offset.length() < 0.22:
				_held_walk_done = true
			if package.restraint == Package.Restraint.STRAPPED:
				stage = 2
				_cooldown = 0.4
			elif _held_walk_done and offset.length() < 0.4 and _cooldown == 0.0:
				cargo.call("send_strap", package_name, anchor_name)
				_cooldown = 0.5
		2:
			if package.restraint == Package.Restraint.HELD and package.held_by == crew:
				stage = 3
				_cooldown = 0.4
			elif _cooldown == 0.0:
				cargo.call("send_unstrap", package_name)
				_cooldown = 0.5
		3:
			if package.restraint == Package.Restraint.FREE:
				stage = 0
				_cooldown = 0.4
			elif _cooldown == 0.0:
				_hands.drop()
				_cooldown = 0.5


func _package() -> Package:
	for node: Node in get_tree().get_nodes_in_group("package"):
		if node is Package and node.name == package_name:
			return node
	return null


func _anchor() -> RestraintAnchor:
	for node: Node in get_tree().get_nodes_in_group("restraint_anchor"):
		if node is RestraintAnchor and node.name == anchor_name:
			return node
	return null
