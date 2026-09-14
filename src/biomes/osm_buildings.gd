class_name OsmBuildings
extends Node3D

## Real building footprints (D65) plus generated infill houses (D67) as
## oriented boxes: facades in one MultiMesh drawn by facade.gdshader (instance
## colour + procedural windows), gabled roofs for low houses in a second
## (PrismMesh), fences for the infill lots, and one StaticBody3D with a rotated
## BoxShape3D per building. The delivery house gets a doorbell pad and a
## receiver on its avenue-facing side.

const FLOOR_M: float = 3.2
const ROOF_H: float = 2.2
const HOUSE_TYPES: Array[String] = ["house", "terrace", "semidetached_house", "fill"]
const FACADE_SHADER: Shader = preload("res://assets/shaders/facade.gdshader")
const FENCE_H_M: float = 1.8
const PALETTE: Array[Color] = [
	Color(0.85, 0.72, 0.45), Color(0.93, 0.9, 0.82), Color(0.9, 0.7, 0.68),
	Color(0.78, 0.8, 0.72), Color(0.86, 0.82, 0.62),
]
const DELIVERY_COLOUR: Color = Color(0.95, 0.55, 0.25)

@export var data_path: String = "res://data/b0_departamental.json"

var data: OsmMapData


func _ready() -> void:
	data = OsmMapData.load_from(data_path)
	if data != null:
		build()


func build() -> void:
	for child: Node in get_children():
		remove_child(child)
		child.free()
	var facades: MultiMesh = _multimesh(_unit_box(true))
	var fences: MultiMesh = _multimesh(_unit_box(false))
	var fence_xforms: Array[Transform3D] = []
	var roofs: MultiMesh = _multimesh(_unit_prism())
	facades.instance_count = data.buildings.size()
	var roof_xforms: Array[Transform3D] = []
	var body: StaticBody3D = StaticBody3D.new()
	body.name = "Body"
	add_child(body)
	for i: int in data.buildings.size():
		var b: Dictionary = data.buildings[i]
		var w: float = float(b.get("w", 8.0))
		var d: float = float(b.get("d", 8.0))
		var levels: int = maxi(1, int(b.get("levels", 1)))
		var h: float = float(levels) * FLOOR_M
		var yaw: float = float(b.get("yaw", 0.0))
		var center: Vector3 = Vector3(float(b.get("x", 0.0)), h * 0.5, float(b.get("z", 0.0)))
		var rot: Basis = Basis(Vector3.UP, yaw)
		facades.set_instance_transform(i, Transform3D(rot * Basis.from_scale(Vector3(w, h, d)), center))
		facades.set_instance_color(i, _colour(b, i))
		var shape_node: CollisionShape3D = CollisionShape3D.new()
		var box: BoxShape3D = BoxShape3D.new()
		box.size = Vector3(w, h, d)
		shape_node.shape = box
		body.add_child(shape_node)
		shape_node.global_transform = Transform3D(rot, center)
		if levels <= 2 and str(b.get("type", "")) in HOUSE_TYPES:
			# prism ridge runs along local Z; rotate 90 deg so it follows the long side (w)
			var roof_rot: Basis = Basis(Vector3.UP, yaw + PI * 0.5) * Basis.from_scale(Vector3(d, ROOF_H, w))
			roof_xforms.append(Transform3D(roof_rot, Vector3(center.x, h + ROOF_H * 0.5, center.z)))
		if bool(b.get("delivery", false)):
			_add_delivery(center, w, d)
		var fence: Dictionary = b.get("fence", {})
		if not fence.is_empty():
			var fence_rot: Basis = Basis(Vector3.UP, float(fence.get("yaw", 0.0))) * Basis.from_scale(Vector3(float(fence.get("len", 8.0)), FENCE_H_M, 0.08))
			fence_xforms.append(Transform3D(fence_rot, Vector3(float(fence.get("x", 0.0)), FENCE_H_M * 0.5, float(fence.get("z", 0.0)))))
	roofs.instance_count = roof_xforms.size()
	for i: int in roof_xforms.size():
		roofs.set_instance_transform(i, roof_xforms[i])
		roofs.set_instance_color(i, Color(0.55, 0.3, 0.25))
	fences.instance_count = fence_xforms.size()
	for i: int in fence_xforms.size():
		fences.set_instance_transform(i, fence_xforms[i])
		fences.set_instance_color(i, Color(0.28, 0.28, 0.3))
	_add_instance("Facades", facades)
	_add_instance("Roofs", roofs)
	_add_instance("Fences", fences)


func fence_count() -> int:
	var node: Node = get_node_or_null("Fences")
	if node is MultiMeshInstance3D:
		var inst: MultiMeshInstance3D = node
		return inst.multimesh.instance_count
	return 0


func facade_count() -> int:
	var node: Node = get_node_or_null("Facades")
	if node is MultiMeshInstance3D:
		var inst: MultiMeshInstance3D = node
		return inst.multimesh.instance_count
	return 0


func collision_count() -> int:
	var body: Node = get_node_or_null("Body")
	return body.get_child_count() if body != null else 0


func delivery_position() -> Vector3:
	var pad: Node = get_node_or_null("DoorbellPad")
	if pad is Node3D:
		var pad3d: Node3D = pad
		return pad3d.global_position
	return Vector3.ZERO


func _colour(b: Dictionary, index: int) -> Color:
	if bool(b.get("delivery", false)):
		return DELIVERY_COLOUR
	var kind: String = str(b.get("type", "yes"))
	if kind == "apartments" or int(b.get("levels", 1)) >= 4:
		return Color(0.62, 0.64, 0.68)
	if kind == "retail":
		return Color(0.9, 0.6, 0.3)
	if kind == "fill":
		return PALETTE[(index * 7 + 3) % PALETTE.size()]
	return PALETTE[index % PALETTE.size()]


func _add_delivery(center: Vector3, w: float, d: float) -> void:
	# the front faces the avenue: step from the centre toward the nearest axis point
	var proj: Vector2 = data.project(center)
	var on_axis: Vector3 = data.lateral_point(proj.x, 0.0)
	var toward: Vector3 = (on_axis - center)
	toward.y = 0.0
	toward = toward.normalized()
	var front: Vector3 = Vector3(center.x, 0.0, center.z) + toward * (minf(w, d) * 0.5 + 2.5)
	var pad: MeshInstance3D = MeshInstance3D.new()
	pad.name = "DoorbellPad"
	var pad_mesh: BoxMesh = BoxMesh.new()
	pad_mesh.size = Vector3(3.0, 0.02, 3.0)
	var pad_mat: StandardMaterial3D = StandardMaterial3D.new()
	pad_mat.albedo_color = Color(0.2, 0.7, 0.3)
	pad_mesh.material = pad_mat
	pad.mesh = pad_mesh
	add_child(pad)
	pad.global_position = front + Vector3.UP * 0.02
	var receiver: MeshInstance3D = MeshInstance3D.new()
	receiver.name = "Receiver"
	var cap: CapsuleMesh = CapsuleMesh.new()
	cap.radius = 0.35
	cap.height = 1.8
	var skin: StandardMaterial3D = StandardMaterial3D.new()
	skin.albedo_color = Color(0.9, 0.6, 0.5)
	cap.material = skin
	receiver.mesh = cap
	add_child(receiver)
	receiver.global_position = front + toward * 1.5 + Vector3.UP * 0.9


func _multimesh(mesh: Mesh) -> MultiMesh:
	var mm: MultiMesh = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	return mm


func _unit_box(windows: bool) -> BoxMesh:
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = Vector3.ONE
	if windows:
		var shader_mat: ShaderMaterial = ShaderMaterial.new()
		shader_mat.shader = FACADE_SHADER
		mesh.material = shader_mat
	else:
		mesh.material = _vertex_colour_material()
	return mesh


func _unit_prism() -> PrismMesh:
	var mesh: PrismMesh = PrismMesh.new()
	mesh.size = Vector3.ONE
	mesh.left_to_right = 0.5
	mesh.material = _vertex_colour_material()
	return mesh


func _vertex_colour_material() -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	return material


func _add_instance(node_name: String, mm: MultiMesh) -> void:
	var inst: MultiMeshInstance3D = MultiMeshInstance3D.new()
	inst.name = node_name
	inst.multimesh = mm
	add_child(inst)
