class_name CrewHands
extends Node

## The crew's hands (D82, D83, D86): one package at a time, following the
## HandAnchor (child of the eye camera, so the hold pitches with the look).
##
## E is a DURATION detector measured in ticks (D86): tap = grab / unstrap /
## seat; hold (strap_hold_seconds, with a package in hand and a free anchor
## in reach) = strap. strap_progress(fraction) is emitted while holding, for
## the future HUD (D29). PRIORITY with a package in hand: an E tap targets
## anchors or nothing — the seat is REJECTED with a print and no effect
## (nobody drives while carrying). An E tap on a STRAPPED package with an
## empty hand unstraps it back to the hand.
## throw (left click) / drop (right click) only act with the pointer
## captured; a click with a FREE pointer only re-captures (crew_input owns
## capture) and NEVER throws.
##
## Implementation notes: the nodes are found by GROUP (D59), never by path —
## "crew", "eye_camera", then the HandAnchor child of that camera. The hold
## follow is a plain global_transform write every physics tick: HELD is
## kinematic with collision OFF (Package.hold owns that), so the carried box
## never depenetrates the hull it rides in (the round-4 seat lesson).

signal strap_progress(fraction: float)

var held: Package = null

var _crew: CrewMember = null
var _eye: Camera3D = null
var _hand: Marker3D = null
var _missing_reported: bool = false
var _strap_anchor: RestraintAnchor = null
var _strap_elapsed: float = 0.0
## Latched when a strap completes so CrewInput can tell "E released after a
## finished strap" (press spent, no tap) apart from "E released early"
## (cancel + tap) — without it the release would instantly unstrap the box.
var _strap_completed: bool = false


func _ready() -> void:
	add_to_group("crew_hands")
	_find_nodes.call_deferred()


func _physics_process(delta: float) -> void:
	if held != null and _hand != null:
		held.global_transform = _hand.global_transform
	if _strap_anchor != null:
		_accumulate_strap(delta)


## Grabs the nearest FREE package within interaction_reach_m of the eye ray.
## Precondition: held == null.
func try_grab() -> bool:
	if held != null or not _nodes_ready():
		return false
	var target: Package = closest_to_ray(
		_packages_with_restraint(Package.Restraint.FREE),
		_hand.global_position, _eye.global_position, -_eye.global_basis.z, _reach_m())
	if target == null:
		return false
	if not target.hold(_crew):
		return false
	held = target
	return true


## Unstraps the STRAPPED package best aligned with the look ray, back to the
## hand. Precondition: held == null.
func try_unstrap() -> bool:
	if held != null or not _nodes_ready():
		return false
	var target: Package = closest_to_ray(
		_packages_with_restraint(Package.Restraint.STRAPPED),
		_hand.global_position, _eye.global_position, -_eye.global_basis.z, _reach_m())
	if target == null:
		return false
	target.unstrap()
	held = target
	return true


## Releases the held package with care: at the hand point if the box fits
## there (overlap test), else at the feet on the floor; velocity = the
## bus-point velocity (v + w x r) so it is not slammed. Package.release()
## owns the place-then-enable order.
func drop() -> void:
	if held == null or not _nodes_ready():
		return
	var package: Package = held
	held = null
	_cancel_strap_state()
	var at: Transform3D = _free_drop_transform(package)
	package.release(at, _bus_point_velocity(at.origin))


## Throws: velocity = camera forward * package_throw_speed_mps + the
## bus-point velocity. The composition is a PURE function, tested without
## physics.
func throw() -> void:
	if held == null or not _nodes_ready():
		return
	var tuning: TuningTable = GameConfig.tuning
	if tuning == null:
		push_error("CrewHands: GameConfig.tuning is null; not throwing")
		return
	var package: Package = held
	held = null
	_cancel_strap_state()
	var at: Transform3D = _hand.global_transform
	var velocity: Vector3 = throw_velocity(
		_eye.global_basis, tuning.package_throw_speed_mps, _bus_point_velocity(at.origin))
	package.release(at, velocity)


## Starts the strap hold (E held with a package in hand and a free anchor in
## reach). Emits strap_progress as the hold accumulates in physics ticks.
func begin_strap() -> void:
	_strap_completed = false
	if held == null or _hand == null:
		return
	var anchor: RestraintAnchor = nearest_free_anchor_in_reach()
	if anchor == null:
		return
	_strap_anchor = anchor
	_strap_elapsed = 0.0


## Cancels the hold (E released before strap_hold_seconds) — nothing changes.
func cancel_strap() -> void:
	_cancel_strap_state()


## True while an E hold is accumulating toward the strap.
func is_strapping() -> bool:
	return _strap_anchor != null


## Reads (and clears) the strap-completed latch: true exactly once after a
## hold reached strap_hold_seconds and the strap landed.
func consume_strap_completed() -> bool:
	var done: bool = _strap_completed
	_strap_completed = false
	return done


## The throw composition (D83), pure: camera forward is -z of the basis.
static func throw_velocity(camera_basis: Basis, throw_speed: float, bus_point_velocity: Vector3) -> Vector3:
	return -camera_basis.z * throw_speed + bus_point_velocity


## Target choice, pure (no physics, no tree state read beyond the candidates'
## positions): among the candidates within reach_m of the HAND, the winner is
## the one closest to the look RAY (perpendicular distance of the package
## center to the camera line); ties break by distance to the hand.
## ray_direction must be unit length.
static func closest_to_ray(candidates: Array[Package], hand_position: Vector3, ray_origin: Vector3, ray_direction: Vector3, reach_m: float) -> Package:
	var best: Package = null
	var best_radial: float = INF
	var best_dist: float = INF
	for package: Package in candidates:
		if package == null:
			continue
		var dist: float = hand_position.distance_to(package.global_position)
		if dist > reach_m:
			continue
		var from_ray: Vector3 = package.global_position - ray_origin
		var along: float = from_ray.dot(ray_direction)
		var radial: float = (from_ray - ray_direction * along).length()
		if radial < best_radial - 0.0001 \
				or (absf(radial - best_radial) <= 0.0001 and dist < best_dist):
			best = package
			best_radial = radial
			best_dist = dist
	return best


## Nearest free restraint anchor within interaction_reach_m of the hand.
func nearest_free_anchor_in_reach() -> RestraintAnchor:
	if _hand == null:
		return null
	var reach: float = _reach_m()
	var best: RestraintAnchor = null
	var best_dist: float = reach
	for node: Node in get_tree().get_nodes_in_group("restraint_anchor"):
		if node is RestraintAnchor:
			var anchor: RestraintAnchor = node
			if not anchor.is_free():
				continue
			var dist: float = _hand.global_position.distance_to(anchor.global_position)
			if dist <= best_dist:
				best = anchor
				best_dist = dist
	return best


func _find_nodes() -> void:
	var crew_node: Node = get_tree().get_first_node_in_group("crew")
	if crew_node is CrewMember:
		_crew = crew_node
	var eye_node: Node = get_tree().get_first_node_in_group("eye_camera")
	if eye_node is Camera3D:
		_eye = eye_node
		var hand_node: Node = _eye.get_node_or_null("HandAnchor")
		if hand_node is Marker3D:
			_hand = hand_node
	_nodes_ready()


func _nodes_ready() -> bool:
	if _crew == null or _eye == null or _hand == null:
		if not _missing_reported:
			_missing_reported = true
			push_error("CrewHands: crew, eye_camera or HandAnchor missing; hands disabled")
		return false
	return true


func _reach_m() -> float:
	var tuning: TuningTable = GameConfig.tuning
	if tuning == null:
		push_error("CrewHands: GameConfig.tuning is null; reach is zero")
		return 0.0
	return tuning.interaction_reach_m


## Packages live anywhere in the scene (cargo racks, the road, the floor):
## there is no package group, so the candidates are found by TYPE scan.
func _packages_with_restraint(want: Package.Restraint) -> Array[Package]:
	var found: Array[Package] = []
	_collect_packages(get_tree().root, want, found)
	return found


func _collect_packages(node: Node, want: Package.Restraint, found: Array[Package]) -> void:
	if node is Package:
		var package: Package = node
		if package.restraint == want:
			found.append(package)
	for child: Node in node.get_children():
		_collect_packages(child, want, found)


func _accumulate_strap(delta: float) -> void:
	var tuning: TuningTable = GameConfig.tuning
	if tuning == null or tuning.strap_hold_seconds <= 0.0:
		push_error("CrewHands: GameConfig.tuning missing strap_hold_seconds; strap cancelled")
		_cancel_strap_state()
		return
	_strap_elapsed += delta
	strap_progress.emit(clampf(_strap_elapsed / tuning.strap_hold_seconds, 0.0, 1.0))
	if _strap_elapsed < tuning.strap_hold_seconds:
		return
	var anchor: RestraintAnchor = _strap_anchor
	_cancel_strap_state()
	# The anchor may have been taken during the hold: strap() fails then and
	# the package simply stays in the hand.
	if held != null and held.strap(anchor):
		held = null
		_strap_completed = true


func _cancel_strap_state() -> void:
	_strap_anchor = null
	_strap_elapsed = 0.0


## The drop point (D83): the hand transform if the box fits there, else the
## floor under the crew's feet. The hand test excludes ONLY the box itself —
## if the hand pokes into her own capsule (looking straight down) the drop
## must fall back, not depenetrate her. The feet placement excludes the crew:
## she is standing exactly there.
func _free_drop_transform(package: Package) -> Transform3D:
	var shape: Shape3D = _package_shape(package)
	var hand_at: Transform3D = _hand.global_transform
	if shape != null and _shape_fits(shape, hand_at, [package.get_rid()]):
		return hand_at
	var half_height: float = 0.2
	if shape is BoxShape3D:
		var box: BoxShape3D = shape
		half_height = box.size.y * 0.5
	var exclude: Array[RID] = [package.get_rid(), _crew.get_rid()]
	var space: PhysicsDirectSpaceState3D = _hand.get_world_3d().direct_space_state
	var ray_from: Vector3 = _crew.global_position + Vector3(0.0, half_height + 0.1, 0.0)
	var ray: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		ray_from, ray_from + Vector3(0.0, -4.0, 0.0), 0b011, exclude)
	var hit: Dictionary = space.intersect_ray(ray)
	var feet_origin: Vector3 = _crew.global_position + Vector3(0.0, half_height + 0.02, 0.0)
	if not hit.is_empty():
		var hit_position: Variant = hit["position"]
		if hit_position is Vector3:
			var point: Vector3 = hit_position
			feet_origin = point + Vector3(0.0, half_height + 0.02, 0.0)
	# Keep the crew's yaw so the box lands square with her, not camera-pitched.
	var basis: Basis = Basis(Vector3(0.0, 1.0, 0.0), _crew.rotation.y)
	return Transform3D(basis, feet_origin)


## Overlap probe for the box shape at `at`, mask world + cargo + crew
## (layers 1 and 2; the crew capsule lives on layer 1).
func _shape_fits(shape: Shape3D, at: Transform3D, exclude: Array[RID]) -> bool:
	var params: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	params.shape = shape
	params.transform = at
	params.collision_mask = 0b011
	params.exclude = exclude
	var hits: Array[Dictionary] = _hand.get_world_3d().direct_space_state.intersect_shape(params, 1)
	return hits.is_empty()


## The box's own collision shape (D81's 0.4 m greybox), for the drop probe.
func _package_shape(package: Package) -> Shape3D:
	for child: Node in package.get_children():
		if child is CollisionShape3D:
			var collision: CollisionShape3D = child
			if collision.shape != null:
				return collision.shape
	return null


## The velocity of the bus point the package is released at (D83): v + w x r
## when aboard, zero on foot outside (dropping on the roadside adds nothing).
func _bus_point_velocity(point: Vector3) -> Vector3:
	if _crew == null or not _crew.aboard:
		return Vector3.ZERO
	var bus_node: Node = get_tree().get_first_node_in_group("bus")
	if bus_node is RigidBody3D:
		var bus: RigidBody3D = bus_node
		return bus.linear_velocity + bus.angular_velocity.cross(point - bus.global_position)
	return Vector3.ZERO
