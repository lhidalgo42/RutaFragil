class_name Package
extends RigidBody3D

## A cargo box (D81): an authored 0.4 m BoxShape3D collider, mass from
## TuningTable.package_mass_kg, collision layer 2 (cargo), mask world + cargo
## + crew. The visual is a separate instanced .glb (M-ART,
## assets/models/package_clean_v1.glb); the physics never reads it (§10.1.3).
## The three physical states of ADR-003: FREE (real RigidBody3D in world
## space), HELD (kinematic, collision OFF, follows the HandAnchor every
## physics tick), STRAPPED (frozen kinematic child of the bus at a
## RestraintAnchor, collision ON so the crew bumps into it like a shelf).
## No contents, types or integrity (M3). One package per hand, one per anchor.
##
## Physics rules that are NOT negotiable (T2.2 measurements):
## - position BEFORE entering the tree and BEFORE re-enabling collision;
## - release() performs the whole pair itself: place at `at`, unfreeze, set
##   velocity, THEN re-enable collision deferred — CrewHands only computes
##   the free point (overlap test) and the velocity;
## - HELD keeps collision OFF (a kinematic body with collision inside the
##   hull kicks the bus every tick — the round-4 seat bug);
## - the relative-velocity damper (D85, measured on the lap): while FREE and
##   inside the hull (BusInterior.is_inside_local on the bus frame), each
##   physics tick applies -k * v_rel but ONLY the component along the bus's
##   up axis (vertical: that is what ejects cargo over the bumps; horizontal
##   sliding under braking IS the game — §5.3's 2-3 m/s impacts need it).
##   v_rel = v_box - (v_bus + w x r). k = TuningTable
##   .package_relative_damping_ns_per_m. GRACE after release(): no damper
##   until the first contact or 30 ticks, whichever first, so drop/throw are
##   not damped mid-air.

enum Restraint { FREE, HELD, STRAPPED }

signal restraint_changed(from: Restraint, to: Restraint)

## Damper grace after release() (D85): a throw is not damped mid-air; the
## first contact ends the grace early.
const RELEASE_GRACE_TICKS: int = 30

var restraint: Restraint = Restraint.FREE
var held_by: CrewMember = null
var strapped_to: RestraintAnchor = null
var holder_peer_id: int = 0
var network_enabled: bool = false
var replica_only: bool = false
var physics_simulation_ticks: int = 0
var integration_callback_ticks: int = 0
var unauthorized_simulation_ticks: int = 0
var _original_parent: Node = null

var _shape: CollisionShape3D = null
var _damping_k: float = 0.0
var _bus: Bus = null
var _grace_ticks: int = 0


func _ready() -> void:
	add_to_group("package")
	freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC if replica_only else RigidBody3D.FREEZE_MODE_STATIC
	if network_enabled and replica_only:
		freeze = true
	_original_parent = get_parent()
	# get_contact_count() — what ends the release grace early — never
	# reports without this.
	max_contacts_reported = maxi(max_contacts_reported, 1)
	# By TYPE, not by node name (r4.2 of T2.2): an art rename must not
	# silently strip the collision logic.
	for child: Node in get_children():
		if child is CollisionShape3D:
			_shape = child
	if _shape == null:
		push_error("Package: missing CollisionShape3D child")
	var tuning: TuningTable = GameConfig.tuning
	if tuning == null:
		push_error("Package: GameConfig.tuning is null; authored mass kept, damper off")
		return
	mass = tuning.package_mass_kg
	_damping_k = tuning.package_relative_damping_ns_per_m


## The bus-point velocity at a world offset (v + w x r): the damper's
## reference, and the same composition CrewHands uses for drop/throw.
static func rigid_point_velocity(body_linear: Vector3, body_angular: Vector3, offset: Vector3) -> Vector3:
	return body_linear + body_angular.cross(offset)


## The D85 damper as a PURE function: only the component along the bus's up
## axis is opposed, and ONLY when it is POSITIVE (the box rising relative to
## the bus — that is what ejects cargo over the bumps). Sinking is left to
## gravity: opposing the whole vertical component gave the box a terminal
## velocity of m*g/k = 8*9.8/160 = 0.49 m/s (measured in review 01: boxes
## "falling like in water", a 0.73 m drop taking 1.5 s instead of 0.39 s).
## Horizontal sliding under braking is the game (§5.3 needs it).
static func vertical_damping_force(box_velocity: Vector3, point_velocity: Vector3, up: Vector3, k: float) -> Vector3:
	var relative: Vector3 = box_velocity - point_velocity
	var vertical_speed: float = relative.dot(up)
	if vertical_speed <= 0.0:
		return Vector3.ZERO
	return up * (-k * vertical_speed)


## Precondition: restraint == FREE. Fails (false) on HELD or STRAPPED (an
## anchored package is unstrapped first — never grabbed off the anchor).
## Disables collision and goes kinematic; the HandAnchor follow runs every
## physics tick from CrewHands.
func hold(by: CrewMember) -> bool:
	if restraint != Restraint.FREE or _shape == null:
		return false
	var from: Restraint = restraint
	restraint = Restraint.HELD
	held_by = by
	freeze = true
	_shape.disabled = true
	# Ordered AFTER any release() enable still pending in the deferred queue
	# (a same-frame release-then-hold): the last deferred write wins.
	_shape.set_deferred("disabled", true)
	restraint_changed.emit(from, restraint)
	return true


## Releases at `at` with `velocity`. The FULL pair lives HERE — place,
## unfreeze, set velocity, enable collision deferred — so the order can never
## split between two owners (coordinator decision, round-1 approval).
## Precondition: restraint == HELD. `at` is a free point the caller computed
## with an overlap test; a caller passing an occupied point is a bug.
func release(at: Transform3D, velocity: Vector3) -> void:
	if restraint != Restraint.HELD or _shape == null:
		push_error("Package.release: precondition violated (restraint %d)" % restraint)
		return
	var from: Restraint = restraint
	restraint = Restraint.FREE
	held_by = null
	_grace_ticks = RELEASE_GRACE_TICKS
	global_transform = at
	freeze = false
	linear_velocity = velocity
	angular_velocity = Vector3.ZERO
	_shape.set_deferred("disabled", false)
	restraint_changed.emit(from, restraint)


## Precondition: restraint == HELD and anchor.is_free(). Reparents to the bus
## at the anchor — position fixed BEFORE the reparent — frozen kinematic,
## collision ON. One package per anchor. Drift vs the anchor is zero by
## construction and measured anyway.
func strap(anchor: RestraintAnchor) -> bool:
	if restraint != Restraint.HELD or _shape == null:
		return false
	if anchor == null or not anchor.is_free():
		return false
	var bus: Bus = _find_bus()
	if bus == null:
		push_error("Package.strap: no node in group 'bus'")
		return false
	var from: Restraint = restraint
	# r1.4: remember the original parent so unstrap() returns to it (the
	# Cargo node), not to the bus's parent (the Playground) — that mattered
	# for M4's MultiplayerSpawner watching a concrete node.
	_original_parent = get_parent()
	restraint = Restraint.STRAPPED
	strapped_to = anchor
	held_by = null
	anchor.occupant = self
	# Pose fixed BEFORE the reparent (the measured rule); the reparent keeps
	# the global pose, so the anchor's bus-local transform becomes ours.
	global_transform = anchor.global_transform
	reparent(bus)
	freeze = true
	_shape.disabled = false
	restraint_changed.emit(from, restraint)
	return true


## Back to the hand (precondition: restraint == STRAPPED and the caller's
## hand is empty). The anchor frees and the package is HELD again.
func unstrap() -> void:
	if restraint != Restraint.STRAPPED or _shape == null:
		push_error("Package.unstrap: precondition violated (restraint %d)" % restraint)
		return
	var from: Restraint = restraint
	var anchor: RestraintAnchor = strapped_to
	restraint = Restraint.HELD
	strapped_to = null
	if anchor != null:
		anchor.occupant = null
	# Back to the ORIGINAL parent with the pose preserved (r1.4); CrewHands
	# drives the transform from the next physics tick on.
	if _original_parent != null and is_instance_valid(_original_parent):
		reparent(_original_parent)
	_shape.disabled = true
	restraint_changed.emit(from, restraint)


func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	integration_callback_ticks += 1
	var mode: PhysicsServer3D.BodyMode = PhysicsServer3D.body_get_mode(get_rid())
	if mode != PhysicsServer3D.BODY_MODE_RIGID and mode != PhysicsServer3D.BODY_MODE_RIGID_LINEAR:
		return
	physics_simulation_ticks += 1
	if network_enabled and (replica_only or not is_multiplayer_authority()):
		unauthorized_simulation_ticks += 1
		freeze = true
		return
	if restraint != Restraint.FREE or _damping_k <= 0.0:
		return
	if _grace_ticks > 0:
		if state.get_contact_count() > 0:
			_grace_ticks = 0
		else:
			_grace_ticks -= 1
			return
	var bus: Bus = _find_bus()
	if bus == null:
		return
	var origin: Vector3 = state.transform.origin
	var local: Vector3 = bus.global_transform.affine_inverse() * origin
	if not BusInterior.is_inside_local(local):
		return
	var up: Vector3 = bus.global_transform.basis.y.normalized()
	var reference: Vector3 = rigid_point_velocity(
		bus.linear_velocity, bus.angular_velocity, origin - bus.global_position)
	var force: Vector3 = vertical_damping_force(state.linear_velocity, reference, up, _damping_k)
	state.apply_central_force(force)


## Configure BEFORE add_child on replicas: no solver tick may see a dynamic
## client box. Single-player physics and restraint methods stay unchanged.
func configure_replication(bus: Bus, only_replica: bool) -> void:
	network_enabled = true
	replica_only = only_replica
	_bus = bus
	freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC if only_replica else RigidBody3D.FREEZE_MODE_STATIC
	if only_replica:
		freeze = true
	if is_inside_tree() and restraint != Restraint.STRAPPED:
		_original_parent = get_parent()


## State delivery is independent of the old state, including STRAPPED ->
## FREE. Authority and holder travel with it; snapshots cannot grant either.
func apply_replicated_state(state: Restraint, at_bus_local: Transform3D,
		velocity_bus_local: Vector3, anchor_name: StringName, peer_id: int) -> void:
	var bus: Bus = _find_bus()
	if bus == null or _shape == null:
		return
	var anchor: RestraintAnchor = _replicated_anchor(anchor_name) if state == Restraint.STRAPPED else null
	if state == Restraint.STRAPPED and anchor == null:
		return
	var from: Restraint = restraint
	var next_holder: int = peer_id if state == Restraint.HELD else 0
	var changed: bool = from != state or holder_peer_id != next_holder or strapped_to != anchor
	if is_instance_valid(strapped_to) and strapped_to != anchor and strapped_to.occupant == self:
		strapped_to.occupant = null
	freeze = true
	_shape.disabled = true
	# State transitions are teleports, not one-tick platform motion from the
	# hand to the floor. STATIC places the physical body immediately in Jolt;
	# continuous replica snapshots resume KINEMATIC movement afterwards.
	if replica_only:
		freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
	if state != Restraint.STRAPPED and is_instance_valid(_original_parent) and get_parent() != _original_parent:
		reparent(_original_parent)
	restraint = state
	holder_peer_id = next_holder
	held_by = NetAuthority.crew_for_peer(get_tree(), next_holder) if next_holder > 0 else null
	strapped_to = anchor
	set_multiplayer_authority(next_holder if next_holder > 0 else 1)
	global_transform = bus.global_transform * at_bus_local
	if state == Restraint.STRAPPED:
		anchor.occupant = self
		global_transform = anchor.global_transform
		if get_parent() != bus:
			reparent(bus)
	elif state == Restraint.FREE:
		if changed:
			_grace_ticks = RELEASE_GRACE_TICKS
		freeze = replica_only or not is_multiplayer_authority()
		if not freeze:
			linear_velocity = bus.global_basis * velocity_bus_local + rigid_point_velocity(
				bus.linear_velocity, bus.angular_velocity, global_position - bus.global_position)
			angular_velocity = Vector3.ZERO
	if replica_only:
		force_update_transform()
		freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	# Last deferred write wins over an earlier transition in the same frame.
	_shape.set_deferred("disabled", state == Restraint.HELD)
	if changed:
		restraint_changed.emit(from, state)


func refresh_replicated_holder() -> void:
	if restraint == Restraint.HELD and holder_peer_id > 0 and not is_instance_valid(held_by):
		held_by = NetAuthority.crew_for_peer(get_tree(), holder_peer_id)


func _replicated_anchor(anchor_name: StringName) -> RestraintAnchor:
	for node: Node in get_tree().get_nodes_in_group("restraint_anchor"):
		if node is RestraintAnchor and node.name == anchor_name and _bus.is_ancestor_of(node):
			return node
	return null


## The bus by GROUP, never by name (D59); no bus in the scene turns the
## damper off (and strap fails).
func _find_bus() -> Bus:
	if _bus != null and is_instance_valid(_bus):
		return _bus
	var node: Node = get_tree().get_first_node_in_group("bus")
	if node is Bus:
		_bus = node
	return _bus
