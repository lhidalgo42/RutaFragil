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

var restraint: Restraint = Restraint.FREE
var held_by: CrewMember = null
var strapped_to: RestraintAnchor = null


## Precondition: restraint == FREE. Fails (false) on HELD or STRAPPED (an
## anchored package is unstrapped first — never grabbed off the anchor).
## Disables collision and goes kinematic; the HandAnchor follow runs every
## physics tick from CrewHands.
func hold(_by: CrewMember) -> bool:
	return false


## Releases at `at` with `velocity`. The FULL pair lives HERE — place,
## unfreeze, set velocity, enable collision deferred — so the order can never
## split between two owners (coordinator decision, round-1 approval).
## Precondition: restraint == HELD. `at` is a free point the caller computed
## with an overlap test; a caller passing an occupied point is a bug.
func release(_at: Transform3D, _velocity: Vector3) -> void:
	pass


## Precondition: restraint == HELD and anchor.is_free(). Reparents to the bus
## at the anchor — position fixed BEFORE the reparent — frozen kinematic,
## collision ON. One package per anchor. Drift vs the anchor is zero by
## construction and measured anyway.
func strap(_anchor: RestraintAnchor) -> bool:
	return false


## Back to the hand (precondition: restraint == STRAPPED and the caller's
## hand is empty). The anchor frees and the package is HELD again.
func unstrap() -> void:
	pass
