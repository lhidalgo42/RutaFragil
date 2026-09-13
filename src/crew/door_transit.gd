class_name DoorTransit
extends Node

## Side-door transit (D75): a PLANE test in the bus frame, not Area3D zones
## (a zone in the doorway fires enter+exit on a single crossing and
## ping-pongs). The door gap is the right wall of the interior at x ~ +1.20,
## z in [-3.2, -2.3], y from the floor (-0.60) to the roof (1.30).
## Boarding sets the `aboard` flag and emits the signals; the crew STAYS in
## the world frame and is carried by the engine's platform inheritance (D74,
## measured). D75's reparent mechanism was MEASURED and rejected: a child of
## the bus that is also carried by the platform system double-counts the bus
## motion (the crew drifted 3.5 m rearward in one lap, 2026-09-13; in the
## world frame the drift is millimetres). The reparent remains available as a
## mechanism for M4's network sync if it is ever needed.

## Local x below this = inside the interior.
@export var inside_x: float = 1.05
## Local x above this = outside (past the wall).
@export var outside_x: float = 1.30

var _crew: CrewMember = null
var _bus: RigidBody3D = null


func _ready() -> void:
	_find.call_deferred()


func _find() -> void:
	var crew_node: Node = get_tree().get_first_node_in_group("crew")
	if crew_node is CrewMember:
		_crew = crew_node
	var bus_node: Node = get_tree().get_first_node_in_group("bus")
	if bus_node is RigidBody3D:
		_bus = bus_node
	if _crew == null or _bus == null:
		push_error("DoorTransit: needs one 'crew' and one 'bus' node")


func _physics_process(_delta: float) -> void:
	if _crew == null or _bus == null or _crew.seated:
		return
	var local: Vector3 = _bus.global_transform.affine_inverse() * _crew.global_position
	if not _crew.aboard and _in_door_gap(local) and local.x < inside_x:
		_board()
	elif _crew.aboard and _in_door_gap(local) and local.x > outside_x:
		_exit()


func _in_door_gap(local: Vector3) -> bool:
	return local.z > -3.2 and local.z < -2.3 and local.y > -0.60 and local.y < 1.30


func _board() -> void:
	_crew.aboard = true
	_crew.boarded.emit()


func _exit() -> void:
	_crew.aboard = false
	_crew.exited.emit()
