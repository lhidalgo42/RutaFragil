class_name GrassStrip
extends MultiMeshInstance3D

## Greybox grass (D64): thousands of two-quad tufts scattered along a polyline
## strip, one MultiMesh, shader `grass_tuft.gdshader` (wind + bend away from
## the bus). Mesh only, no collision. Joins group "grass" so the route scene
## can hand it the bus with set_follow().

const SHADER: Shader = preload("res://assets/shaders/grass_tuft.gdshader")
const TUFT_W: float = 0.5
const TUFT_H: float = 0.45

@export var follow: Node3D
@export var base_colour: Color = Color(0.22, 0.42, 0.18)
@export var tip_colour: Color = Color(0.55, 0.75, 0.3)

var _material: ShaderMaterial
## Tuft origins from the last build (readable in headless tests, unlike the MultiMesh buffer).
var positions: PackedVector3Array = PackedVector3Array()


func _ready() -> void:
	add_to_group("grass")


func set_follow(node: Node3D) -> void:
	follow = node


func _process(_delta: float) -> void:
	if follow != null and _material != null:
		_material.set_shader_parameter("bus_position", follow.global_position)


## Scatters tufts along the strip centred on `points`, `half_width` each side,
## `per_m2` tufts per square metre, deterministic for `seed`. Returns the count.
func build_along(points: PackedVector3Array, half_width: float, per_m2: float, seed: int) -> int:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed
	var transforms: Array[Transform3D] = []
	for i: int in points.size() - 1:
		var a: Vector3 = points[i]
		var b: Vector3 = points[i + 1]
		var seg: Vector3 = b - a
		var length: float = seg.length()
		if length < 0.01:
			continue
		var tangent: Vector3 = seg / length
		var normal: Vector3 = Vector3.UP.cross(tangent)
		var count: int = int(round(length * half_width * 2.0 * per_m2))
		for _k: int in count:
			var along: float = rng.randf() * length
			var across: float = rng.randf_range(-half_width, half_width)
			var pos: Vector3 = a + tangent * along + normal * across
			var basis: Basis = Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.7, 1.3))
			transforms.append(Transform3D(basis, pos))
	positions = PackedVector3Array()
	for xf: Transform3D in transforms:
		positions.append(xf.origin)
	_apply(transforms)
	return transforms.size()


func _apply(transforms: Array[Transform3D]) -> void:
	var mm: MultiMesh = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = _make_tuft_mesh()
	mm.instance_count = transforms.size()
	for i: int in transforms.size():
		mm.set_instance_transform(i, transforms[i])
	multimesh = mm
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_material.set_shader_parameter("base_colour", Vector3(base_colour.r, base_colour.g, base_colour.b))
	_material.set_shader_parameter("tip_colour", Vector3(tip_colour.r, tip_colour.g, tip_colour.b))
	material_override = _material
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _make_tuft_mesh() -> ArrayMesh:
	var verts: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()
	var uvs: PackedVector2Array = PackedVector2Array()
	var indices: PackedInt32Array = PackedInt32Array()
	for q: int in 2:
		var angle: float = float(q) * PI * 0.5
		var side: Vector3 = Vector3(cos(angle), 0.0, sin(angle)) * (TUFT_W * 0.5)
		var base: int = verts.size()
		verts.append(-side)
		verts.append(side)
		verts.append(side + Vector3.UP * TUFT_H)
		verts.append(-side + Vector3.UP * TUFT_H)
		for _n: int in 4:
			normals.append(Vector3.UP)
		uvs.append(Vector2(0.0, 0.0))
		uvs.append(Vector2(1.0, 0.0))
		uvs.append(Vector2(1.0, 1.0))
		uvs.append(Vector2(0.0, 1.0))
		indices.append_array(PackedInt32Array([base, base + 1, base + 2, base, base + 2, base + 3]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
