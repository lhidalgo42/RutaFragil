class_name OsmTrench
extends RefCounted

## The cutting the Ruta 5 Sur runs through under the town bridge (D69). Builds the ground
## around it as seven slabs: the crossing itself is ONE continuous slab from edge to edge,
## because the placeholder bus trips and rolls when it slides over the seam between two
## floor boxes at 85 km/h. From below that slab reads as the bridge deck over the motorway.
## Called by OsmRoad, which owns the body and the batcher; OsmTown draws the motorway.

const REACH_M: float = 2600.0
const CAUSEWAY_HALF_M: float = 13.0


static func build(body: StaticBody3D, batcher: MeshBatcher, data: OsmMapData) -> void:
	var t: Dictionary = data.trench
	if t.is_empty():
		return
	var hw: float = float(t.get("half_width", 15.0))
	var hl: float = float(t.get("half_length", 160.0))
	var depth: float = float(t.get("depth", 5.0))
	var centre: Vector3 = data.trench_centre()
	# Local x across the motorway, local z along it (the x axis of yaw+90° is the across axis).
	var rot: Basis = Basis(Vector3.UP, float(t.get("yaw", 0.0)) + PI * 0.5)
	var far: float = (REACH_M + CAUSEWAY_HALF_M) * 0.5
	var mid_x: float = (REACH_M + hw) * 0.5
	var slabs: Array[Vector4] = [
		Vector4(0.0, 0.0, REACH_M * 2.0, CAUSEWAY_HALF_M * 2.0),          # el cruce, de lado a lado y sin junta
		Vector4(-mid_x, far, REACH_M - hw, REACH_M - CAUSEWAY_HALF_M),
		Vector4(-mid_x, -far, REACH_M - hw, REACH_M - CAUSEWAY_HALF_M),
		Vector4(mid_x, far, REACH_M - hw, REACH_M - CAUSEWAY_HALF_M),
		Vector4(mid_x, -far, REACH_M - hw, REACH_M - CAUSEWAY_HALF_M),
		Vector4(0.0, (REACH_M + hl) * 0.5, hw * 2.0, REACH_M - hl),
		Vector4(0.0, -(REACH_M + hl) * 0.5, hw * 2.0, REACH_M - hl),
	]
	for s: Vector4 in slabs:
		var pos: Vector3 = centre + rot * Vector3(s.x, -0.5, s.y)
		var size: Vector3 = Vector3(s.z, 1.0, s.w)
		_shape(body, size, Transform3D(rot, pos))
		batcher.box("ground", Transform3D(rot * Basis.from_scale(size), pos))
	var floor_pos: Vector3 = centre + Vector3.DOWN * (depth + 0.5)
	_shape(body, Vector3(hw * 2.0, 1.0, hl * 2.0), Transform3D(rot, floor_pos))
	batcher.box("dirt", Transform3D(rot * Basis.from_scale(Vector3(hw * 2.0, 1.0, hl * 2.0)), floor_pos))
	for side: float in [-1.0, 1.0]:
		batcher.box("concrete", Transform3D(rot * Basis.from_scale(Vector3(0.8, depth, hl * 2.0)), centre + rot * Vector3(side * (hw - 0.4), -depth * 0.5, 0.0)))
		batcher.box("concrete", Transform3D(rot * Basis.from_scale(Vector3(hw * 2.0, depth, 0.8)), centre + rot * Vector3(0.0, -depth * 0.5, side * (hl - 0.4))))
		batcher.box("concrete", Transform3D(rot * Basis.from_scale(Vector3(hw * 2.0, depth - 1.0, 0.7)), centre + rot * Vector3(0.0, -(depth + 1.0) * 0.5, side * CAUSEWAY_HALF_M)))


static func _shape(body: StaticBody3D, size: Vector3, xform: Transform3D) -> void:
	var node: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = size
	node.shape = box
	body.add_child(node)
	node.global_transform = xform
