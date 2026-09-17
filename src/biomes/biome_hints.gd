class_name BiomeHints
extends Node3D

## Las cuatro salidas del pueblo y lo que se ve al final de cada una (D78). El dueño lo
## dijo así: «solo 4 caminos van a la nada, que son los que te llevarían a los otros
## biomas; las sombras de esos 4 caminos a lo lejos deberían ser montañas, pantanos,
## océano y desierto». Cada salida (OsmMapData.exit_streets) se prolonga recta hacia
## afuera con la misma cinta de calzada, y a `hint_distance_m` del centro se planta la
## SILUETA del bioma que viene, en la geografía de Chile: cordillera al ESTE (ya la pone
## CityBackdrop, D67), desierto al NORTE, océano al OESTE, humedal al SUR. Son bultos
## grandes y baratos que la bruma vuelve sombras: prometen, no describen.

const COLOURS: Dictionary = {
	"dune": Color(0.78, 0.66, 0.42), "dune_b": Color(0.7, 0.56, 0.34), "dune_c": Color(0.84, 0.74, 0.5),
	"sea": Color(0.26, 0.42, 0.52), "surf": Color(0.86, 0.9, 0.9), "sand": Color(0.8, 0.74, 0.58),
	"marsh": Color(0.2, 0.3, 0.16), "marsh_water": Color(0.3, 0.42, 0.4), "dead_trunk": Color(0.5, 0.48, 0.44),
	"reed": Color(0.42, 0.5, 0.26), "street": Color(0.3, 0.31, 0.33),
}
## Este, norte, oeste, sur — el orden de OsmMapData.exit_quadrant.
const DIRS: Array[Vector3] = [Vector3(1, 0, 0), Vector3(0, 0, -1), Vector3(-1, 0, 0), Vector3(0, 0, 1)]

@export var data_path: String = "res://data/b0_requinoa.json"
## Dónde empieza la silueta, medido desde el centro del pueblo.
@export var hint_distance_m: float = 2200.0
## Cuánto sigue recta cada salida más allá de su último punto de OSM.
@export var road_extension_m: float = 700.0
@export var seed: int = 78

var data: OsmMapData
var _b: MeshBatcher = MeshBatcher.new()
var _r: RoadRibbon = RoadRibbon.new()


func _ready() -> void:
	data = OsmMapData.load_from(data_path)
	if data != null:
		build()


func build() -> void:
	for child: Node in get_children():
		remove_child(child)
		child.free()
	var centre2: Vector2 = data.axis_centre()
	var centre: Vector3 = Vector3(centre2.x, 0.0, centre2.y)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed
	for street: Dictionary in data.exit_streets():
		var far: Vector3 = _far_end(street, centre)
		var q: int = OsmMapData.exit_quadrant(Vector2(far.x - centre.x, far.z - centre.z))
		var dir: Vector3 = DIRS[q]
		var half: float = float(street.get("w", 6.0)) * 0.5
		var pts: PackedVector3Array = PackedVector3Array([far, far + dir * road_extension_m])
		_r.band("street", pts, RoadRibbon.lefts(pts), -half, half, 0.02)
		var at: Vector3 = centre + dir * hint_distance_m
		match q:
			1:
				_desert(at, dir, rng)
			2:
				_ocean(at, dir)
			3:
				_wetland(at, dir, rng)
	_b.flush(self, COLOURS)
	_r.flush(self, COLOURS)


func batch_count(kind: String) -> int:
	var node: Node = get_node_or_null("Batch_" + kind)
	if node is MultiMeshInstance3D:
		var inst: MultiMeshInstance3D = node
		return inst.multimesh.instance_count
	return 0


## Desierto árido: dunas anchas y bajas en tres tonos de ocre, más grandes hacia el fondo.
func _desert(at: Vector3, dir: Vector3, rng: RandomNumberGenerator) -> void:
	var across: Vector3 = Vector3.UP.cross(dir)
	_b.box("sand", Transform3D(Basis.from_scale(Vector3(3600.0, 0.3, 2400.0)), at + dir * 1200.0 + Vector3.UP * 0.05))
	for k: int in 18:
		var depth: float = rng.randf_range(0.0, 1800.0)
		var w: float = rng.randf_range(260.0, 520.0) * (1.0 + depth / 1800.0)
		var h: float = rng.randf_range(28.0, 60.0) * (1.0 + depth / 1200.0)
		var pos: Vector3 = at + dir * depth + across * rng.randf_range(-1500.0, 1500.0)
		var kind: String = ["dune", "dune_b", "dune_c"][k % 3]
		_b.add(kind, "sph", Transform3D(Basis(Vector3.UP, rng.randf() * TAU) * Basis.from_scale(Vector3(w, h * 2.0, w * rng.randf_range(0.45, 0.7))), pos + Vector3.DOWN * (h * 0.2)))


## Océano: un mar hasta el horizonte con una línea de espuma y una playa delante.
func _ocean(at: Vector3, dir: Vector3) -> void:
	var across: Vector3 = Vector3.UP.cross(dir)
	var rot: Basis = Basis(Vector3.UP, OsmMapData.yaw_facing(dir))
	_b.box("sand", MeshBatcher.along(rot, at - dir * 120.0, Vector3(4000.0, 0.3, 240.0), 0.05))
	_b.box("sea", MeshBatcher.along(rot, at + dir * 3000.0, Vector3(6000.0, 0.4, 6000.0), 0.08))
	for k: int in 3:
		_b.box("surf", MeshBatcher.along(rot, at + dir * (8.0 + float(k) * 26.0), Vector3(4000.0, 0.06, 6.0 - float(k) * 1.5), 0.3))
	# un par de rocas mar adentro, para que el borde no sea una regla
	_b.add("dead_trunk", "sph", Transform3D(Basis.from_scale(Vector3(60.0, 24.0, 40.0)), at + dir * 700.0 + across * 500.0))
	_b.add("dead_trunk", "sph", Transform3D(Basis.from_scale(Vector3(40.0, 16.0, 30.0)), at + dir * 900.0 - across * 800.0))


## Humedal: suelo oscuro, espejos de agua y el bosque ahogado de troncos muertos (D71).
func _wetland(at: Vector3, dir: Vector3, rng: RandomNumberGenerator) -> void:
	var across: Vector3 = Vector3.UP.cross(dir)
	_b.box("marsh", Transform3D(Basis.from_scale(Vector3(3200.0, 0.3, 2000.0)), at + dir * 1000.0 + Vector3.UP * 0.05))
	for k: int in 14:
		var pos: Vector3 = at + dir * rng.randf_range(100.0, 1800.0) + across * rng.randf_range(-1400.0, 1400.0)
		var w: float = rng.randf_range(120.0, 320.0)
		_b.add("marsh_water", "cyl", Transform3D(Basis(Vector3.UP, rng.randf() * TAU) * Basis.from_scale(Vector3(w, 0.2, w * rng.randf_range(0.5, 0.9))), pos + Vector3.UP * 0.25))
	for k2: int in 90:
		var pos2: Vector3 = at + dir * rng.randf_range(60.0, 1900.0) + across * rng.randf_range(-1500.0, 1500.0)
		var h: float = rng.randf_range(9.0, 18.0)
		_b.add("dead_trunk", "cyl", Transform3D(Basis(Vector3.RIGHT, rng.randf_range(-0.12, 0.12)) * Basis.from_scale(Vector3(1.4, h, 1.4)), pos2 + Vector3.UP * (h * 0.5)))
	for k3: int in 40:
		var pos3: Vector3 = at + dir * rng.randf_range(0.0, 600.0) + across * rng.randf_range(-1500.0, 1500.0)
		_b.add("reed", "cyl", Transform3D(Basis.from_scale(Vector3(rng.randf_range(30.0, 70.0), 2.4, rng.randf_range(30.0, 70.0))), pos3 + Vector3.UP * 1.2))


static func _far_end(street: Dictionary, centre: Vector3) -> Vector3:
	var raw: Array = street.get("pts", []) as Array
	var best: Vector3 = centre
	var best_d: float = -1.0
	for pair: Variant in raw:
		var arr: Array = pair
		if arr.size() < 2:
			continue
		var p: Vector3 = Vector3(float(arr[0]), 0.0, float(arr[1]))
		var d: float = p.distance_to(centre)
		if d > best_d:
			best_d = d
			best = p
	return best
