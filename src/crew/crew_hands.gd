class_name CrewHands
extends Node

## The crew's hands (D82, D83, D86): one package at a time, following the
## HandAnchor (child of the eye camera, so the hold pitches with the look).
##
## The eye belongs to this pair of hands' parent, never another peer. The hold
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
var _pending_strap: Package = null


func _ready() -> void:
	add_to_group("crew_hands")
	_find_nodes.call_deferred()


func _physics_process(delta: float) -> void:
	if not _nodes_ready():
		return
	_refresh_strap_confirmation()
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
	var sync: Node = _network_sync()
	if sync != null:
		sync.call("send_hold", target.name)
		return true
	if not target.hold(_crew):
		return false
	held = target
	return true


## The package of the given restraint state best aligned with the look ray
## within reach (null when none): the reticle-rule accessor, same selection
## as try_grab/try_unstrap but with no side effects.
func ray_best_package(restraint_value: Package.Restraint) -> Package:
	if not _nodes_ready():
		return null
	return closest_to_ray(
		_packages_with_restraint(restraint_value),
		_hand.global_position, _eye.global_position, -_eye.global_basis.z, _reach_m())


## Distance from the hand to the nearest FREE package (INF when none or the
## nodes are not ready). The tap priority (seat vs grab) compares this
## against the seat's distance — the closest interactable wins.
func nearest_free_package_distance() -> float:
	if not _nodes_ready():
		return INF
	var best: float = INF
	for pkg: Package in _packages_with_restraint(Package.Restraint.FREE):
		best = minf(best, _hand.global_position.distance_to(pkg.global_position))
	return best


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
	var sync: Node = _network_sync()
	if sync != null:
		sync.call("send_unstrap", target.name)
		return true
	target.unstrap()
	held = target
	return true


## Releases the held package with care: at the hand point if the box fits
## there (overlap test), else at a clear floor point beside the feet; velocity = the
## bus-point velocity (v + w x r) so it is not slammed. Package.release()
## owns the place-then-enable order.
func drop() -> void:
	if held == null or not _nodes_ready():
		return
	var package: Package = held
	_cancel_strap_state()
	var candidates: Array[Transform3D] = NetCargoPlacement.find_drop(package, _crew, _hand, _reach_m())
	if candidates.is_empty():
		return
	var at: Transform3D = candidates[0]
	var sync: Node = _network_sync()
	if sync != null:
		sync.call("send_release", package.name, at, _bus_point_velocity(at.origin))
		return
	held = null
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
	_cancel_strap_state()
	var at: Transform3D = _hand.global_transform
	if not NetCargoPlacement.fits(package, at) or not NetCargoPlacement.unobstructed(package, _crew, at.origin):
		return
	var velocity: Vector3 = throw_velocity(
		_eye.global_basis, tuning.package_throw_speed_mps, _bus_point_velocity(at.origin))
	var sync: Node = _network_sync()
	if sync != null:
		sync.call("send_release", package.name, at, velocity)
		return
	held = null
	package.release(at, velocity)


## Starts the strap hold (E held with a package in hand and a free anchor in
## reach). Emits strap_progress as the hold accumulates in physics ticks.
func begin_strap() -> void:
	_strap_completed = false
	_pending_strap = null
	if held == null or not _nodes_ready():
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
## Latch for the E-release after a completed strap: without it, letting E go
## once the strap finished fired a tap that instantly unstrapped the very
## package just strapped (measured by agent B while wiring the duration
## detector). Consumed once by the tap handler.
func consume_strap_completed() -> bool:
	_refresh_strap_confirmation()
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
	var crew_node: Node = get_parent()
	if crew_node is CrewMember:
		_crew = crew_node
	var eye_node: Node = NetAuthority.scoped_eye(_crew)
	if eye_node is Camera3D:
		_eye = eye_node
		var hand_node: Node = _eye.get_node_or_null("HandAnchor")
		if hand_node is Marker3D:
			_hand = hand_node


func _nodes_ready() -> bool:
	if not is_instance_valid(_crew) or not is_instance_valid(_eye) or not is_instance_valid(_hand):
		_find_nodes()
	if _crew == null or _eye == null or _hand == null:
		if not _missing_reported:
			_missing_reported = true
			push_error("CrewHands: crew, eye_camera or HandAnchor missing; hands disabled")
		return false
	return NetAuthority.is_local(_crew) and _crew.network_ready \
		and (not _crew.network_member or _network_sync() != null)


func _network_sync() -> Node:
	if _crew == null or not _crew.network_member:
		return null
	return get_tree().get_first_node_in_group("net_cargo_sync")


func _refresh_strap_confirmation() -> void:
	if is_instance_valid(_pending_strap) and _pending_strap.restraint != Package.Restraint.HELD:
		_strap_completed = _pending_strap.restraint == Package.Restraint.STRAPPED
		_pending_strap = null


func _reach_m() -> float:
	var tuning: TuningTable = GameConfig.tuning
	if tuning == null:
		push_error("CrewHands: GameConfig.tuning is null; reach is zero")
		return 0.0
	return tuning.interaction_reach_m


## A strapped package changes parent but retains its identity group.
func _packages_with_restraint(want: Package.Restraint) -> Array[Package]:
	var found: Array[Package] = []
	for node: Node in get_tree().get_nodes_in_group("package"):
		if node is Package:
			var package: Package = node
			if package.restraint == want:
				found.append(package)
	return found


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
	var sync: Node = _network_sync()
	if sync != null and held != null:
		_pending_strap = held
		sync.call("send_strap", held.name, anchor.name)
		return
	# The anchor may have been taken during the hold: strap() fails then and
	# the package simply stays in the hand.
	if held != null and held.strap(anchor):
		held = null
		_strap_completed = true


func _cancel_strap_state() -> void:
	_strap_anchor = null
	_strap_elapsed = 0.0


## The velocity of the bus point the package is released at (D83): v + w x r
## when aboard, zero on foot outside (dropping on the roadside adds nothing).
func _bus_point_velocity(point: Vector3) -> Vector3:
	if _crew == null or not _crew.aboard:
		return Vector3.ZERO
	var bus_node: Node = get_tree().get_first_node_in_group("bus")
	if bus_node is RigidBody3D:
		var bus: RigidBody3D = bus_node
		return NetBusSync.point_velocity(bus, point)
	return Vector3.ZERO
