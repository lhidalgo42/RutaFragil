class_name MeshBatcher
extends RefCounted

## Collects transforms per kind and emits one MultiMeshInstance3D per kind
## ("Batch_<kind>") under a parent. Shared by OsmRoad, OsmFurniture and
## CityBackdrop so the greybox draws thousands of boxes in a handful of calls.

var _batches: Dictionary = {}
var _flushed: Dictionary = {}


func add(kind: String, mesh_kind: String, xform: Transform3D) -> void:
	if not _batches.has(kind):
		_batches[kind] = {"mesh": mesh_kind, "xforms": []}
	var entry: Dictionary = _batches[kind]
	var xforms: Array = entry["xforms"]
	xforms.append(xform)


func box(kind: String, xform: Transform3D) -> void:
	add(kind, "box", xform)


func count(kind: String) -> int:
	if not _batches.has(kind):
		return 0
	var entry: Dictionary = _batches[kind]
	var xforms: Array = entry["xforms"]
	return xforms.size()


## Origins of the instances emitted at the last flush for `kind`. Tests read
## this: MultiMesh.get_instance_transform() returns identity under the headless
## (dummy) renderer, so buffers cannot be read back there.
func positions(kind: String) -> PackedVector3Array:
	if _flushed.has(kind):
		return _flushed[kind]
	return PackedVector3Array()


func flush(parent: Node, colours: Dictionary) -> void:
	for kind: String in _batches.keys():
		var entry: Dictionary = _batches[kind]
		var xforms: Array = entry["xforms"]
		var mm: MultiMesh = MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = unit_mesh(str(entry["mesh"]), colours.get(kind, Color.MAGENTA))
		mm.instance_count = xforms.size()
		for i: int in xforms.size():
			var xf: Transform3D = xforms[i]
			mm.set_instance_transform(i, xf)
		var origins: PackedVector3Array = PackedVector3Array()
		for xf: Transform3D in xforms:
			origins.append(xf.origin)
		_flushed[kind] = origins
		var inst: MultiMeshInstance3D = MultiMeshInstance3D.new()
		inst.name = "Batch_" + kind
		inst.multimesh = mm
		parent.add_child(inst)
	_batches.clear()


## Box of `size` (x across, y up, z along) laid along basis `rot` at `pos`, lifted by `y`.
static func along(rot: Basis, pos: Vector3, size: Vector3, y: float) -> Transform3D:
	return Transform3D(rot * Basis.from_scale(size), pos + Vector3.UP * y)


## Thin box from `a` to `b` with square section `thickness` (cables, rails).
static func between(a: Vector3, b: Vector3, thickness: float) -> Transform3D:
	var dir: Vector3 = b - a
	var length: float = dir.length()
	if length < 0.001:
		return Transform3D(Basis.from_scale(Vector3.ONE * thickness), a)
	var basis: Basis = Basis.looking_at(dir / length, Vector3.UP if absf(dir.normalized().y) < 0.99 else Vector3.RIGHT)
	return Transform3D(basis * Basis.from_scale(Vector3(thickness, thickness, length)), (a + b) * 0.5)


static func unit_mesh(mesh_kind: String, colour: Color) -> Mesh:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = colour
	var mesh: Mesh
	match mesh_kind:
		"cyl":
			var cyl: CylinderMesh = CylinderMesh.new()
			cyl.top_radius = 0.5
			cyl.bottom_radius = 0.5
			cyl.height = 1.0
			mesh = cyl
		"sph":
			var sph: SphereMesh = SphereMesh.new()
			sph.radius = 0.5
			sph.height = 1.0
			mesh = sph
		"prism":
			var prism: PrismMesh = PrismMesh.new()
			prism.size = Vector3.ONE
			prism.left_to_right = 0.5
			mesh = prism
		_:
			var box: BoxMesh = BoxMesh.new()
			box.size = Vector3.ONE
			mesh = box
	mesh.surface_set_material(0, material)
	return mesh
