class_name CrewInput
extends Node

## Crew input → CrewMember (D73): reads the on-foot actions and calls
## CrewMember.drive_move with the camera-relative wish direction. The member
## never reads Input itself (headless delivers no keyboard InputEvents, but
## Input.action_press/release DO drive the action state — measured by the
## reviewer 2026-09-14 — so tests exercise this node for real).
## Sprint = walk_sprint (Shift), jump = walk_jump (Space), per §9.2's style.
## interact (E) is a DURATION detector (D86): a TAP (press + release before
## strap_hold_seconds) grabs a free package / unstraps a strapped one to the
## hand / toggles the nearest seat, in that priority; a HOLD with a package
## in hand and a free anchor in reach straps (CrewHands owns the progress).
## With a package in hand the tap never seats: the seat is rejected with a
## print and no effect (nobody drives while carrying — owner's priority).
## interact is read whenever the member is seated even with enabled=false,
## because Seat clears `enabled` exactly while seated (D76): gating interact
## on `enabled` would lock the crew in the seat (the round-1 lesson: a wire
## nobody calls does not exist). The press edge is detected by hand
## (is_action_pressed + last-tick state) — and so is the release edge.
## is_action_just_pressed is NOT visible in the same call that pressed the
## action, but it DOES reach a node's _physics_process when press and release
## land in different physics ticks (measured 2026-09-14: 20/20); the manual
## edge stays as a defense against refresh rates that alias a tap away.
## Mouse look (§9.2): Escape always frees the pointer, a left click captures
## it back while capture is allowed, and motion yaws the body + pitches the
## eye camera only with the mouse captured (free pointer = parked look).
## Capture state is tracked in `_captured` (this node OWNS it; BusInput reads
## it from here): the headless DisplayServer does NOT retain
## Input.mouse_mode — set CAPTURED, read back VISIBLE (measured 2026-09-14) —
## so gating on the engine flag would make the wiring untestable headless.
## Every capture change still writes Input.mouse_mode for the real runs.
## throw (left) / drop (right) arrive as ACTIONS (mouse buttons are in the
## input map) and act ONLY with the pointer captured and a package in hand.
## A click with a FREE pointer only re-captures and never throws (D83):
## _set_captured swallows any throw/drop press already in flight, so the
## recapture click produces no edge in the physics poll.

@export var enabled: bool = false

var _crew: CrewMember = null
var _interact_was_held: bool = false
var _throw_was_held: bool = false
var _drop_was_held: bool = false
var _captured: bool = false
var _capture_allowed: bool = false
var _eye: Camera3D = null
var _eye_missing_reported: bool = false
var _hands: CrewHands = null


func _ready() -> void:
	add_to_group("crew_input")
	_find_crew.call_deferred()


## Mouse capture entry point, owned by the playground (the mode owner):
## player mode calls set_mouse_captured(true) at start and when F1 leaves the
## demo; the demo calls set_mouse_captured(false) so the cursor stays free.
## `_capture_allowed` is the preference memory click-to-recapture checks.
func set_mouse_captured(captured: bool) -> void:
	_capture_allowed = captured
	_set_captured(captured)


## The capture truth other nodes read (BusInput's cabin look): this node owns
## it because the engine flag cannot hold it in headless (see header).
func is_pointer_captured() -> bool:
	return _captured


func _set_captured(captured: bool) -> void:
	_captured = captured
	if captured:
		# The click that recaptures must NEVER throw (D83): swallow whatever
		# throw/drop press is already in flight, so the physics poll below
		# sees no edge from the recapture click.
		_throw_was_held = Input.is_action_pressed("throw")
		_drop_was_held = Input.is_action_pressed("drop")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if captured else Input.MOUSE_MODE_VISIBLE


func _find_crew() -> void:
	var member: CrewMember = NetAuthority.local_crew(get_tree())
	if member != _crew:
		_crew = member
		_eye = null
		_hands = null
		_eye_missing_reported = false


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key: InputEventKey = event
		if key.pressed and key.keycode == KEY_ESCAPE:
			# Always available, seated or not: if the owner cannot free the
			# pointer, the fix is worse than the problem.
			_set_captured(false)
		return
	if event is InputEventMouseButton:
		var button: InputEventMouseButton = event
		if button.pressed and button.button_index == MOUSE_BUTTON_LEFT \
				and not _captured and _capture_allowed:
			_set_captured(true)
		return
	if event is InputEventMouseMotion:
		var motion: InputEventMouseMotion = event
		_apply_look(motion)


## On-foot mouse look (§9.2): yaw goes on the body, pitch on the eye camera.
## With the pointer free the look does NOT move (acceptance criterion).
func _apply_look(motion: InputEventMouseMotion) -> void:
	if not enabled or not is_instance_valid(_crew) or _crew.seated:
		return
	if not _captured:
		return
	var eye: Camera3D = _eye_camera()
	if eye == null:
		return
	var tuning: TuningTable = GameConfig.tuning
	if tuning == null:
		push_error("CrewInput: GameConfig.tuning is null; mouse look skipped")
		return
	# screen_relative, NEVER .relative: with window/stretch/mode="canvas_items"
	# the engine scales .relative by the stretch factor (measured: a (10, -4)
	# physical move arrives as (180, -72)), so the sensitivity would change
	# with the window size. screen_relative reaches the node intact.
	var next: Vector2 = MouseLook.next_yaw_pitch(
		_crew.rotation.y, eye.rotation.x, motion.screen_relative,
		tuning.player_mouse_sensitivity, -1.0, deg_to_rad(89.0))
	_crew.rotation.y = next.x
	eye.rotation.x = next.y


## Scope the group lookup to this input's crew: remote eyes join it too.
func _eye_camera() -> Camera3D:
	if not is_instance_valid(_eye):
		_eye = NetAuthority.scoped_eye(_crew)
		if _eye == null and is_instance_valid(_crew) and not _eye_missing_reported:
			_eye_missing_reported = true
			push_error("CrewInput: local crew has no Camera3D in group 'eye_camera'")
	return _eye


func _physics_process(_delta: float) -> void:
	# MultiplayerSpawner can deliver the local crew after this node is ready.
	if not NetAuthority.is_local(_crew):
		_find_crew()
	if _crew == null:
		return
	if _crew.network_member and not _crew.network_ready:
		return
	if not enabled and not _crew.seated:
		# The scripted run owns movement while player input is disabled.
		return
	var interact_held: bool = Input.is_action_pressed("interact")
	if interact_held and not _interact_was_held:
		_on_interact_pressed()
	elif not interact_held and _interact_was_held:
		_on_interact_released()
	_interact_was_held = interact_held
	_poll_clicks()
	if not enabled or _crew.seated:
		return
	var input: Vector2 = Vector2(
		Input.get_action_strength("walk_right") - Input.get_action_strength("walk_left"),
		Input.get_action_strength("walk_back") - Input.get_action_strength("walk_forward"))
	var sprint: bool = Input.is_action_pressed("walk_sprint")
	var jump: bool = Input.is_action_just_pressed("walk_jump")
	_crew.drive_move(input, sprint, jump, _crew.global_basis)


## E went down: with a package in hand this MAY become a strap hold, so
## CrewHands starts counting (it no-ops without a free anchor in reach).
func _on_interact_pressed() -> void:
	var hands: CrewHands = _hands_node()
	if hands != null and hands.held != null and not _crew.seated:
		hands.begin_strap()


## E went up: an interrupted hold cancels (nothing changes) and the press
## degrades to a TAP, dispatched by the owner's priority (D86). A hold that
## COMPLETED the strap spends the press: the release is not a tap, or the
## package would bounce straight back to the hand.
func _on_interact_released() -> void:
	var hands: CrewHands = _hands_node()
	if hands != null and hands.is_strapping():
		hands.cancel_strap()
	elif hands != null and hands.consume_strap_completed():
		return
	_interact_tap(hands)


## Tap priority: a package in hand REJECTS the seat (print, no effect —
## nobody drives while carrying); an empty hand grabs the free package on
## the look ray, else unstraps the strapped one in reach, else seats as
## before. Seated with an empty hand: only the seat route remains.
func _interact_tap(hands: CrewHands) -> void:
	if hands != null and hands.held != null:
		if _crew.seated or nearest_free_seat_in_reach(_crew.global_position) != null:
			print("CrewInput: seat refused while carrying a package")
		return
	if not _crew.seated and hands != null:
		# The RETICLE rule (measured in the playthrough probe: in a cargo-filled
		# bus grab always won by distance, so E never reached the seat): the
		# interactable best aligned with the look ray within reach wins — point
		# at the wheel to drive, at a free box to grab, at a strapped one to
		# unstrap. Nothing in the reticle: the seat as before.
		var eye_node: Camera3D = _eye_camera()
		if eye_node is Camera3D:
			var eye: Camera3D = eye_node
			# No absolute radial cutoff: floor packages sit ~1.4 m below the eye
			# line and any fixed threshold would exclude them (measured in the
			# probe). The MOST ray-aligned candidate wins; "nothing in reach"
			# falls through to the seat below.
			var best_radial: float = INF
			var best: String = ""
			var seat: Seat = nearest_free_seat_in_reach(_crew.global_position)
			if seat != null and seat.seat_marker != null:
				var radial: float = _ray_radial(eye.global_position, -eye.global_basis.z, seat.seat_marker.global_position)
				if radial < best_radial:
					best_radial = radial
					best = "seat"
			var free_pkg: Package = hands.ray_best_package(Package.Restraint.FREE)
			if free_pkg != null:
				var radial: float = _ray_radial(eye.global_position, -eye.global_basis.z, free_pkg.global_position)
				if radial < best_radial:
					best_radial = radial
					best = "grab"
			var strapped_pkg: Package = hands.ray_best_package(Package.Restraint.STRAPPED)
			if strapped_pkg != null:
				var radial: float = _ray_radial(eye.global_position, -eye.global_basis.z, strapped_pkg.global_position)
				if radial < best_radial:
					best_radial = radial
					best = "unstrap"
			if best == "seat":
				toggle_nearest_seat(_crew)
				return
			if best == "grab":
				if hands.try_grab():
					return
			elif best == "unstrap":
				if hands.try_unstrap():
					return
	toggle_nearest_seat(_crew)


## Lateral distance of a point to the look ray (INF behind the camera).
func _ray_radial(origin: Vector3, dir: Vector3, point: Vector3) -> float:
	var to_point: Vector3 = point - origin
	var axial: float = to_point.dot(dir)
	if axial <= 0.0:
		return INF
	var lateral: Vector3 = to_point - dir * axial
	return lateral.length()


## throw (left) / drop (right) are actions bound to the mouse buttons. They
## act ONLY with the pointer captured and never while seated; the free-pointer
## click's recapture press was already swallowed in _set_captured.
func _poll_clicks() -> void:
	var hands: CrewHands = _hands_node()
	var throw_held: bool = Input.is_action_pressed("throw")
	if throw_held and not _throw_was_held and _captured \
			and not _crew.seated and hands != null:
		hands.throw()
	_throw_was_held = throw_held
	var drop_held: bool = Input.is_action_pressed("drop")
	if drop_held and not _drop_was_held and _captured \
			and not _crew.seated and hands != null:
		hands.drop()
	_drop_was_held = drop_held


## The hands are found by GROUP (D59): the node lives inside crew_member.tscn
## (one pair of hands per crew member).
func _hands_node() -> CrewHands:
	if not is_instance_valid(_crew):
		return null
	if not is_instance_valid(_hands):
		for node: Node in get_tree().get_nodes_in_group("crew_hands"):
			if node is CrewHands and _crew.is_ancestor_of(node):
				_hands = node
				break
	return _hands


## Interact logic as a named entry point so tests call it WITHOUT input:
## seated → leave the seat that holds the member; on foot → occupy the
## nearest free seat whose marker is within interaction_reach_m.
func toggle_nearest_seat(crew: CrewMember) -> void:
	# Driver authority and replicated seats belong to M4, not this gate.
	if crew.network_member:
		return
	if crew.seated:
		var current: Seat = occupied_seat_of(crew)
		if current != null:
			current.vacate()
		return
	var seat: Seat = nearest_free_seat_in_reach(crew.global_position)
	if seat != null:
		seat.occupy(crew)


func occupied_seat_of(crew: CrewMember) -> Seat:
	for node: Node in get_tree().get_nodes_in_group("seat"):
		if node is Seat:
			var seat: Seat = node
			if seat.occupied_by == crew:
				return seat
	return null


func nearest_free_seat_in_reach(from: Vector3) -> Seat:
	var tuning: TuningTable = GameConfig.tuning
	if tuning == null:
		push_error("CrewInput: GameConfig.tuning is null; cannot reach seats")
		return null
	var best: Seat = null
	var best_dist: float = tuning.interaction_reach_m
	for node: Node in get_tree().get_nodes_in_group("seat"):
		if node is Seat:
			var seat: Seat = node
			if seat.occupied_by != null or seat.seat_marker == null:
				continue
			var dist: float = from.distance_to(seat.seat_marker.global_position)
			if dist <= best_dist:
				best = seat
				best_dist = dist
	return best
