class_name CrewInput
extends Node

## Crew input → CrewMember (D73): reads the on-foot actions and calls
## CrewMember.drive_move with the camera-relative wish direction. The member
## never reads Input itself (headless has none; tests call drive_move).
## Sprint = walk_sprint (Shift), jump = walk_jump (Space), per §9.2's style.

@export var enabled: bool = false

var _crew: CrewMember = null


func _ready() -> void:
	add_to_group("crew_input")
	_find_crew.call_deferred()


func _find_crew() -> void:
	var node: Node = get_tree().get_first_node_in_group("crew")
	if node is CrewMember:
		_crew = node
	if _crew == null:
		push_error("CrewInput: no node in group 'crew'")


func _physics_process(_delta: float) -> void:
	if not enabled or _crew == null or _crew.seated:
		return
	var input: Vector2 = Vector2(
		Input.get_action_strength("walk_right") - Input.get_action_strength("walk_left"),
		Input.get_action_strength("walk_back") - Input.get_action_strength("walk_forward"))
	var sprint: bool = Input.is_action_pressed("walk_sprint")
	var jump: bool = Input.is_action_just_pressed("walk_jump")
	_crew.drive_move(input, sprint, jump, _crew.global_basis)
