class_name Package
extends RigidBody3D

## A cargo box (D81): a 0.4 m greybox box, mass from TuningTable
## .package_mass_kg, collision layer 2 (cargo), mask world + cargo + crew.
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
var _original_parent: Node = null

var _shape: CollisionShape3D = null
var _damping_k: float = 0.0
var _bus: Bus = null
var _grace_ticks: int = 0


func _ready() -> void:
	freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
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


## The bus by GROUP, never by name (D59); no bus in the scene turns the
## damper off (and strap fails).
func _find_bus() -> Bus:
	if _bus != null and is_instance_valid(_bus):
		return _bus
	var node: Node = get_tree().get_first_node_in_group("bus")
	if node is Bus:
		_bus = node
	return _bus
