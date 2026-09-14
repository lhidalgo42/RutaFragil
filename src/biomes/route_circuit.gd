class_name RouteCircuit
extends Circuit

## Chains the circuits of every BiomeSegment under segments_root, in tree
## order, so the DemoDriver laps the whole route as one waypoint list.

@export var segments_root: Node3D


func waypoint_count() -> int:
	var count: int = 0
	for segment: BiomeSegment in segments():
		var circuit: Circuit = segment.circuit()
		if circuit != null:
			count += circuit.waypoint_count()
	return count


func waypoint_position(index: int) -> Vector3:
	var remaining: int = index
	for segment: BiomeSegment in segments():
		var circuit: Circuit = segment.circuit()
		if circuit == null:
			continue
		var count: int = circuit.waypoint_count()
		if remaining < count:
			return circuit.waypoint_position(remaining)
		remaining -= count
	push_error("RouteCircuit: waypoint index %d out of range (count %d)" % [index, waypoint_count()])
	return Vector3.ZERO


func segments() -> Array[BiomeSegment]:
	var result: Array[BiomeSegment] = []
	if segments_root == null:
		return result
	for child: Node in segments_root.get_children():
		if child is BiomeSegment:
			var segment: BiomeSegment = child
			result.append(segment)
	return result
