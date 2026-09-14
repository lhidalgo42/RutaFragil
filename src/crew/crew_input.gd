class_name CrewInput
extends Node

## Crew input → CrewMember (D73): reads the on-foot actions and calls
## CrewMember.drive_move with the camera-relative wish direction. The member
## never reads Input itself (headless delivers no keyboard InputEvents, but
## Input.action_press/release DO drive the action state — measured by the
## reviewer 2026-09-14 — so tests exercise this node for real).
## Sprint = walk_sprint (Shift), jump = walk_jump (Space), per §9.2's style.
## interact (E) toggles the nearest seat in reach. It is read whenever the
## member is seated even with enabled=false, because Seat clears `enabled`
## exactly while seated (D76): gating interact on `enabled` would lock the
## crew in the seat (the round-1 lesson: a wire nobody calls does not exist).
## The press edge is detected by hand (is_action_pressed + last-tick state):
## is_action_just_pressed is flushed at the next PROCESS frame, and headless
## runs process frames far faster than the 60 Hz physics ticks, so a node
## never saw it in tests (measured 2026-09-13: 40 presses, zero seen).

@export var enabled: bool = false

var _crew: CrewMember = null
var _interact_was_held: bool = false


func _ready() -> void:
	add_to_group("crew_input")
	_find_crew.call_deferred()


## Mouse capture entry point, owned by the playground (the mode owner):
## player mode calls set_mouse_captured(true) at start and when F1 leaves the
## demo; the demo calls set_mouse_captured(false) so the cursor stays free.
## FASE-0 skeleton; the mouse-wiring agent implements capture, release and
## the capture-allowed memory used by click-to-recapture.
func set_mouse_captured(_captured: bool) -> void:
	pass


func _find_crew() -> void:
	var node: Node = get_tree().get_first_node_in_group("crew")
	if node is CrewMember:
		_crew = node
	if _crew == null:
		push_error("CrewInput: no node in group 'crew'")


func _physics_process(_delta: float) -> void:
	if _crew == null:
		return
	if not enabled and not _crew.seated:
		# Demo or network client: nobody is driving the crew, ignore input.
		return
	var interact_held: bool = Input.is_action_pressed("interact")
	if interact_held and not _interact_was_held:
		toggle_nearest_seat(_crew)
	_interact_was_held = interact_held
	if not enabled or _crew.seated:
		return
	var input: Vector2 = Vector2(
		Input.get_action_strength("walk_right") - Input.get_action_strength("walk_left"),
		Input.get_action_strength("walk_back") - Input.get_action_strength("walk_forward"))
	var sprint: bool = Input.is_action_pressed("walk_sprint")
	var jump: bool = Input.is_action_just_pressed("walk_jump")
	_crew.drive_move(input, sprint, jump, _crew.global_basis)


## Interact logic as a named entry point so tests call it WITHOUT input:
## seated → leave the seat that holds the member; on foot → occupy the
## nearest free seat whose marker is within interaction_reach_m.
func toggle_nearest_seat(crew: CrewMember) -> void:
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
