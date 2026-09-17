class_name NetCargoPlacement
extends RefCounted

## Releasing a kinematic replica inside a capsule ejects its passenger.
## Every candidate includes crew layer 3; the held box alone is excluded.
static func fits(package: Package, at: Transform3D) -> bool:
	var collision: CollisionShape3D = _shape(package)
	if collision == null:
		return false
	var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	query.shape = collision.shape
	query.transform = at * collision.transform
	query.collision_mask = 0b111
	query.exclude = [package.get_rid()]
	return package.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()


static func find_drop(package: Package, crew: CrewMember, hand: Node3D, reach_m: float) -> Array[Transform3D]:
	if fits(package, hand.global_transform) and unobstructed(package, crew, hand.global_position):
		return [hand.global_transform]
	var collision: CollisionShape3D = _shape(package)
	if collision == null or collision.shape is not BoxShape3D:
		return []
	var box: BoxShape3D = collision.shape
	var half: Vector3 = box.size * 0.5
	var radius: float = 0.0
	for child: Node in crew.get_children():
		if child is CollisionShape3D:
			var capsule_shape: CollisionShape3D = child
			if capsule_shape.shape is CapsuleShape3D:
				var capsule: CapsuleShape3D = capsule_shape.shape
				radius = maxf(radius, capsule.radius)
	var clearance: float = radius + Vector2(half.x, half.z).length() + 0.04
	var basis: Basis = Basis(Vector3.UP, crew.global_rotation.y)
	var space: PhysicsDirectSpaceState3D = crew.get_world_3d().direct_space_state
	for direction: Vector3 in [Vector3.LEFT, Vector3.RIGHT, Vector3.BACK, Vector3.FORWARD,
			Vector3(-1.0, 0.0, 1.0), Vector3(1.0, 0.0, 1.0),
			Vector3(-1.0, 0.0, -1.0), Vector3(1.0, 0.0, -1.0)]:
		var from: Vector3 = crew.global_position + basis * direction.normalized() * clearance + Vector3.UP * 0.8
		var ray: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
			from, from + Vector3.DOWN * 4.0, 0b011, [package.get_rid()])
		var hit: Dictionary = space.intersect_ray(ray)
		if hit.is_empty():
			continue
		var point: Vector3 = hit["position"]
		var at: Transform3D = Transform3D(basis, point + Vector3.UP * (half.y + 0.02))
		if hand.global_position.distance_to(at.origin) <= reach_m and fits(package, at) \
				and unobstructed(package, crew, at.origin):
			return [at]
	return []


static func unobstructed(package: Package, crew: CrewMember, point: Vector3) -> bool:
	var from: Vector3 = Vector3(crew.global_position.x, point.y, crew.global_position.z)
	var ray: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		from, point, 0b011, [package.get_rid(), crew.get_rid()])
	return crew.get_world_3d().direct_space_state.intersect_ray(ray).is_empty()


static func _shape(package: Package) -> CollisionShape3D:
	for child: Node in package.get_children():
		if child is CollisionShape3D:
			var collision: CollisionShape3D = child
			if collision.shape != null:
				return collision
	return null
