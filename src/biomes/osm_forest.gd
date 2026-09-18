class_name OsmForest
extends Node3D

## Bosque denso alrededor del pueblo (D81; modelos reales y orla irregular en D82). El dueño
## pintó de rojo todo lo que rodea al anillo: «tiene que ser un bosque, con pinos y cosas por
## el estilo, gigantes». Cada polígono de `data.forests` se siembra con pinos de 16 a 38 m
## (modelos CC0 de Quaternius, con el de Kenney de lejos) en una grilla de FOREST_STEP metros
## movida al azar; uno de cada ocho es un árbol frondoso, y entre los troncos hay helechos,
## piedras y tocones. Se respeta un claro de CLEAR_M a cada lado de cualquier calzada y de
## RAIL_CLEAR_M a cada lado de las vías: las salidas se leen como un camino de álamos que
## entra al bosque, y el tren pasa por su corredor.
##
## La ORLA (D82): un bosque no termina en una línea recta. En los EDGE_M metros pegados al
## borde del polígono el bosque se deshace en claros con forma de ruido y los árboles son
## más bajos (los jóvenes crecen en el borde). Lejos del pueblo (más de DENSE_UNTIL_M) se
## siembra la mitad: es silueta de fondo.
##
## Cada polígono se parte en LOSAS de TILE_M metros y cada losa es su propio lote de
## MultiMesh, así la cámara descarta las que no mira y el nivel de detalle cambia por losa.
## Las losas se siembran POR CUADROS (`progressive`), de FRAME_BUDGET_MS cada uno y las más
## cercanas al pueblo primero: el pueblo aparece al instante y el bosque se completa en un
## par de segundos, en vez de congelar la carga. `build()` siembra todo de una vez (pruebas,
## fotos). Las copas se anotan en la máscara de sombra para que el suelo ponga hojas y musgo.

const FOREST_STEP: float = 8.0
const TILE_M: float = 160.0
const CLEAR_M: float = 22.0
const RAIL_CLEAR_M: float = 12.0
const EDGE_M: float = 90.0
const DENSE_UNTIL_M: float = 750.0
const FRAME_BUDGET_MS: int = 16
const COLOURS: Dictionary = {"fern": Color(0.3, 0.48, 0.24)}

@export var data_path: String = "res://data/b0_pueblo.json"
@export var seed: int = 81
## Densidad relativa: 1 = un árbol cada FOREST_STEP metros. Baja para aligerar.
@export_range(0.2, 1.5) var density: float = 1.0
## Sembrar por losas a lo largo de varios cuadros. Apagado, `_ready` siembra todo de una vez.
@export var progressive: bool = true

var data: OsmMapData
var _tiles: int = 0
var _pines: int = 0
var _jobs: Array = []
var _mask: RoadMask
var _rails: Array[PackedVector2Array] = []
var _noise: FastNoiseLite
var _centre: Vector2


func _ready() -> void:
	data = OsmMapData.load_from(data_path)
	if data == null:
		set_process(false)
		return
	_queue()
	if progressive:
		set_process(true)
	else:
		build()


## Siembra todo lo que quede en cola, de una vez.
func build() -> void:
	if data == null:
		return
	if _jobs.is_empty() and _tiles == 0:
		_queue()
	while not _jobs.is_empty():
		_plant_tile(_jobs.pop_front())
	MeshBatcher.update_canopy()
	set_process(false)


func _process(_delta: float) -> void:
	var t0: int = Time.get_ticks_msec()
	while not _jobs.is_empty() and Time.get_ticks_msec() - t0 < FRAME_BUDGET_MS:
		_plant_tile(_jobs.pop_front())
	if _jobs.is_empty():
		MeshBatcher.update_canopy()
		set_process(false)


func pine_count() -> int:
	return _pines


func tile_count() -> int:
	return _tiles


func pending_tiles() -> int:
	return _jobs.size()


func _queue() -> void:
	for child: Node in get_children():
		remove_child(child)
		child.free()
	_tiles = 0
	_pines = 0
	_jobs.clear()
	_mask = RoadMask.shared(data, data_path)
	_rails.clear()
	for line: Variant in data.rail_lines:
		var pts: PackedVector2Array = PackedVector2Array()
		for q: Variant in (line as Array):
			var pair: Array = q
			if pair.size() >= 2:
				pts.append(Vector2(float(pair[0]), float(pair[1])))
		if pts.size() >= 2:
			_rails.append(pts)
	_noise = FastNoiseLite.new()
	_noise.seed = seed
	_noise.frequency = 0.009
	_centre = data.axis_centre()
	for forest: Dictionary in data.forests:
		var poly: PackedVector2Array = PackedVector2Array()
		for q: Variant in (forest.get("polygon", []) as Array):
			var pair: Array = q
			if pair.size() >= 2:
				poly.append(Vector2(float(pair[0]), float(pair[1])))
		if poly.size() < 3:
			continue
		var lo: Vector2 = poly[0]
		var hi: Vector2 = poly[0]
		for v: Vector2 in poly:
			lo = lo.min(v)
			hi = hi.max(v)
		var tx: float = lo.x
		while tx < hi.x:
			var tz: float = lo.y
			while tz < hi.y:
				_jobs.append([poly, Vector2(tx, tz), str(forest.get("name", "bosque")).replace(" ", "_")])
				tz += TILE_M
			tx += TILE_M
	# las losas cercanas al pueblo primero: son las que se ven al arrancar
	_jobs.sort_custom(func(a: Array, b: Array) -> bool:
		return (a[1] as Vector2).distance_squared_to(_centre) < (b[1] as Vector2).distance_squared_to(_centre))


func _plant_tile(job: Array) -> void:
	var poly: PackedVector2Array = job[0]
	var lo: Vector2 = job[1]
	var hi: Vector2 = lo + Vector2.ONE * TILE_M
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed + int(lo.x) * 7 + int(lo.y)
	var step: float = FOREST_STEP / maxf(density, 0.05)
	if (lo + Vector2.ONE * (TILE_M * 0.5)).distance_to(_centre) > DENSE_UNTIL_M:
		step *= 1.5
	var batcher: MeshBatcher = MeshBatcher.new()
	var planted: int = 0
	var x: float = lo.x + step * 0.5
	while x < hi.x:
		var z: float = lo.y + step * 0.5
		while z < hi.y:
			var p: Vector2 = Vector2(x + rng.randf_range(-0.45, 0.45) * step, z + rng.randf_range(-0.45, 0.45) * step)
			var pick: float = rng.randf()
			z += step
			if not Geometry2D.is_point_in_polygon(p, poly):
				continue
			var edge: float = clampf(_edge_distance(p, poly) / EDGE_M, 0.0, 1.0)
			if _noise.get_noise_2d(p.x, p.y) * 0.5 + 0.5 > edge + 0.12:
				continue
			var world: Vector3 = Vector3(p.x, 0.0, p.y)
			if _mask.is_paved(world, CLEAR_M) or _near_rail(p):
				continue
			planted += 1
			var young: float = lerpf(0.5, 1.0, sqrt(edge))
			if pick < 0.12:
				batcher.broadleaf(world, rng.randf_range(9.0, 15.0) * young)
			else:
				batcher.pine(world, rng.randf_range(16.0, 38.0) * young)
			if rng.randf() < 0.3:
				var f: float = rng.randf_range(0.9, 1.5)
				batcher.add("fern", "card", Transform3D(Basis(Vector3.UP, rng.randf() * TAU) * Basis.from_scale(Vector3(f * 0.7, f * 1.1, f * 0.7)), world + Vector3(rng.randf_range(-3.0, 3.0), f * 0.5, rng.randf_range(-3.0, 3.0))))
			var extra: float = rng.randf()
			if extra < 0.04:
				batcher.prop("rock_%d" % (rng.randi_range(1, 3)), world + Vector3(rng.randf_range(-3.5, 3.5), 0.0, rng.randf_range(-3.5, 3.5)), rng.randf_range(0.6, 1.8))
			elif extra < 0.055:
				batcher.prop("stump_1", world + Vector3(rng.randf_range(-3.5, 3.5), 0.0, rng.randf_range(-3.5, 3.5)), rng.randf_range(0.7, 1.2))
		x += step
	if planted > 0:
		var tile: Node3D = Node3D.new()
		tile.name = "%s_%d" % [job[2], _tiles]
		add_child(tile)
		batcher.flush(tile, COLOURS)
		_tiles += 1
		_pines += planted


## Distancia al borde más cercano del polígono, en metros.
func _edge_distance(p: Vector2, poly: PackedVector2Array) -> float:
	var best: float = INF
	for i: int in poly.size():
		var a: Vector2 = poly[i]
		var b: Vector2 = poly[(i + 1) % poly.size()]
		best = minf(best, Geometry2D.get_closest_point_to_segment(p, a, b).distance_to(p))
	return best


func _near_rail(p: Vector2) -> bool:
	for line: PackedVector2Array in _rails:
		for i: int in line.size() - 1:
			if Geometry2D.get_closest_point_to_segment(p, line[i], line[i + 1]).distance_to(p) < RAIL_CLEAR_M:
				return true
	return false
