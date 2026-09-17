class_name OsmTown
extends Node3D

## Everything that makes the small town read as Requínoa (D69), all mesh only:
## the railway with its level crossings, the historic station and its platforms,
## the Plaza de Armas, the churches, the irrigation ditches, the vineyard rows
## and the motorway that runs under the bridge. Roadway lives in OsmRoad,
## houses in OsmBuildings, fences and poplars in OsmFurniture.

const COLOURS: Dictionary = {
	"ballast": Color(0.42, 0.38, 0.34), "sleeper": Color(0.3, 0.24, 0.18), "rail": Color(0.45, 0.42, 0.4),
	"platform": Color(0.72, 0.7, 0.66), "station": Color(0.78, 0.72, 0.6), "roof": Color(0.5, 0.26, 0.2),
	"barrier": Color(0.92, 0.92, 0.9), "barrier_red": Color(0.8, 0.15, 0.12), "cross": Color(0.95, 0.95, 0.93),
	"paving": Color(0.74, 0.72, 0.68), "grass": Color(0.34, 0.5, 0.28), "kiosk": Color(0.85, 0.82, 0.74),
	"path": Color(0.78, 0.73, 0.64), "fountain": Color(0.8, 0.78, 0.72), "fountain_water": Color(0.32, 0.56, 0.62),
	"hedge": Color(0.24, 0.42, 0.22), "plaza_lawn": Color(0.31, 0.49, 0.25), "lamp_post": Color(0.2, 0.22, 0.24), "lamp_globe": Color(0.96, 0.94, 0.84),
	"bench": Color(0.45, 0.32, 0.2), "trunk": Color(0.4, 0.28, 0.18), "crown": Color(0.26, 0.48, 0.24),
	"tower": Color(0.85, 0.8, 0.72), "cross_church": Color(0.9, 0.88, 0.84),
	"water": Color(0.32, 0.42, 0.45), "bank": Color(0.46, 0.4, 0.3),
	"vine": Color(0.3, 0.42, 0.22), "vine_post": Color(0.5, 0.42, 0.32), "vine_wire": Color(0.35, 0.35, 0.36),
	"fountain_stream": Color(0.55, 0.75, 0.8), "fountain_floor": Color(0.78, 0.8, 0.76),
	"foam": Color(0.94, 0.97, 0.98), "spray": Color(0.9, 0.95, 0.97),
	"motorway": Color(0.26, 0.27, 0.29), "motorway_paint": Color(0.92, 0.92, 0.88),
	"street": Color(0.27, 0.28, 0.3), "street_dirt": Color(0.54, 0.44, 0.32), "street_line": Color(0.86, 0.85, 0.8),
	"truck_a": Color(0.85, 0.85, 0.85), "truck_b": Color(0.2, 0.35, 0.6),
}
const RAIL_GAUGE_M: float = 1.676        # trocha chilena
const SLEEPER_STEP_M: float = 5.0
const MAX_SLEEPERS: int = 1400
const RAIL_RANGE_M: float = 900.0

@export var data_path: String = "res://data/b0_requinoa.json"

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
	_build_streets()
	_build_rail()
	_build_crossings()
	_build_station()
	_build_plaza()
	_build_churches()
	_build_water()
	_build_vines()
	_build_motorway()
	_b.flush(self, COLOURS)
	_r.flush(self, COLOURS)
	MeshBatcher.update_canopy()


func batch_count(kind: String) -> int:
	var node: Node = get_node_or_null("Batch_" + kind)
	if node is MultiMeshInstance3D:
		var inst: MultiMeshInstance3D = node
		return inst.multimesh.instance_count
	return 0


## The rest of the town's streets (D69 round 7): every drivable OSM way within 520 m of the
## route, minus the route itself, so the town reads as connected instead of one loose ribbon.
## Mesh only: the ground is flat, so the bus can drive on any of them.
func _build_streets() -> void:
	for item: Variant in data.streets:
		if not (item is Dictionary):
			continue
		var street: Dictionary = item
		# Poda (D78): una calle sin casas a 45 m en al menos el 30 % de su largo es campo,
		# no pueblo, y no se dibuja — salvo las cuatro salidas, que llevan a los otros biomas.
		if not (data.street_is_inhabited(street) or data.is_exit_street(street)):
			continue
		var pts: PackedVector3Array = _points(street.get("pts", []))
		if pts.size() < 2:
			continue
		var half: float = float(street.get("w", 6.0)) * 0.5
		var dirt: bool = str(street.get("surface", "street")) == "gravel"
		# Las calles de OSM llegan hasta el EJE de la ruta: la cinta pisaba la calzada
		# principal con otra textura y otra altura (D76). Se recortan al cordón.
		pts = _trim_to_route(pts)
		if pts.size() < 2:
			continue
		# Cinta continua (D72): en las esquinas del pueblo la cadena de cajas dejaba
		# el mismo diente que en la ruta, y aquí hay 217 calles con esquinas.
		var lefts: PackedVector3Array = RoadRibbon.lefts(pts)
		# La textura de la calzada (D74) trae la línea central pintada: ya no se dibuja aparte.
		# A la misma altura que la calzada de la ruta: a 4 cm quedaba un escalón visible.
		_r.band("street_dirt" if dirt else "street", pts, lefts, -half, half, 0.02)


func _build_rail() -> void:
	var sleepers: int = 0
	for line: Variant in data.rail_lines:
		var pts: PackedVector3Array = _points(line)
		for i: int in maxi(0, pts.size() - 1):
			var a: Vector3 = pts[i]
			var b: Vector3 = pts[i + 1]
			if not (_near_route(a) or _near_route(b)):
				continue
			var seg: float = a.distance_to(b)
			if seg < 0.5:
				continue
			var dir: Vector3 = (b - a) / seg
			var across: Vector3 = Vector3.UP.cross(dir)
			var mid: Vector3 = (a + b) * 0.5
			var rot: Basis = Basis.looking_at(dir, Vector3.UP)
			_b.box("ballast", Transform3D(rot * Basis.from_scale(Vector3(4.2, 0.3, seg)), mid + Vector3.UP * 0.15))
			for side: float in [-1.0, 1.0]:
				_b.box("rail", Transform3D(rot * Basis.from_scale(Vector3(0.12, 0.16, seg)), mid + across * (side * RAIL_GAUGE_M * 0.5) + Vector3.UP * 0.38))
			var t: float = 0.0
			while t < seg and sleepers < MAX_SLEEPERS:
				_b.box("sleeper", Transform3D(rot * Basis.from_scale(Vector3(2.6, 0.16, 0.24)), a + dir * t + Vector3.UP * 0.31))
				sleepers += 1
				t += SLEEPER_STEP_M


## Level crossing: rails across the asphalt, the Saint Andrew's cross and a raised boom each side.
func _build_crossings() -> void:
	for c: Dictionary in data.crossings:
		var centre: Vector3 = Vector3(float(c.get("x", 0.0)), 0.0, float(c.get("z", 0.0)))
		var rail_yaw: float = float(c.get("rail_yaw", 0.0))
		var along: Vector3 = Vector3(cos(rail_yaw), 0.0, -sin(rail_yaw))
		var frame: Transform3D = data.sample(float(c.get("s", 0.0)))
		var across: Vector3 = data.left_of(frame)
		var half: float = data.curb_at(float(c.get("s", 0.0))) + 1.0
		for side: float in [-1.0, 1.0]:
			var rail_a: Vector3 = centre + along * (side * RAIL_GAUGE_M * 0.5) - across * half
			var rail_b: Vector3 = centre + along * (side * RAIL_GAUGE_M * 0.5) + across * half
			_b.box("rail", MeshBatcher.between(rail_a + Vector3.UP * 0.05, rail_b + Vector3.UP * 0.05, 0.12))
			var post: Vector3 = centre + across * (side * (half + 1.2)) + along * 2.6
			_b.add("barrier", "cyl", Transform3D(Basis.from_scale(Vector3(0.22, 3.2, 0.22)), post + Vector3.UP * 1.6))
			_b.box("cross", Transform3D(Basis(Vector3.UP, rail_yaw) * Basis(Vector3.BACK, PI * 0.25) * Basis.from_scale(Vector3(1.5, 0.18, 0.1)), post + Vector3.UP * 3.0))
			_b.box("cross", Transform3D(Basis(Vector3.UP, rail_yaw) * Basis(Vector3.BACK, -PI * 0.25) * Basis.from_scale(Vector3(1.5, 0.18, 0.1)), post + Vector3.UP * 3.0))
			# boom up, resting against its post
			_b.box("barrier_red", Transform3D(Basis(Vector3.UP, rail_yaw) * Basis(Vector3.BACK, PI * 0.42) * Basis.from_scale(Vector3(0.18, 5.6, 0.18)), post + Vector3.UP * 2.6))


func _build_station() -> void:
	var st: Dictionary = data.rail_station
	if st.is_empty():
		return
	var centre: Vector3 = Vector3(float(st.get("x", 0.0)), 0.0, float(st.get("z", 0.0)))
	var yaw: float = float(st.get("yaw", 0.0))
	var rot: Basis = Basis(Vector3.UP, yaw)
	_b.box("station", Transform3D(rot * Basis.from_scale(Vector3(26.0, 6.0, 11.0)), centre + Vector3.UP * 3.0))
	_b.box("roof", Transform3D(rot * Basis.from_scale(Vector3(28.5, 0.4, 13.5)), centre + Vector3.UP * 6.2))
	_b.add("roof", "prism", Transform3D(rot * Basis.from_scale(Vector3(28.0, 2.2, 13.0)), centre + Vector3.UP * 7.3))
	for p: Dictionary in data.rail_platforms:
		var pc: Vector3 = Vector3(float(p.get("x", 0.0)), 0.0, float(p.get("z", 0.0)))
		var plen: float = float(p.get("len", 40.0))
		var prot: Basis = Basis(Vector3.UP, float(p.get("yaw", yaw)))
		_b.box("platform", Transform3D(prot * Basis.from_scale(Vector3(4.0, 0.55, plen)), pc + Vector3.UP * 0.27))
		for k: int in 4:
			var off: float = (float(k) / 3.0 - 0.5) * (plen - 6.0)
			_b.add("barrier", "cyl", Transform3D(Basis.from_scale(Vector3(0.14, 3.0, 0.14)), pc + prot * Vector3(0.0, 0.0, off) + Vector3.UP * 2.05))
			_b.box("roof", Transform3D(prot * Basis.from_scale(Vector3(4.4, 0.15, plen / 3.4)), pc + prot * Vector3(0.0, 0.0, off) + Vector3.UP * 3.6))


## Plaza de Armas (D72). Antes: un pavimento rectangular, cuatro cajas de pasto y un
## quiosco de cilindros. Ahora tiene su centro — la fuente "Pilón Quenlobo", una taza
## de tres cuerpos escalonados sobre un estanque redondo — y los caminos llegan a ella
## en diagonal, con el césped partido en cuñas en vez de en cuatro cuadrados.
func _build_plaza() -> void:
	var pz: Dictionary = data.plaza
	if pz.is_empty():
		return
	var poly: PackedVector3Array = _points(pz.get("polygon", []))
	if poly.size() < 3:
		return
	var lo: Vector3 = poly[0]
	var hi: Vector3 = poly[0]
	for p: Vector3 in poly:
		lo = lo.min(p)
		hi = hi.max(p)
	var centre: Vector3 = (lo + hi) * 0.5
	var size: Vector3 = hi - lo
	var reach: float = minf(size.x, size.z) * 0.5
	_b.box("paving", Transform3D(Basis.from_scale(Vector3(size.x, 0.12, size.z)), centre + Vector3.UP * 0.06))
	# Cuatro canteros de césped chicos y a ras (D77): los de antes eran losas de 27 m
	# flotando 10 cm, «cuatro losas verdes enormes» en la foto. Cada cantero: borde de
	# seto bajo por sus cuatro lados, dos árboles grandes y una banca.
	for k: int in 4:
		var ang: float = TAU * float(k) / 4.0 + PI * 0.25
		var dir: Vector3 = Vector3(cos(ang), 0.0, sin(ang))
		var side_dir: Vector3 = Vector3(-sin(ang), 0.0, cos(ang))
		var lawn: Vector3 = centre + dir * (reach * 0.52)
		var lawn_half: float = reach * 0.17
		var lawn_rot: Basis = Basis(Vector3.UP, -ang)
		_b.box("plaza_lawn", Transform3D(lawn_rot * Basis.from_scale(Vector3(lawn_half * 2.0, 0.05, lawn_half * 2.0)), lawn + Vector3.UP * 0.135))
		for edge: int in 4:
			var e_ang: float = ang + TAU * float(edge) / 4.0
			var e_dir: Vector3 = Vector3(cos(e_ang), 0.0, sin(e_ang))
			_b.box("hedge", Transform3D(Basis(Vector3.UP, -e_ang) * Basis.from_scale(Vector3(0.5, 0.55, lawn_half * 1.9)), lawn + e_dir * lawn_half + Vector3.UP * 0.4))
		_tree(lawn + side_dir * (lawn_half * 0.45), 5.2, 2.6)
		_tree(lawn - side_dir * (lawn_half * 0.5) + dir * (lawn_half * 0.3), 4.4, 2.2)
	# Los cuatro caminos que entran a la fuente, en diagonal
	for k: int in 4:
		var ang2: float = TAU * float(k) / 4.0
		var dir2: Vector3 = Vector3(cos(ang2), 0.0, sin(ang2))
		_b.box("path", Transform3D(Basis(Vector3.UP, -ang2) * Basis.from_scale(Vector3(reach * 1.05, 0.14, 3.4)), centre + dir2 * (reach * 0.52) + Vector3.UP * 0.09))
	_build_fountain(centre)
	for k: int in 8:
		var a2: float = TAU * float(k) / 8.0
		var seat: Vector3 = centre + Vector3(cos(a2), 0.0, sin(a2)) * (reach * 0.72)
		# mirando a la fuente, no cada una para su lado
		_b.box("bench", Transform3D(Basis(Vector3.UP, -a2) * Basis.from_scale(Vector3(0.5, 0.12, 1.9)), seat + Vector3.UP * 0.5))
		for leg: float in [-0.7, 0.7]:
			_b.box("bench", Transform3D(Basis(Vector3.UP, -a2) * Basis.from_scale(Vector3(0.12, 0.44, 0.12)), seat + Vector3(cos(a2 + PI * 0.5), 0.0, sin(a2 + PI * 0.5)) * leg + Vector3.UP * 0.22))
	for k: int in 4:
		var a3: float = TAU * float(k) / 4.0 + PI * 0.25
		var post: Vector3 = centre + Vector3(cos(a3), 0.0, sin(a3)) * (reach * 0.9)
		_b.add("lamp_post", "cyl", Transform3D(Basis.from_scale(Vector3(0.16, 4.2, 0.16)), post + Vector3.UP * 2.1))
		_b.add("lamp_globe", "sph", Transform3D(Basis.from_scale(Vector3.ONE * 0.5), post + Vector3.UP * 4.45))


## Pilón Quenlobo: estanque redondo, taza de tres cuerpos que se van angostando y el
## chorro arriba. Nada de esto es un cubo, que era justo el problema.
func _build_fountain(centre: Vector3) -> void:
	_b.add("fountain", "cyl", Transform3D(Basis.from_scale(Vector3(11.0, 0.55, 11.0)), centre + Vector3.UP * 0.28))
	# fondo claro del estanque: el agua es transparente y tiene que verse algo a través
	_b.add("fountain_floor", "cyl", Transform3D(Basis.from_scale(Vector3(10.1, 0.06, 10.1)), centre + Vector3.UP * 0.3))
	_b.add("fountain_water", "cyl", Transform3D(Basis.from_scale(Vector3(10.1, 0.36, 10.1)), centre + Vector3.UP * 0.42))
	_b.add("fountain", "cyl", Transform3D(Basis.from_scale(Vector3(3.6, 0.9, 3.6)), centre + Vector3.UP * 0.75))
	_b.add("fountain", "cyl", Transform3D(Basis.from_scale(Vector3(4.6, 0.22, 4.6)), centre + Vector3.UP * 1.2))
	_b.add("fountain_water", "cyl", Transform3D(Basis.from_scale(Vector3(4.2, 0.1, 4.2)), centre + Vector3.UP * 1.3))
	_b.add("fountain", "cyl", Transform3D(Basis.from_scale(Vector3(1.6, 1.5, 1.6)), centre + Vector3.UP * 2.05))
	_b.add("fountain", "cyl", Transform3D(Basis.from_scale(Vector3(2.5, 0.18, 2.5)), centre + Vector3.UP * 2.85))
	_b.add("fountain_water", "cyl", Transform3D(Basis.from_scale(Vector3(2.2, 0.08, 2.2)), centre + Vector3.UP * 2.94))
	_b.add("fountain", "cyl", Transform3D(Basis.from_scale(Vector3(0.6, 1.1, 0.6)), centre + Vector3.UP * 3.5))
	_b.add("fountain_water", "sph", Transform3D(Basis.from_scale(Vector3(0.7, 0.9, 0.7)), centre + Vector3.UP * 4.3))
	# Ocho CORTINAS de agua de la taza alta a la taza media, y ocho de la media al estanque:
	# láminas de 35 cm de ancho con el shader corriendo hacia abajo, espuma blanca donde
	# caen y un penacho de rocío arriba. Con hilos de 9 cm la fuente se leía como palitos
	# azules (D77): agua cayendo es ancha, blanca y salpica.
	# Chorros en ARCO (D78): un surtidor central que sube 1,3 m y se abre en seis arcos
	# hasta la taza alta, y de cada taza ocho arcos al nivel de abajo. Cada arco es una
	# cadena de tramos que se afinan, siguiendo una parábola: las láminas rectangulares de
	# antes «no parecían agua fluida», y el penacho suelto arriba no se entendía.
	_jet(centre + Vector3.UP * 4.32, Vector3.UP, 1.3, 0.16, 0.06)
	for k: int in 6:
		var ang0: float = TAU * float(k) / 6.0
		_arc(centre + Vector3.UP * 5.55, Vector3(cos(ang0), 0.0, sin(ang0)), 0.6, 1.25, 2.95, 0.07)
	for k1: int in 8:
		var ang1: float = TAU * float(k1) / 8.0 + PI / 8.0
		var out_dir: Vector3 = Vector3(cos(ang1), 0.0, sin(ang1))
		# taza alta -> taza media
		_arc(centre + out_dir * 1.2 + Vector3.UP * 2.9, out_dir, 0.45, 1.05, 1.36, 0.09)
		_b.add("foam", "cyl", Transform3D(Basis.from_scale(Vector3(0.6, 0.05, 0.6)), centre + out_dir * 2.25 + Vector3.UP * 1.36))
		# taza media -> estanque
		_arc(centre + out_dir * 2.25 + Vector3.UP * 1.25, out_dir, 0.5, 1.3, 0.62, 0.11)
		_b.add("foam", "cyl", Transform3D(Basis.from_scale(Vector3(1.0, 0.05, 1.0)), centre + out_dir * 3.55 + Vector3.UP * 0.62))


## Chorro vertical: cadena de tramos que sube `height` y se afina de `w0` a `w1`.
func _jet(from: Vector3, dir: Vector3, height: float, w0: float, w1: float) -> void:
	var steps: int = 4
	for i: int in steps:
		var t0: float = float(i) / float(steps)
		var t1: float = float(i + 1) / float(steps)
		var w: float = lerpf(w0, w1, (t0 + t1) * 0.5)
		_b.box("fountain_stream", MeshBatcher.between(from + dir * (height * t0), from + dir * (height * t1), w))
	_b.add("spray", "sph", Transform3D(Basis.from_scale(Vector3(0.28, 0.42, 0.28)), from + dir * (height + 0.1)))


## Arco de agua: sale de `from` con impulso hacia arriba `rise`, avanza `run` metros en `dir`
## y cae hasta la altura `land_y`, como parábola en seis tramos que se afinan hacia el final.
func _arc(from: Vector3, dir: Vector3, rise: float, run: float, land_y: float, width: float) -> void:
	var steps: int = 6
	var prev: Vector3 = from
	var drop: float = from.y - land_y
	for i: int in steps:
		var t: float = float(i + 1) / float(steps)
		# altura: sube con `rise` y baja parabólicamente hasta land_y
		var y: float = from.y + rise * 4.0 * t * (1.0 - t) - drop * t * t
		var p: Vector3 = from + dir * (run * t)
		p.y = y
		var w: float = width * (1.0 - t * 0.45)
		_b.box("fountain_stream", MeshBatcher.between(prev, p, w))
		prev = p


func _build_churches() -> void:
	for ch: Dictionary in data.churches:
		var centre: Vector3 = Vector3(float(ch.get("x", 0.0)), 0.0, float(ch.get("z", 0.0)))
		_b.box("tower", Transform3D(Basis.from_scale(Vector3(5.0, 15.0, 5.0)), centre + Vector3.UP * 7.5))
		_b.add("roof", "prism", Transform3D(Basis.from_scale(Vector3(5.4, 4.0, 5.4)), centre + Vector3.UP * 17.0))
		_b.box("cross_church", Transform3D(Basis.from_scale(Vector3(0.22, 2.4, 0.22)), centre + Vector3.UP * 20.2))
		_b.box("cross_church", Transform3D(Basis.from_scale(Vector3(1.2, 0.22, 0.22)), centre + Vector3.UP * 20.6))


func _build_water() -> void:
	for line: Variant in data.water:
		var pts: PackedVector3Array = _points(line)
		for i: int in maxi(0, pts.size() - 1):
			var a: Vector3 = pts[i]
			var b: Vector3 = pts[i + 1]
			if not (_near_route(a) or _near_route(b)):
				continue
			var seg: float = a.distance_to(b)
			if seg < 0.5:
				continue
			var rot: Basis = Basis.looking_at((b - a) / seg, Vector3.UP)
			var mid: Vector3 = (a + b) * 0.5
			_b.box("bank", Transform3D(rot * Basis.from_scale(Vector3(3.4, 0.5, seg)), mid - Vector3.UP * 0.3))
			_b.box("water", Transform3D(rot * Basis.from_scale(Vector3(2.2, 0.2, seg)), mid - Vector3.UP * 0.22))


func _build_vines() -> void:
	for row: Variant in data.vine_rows:
		var arr: Array = row
		if arr.size() < 3:
			continue
		var a: Vector3 = Vector3(float(arr[0]), 0.0, float(arr[1]))
		var b: Vector3 = Vector3(float(arr[2]), 0.0, float(arr[1]))
		var seg: float = a.distance_to(b)
		if seg < 1.0:
			continue
		# Una parra cada 1,6 m como mechón de hojas sobre el alambre, no una barra verde de
		# 60 m (D76): «solo líneas verdes rectangulares en 3D», dijo el dueño, y tenía razón.
		var dir: Vector3 = (b - a) / seg
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.seed = int(a.x * 31.0 + a.z * 17.0)
		# cada 3,2 m y algo más grandes: a 1,6 m eran 54.000 mechones en un solo lote y la
		# tarjeta pesaba más que todo el pasto del recorrido
		var t: float = 1.2
		while t < seg:
			var size: float = rng.randf_range(1.6, 2.2)
			var yaw: float = OsmMapData.yaw_facing(dir) + rng.randf_range(-0.3, 0.3)
			_b.add("vine", "card", Transform3D(Basis(Vector3.UP, yaw) * Basis.from_scale(Vector3(size, size * 0.7, size * 0.5)), a + dir * t + Vector3.UP * (size * 0.5)))
			t += 3.2
		for h: float in [0.7, 1.3]:
			_b.box("vine_wire", MeshBatcher.between(a + Vector3.UP * h, b + Vector3.UP * h, 0.02))
		var post: float = 0.0
		while post <= seg:
			_b.add("vine_post", "cyl", Transform3D(Basis.from_scale(Vector3(0.14, 1.9, 0.14)), a + dir * post + Vector3.UP * 0.95))
			post += 6.0


## The Ruta 5 Sur inside the cutting under the bridge (D69): only the stretch that the trench
## opens up is drawn, 5 m down, with a few trucks going by.
func _build_motorway() -> void:
	var k: int = 0
	var depth: float = float(data.trench.get("depth", 5.0))
	var hw: float = float(data.trench.get("half_width", 17.0))
	var hl: float = float(data.trench.get("half_length", 160.0))
	for line: Variant in data.motorway:
		var pts: PackedVector3Array = _points(line)
		for i: int in maxi(0, pts.size() - 1):
			var a: Vector3 = pts[i] + Vector3.DOWN * depth
			var b: Vector3 = pts[i + 1] + Vector3.DOWN * depth
			var la: Vector2 = data.trench_local(a)
			var lb: Vector2 = data.trench_local(b)
			if absf(la.x) > hw - 1.0 or absf(lb.x) > hw - 1.0 or absf(la.y) > hl - 1.0 or absf(lb.y) > hl - 1.0:
				continue
			var seg: float = a.distance_to(b)
			if seg < 0.5:
				continue
			var dir: Vector3 = (b - a) / seg
			var rot: Basis = Basis.looking_at(dir, Vector3.UP)
			var mid: Vector3 = (a + b) * 0.5
			_b.box("motorway", Transform3D(rot * Basis.from_scale(Vector3(11.0, 0.06, seg + 0.4)), mid + Vector3.UP * 0.06))
			_b.box("motorway_paint", Transform3D(rot * Basis.from_scale(Vector3(0.14, 0.02, seg + 0.2)), mid + Vector3.UP * 0.07 + Vector3.UP * 0.0 + rot.x * 5.0))
			_b.box("motorway_paint", Transform3D(rot * Basis.from_scale(Vector3(0.14, 0.02, seg + 0.2)), mid + Vector3.UP * 0.07 - rot.x * 5.0))
			k += 1
			if k % 9 == 4:
				var colour: String = "truck_a" if k % 18 == 4 else "truck_b"
				_b.box(colour, Transform3D(rot * Basis.from_scale(Vector3(2.5, 3.6, 14.0)), mid + Vector3.UP * 1.9 + rot.x * 2.6))


## Árbol de plaza: tronco con corteza y copa de mechones de hojas (D76), no esferas.
func _tree(p: Vector3, trunk_h: float, crown_r: float) -> void:
	_b.tree(p, trunk_h, crown_r, 8, 2, "trunk", "crown", 0.45)


## Acorta una calle lateral para que termine en el borde del cordón de la ruta y no encima
## de su calzada. Solo mira los dos extremos: es donde OSM la une al eje.
func _trim_to_route(pts: PackedVector3Array) -> PackedVector3Array:
	var out: PackedVector3Array = pts.duplicate()
	for end: int in [0, out.size() - 1]:
		var inner: int = 1 if end == 0 else out.size() - 2
		if inner < 0 or inner >= out.size() or inner == end:
			break
		var pr: Vector2 = data.project(out[end])
		var limit: float = data.curb_at(pr.x) + 0.6
		if absf(pr.y) >= limit:
			continue
		if absf(data.project(out[inner]).y) < limit:
			# el tramo entero corre dentro del corredor (una calle paralela pegada al eje): se deja
			continue
		# bisección sobre el tramo hasta caer justo fuera del corredor
		var lo: float = 0.0
		var hi: float = 1.0
		for _i: int in 12:
			var mid: float = (lo + hi) * 0.5
			if absf(data.project(out[inner].lerp(out[end], mid)).y) < limit:
				hi = mid
			else:
				lo = mid
		out[end] = out[inner].lerp(out[end], lo)
	return out


func _near_route(p: Vector3) -> bool:
	return absf(data.project(p).y) < RAIL_RANGE_M


func _points(line: Variant) -> PackedVector3Array:
	var out: PackedVector3Array = PackedVector3Array()
	if not (line is Array):
		return out
	var arr: Array = line
	for item: Variant in arr:
		if item is Array:
			var pair: Array = item
			if pair.size() >= 2:
				out.append(Vector3(float(pair[0]), 0.0, float(pair[1])))
	return out
