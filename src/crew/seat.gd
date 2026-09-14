class_name Seat
extends Node

## The driver's seat, minimal form (D76): on interact, the crew member is
## hidden and frozen, the camera goes to the cabin and the driving input turns
## on; on the second interact, the reverse. One occupant, no network, no
## CoopInteractable (that is M3). Cameras and inputs are found by GROUP, never
## by node name (D59/D63).

signal occupied(seat_name: String)
signal vacated(seat_name: String)

@export var seat_name: String = "driver"
@export var seat_marker: Marker3D

var occupied_by: CrewMember = null


func _ready() -> void:
	# CrewInput finds the seats by GROUP, never by node path (D59 style).
	add_to_group("seat")


func occupy(member: CrewMember) -> bool:
	if occupied_by != null or member == null:
		return false
	occupied_by = member
	member.set_seated(true)
	member.visible = false
	if seat_marker != null:
		member.global_position = seat_marker.global_position
	_set_driving_ui(true)
	occupied.emit(seat_name)
	return true


func vacate() -> void:
	if occupied_by == null:
		return
	var member: CrewMember = occupied_by
	occupied_by = null
	member.set_seated(false)
	member.visible = true
	_set_driving_ui(false)
	vacated.emit(seat_name)


func _set_driving_ui(driving: bool) -> void:
	var tree: SceneTree = get_tree()
	var cabin: Node = tree.get_first_node_in_group("cabin_camera")
	var chase: Node = tree.get_first_node_in_group("chase_camera")
	if cabin is Camera3D and chase is Camera3D:
		var cabin_cam: Camera3D = cabin
		var chase_cam: Camera3D = chase
		cabin_cam.current = driving
		chase_cam.current = not driving
	var bus_input: Node = tree.get_first_node_in_group("bus_input")
	if bus_input != null:
		bus_input.set("enabled", driving)
	var crew_input: Node = tree.get_first_node_in_group("crew_input")
	if crew_input != null:
		crew_input.set("enabled", not driving)
