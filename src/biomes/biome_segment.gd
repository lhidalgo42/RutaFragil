class_name BiomeSegment
extends Node3D

## One greybox biome stretch (B0 city today; B1 hill and B2 swamp later).
## The route scene chains segments end to end: Entry is where the bus arrives
## facing -Z, Exit where it leaves, and the child Circuit holds this segment's
## waypoints in tree order so a RouteCircuit can lap the whole chain.

@export var biome_id: String = ""
## Entry-to-Exit distance along -Z, informative for the route assembler.
@export var length_m: float = 0.0


func entry_position() -> Vector3:
	return _marker_position("Entry")


func exit_position() -> Vector3:
	return _marker_position("Exit")


func circuit() -> Circuit:
	var node: Node = get_node_or_null("Circuit")
	if node is Circuit:
		var found: Circuit = node
		return found
	push_error("BiomeSegment %s: missing Circuit child" % name)
	return null


func _marker_position(marker_name: String) -> Vector3:
	var node: Node = get_node_or_null(marker_name)
	if node is Marker3D:
		var marker: Marker3D = node
		return marker.global_position
	push_error("BiomeSegment %s: missing %s marker" % [name, marker_name])
	return global_position
