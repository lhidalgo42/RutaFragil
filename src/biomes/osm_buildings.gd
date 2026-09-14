class_name OsmBuildings
extends Node3D

## Buildings of a real-map segment (D65, D67, D68): OSM footprints plus generated
## infill as oriented boxes drawn by facade.gdshader (instance colour = paint,
## INSTANCE_CUSTOM.r = damage), roofs per style (teja for adobe, zinc for
## poblacion/parcela), fences (bars or wire), one collision box per standing
## building, collapsed houses as two stub walls plus a rubble mound, eriazos as
## dirt with dry grass and litter, and the delivery front (pad + receiver).

const FLOOR_M: Dictionary = {"adobe": 3.8, "poblacion": 2.9, "parcela": 3.1, "default": 3.2}
const ROOF_H: Dictionary = {"adobe": 1.6, "poblacion": 0.9, "parcela": 1.1, "default": 2.2}
const ROOF_COLOUR: Dictionary = {"adobe": Color(0.6, 0.32, 0.22), "poblacion": Color(0.55, 0.57, 0.6), "parcela": Color(0.5, 0.52, 0.55), "default": Color(0.55, 0.3, 0.25)}
const PALETTE: Dictionary = {
	"adobe": [Color(0.93, 0.9, 0.84), Color(0.9, 0.82, 0.62), Color(0.86, 0.68, 0.5), Color(0.93, 0.93, 0.9), Color(0.8, 0.6, 0.45)],
	"poblacion": [Color(0.85, 0.72, 0.45), Color(0.7, 0.78, 0.7), Color(0.9, 0.7, 0.68), Color(0.78, 0.8, 0.86), Color(0.86, 0.82, 0.62)],
	"parcela": [Color(0.9, 0.88, 0.8), Color(0.82, 0.74, 0.6), Color(0.75, 0.7, 0.6)],
	"default": [Color(0.85, 0.72, 0.45), Color(0.93, 0.9, 0.82), Color(0.9, 0.7, 0.68), Color(0.78, 0.8, 0.72), Color(0.86, 0.82, 0.62)],
}
const HOUSE_TYPES: Array[String] = ["house", "terrace", "semidetached_house", "fill"]
const FACADE_SHADER: Shader = preload("res://assets/shaders/facade.gdshader")
const FENCE_H_M: float = 1.8
const DELIVERY_COLOUR: Color = Color(0.95, 0.55, 0.25)
const LOT_COLOURS: Dictionary = {"rubble": Color(0.62, 0.5, 0.38), "stub": Color(0.7, 0.62, 0.5), "dirt": Color(0.55, 0.45, 0.33), "trash": Color(0.2, 0.2, 0.22), "trash_b": Color(0.8, 0.8, 0.78)}

@export var data_path: String = "res://data/b0_departamental.json"

var data: OsmMapData
var _b: MeshBatcher = MeshBatcher.new()


func _ready() -> void:
	data = OsmMapData.load_from(data_path)
	if data != null:
		build()


func build() -> void:
	for child: Node in get_children():
		remove_child(child)
		child.free()
	var standing: Array[Dictionary] = []
	for b: Dictionary in data.buildings:
		if bool(b.get("collapsed", false)):
			_collapsed(b)
		else:
			standing.append(b)
	var facades: MultiMesh = _multimesh(_unit_box(true), true)
	var roofs: MultiMesh = _multimesh(_unit_prism(), false)
	var fences: MultiMesh = _multimesh(_unit_box(false), false)
	facades.instance_count = standing.size()
	var roof_xforms: Array[Transform3D] = []
	var roof_colours: Array[Color] = []
	var fence_xforms: Array[Transform3D] = []
	var fence_colours: Array[Color] = []
	var body: StaticBody3D = StaticBody3D.new()
	body.name = "Body"
	add_child(body)
	for i: int in standing.size():
		var b: Dictionary = standing[i]
		var style: String = _style(b)
		var w: float = float(b.get("w", 8.0))
		var d: float = float(b.get("d", 8.0))
		var levels: int = maxi(1, int(b.get("levels", 1)))
		var h: float = float(levels) * float(FLOOR_M.get(style, 3.2))
		var yaw: float = float(b.get("yaw", 0.0))
		var center: Vector3 = Vector3(float(b.get("x", 0.0)), h * 0.5, float(b.get("z", 0.0)))
		var rot: Basis = Basis(Vector3.UP, yaw)
		facades.set_instance_transform(i, Transform3D(rot * Basis.from_scale(Vector3(w, h, d)), center))
		facades.set_instance_color(i, _colour(b, i, style))
		facades.set_instance_custom_data(i, Color(1.0 if int(b.get("damage", 0)) > 0 else 0.0, fmod(float(i) * 0.6180339, 1.0), 0.0, 0.0))
		var shape_node: CollisionShape3D = CollisionShape3D.new()
		var box: BoxShape3D = BoxShape3D.new()
		box.size = Vector3(w, h, d)
		shape_node.shape = box
		body.add_child(shape_node)
		shape_node.transform = Transform3D(rot, center)
		if levels <= 2 and (str(b.get("type", "")) in HOUSE_TYPES or style != "default"):
			var roof_h: float = float(ROOF_H.get(style, 2.2))
			roof_xforms.append(Transform3D(Basis(Vector3.UP, yaw + PI * 0.5) * Basis.from_scale(Vector3(d, roof_h, w)), Vector3(center.x, h + roof_h * 0.5, center.z)))
			roof_colours.append(ROOF_COLOUR.get(style, Color(0.55, 0.3, 0.25)))
		if bool(b.get("delivery", false)):
			_add_delivery(center, w, d)
		var fence: Dictionary = b.get("fence", {})
		if not fence.is_empty():
			var wire: bool = str(fence.get("kind", "bars")) == "wire"
			var fence_rot: Basis = Basis(Vector3.UP, float(fence.get("yaw", 0.0))) * Basis.from_scale(Vector3(float(fence.get("len", 8.0)), 1.3 if wire else FENCE_H_M, 0.05 if wire else 0.08))
			fence_xforms.append(Transform3D(fence_rot, Vector3(float(fence.get("x", 0.0)), (1.3 if wire else FENCE_H_M) * 0.5, float(fence.get("z", 0.0)))))
			fence_colours.append(Color(0.45, 0.42, 0.38) if wire else Color(0.28, 0.28, 0.3))
	_fill(roofs, roof_xforms, roof_colours)
	_fill(fences, fence_xforms, fence_colours)
	_add_instance("Facades", facades)
	_add_instance("Roofs", roofs)
	_add_instance("Fences", fences)
	for lot: Dictionary in data.lots:
		_lot(lot)
	_b.flush(self, LOT_COLOURS)


func facade_count() -> int:
	return _count("Facades")


func fence_count() -> int:
	return _count("Fences")


func collision_count() -> int:
	var body: Node = get_node_or_null("Body")
	return body.get_child_count() if body != null else 0


func rubble_count() -> int:
	return _b.positions("rubble").size()


func lot_count() -> int:
	var n: int = 0
	for child: Node in get_children():
		if child.name.begins_with("Lot"):
			n += 1
	return n


func delivery_position() -> Vector3:
	var pad: Node = get_node_or_null("DoorbellPad")
	if pad is Node3D:
		var pad3d: Node3D = pad
		return pad3d.global_position
	return Vector3.ZERO


func _count(node_name: String) -> int:
	var node: Node = get_node_or_null(node_name)
	if node is MultiMeshInstance3D:
		var inst: MultiMeshInstance3D = node
		return inst.multimesh.instance_count
	return 0


func _style(b: Dictionary) -> String:
	var style: String = str(b.get("style", "default"))
	return style if PALETTE.has(style) else "default"


func _colour(b: Dictionary, index: int, style: String) -> Color:
	if bool(b.get("delivery", false)):
		return DELIVERY_COLOUR
	var kind: String = str(b.get("type", "yes"))
	if kind == "apartments" or int(b.get("levels", 1)) >= 4:
		return Color(0.62, 0.64, 0.68)
	if kind == "retail":
		return Color(0.9, 0.6, 0.3)
	var palette: Array = PALETTE[style]
	return palette[(index * 7 + 3) % palette.size()] if kind == "fill" else palette[index % palette.size()]


## Collapsed adobe house (D68): two stub walls left standing and a mound of rubble; no roof, no collision box.
func _collapsed(b: Dictionary) -> void:
	var w: float = float(b.get("w", 8.0))
	var d: float = float(b.get("d", 8.0))
	var yaw: float = float(b.get("yaw", 0.0))
	var rot: Basis = Basis(Vector3.UP, yaw)
	var center: Vector3 = Vector3(float(b.get("x", 0.0)), 0.0, float(b.get("z", 0.0)))
	for side: float in [-1.0, 1.0]:
		var stub_h: float = 1.4 + 0.6 * (side + 1.0)
		_b.box("stub", Transform3D(rot * Basis.from_scale(Vector3(0.35, stub_h, d * 0.8)), center + rot.x * (side * (w * 0.5 - 0.2)) + Vector3.UP * (stub_h * 0.5)))
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = int(center.x * 13.0 + center.z * 7.0)
	for _k: int in 14:
		var size: Vector3 = Vector3(rng.randf_range(0.5, 1.4), rng.randf_range(0.3, 0.8), rng.randf_range(0.5, 1.2))
		var pos: Vector3 = center + rot.x * rng.randf_range(-w * 0.35, w * 0.35) + rot.z * rng.randf_range(-d * 0.35, d * 0.35) + Vector3.UP * (size.y * 0.5 + rng.randf_range(0.0, 0.5))
		_b.box("rubble", Transform3D(Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, rng.randf_range(-0.4, 0.4)) * Basis.from_scale(size), pos))
	_b.box("dirt", Transform3D(rot * Basis.from_scale(Vector3(w, 0.02, d)), center + Vector3.UP * 0.01))


## Sitio eriazo (D68): dirt, dry grass and litter; the corner ones make room for the bus arcs.
func _lot(lot: Dictionary) -> void:
	var w: float = float(lot.get("w", 20.0))
	var d: float = float(lot.get("d", 30.0))
	var yaw: float = float(lot.get("yaw", 0.0))
	var rot: Basis = Basis(Vector3.UP, yaw)
	var center: Vector3 = Vector3(float(lot.get("x", 0.0)), 0.0, float(lot.get("z", 0.0)))
	_b.box("dirt", Transform3D(rot * Basis.from_scale(Vector3(w, 0.02, d)), center + Vector3.UP * 0.01))
	var grass: GrassStrip = GrassStrip.new()
	grass.name = "Lot%d" % (lot_count() + 1)
	grass.base_colour = Color(0.55, 0.48, 0.25)
	grass.tip_colour = Color(0.8, 0.72, 0.4)
	add_child(grass)
	grass.build_along(PackedVector3Array([center - rot.z * (d * 0.45), center + rot.z * (d * 0.45)]), w * 0.42, 2.0, int(center.x) + 3)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = int(center.x * 11.0 + center.z * 5.0)
	for _k: int in int(lot.get("trash", 5)):
		var pos: Vector3 = center + rot.x * rng.randf_range(-w * 0.4, w * 0.4) + rot.z * rng.randf_range(-d * 0.4, d * 0.4)
		var size: float = rng.randf_range(0.4, 0.9)
		_b.add("trash" if rng.randf() < 0.6 else "trash_b", "box" if rng.randf() < 0.7 else "sph", Transform3D(Basis(Vector3.UP, rng.randf() * TAU) * Basis.from_scale(Vector3(size, size * 0.6, size * 0.8)), pos + Vector3.UP * (size * 0.3)))


func _add_delivery(center: Vector3, w: float, d: float) -> void:
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
	pad.position = front + Vector3.UP * 0.02
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
	receiver.position = front + toward * 1.5 + Vector3.UP * 0.9


func _fill(mm: MultiMesh, xforms: Array[Transform3D], colours: Array[Color]) -> void:
	mm.instance_count = xforms.size()
	for i: int in xforms.size():
		mm.set_instance_transform(i, xforms[i])
		mm.set_instance_color(i, colours[i])


func _multimesh(mesh: Mesh, custom: bool) -> MultiMesh:
	var mm: MultiMesh = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = custom
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
