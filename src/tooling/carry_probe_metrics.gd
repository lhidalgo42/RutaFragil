class_name CarryProbeMetrics
extends RefCounted


static func has_bus_support(crew: CharacterBody3D, bus: RigidBody3D, local: Vector3) -> bool:
	if not crew.is_on_floor():
		return false
	var floor_contact: bool = false
	for slide: int in range(crew.get_slide_collision_count()):
		var collision: KinematicCollision3D = crew.get_slide_collision(slide)
		for contact: int in range(collision.get_collision_count()):
			if collision.get_normal(contact).dot(crew.up_direction) < cos(crew.floor_max_angle):
				continue
			floor_contact = true
			var collider: Object = collision.get_collider(contact)
			if collider == bus:
				return true
			if collider is Node:
				var support: Node = collider
				if bus.is_ancestor_of(support):
					return true
	# Floor snap need not expose a slide collision; reject the distant Ground.
	return not floor_contact and BusInterior.is_inside_local(local)


static func percentile(values: Array[float], fraction: float) -> float:
	if values.is_empty():
		return 0.0
	var sorted: Array[float] = values.duplicate()
	sorted.sort()
	var index: int = mini(sorted.size() - 1, int(fraction * float(sorted.size() - 1)))
	return sorted[index]


static func trajectory_distances(a: Array[Transform3D], b: Array[Transform3D]) -> Dictionary:
	var distances: Array[float] = []
	for i: int in range(mini(a.size(), b.size())):
		distances.append(a[i].origin.distance_to(b[i].origin))
	return {"samples": distances.size(), "p95_m": percentile(distances, 0.95),
		"max_m": percentile(distances, 1.0)}
