class_name GateHullProbe
extends RefCounted

## The authored solid pieces exclude the door opening without exempting its
## floor, roof or jambs. No gameplay transforms or collision shapes are changed.
const HULL_NAMES: Array[String] = ["Floor", "Roof", "WallLeft", "WallRightRear",
	"WallRightFront", "WallFront", "Windshield", "WallRearLeft", "WallRearRight"]

var pieces: Array[Dictionary] = []
var missing: Array[String] = []


func configure(bus: RigidBody3D) -> void:
	pieces.clear()
	missing.clear()
	var found: Array[String] = []
	var pending: Array[Node] = [bus]
	while not pending.is_empty():
		var node: Node = pending.pop_back()
		for child: Node in node.get_children():
			pending.append(child)
		if node is CollisionShape3D and str(node.name) in HULL_NAMES:
			var collision: CollisionShape3D = node
			if collision.shape is BoxShape3D and not collision.disabled:
				var box: BoxShape3D = collision.shape
				pieces.append({"name": str(node.name), "half": box.size * 0.5,
					"at": bus.global_transform.affine_inverse() * collision.global_transform})
				found.append(str(node.name))
	for required: String in HULL_NAMES:
		if required not in found:
			missing.append(required)


func measure(body: Node3D, bus_transform: Transform3D) -> Dictionary:
	var maximum: float = 0.0
	var deepest_piece: String = ""
	var shapes: int = 0
	var unsupported: bool = false
	for child: Node in body.get_children():
		if child is not CollisionShape3D:
			continue
		var collision: CollisionShape3D = child
		if collision.disabled or collision.shape == null:
			continue
		shapes += 1
		var at: Transform3D = bus_transform.affine_inverse() * collision.global_transform
		for piece: Dictionary in pieces:
			var hull_at: Transform3D = piece["at"]
			var half: Vector3 = piece["half"]
			var relative: Transform3D = hull_at.affine_inverse() * at
			var depth: float = 0.0
			if collision.shape is CapsuleShape3D:
				var capsule: CapsuleShape3D = collision.shape
				depth = capsule_box_depth(relative, capsule.radius, capsule.height, half)
			elif collision.shape is BoxShape3D:
				var box: BoxShape3D = collision.shape
				depth = box_box_depth(relative, box.size * 0.5, half)
			else:
				unsupported = true
			if depth > maximum:
				maximum = depth
				deepest_piece = str(piece["name"])
	return {"depth_m": maximum, "piece": deepest_piece, "shapes": shapes,
		"unsupported_shape": unsupported}


## Capsule centreline to finite box distance is exact outside the box. If
## the centreline enters a solid, box-axis exit depth is conservative; that
## case already exceeds the capsule radius, well above D95's 5 cm limit.
static func capsule_box_depth(at: Transform3D, radius: float, height: float, half: Vector3) -> float:
	var axis: Vector3 = at.basis.y.normalized()
	var segment_half: float = maxf(0.0, height * 0.5 - radius)
	var start: Vector3 = at.origin - axis * segment_half
	var end: Vector3 = at.origin + axis * segment_half
	var distance: float = _segment_box_distance(start, end, half)
	if distance > 0.000001:
		return maxf(0.0, radius - distance)
	var depth: float = INF
	for dimension: int in range(3):
		var extent: float = radius + absf(axis[dimension]) * segment_half
		depth = minf(depth, half[dimension] + extent - absf(at.origin[dimension]))
	return maxf(0.0, depth)


## Separating-axis minimum overlap for oriented cargo boxes against a solid
## hull box. Cross-product axes retain correctness at rotated door edges.
static func box_box_depth(at: Transform3D, half: Vector3, hull_half: Vector3) -> float:
	var axes: Array[Vector3] = [Vector3.RIGHT, Vector3.UP, Vector3.BACK,
		at.basis.x.normalized(), at.basis.y.normalized(), at.basis.z.normalized()]
	for hull_axis: Vector3 in [Vector3.RIGHT, Vector3.UP, Vector3.BACK]:
		for body_axis: Vector3 in [at.basis.x, at.basis.y, at.basis.z]:
			var cross_axis: Vector3 = hull_axis.cross(body_axis)
			if cross_axis.length_squared() > 0.00000001:
				axes.append(cross_axis.normalized())
	var minimum: float = INF
	for axis: Vector3 in axes:
		var hull_radius: float = axis.abs().dot(hull_half)
		var body_radius: float = absf(axis.dot(at.basis.x)) * half.x + absf(axis.dot(at.basis.y)) * half.y + absf(axis.dot(at.basis.z)) * half.z
		var depth: float = hull_radius + body_radius - absf(axis.dot(at.origin))
		if depth <= 0.0:
			return 0.0
		minimum = minf(minimum, depth)
	return minimum


static func _segment_box_distance(start: Vector3, end: Vector3, half: Vector3) -> float:
	var direction: Vector3 = end - start
	var cuts: Array[float] = [0.0, 1.0]
	for axis: int in range(3):
		if absf(direction[axis]) < 0.0000001:
			continue
		for sign_value: float in [-1.0, 1.0]:
			var weight: float = (sign_value * half[axis] - start[axis]) / direction[axis]
			if weight > 0.0 and weight < 1.0:
				cuts.append(weight)
	cuts.sort()
	var minimum_squared: float = INF
	for index: int in range(cuts.size() - 1):
		var low: float = cuts[index]
		var high: float = cuts[index + 1]
		var middle: Vector3 = start + direction * ((low + high) * 0.5)
		var quadratic: float = 0.0
		var linear: float = 0.0
		for axis: int in range(3):
			if absf(middle[axis]) <= half[axis]:
				continue
			var offset: float = start[axis] - signf(middle[axis]) * half[axis]
			quadratic += direction[axis] * direction[axis]
			linear += offset * direction[axis]
		var weight: float = clampf(-linear / quadratic, low, high) if quadratic > 0.0 else low
		var point: Vector3 = start + direction * weight
		var outside: Vector3 = (point.abs() - half).max(Vector3.ZERO)
		minimum_squared = minf(minimum_squared, outside.length_squared())
	return sqrt(minimum_squared)
