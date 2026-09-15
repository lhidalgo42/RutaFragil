class_name Seat
extends Node

## The driver's seat, minimal form (D76): on interact, the crew member is
## hidden and frozen, the camera goes to the cabin and the driving input turns
## on; on the second interact, the reverse. One occupant, no network, no
## CoopInteractable (that is M3). Cameras and inputs are found by GROUP, never
## by node name (D59/D63); cameras go through the CameraArbiter (D79).
## Round 4: sitting disables the crew's collision shape and standing moves her
## to the SAVED point (bus-local, restored with the bus's CURRENT transform)
## BEFORE the shape is re-enabled — a capsule teleported into the hull with
## an active shape depenetrated the bus every tick (the owner's gate: the bus
## rocked and swerved when driving seated). Standing while driving inherits
## the bus-point velocity so the floor does not escape under her feet.

signal occupied(seat_name: String)
signal vacated(seat_name: String)

@export var seat_name: String = "driver"
@export var seat_marker: Marker3D

## Where standing puts the crew when the saved point is not inside the hull
## (r4.3: a poisoned point on the roof kicked the bus to 16 rad/s, measured).
## Verified free of the interior's shapes with an overlap probe.
const CORRIDOR_FALLBACK_LOCAL: Vector3 = Vector3(0.0, -0.55, -2.0)

var occupied_by: CrewMember = null
## Where the occupant stood, in the bus's local frame (test-visible state).
var saved_local_position: Vector3 = Vector3.ZERO
var _has_saved_position: bool = false
## r4.1: while seated, the body is DRAGGED to the marker every physics tick —
## without it the crew stayed at the world point where she sat and the bus
## left her 30+ m behind (invisible today, a lie in M4). The flag exists
## because the drag may only start after the deferred pair (shape off, then
## move): dragging with the shape still active is the overlap bug again.
var _dragging: bool = false


## The interior bounds (D67/D72) live in ONE place now (BusInterior.
## is_inside_local): Seat's restore validation and Package's damper gate call
## it; two copies of the limits would drift apart.
func _is_inside_interior(local: Vector3) -> bool:
	return BusInterior.is_inside_local(local)


func _ready() -> void:
	# CrewInput finds the seats by GROUP, never by node path (D59 style).
	add_to_group("seat")


func occupy(member: CrewMember) -> bool:
	if occupied_by != null or member == null:
		return false
	var bus_node: Node = get_tree().get_first_node_in_group("bus")
	if bus_node != null and not member.aboard:
		# With a real bus in the scene the seat is only taken from aboard:
		# the marker sits ~1.1 m from the outer skin and the reach is 2.5 m,
		# so E goes through the wall from outside (measured in round 4) and
		# the restore point would land outside the hull. Unit tests without a
		# bus are unaffected.
		return false
	occupied_by = member
	member.set_seated(true)
	member.visible = false
	if bus_node is RigidBody3D:
		var bus: RigidBody3D = bus_node
		saved_local_position = bus.global_transform.affine_inverse() * member.global_position
		_has_saved_position = true
	if seat_marker != null:
		# Deferred as one pair: the shape goes off BEFORE the body moves, so
		# no solver tick ever sees the capsule overlapped with the hull.
		call_deferred("_apply_seat_transform", seat_marker.global_position)
	_set_driving_ui(true)
	occupied.emit(seat_name)
	return true


func vacate() -> void:
	if occupied_by == null:
		return
	var member: CrewMember = occupied_by
	occupied_by = null
	var bus_node: Node = get_tree().get_first_node_in_group("bus")
	if bus_node is RigidBody3D and _has_saved_position:
		var bus: RigidBody3D = bus_node
		# Move FIRST, to the saved point in the bus's CURRENT frame — or to the
		# corridor fallback if the saved point is not inside the hull (r4.3).
		var target_local: Vector3 = saved_local_position
		if not _is_inside_interior(target_local):
			target_local = CORRIDOR_FALLBACK_LOCAL
		member.global_position = bus.global_transform * target_local
		# ...inherit the bus-point velocity (standing up at 50 km/h with zero
		# velocity would slam her against the rear wall), ...
		member.velocity = bus.linear_velocity + bus.angular_velocity.cross(member.global_position - bus.global_position)
		# ...and only then, next frame, re-enable the shape. Enabling it at
		# the marker inside the roof is the round-3 gate bug all over again.
		member.call_deferred("set_collision_disabled", false)
		member.aboard = true
	member.set_seated(false)
	member.visible = true
	_dragging = false
	_set_driving_ui(false)
	vacated.emit(seat_name)


func _physics_process(_delta: float) -> void:
	if _dragging and occupied_by != null and seat_marker != null:
		occupied_by.global_position = seat_marker.global_position


## Deferred occupy transform: disable first, then move (never an overlapped
## tick with an active shape).
func _apply_seat_transform(target: Vector3) -> void:
	if occupied_by == null:
		return
	occupied_by.set_collision_disabled(true)
	occupied_by.global_position = target
	_dragging = true


func _set_driving_ui(driving: bool) -> void:
	var tree: SceneTree = get_tree()
	# The arbiter owns the camera switch (M2-T2.2 r3): seated goes to the
	# bus view, standing up returns the crew member's own eyes — that return
	# was the bug this round closes.
	if driving:
		CameraArbiter.apply(tree, CameraArbiter.Mode.SEATED)
	else:
		CameraArbiter.apply(tree, CameraArbiter.Mode.ON_FOOT)
	var bus_input: Node = tree.get_first_node_in_group("bus_input")
	if bus_input != null:
		bus_input.set("enabled", driving)
	var crew_input: Node = tree.get_first_node_in_group("crew_input")
	if crew_input != null:
		crew_input.set("enabled", not driving)
