class_name Circuit
extends Node3D

## Ordered waypoint lap (D49): every Marker3D child, in tree order, is one
## waypoint. DemoDriver loops through them; T0.4 reuses the same order for
## its scripted network scenario.


func waypoint_count() -> int:
	var count: int = 0
	for child: Node in get_children():
		if child is Marker3D:
			count += 1
	return count


func waypoint_position(index: int) -> Vector3:
	var seen: int = 0
	for child: Node in get_children():
		if child is Marker3D:
			if seen == index:
				var marker: Marker3D = child
				return marker.global_position
			seen += 1
	push_error("Circuit: waypoint index %d out of range (count %d)" % [index, waypoint_count()])
	return Vector3.ZERO
