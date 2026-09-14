class_name CityBackdrop
extends Node3D

## Santiago backdrop (D67), mesh only: the Andes as a line of big low-poly
## prisms kilometres to the east (+X), a lower foothill line in front of them,
## and dry island hills scattered around the city outside the corridor. The
## route cameras need `far` beyond the ridge distance to see them.

const COLOURS: Dictionary = {"andes": Color(0.55, 0.58, 0.68), "foothills": Color(0.52, 0.5, 0.46), "hills": Color(0.5, 0.47, 0.35)}

@export var seed: int = 7
@export var ridge_distance_m: float = 6000.0
@export var peaks: int = 14
@export var hills: int = 14
## No hill closer than this to the origin of the corridor (metres).
@export var hill_min_distance_m: float = 900.0

var _b: MeshBatcher = MeshBatcher.new()


func _ready() -> void:
	build()


func build() -> void:
	for child: Node in get_children():
		remove_child(child)
		child.free()
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed
	for i: int in peaks:
		var z: float = -5200.0 + float(i) * (10400.0 / float(maxi(1, peaks - 1))) + rng.randf_range(-250.0, 250.0)
		var h: float = rng.randf_range(1100.0, 2100.0)
		var base: float = rng.randf_range(1500.0, 2600.0)
		var x: float = ridge_distance_m + rng.randf_range(-500.0, 500.0)
		# the prism triangle faces the city (west): rotate 90 deg so the silhouette is a peak, not a ridge line
		_b.add("andes", "prism", Transform3D(Basis(Vector3.UP, PI * 0.5 + rng.randf_range(-0.2, 0.2)) * Basis.from_scale(Vector3(base, h, base * 0.7)), Vector3(x, h * 0.5 - 60.0, z)))
	for i: int in peaks - 2:
		var z: float = -4800.0 + float(i) * (9600.0 / float(maxi(1, peaks - 3))) + rng.randf_range(-200.0, 200.0)
		var h: float = rng.randf_range(450.0, 800.0)
		var base: float = rng.randf_range(900.0, 1500.0)
		_b.add("foothills", "prism", Transform3D(Basis(Vector3.UP, PI * 0.5 + rng.randf_range(-0.3, 0.3)) * Basis.from_scale(Vector3(base, h, base * 0.6)), Vector3(ridge_distance_m - 1700.0 + rng.randf_range(-300.0, 300.0), h * 0.5 - 30.0, z)))
	var placed: int = 0
	while placed < hills:
		var angle: float = rng.randf() * TAU
		var dist: float = rng.randf_range(hill_min_distance_m, 3200.0)
		var pos: Vector3 = Vector3(cos(angle) * dist, 0.0, sin(angle) * dist)
		if pos.x > ridge_distance_m - 2600.0:
			continue
		var w: float = rng.randf_range(350.0, 900.0)
		var h: float = rng.randf_range(60.0, 220.0)
		_b.add("hills", "sph", Transform3D(Basis(Vector3.UP, rng.randf() * TAU) * Basis.from_scale(Vector3(w, h * 2.0, w * rng.randf_range(0.6, 1.0))), pos + Vector3.DOWN * (h * 0.15)))
		placed += 1
	_b.flush(self, COLOURS)


func batch_positions(kind: String) -> PackedVector3Array:
	return _b.positions(kind)


func batch_count(kind: String) -> int:
	var node: Node = get_node_or_null("Batch_" + kind)
	if node is MultiMeshInstance3D:
		var inst: MultiMeshInstance3D = node
		return inst.multimesh.instance_count
	return 0
