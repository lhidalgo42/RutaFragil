class_name HouseRow
extends Node3D

## Greybox row of terraced houses along the avenue (D63): the facades are one
## MultiMesh (8 m fronts, one or two floors of 3.5 m, three flat colours),
## the front fence at the property line is a second MultiMesh, and one long
## StaticBody3D box covers the whole row so the bus stops at the fence line.
## Deterministic from `seed`; rebuilt on `build()`.

const FRONT_M: float = 8.0
const DEPTH_M: float = 10.0
const FLOOR_M: float = 3.5
## Antejardín between the fence (property line, row origin) and the facade.
const SETBACK_M: float = 2.5
const FENCE_H_M: float = 1.8
const FENCE_T_M: float = 0.1
const COLOURS: Array[Color] = [
	Color(0.85, 0.72, 0.45),
	Color(0.93, 0.9, 0.82),
	Color(0.9, 0.7, 0.68),
]

@export var count: int = 10
## +1 puts the houses on the +X side of the row origin (fronts face -X); -1 mirrors.
@export var side: int = 1
@export var seed: int = 1


func _ready() -> void:
	build()


func build() -> void:
	for child: Node in get_children():
		child.queue_free()
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed
	var sign_x: float = -1.0 if side < 0 else 1.0
	var facades: MultiMesh = _make_multimesh(true)
	var fences: MultiMesh = _make_multimesh(false)
	for i: int in count:
		var floors: int = 1 + (rng.randi() % 2)
		var h: float = float(floors) * FLOOR_M
		var z: float = (float(i) + 0.5) * FRONT_M
		var facade_basis: Basis = Basis.from_scale(Vector3(DEPTH_M, h, FRONT_M * 0.96))
		var facade_pos: Vector3 = Vector3(sign_x * (SETBACK_M + DEPTH_M * 0.5), h * 0.5, z)
		facades.set_instance_transform(i, Transform3D(facade_basis, facade_pos))
		facades.set_instance_color(i, COLOURS[rng.randi() % COLOURS.size()])
		var fence_basis: Basis = Basis.from_scale(Vector3(FENCE_T_M, FENCE_H_M, FRONT_M))
		fences.set_instance_transform(i, Transform3D(fence_basis, Vector3(sign_x * FENCE_T_M * 0.5, FENCE_H_M * 0.5, z)))
	_add_instance("Facades", facades)
	_add_instance("Fences", fences)
	_add_body(sign_x)


func facade_count() -> int:
	var node: Node = get_node_or_null("Facades")
	if node is MultiMeshInstance3D:
		var instance: MultiMeshInstance3D = node
		return instance.multimesh.instance_count
	return 0


func row_length_m() -> float:
	return float(count) * FRONT_M


func _make_multimesh(coloured: bool) -> MultiMesh:
	var mm: MultiMesh = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = coloured
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = Vector3.ONE
	var material: StandardMaterial3D = StandardMaterial3D.new()
	if coloured:
		material.vertex_color_use_as_albedo = true
	else:
		material.albedo_color = Color(0.3, 0.3, 0.32)
	mesh.material = material
	mm.mesh = mesh
	mm.instance_count = count
	return mm


func _add_instance(node_name: String, mm: MultiMesh) -> void:
	var instance: MultiMeshInstance3D = MultiMeshInstance3D.new()
	instance.name = node_name
	instance.multimesh = mm
	add_child(instance)


func _add_body(sign_x: float) -> void:
	var body: StaticBody3D = StaticBody3D.new()
	body.name = "Body"
	var shape_node: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	var depth: float = SETBACK_M + DEPTH_M
	box.size = Vector3(depth, FLOOR_M * 2.0, row_length_m())
	shape_node.shape = box
	shape_node.position = Vector3(sign_x * depth * 0.5, FLOOR_M, row_length_m() * 0.5)
	body.add_child(shape_node)
	add_child(body)
