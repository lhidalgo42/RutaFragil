class_name OsmRoad
extends Node3D

## Builds the real-avenue roadway from OsmMapData at runtime (D65, D67):
## ground, two carriageways with lane markings, median with grass, sidewalks,
## curbs with collision (open at side streets, the station and the pasaje),
## crosswalks and stop lines at the real junctions, flat and rounded speed
## humps (Decreto 200) with signs, the crossing avenue's deck over the
## underpass, parked cars (mesh only) and the side pasaje with its fuel lot.
## Street furniture lives in OsmFurniture. Collision only on: ground, curbs,
## humps, underpass, pasaje curbs.

const COLOURS: Dictionary = {
	"ground": Color(0.45, 0.5, 0.42), "asphalt": Color(0.24, 0.25, 0.27), "asphalt_plain": Color(0.24, 0.25, 0.27), "asphalt_side": Color(0.3, 0.31, 0.33),
	"median": Color(0.35, 0.55, 0.3), "curb": Color(0.72, 0.72, 0.7), "sidewalk": Color(0.8, 0.78, 0.72),
	"hump": Color(0.27, 0.28, 0.3), "paint": Color(0.95, 0.85, 0.2), "paint_white": Color(0.93, 0.93, 0.9),
	"paint_yellow": Color(0.95, 0.8, 0.15), "concrete": Color(0.55, 0.52, 0.48), "warn": Color(0.95, 0.8, 0.1),
	"post": Color(0.6, 0.6, 0.62), "diamond": Color(0.95, 0.75, 0.1), "disc": Color(0.95, 0.95, 0.95), "dirt": Color(0.5, 0.38, 0.25),
	"car_a": Color(0.85, 0.85, 0.88), "car_b": Color(0.25, 0.3, 0.55), "car_c": Color(0.6, 0.15, 0.15),
	"parapet": Color(0.68, 0.66, 0.62), "pier": Color(0.5, 0.48, 0.46), "island": Color(0.62, 0.6, 0.55), "crown": Color(0.28, 0.5, 0.26), "monument": Color(0.8, 0.78, 0.72),
	"canopy": Color(0.93, 0.93, 0.9), "canopy_band": Color(0.16, 0.5, 0.45), "pump": Color(0.9, 0.89, 0.86), "pump_island": Color(0.62, 0.6, 0.55),
	"pump_dark": Color(0.2, 0.22, 0.24), "hose": Color(0.12, 0.12, 0.13), "shop": Color(0.88, 0.86, 0.8),
	"glass": Color(0.55, 0.68, 0.72), "totem": Color(0.16, 0.5, 0.45), "forecourt": Color(0.66, 0.65, 0.63),
}
const HUMP_H: float = 0.15
const HUMP_RAMP: float = 1.8
const HUMP_CREST: float = 5.0
const SIGN_BEFORE_M: float = 35.0

@export var data_path: String = "res://data/b0_departamental.json"
@export var grass_per_m2: float = 5.0
## Pasto a los costados de todo el recorrido (D72). El suelo era una losa verde plana y
## las únicas matas estaban en la mediana: por eso el pasto se veía como un plano cuadrado.
## La franja va CORRIDA hacia afuera del pavimento, no centrada en el eje: centrada, casi
## todas las matas caían sobre la calzada y la máscara las botaba todas.
@export var verge_half_width_m: float = 11.0
## Matas de 0,9 m (D78): la mitad de las hojas-triángulo de antes cubren más suelo.
@export var verge_per_m2: float = 1.4
## Puntos del eje por tramo de pasto (~300 m): el trozo que la cámara descarta o dibuja.
const VERGE_CHUNK: int = 30
## Pasto por TODO el campo (D79), no solo la franja: matas grandes y ralas en tramos de
## 300 m sobre el rectángulo del pueblo, saltando pavimento. «Más tupido a lo largo de
## todo el mapa», dijo el dueño; es lo que quita la sensación de losa verde lisa.
@export var field_per_m2: float = 0.05
@export var field_margin_m: float = 250.0
const FIELD_CHUNK_M: float = 300.0
## Suelo con textura (D73): cuánto del segundo juego de texturas —la nieve— se ve
## mezclado con el pasto, y cuántos metros mide una baldosa. 0.0 deja el suelo solo de
## pasto; 1.0 lo deja nevado entero. Va en 0 por defecto y lo sube **la escena** que lo
## quiere: hoy solo Requínoa. El material del suelo es uno solo y compartido, así que en
## un árbol con dos biomas manda el último que se arma; hoy siempre hay uno.
@export_range(0.0, 1.0) var ground_snow: float = 0.0
@export var ground_tile_m: float = 3.0
@export var seed: int = 5

var data: OsmMapData
var _b: MeshBatcher = MeshBatcher.new()
var _r: RoadRibbon = RoadRibbon.new()
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _built_at: PackedVector3Array = PackedVector3Array()
var _built_dir: PackedVector3Array = PackedVector3Array()
var _built_index: PackedInt32Array = PackedInt32Array()
## Bocacalles derivadas de las calles del pueblo: (s0, s1, lado). Ver _collect_street_gaps.
var _street_gaps: Array[Vector3] = []
## La misma máscara que consultan pasto y árboles: aquí dice dónde una vereda o un cordón
## caería sobre OTRA calzada (la otra pasada del lazo, una calle del pueblo) y se omite.
var _mask: RoadMask


func _ready() -> void:
	data = OsmMapData.load_from(data_path)
	if data != null:
		build()


func build() -> void:
	for child: Node in get_children():
		remove_child(child)
		child.free()
	_rng.seed = seed
	# Un mapa nuevo empieza sin copas anotadas; Furniture y Town las vuelven a anotar (D76).
	MeshBatcher.reset_canopy()
	_mask = RoadMask.shared(data, data_path)
	MeshBatcher.set_ground_over_amount(ground_snow)
	MeshBatcher.set_ground_tile_m(ground_tile_m)
	_build_ground()
	_build_segments()
	_build_roundabout()
	OsmCrosswalks.build(_b, data)   # las cebras y las líneas de detención (D67)
	_build_humps()
	_build_underpass()
	_build_pasaje()
	_build_station_lot()
	_build_grass()
	_b.flush(self, COLOURS)
	_r.flush(self, COLOURS)


func curb_shape_count() -> int:
	return _shape_count("Curbs")


func hump_shape_count() -> int:
	return _shape_count("Humps")


## Orígenes de las instancias de un lote (las pruebas leen esto: bajo el renderizador
## headless los MultiMesh no devuelven sus transformaciones).
func positions_of(kind: String) -> PackedVector3Array:
	return _b.positions(kind)


func batch_count(kind: String) -> int:
	var node: Node = get_node_or_null("Batch_" + kind)
	if node is MultiMeshInstance3D:
		var inst: MultiMeshInstance3D = node
		return inst.multimesh.instance_count
	return 0


func _shape_count(body_name: String) -> int:
	var body: Node = get_node_or_null(body_name)
	return body.get_child_count() if body != null else 0


# ---------- pieces ----------

func _build_ground() -> void:
	var body: StaticBody3D = _body("Ground")
	if data.trench.is_empty():
		var lo: Vector3 = data.axis[0]
		var hi: Vector3 = data.axis[0]
		for p: Vector3 in data.axis:
			lo = lo.min(p)
			hi = hi.max(p)
		# El pantano tiene agua más allá del eje: si el suelo solo cubre la ruta, el agua
		# queda flotando sobre el vacío y se ve el corte (medido en B2, 2026-09-16).
		for item: Variant in (data.swamp.get("bodies", []) if not data.swamp.is_empty() else []):
			if not (item is Dictionary):
				continue
			for q: Variant in ((item as Dictionary).get("polygon", []) as Array):
				var pair: Array = q
				if pair.size() >= 2:
					var w: Vector3 = Vector3(float(pair[0]), 0.0, float(pair[1]))
					lo = lo.min(w)
					hi = hi.max(w)
		var size: Vector3 = Vector3(hi.x - lo.x + 1200.0, 1.0, hi.z - lo.z + 1200.0)
		var center: Vector3 = Vector3((lo.x + hi.x) * 0.5, -0.5, (lo.z + hi.z) * 0.5)
		_shape(body, size, Transform3D(Basis.IDENTITY, center))
		_b.box("ground", Transform3D(Basis.from_scale(size), center))
		return
	OsmTrench.build(body, _b, data)   # la trinchera de la Ruta 5 y el suelo a su alrededor (D69)


## A closed town loop drives some streets twice (out and back). Building the same
## stretch twice leaves two surfaces a few centimetres apart, and the placeholder bus
## trips on the lip, so each physical stretch is built only once (D69).
func _is_repeat(mid: Vector3, dir: Vector3, index: int) -> bool:
	for k: int in _built_at.size():
		if absi(_built_index[k] - index) <= 3 or _built_at[k].distance_to(mid) >= 6.0:
			continue
		# Solo se salta el tramo si va casi en la misma línea: en un cruce perpendicular
		# los dos tramos son calles distintas y hay que pavimentar los dos.
		if absf(_built_dir[k].dot(dir)) > 0.75:
			return true
	_built_at.append(mid)
	_built_dir.append(dir)
	_built_index.append(index)
	return false


func _build_segments() -> void:
	var curbs: StaticBody3D = _body("Curbs")
	_collect_street_gaps()
	_built_at.clear()
	_built_dir.clear()
	_built_index.clear()
	var run: PackedVector3Array = PackedVector3Array()
	var run_s: PackedFloat32Array = PackedFloat32Array()
	var run_kind: String = ""
	for i: int in data.segment_count():
		var a: Vector3 = data.axis[i]
		var b: Vector3 = data.axis[i + 1]
		var seg_len: float = a.distance_to(b)
		var mid: Vector3 = (a + b) * 0.5
		var ribbon: String = ""
		if not _is_repeat(mid, (b - a).normalized(), i):
			var s_mid: float = data.project(mid).x
			var frame: Transform3D = data.sample(s_mid)
			var kind: String = data.section_at(s_mid)
			if kind == "bridge":
				_bridge_segment(frame, mid, seg_len, s_mid)
			elif not (kind in ["gravel", "mud", "ford", "causeway"]):
				# OsmGravel hace el ripio; SwampRoad hace el barro, el vado y la pasarela
				if maxf(a.y, b.y) > 0.05:
					_deck_collision(frame, mid, seg_len, data.curb_at(s_mid) * 2.0)
				ribbon = kind
				if kind == "street":
					_street_details(frame, mid, seg_len, s_mid)
				else:
					_avenue_details(curbs, frame, mid, seg_len, s_mid)
		# La tirada se corta donde cambia el tipo o donde el tramo se salta por repetido:
		# cada tirada sale como UNA cinta sin juntas.
		if ribbon != run_kind:
			_close_run(run, run_s, run_kind)
			run = PackedVector3Array()
			run_s = PackedFloat32Array()
			run_kind = ribbon
		if ribbon != "":
			if run.is_empty():
				run.append(a)
				run_s.append(data.s_at(i))
			run.append(b)
			run_s.append(data.s_at(i + 1))
	_close_run(run, run_s, run_kind)


## Bocacalles que abren cordón y vereda: los `curb_gaps` reales de OSM más cada calle del
## pueblo que llega al corredor de la ruta (D76). Cada hueco es (s0, s1, lado).
func _collect_street_gaps() -> void:
	_street_gaps.clear()
	for item: Variant in data.streets:
		if not (item is Dictionary):
			continue
		var street: Dictionary = item
		# una calle podada (sin casas) no abre bocacalle en el cordón (D78)
		if not (data.street_is_inhabited(street) or data.is_exit_street(street)):
			continue
		var raw: Array = data.inhabited_span(street)
		if raw.size() < 2:
			continue
		var half: float = float(street.get("w", 6.0)) * 0.5 + 1.5
		for end: int in [0, raw.size() - 1]:
			var inner: int = 1 if end == 0 else raw.size() - 2
			var pe: Array = raw[end]
			var pi: Array = raw[inner]
			if pe.size() < 2 or pi.size() < 2:
				continue
			var p_end: Vector3 = Vector3(float(pe[0]), 0.0, float(pe[1]))
			var pr: Vector2 = data.project(p_end)
			if absf(pr.y) > data.curb_at(pr.x) + 4.0:
				continue   # este extremo no toca la ruta
			# el lado lo dice el punto interior: el extremo cae casi sobre el eje
			var pr_in: Vector2 = data.project(Vector3(float(pi[0]), 0.0, float(pi[1])))
			var side: float = 1.0 if pr_in.y >= 0.0 else -1.0
			_street_gaps.append(Vector3(pr.x - half, pr.x + half, side))


func _in_gap(side: int, s: float) -> bool:
	if data.in_gap(side, s):
		return true
	for g: Vector3 in _street_gaps:
		if int(g.z) == side and s >= g.x and s <= g.y:
			return true
	return false


## Una tirada continua del mismo tipo de calzada, emitida como cinta (D72). Antes cada
## tramo era una caja rotada y en las curvas dos cajas vecinas dejaban una cuña abierta
## por fuera y se pisaban por dentro. Aquí los dos tramos comparten la fila de vértices.
func _close_run(points: PackedVector3Array, s_list: PackedFloat32Array, kind: String) -> void:
	if kind == "" or points.size() < 2:
		return
	var lefts: PackedVector3Array = RoadRibbon.lefts(points)
	if kind == "avenue":
		var half_median: float = data.median_width * 0.5
		var curb: float = data.curb_lateral
		var walk: float = data.sidewalk_lateral
		_r.band("median", points, lefts, -half_median, half_median, 0.15)
		for side: float in [-1.0, 1.0]:
			_r.wall("median", points, lefts, side * half_median, 0.02, 0.15, side)
			# asfalto liso: la avenida pinta sus propias marcas (dos calzadas de un sentido)
			_side_band("asphalt_plain", points, lefts, side, half_median, curb - 1.0, 0.02)
			_gapped_band("sidewalk", points, lefts, s_list, side, curb + 1.0, walk + 1.0, false)
			_gapped_band("curb", points, lefts, s_list, side, curb - 1.0, curb + 1.0, true)
	else:
		var street_curb: float = data.curb_at(s_list[0])
		_r.band("asphalt", points, lefts, -(street_curb - 1.0), street_curb - 1.0, 0.02)
		for side: float in [-1.0, 1.0]:
			_gapped_band("sidewalk", points, lefts, s_list, side, street_curb + 0.5, street_curb + 2.3, false)
			_gapped_band("curb", points, lefts, s_list, side, street_curb - 0.5, street_curb + 0.5, true)


## Banda de un costado. `lat_in` es el borde que mira al eje; la cinta siempre se emite
## con el costado derecho primero para que la cara quede mirando arriba.
func _side_band(kind: String, points: PackedVector3Array, lefts: PackedVector3Array, side: float, lat_in: float, lat_out: float, y: float) -> void:
	if side > 0.0:
		_r.band(kind, points, lefts, lat_in, lat_out, y)
	else:
		_r.band(kind, points, lefts, -lat_out, -lat_in, y)


## El cordón Y la vereda se cortan en cada bocacalle: en los `curb_gaps` reales de OSM y
## donde una calle del pueblo llega a la ruta (D76). Antes solo se abría el cordón y la
## vereda cruzaba entera por delante de cada calle lateral, como un puente de 15 cm.
func _gapped_band(kind: String, points: PackedVector3Array, lefts: PackedVector3Array, s_list: PackedFloat32Array, side: float, lat_in: float, lat_out: float, with_wall: bool) -> void:
	var sub: PackedVector3Array = PackedVector3Array()
	var sub_lefts: PackedVector3Array = PackedVector3Array()
	for i: int in points.size():
		# Bocacalle registrada, o el borde exterior de la banda cae sobre OTRA calzada (la otra
		# pasada del lazo en una T, una calle del pueblo): en la foto la vereda de una pasada
		# cruzaba por delante de la otra como un puente (D79).
		var outer: Vector3 = points[i] + lefts[i] * (side * lat_out)
		if _in_gap(int(side), s_list[i]) or (_mask != null and _mask.is_roadway(outer, 0.0)):
			_emit_band(kind, sub, sub_lefts, side, lat_in, lat_out, with_wall)
			sub = PackedVector3Array()
			sub_lefts = PackedVector3Array()
			continue
		sub.append(points[i])
		sub_lefts.append(lefts[i])
	_emit_band(kind, sub, sub_lefts, side, lat_in, lat_out, with_wall)


func _emit_band(kind: String, points: PackedVector3Array, lefts: PackedVector3Array, side: float, lat_in: float, lat_out: float, with_wall: bool) -> void:
	if points.size() < 2:
		return
	_side_band(kind, points, lefts, side, lat_in, lat_out, 0.15)
	if with_wall:
		_r.wall(kind, points, lefts, side * lat_in, 0.02, 0.15, -side)


## Avenue (D63): lo que NO es superficie continua — pintura, colisión del cordón y autos
## estacionados. El asfalto, la mediana, el cordón y la vereda salen de la cinta.
func _avenue_details(curbs: StaticBody3D, frame: Transform3D, mid: Vector3, seg_len: float, s_mid: float) -> void:
	var lane: float = data.lane_offset
	var left: Vector3 = data.left_of(frame)
	var fwd: Vector3 = -frame.basis.z
	var rot: Basis = frame.basis
	for side: float in [-1.0, 1.0]:
		_b.box("paint_white", MeshBatcher.along(rot, mid + left * (side * (data.curb_lateral - 1.3)), Vector3(0.12, 0.02, seg_len + 0.2), 0.025))
		_b.box("paint_yellow", MeshBatcher.along(rot, mid + left * (side * (data.median_width * 0.5 + 0.3)), Vector3(0.12, 0.02, seg_len + 0.2), 0.025))
		for k: float in [-0.25, 0.25]:
			_b.box("paint_white", MeshBatcher.along(rot, mid + left * (side * lane) + fwd * (seg_len * k), Vector3(0.12, 0.02, 3.0), 0.025))
		if not data.in_gap(int(side), s_mid):
			var curb_pos: Vector3 = mid + left * (side * data.curb_lateral) + Vector3.UP * 0.075
			_shape(curbs, Vector3(2.0, 0.15, seg_len + 0.2), Transform3D(rot, curb_pos))
			if int(s_mid / 20.0) % 2 == 0 and _far_from_features(s_mid, 22.0):
				var colour: String = ["car_a", "car_b", "car_c"][_rng.randi() % 3]
				_b.box(colour, MeshBatcher.along(rot, mid + left * (side * (data.curb_lateral - 2.1)), Vector3(1.7, 1.5, 4.4), 0.75))


## Población street (D68): la calzada, el cordón y la vereda son cinta, y desde D74 la
## textura de la calzada (Road008B) trae la línea central y las de borde pintadas, así que
## aquí ya no se pinta nada. Queda el gancho por si una calle necesita algo propio.
func _street_details(_frame: Transform3D, _mid: Vector3, _seg_len: float, _s_mid: float) -> void:
	pass


## Bridge deck (D69): flat asphalt spanning the trench with its own collision, plus parapets,
## the deck beam underneath and piers down to the trench floor. The bus road stays level: a
## raised deck needed ramps that overlapped between the two passes and tripped the bus.
func _bridge_segment(frame: Transform3D, mid: Vector3, seg_len: float, s_mid: float) -> void:
	var curb: float = data.curb_at(s_mid)
	var rot: Basis = frame.basis
	var left: Vector3 = data.left_of(frame)
	_b.box("asphalt", MeshBatcher.along(rot, mid, Vector3(curb * 2.0 - 1.2, 0.04, seg_len + 0.4), 0.02))
	for k: float in [-0.25, 0.25]:
		_b.box("paint_yellow", MeshBatcher.along(rot, mid + -frame.basis.z * (seg_len * k), Vector3(0.12, 0.02, 3.0), 0.05))
	var depth: float = float(data.trench.get("depth", 5.0))
	var span: bool = data.over_trench(mid)
	if span:
		_b.box("pier", MeshBatcher.along(rot, mid, Vector3(curb * 2.0 + 1.0, 0.7, seg_len + 0.4), -0.36))
	for side: float in [-1.0, 1.0]:
		_b.box("parapet", MeshBatcher.along(rot, mid + left * (side * curb), Vector3(0.45, 0.95, seg_len + 0.2), 0.48))
		if span and absf(data.trench_local(mid).y) > float(data.trench.get("half_length", 160.0)) - 26.0:
			_b.box("pier", Transform3D(Basis.from_scale(Vector3(1.1, depth, 1.1)), mid + left * (side * (curb - 0.6)) + Vector3.DOWN * (depth * 0.5)))


## Collision box under a raised deck or ramp, pitched with the frame so the wheels climb smoothly.
func _deck_collision(frame: Transform3D, mid: Vector3, seg_len: float, width: float) -> void:
	var body: StaticBody3D = get_node_or_null("Deck") as StaticBody3D
	if body == null:
		body = _body("Deck")
	_shape(body, Vector3(width, 1.0, seg_len + 0.6), Transform3D(frame.basis, mid - frame.basis.y * 0.5))


## Roundabout (D69, design addition): raised island, painted ring and a small monument; mesh only
## so the placeholder bus can clip the island instead of jamming on a 15 cm kerb.
func _build_roundabout() -> void:
	var r: Dictionary = data.roundabout
	if r.is_empty():
		return
	var centre: Vector3 = Vector3(float(r.get("x", 0.0)), 0.0, float(r.get("z", 0.0)))
	var island: float = float(r.get("island_radius", 6.5))
	_b.add("island", "cyl", Transform3D(Basis.from_scale(Vector3(island * 2.0, 0.3, island * 2.0)), centre + Vector3.UP * 0.15))
	_b.add("paint_white", "cyl", Transform3D(Basis.from_scale(Vector3(island * 2.4, 0.02, island * 2.4)), centre + Vector3.UP * 0.035))
	_b.add("monument", "cyl", Transform3D(Basis.from_scale(Vector3(1.1, 2.6, 1.1)), centre + Vector3.UP * 1.6))
	_b.add("monument", "sph", Transform3D(Basis.from_scale(Vector3.ONE * 1.1), centre + Vector3.UP * 3.2))
	for k: int in 6:
		var ang: float = TAU * float(k) / 6.0
		_b.add("crown", "sph", Transform3D(Basis.from_scale(Vector3.ONE * 1.5), centre + Vector3(cos(ang), 0.0, sin(ang)) * (island - 1.4) + Vector3.UP * 0.9))


## Zebra crossing and stop line at every real side-street junction (gaps that are not the station or the pasaje).
func _far_from_features(s: float, margin: float) -> bool:
	for h: Dictionary in data.humps:
		if absf(float(h.get("s", 0.0)) - s) < margin:
			return false
	if absf(float(data.underpass.get("s", -1000.0)) - s) < margin + 15.0:
		return false
	return true


func _build_humps() -> void:
	var body: StaticBody3D = _body("Humps")
	for h: Dictionary in data.humps:
		var s: float = float(h.get("s", 0.0))
		var side: int = int(h.get("side", -1))
		var frame: Transform3D = data.sample(s)
		var avenue: bool = data.section_at(s) == "avenue"
		var width: float = data.carriageway_width if avenue else data.curb_at(s) * 2.0 - 2.0
		var center: Vector3 = frame.origin
		if avenue:
			center += data.left_of(frame) * (float(side) * data.lane_offset)
		if str(h.get("kind", "flat")) == "round":
			_ramps(body, frame, center, 0.075, 1.85, 0.0, width)
			_b.box("paint", MeshBatcher.along(frame.basis, center, Vector3(width, 0.02, 0.15), 0.085))
		else:
			_flat_hump(body, frame, center, width)
		var sign_s: float = s - SIGN_BEFORE_M if side < 0 else s + SIGN_BEFORE_M
		_sign(sign_s, float(side) * (data.curb_lateral + 1.4), "diamond", "disc")


## Resalto plano (Decreto 200): 15 cm at curb level, 5 m plateau, 1.8 m ramps.
func _flat_hump(body: StaticBody3D, frame: Transform3D, center: Vector3, cw: float) -> void:
	var fwd: Vector3 = -frame.basis.z
	var crest_t: Transform3D = Transform3D(frame.basis, center + Vector3.UP * (HUMP_H - 0.5))
	_shape(body, Vector3(cw, 1.0, HUMP_CREST), crest_t)
	_b.box("hump", Transform3D(frame.basis * Basis.from_scale(Vector3(cw, 1.0, HUMP_CREST)), crest_t.origin))
	_ramps(body, frame, center, HUMP_H, HUMP_RAMP, HUMP_CREST * 0.5, cw)
	for dir: float in [1.0, -1.0]:
		_b.box("paint", MeshBatcher.along(frame.basis, center - fwd * ((HUMP_CREST * 0.5 - 0.1) * dir), Vector3(cw, 0.02, 0.15), HUMP_H + 0.01))


## Two ramps of horizontal run `run` rising `height`, starting `plateau_half` from the centre;
## the ramp behind (local +Z) pitches +ang, the one ahead pitches -ang (same as city_bumps.tscn).
func _ramps(body: StaticBody3D, frame: Transform3D, center: Vector3, height: float, run: float, plateau_half: float, cw: float) -> void:
	var fwd: Vector3 = -frame.basis.z
	var ang: float = atan2(height, run)
	var ramp_len: float = sqrt(run * run + height * height)
	var ramp_y: float = height * 0.5 - 0.5 * cos(ang)
	var ramp_dz: float = plateau_half + run * 0.5
	for dir: float in [1.0, -1.0]:
		var basis: Basis = frame.basis * Basis(Vector3.RIGHT, ang * dir)
		var pos: Vector3 = center - fwd * (ramp_dz * dir) + Vector3.UP * ramp_y
		_shape(body, Vector3(cw, 1.0, ramp_len), Transform3D(basis, pos))
		_b.box("hump", Transform3D(basis * Basis.from_scale(Vector3(cw, 1.0, ramp_len)), pos))


func _build_underpass() -> void:
	var u: Dictionary = data.underpass
	if u.is_empty():
		return
	var s: float = float(u.get("s", 0.0))
	var clearance: float = float(u.get("maxheight", 3.9))
	var along: float = float(u.get("deck_length_along", 30.0))
	var across: float = float(u.get("deck_width_across", 44.0))
	var frame: Transform3D = data.sample(s)
	var body: StaticBody3D = _body("Underpass")
	var deck_t: Transform3D = Transform3D(frame.basis, frame.origin + Vector3.UP * (clearance + 0.5))
	_shape(body, Vector3(across, 1.0, along), deck_t)
	_b.box("concrete", Transform3D(frame.basis * Basis.from_scale(Vector3(across, 1.0, along)), deck_t.origin))
	var fwd: Vector3 = -frame.basis.z
	for side: float in [-1.0, 1.0]:
		var wall_pos: Vector3 = frame.origin + data.left_of(frame) * (side * (data.curb_lateral + 1.0)) + Vector3.UP * (clearance * 0.5)
		_shape(body, Vector3(1.0, clearance, along), Transform3D(frame.basis, wall_pos))
		_b.box("concrete", Transform3D(frame.basis * Basis.from_scale(Vector3(1.0, clearance, along)), wall_pos))
		_b.box("warn", MeshBatcher.along(frame.basis, frame.origin + fwd * (side * (along * 0.5 + 0.04)), Vector3(across, 0.35, 0.06), clearance - 0.12))
		# the crossing avenue on top of the deck: its own asphalt and parapets
		_b.box("concrete", MeshBatcher.along(frame.basis, frame.origin + fwd * (side * (along * 0.5 - 0.5)), Vector3(across, 1.1, 1.0), clearance + 1.55))
	_b.box("asphalt", MeshBatcher.along(frame.basis, frame.origin, Vector3(across - 2.0, 0.04, along - 2.0), clearance + 1.02))
	_sign(s - SIGN_BEFORE_M, -(data.curb_lateral + 1.4), "diamond", "disc")
	_sign(s + SIGN_BEFORE_M, data.curb_lateral + 1.4, "diamond", "disc")


func _build_pasaje() -> void:
	var pz: Dictionary = data.pasaje
	if pz.is_empty():
		return
	var mouth: Vector3 = Vector3(float(pz.get("x", 0.0)), 0.0, float(pz.get("z", 0.0)))
	var dir_arr: Array = pz.get("dir", [0.0, 1.0])
	var dir: Vector3 = Vector3(float(dir_arr[0]), 0.0, float(dir_arr[1])).normalized()
	var left: Vector3 = Vector3.UP.cross(dir)
	var rot: Basis = Basis(Vector3.UP, OsmMapData.yaw_facing(dir))
	var length: float = float(pz.get("length", 54.0))
	var width: float = float(pz.get("width", 14.0))
	var start: float = 16.0
	var road_len: float = length - start
	var curbs: StaticBody3D = get_node("Curbs") as StaticBody3D
	_b.box("asphalt_side", MeshBatcher.along(rot, mouth + dir * (length * 0.5), Vector3(width, 0.02, length), 0.01))
	for side: float in [-1.0, 1.0]:
		var pos: Vector3 = mouth + dir * (start + road_len * 0.5) + left * (side * (width * 0.5 + 1.0))
		_b.box("curb", MeshBatcher.along(rot, pos, Vector3(2.0, 0.15, road_len), 0.075))
		_shape(curbs, Vector3(2.0, 0.15, road_len), Transform3D(rot, pos + Vector3.UP * 0.075))
	var lot_along: float = float(pz.get("lot_along", 60.0))
	var lot_depth: float = float(pz.get("lot_depth", 44.0))
	var lot_half: float = float(pz.get("lot_half_width", 26.0))
	var lot_centre: Vector3 = mouth + dir * (lot_along + lot_depth * 0.5)
	_b.box("forecourt", MeshBatcher.along(rot, lot_centre, Vector3(lot_half * 2.0, 0.02, lot_depth), 0.015))
	_build_fuel_station(lot_centre, rot, dir, left)


## La bencinera del pueblo, en un lote retirado de la calle (D76). Antes estaba la escena
## `CityStation` de la ronda 1 (techo rojo, cajas) puesta a 30 m del eje, y su explanada
## pisaba la calzada: «la bencinera sigue apareciendo al medio de la calle». Ahora se arma
## con el mismo código que la del pasaje, en el lado que dice OSM y a 26 m del cordón.
func _build_station_lot() -> void:
	if not data.pasaje.is_empty() or data.station.is_empty() or not data.station.has("s"):
		return
	var s: float = float(data.station.get("s", 0.0))
	var side: float = float(data.station.get("side", 1.0))
	if absf(side) < 0.01:
		side = 1.0
	var frame: Transform3D = data.sample(s)
	# El lazo del pueblo pasa DOS veces cerca de la Copec: a 26 m de una pasada el lote caía
	# justo sobre la otra (lo cazó la prueba). Se prueban los dos lados y varias distancias
	# y se toma el primer lote cuya explanada entera queda fuera de cualquier pasada.
	var best_centre: Vector3 = Vector3.ZERO
	var best_away: Vector3 = Vector3.ZERO
	var best_clear: float = -INF
	for try_side: float in [signf(side), -signf(side)]:
		var away: Vector3 = data.left_of(frame) * try_side
		for dist: float in [26.0, 34.0, 44.0, 56.0]:
			var centre: Vector3 = frame.origin + away * (data.curb_at(s) + dist)
			var clear: float = _lot_clearance(centre, away)
			if clear > best_clear:
				best_clear = clear
				best_centre = centre
				best_away = away
			if clear > 3.0:
				break
		if best_clear > 3.0:
			break
	var rot: Basis = Basis(Vector3.UP, OsmMapData.yaw_facing(best_away))
	_b.box("forecourt", MeshBatcher.along(rot, best_centre, Vector3(52.0, 0.02, 44.0), 0.015))
	_build_fuel_station(best_centre, rot, best_away, Vector3.UP.cross(best_away))


## Metros que sobran entre la explanada de la bencinera (52 × 44 m, centrada en `centre`,
## con el fondo hacia `away`) y el cordón de la pasada de la ruta más cercana a cada esquina.
## Negativo = la explanada pisa la calzada.
func _lot_clearance(centre: Vector3, away: Vector3) -> float:
	var along: Vector3 = Vector3.UP.cross(away)
	var worst: float = INF
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var corner: Vector3 = centre + along * (sx * 26.0) + away * (sz * 22.0)
			var pr: Vector2 = data.project(corner)
			worst = minf(worst, absf(pr.y) - data.curb_at(pr.x))
	return worst


## Bencinera "Quenlobo" (D72). Antes eran puras cajas superpuestas sobre tierra. Ahora:
## marquesina con el canto grueso a la vista y cuatro pilares redondos, dos islas con sus
## surtidores y la manguera colgando, la tienda con su vitrina y el tótem de precios en la
## entrada. La marca es inventada; ninguna forma copia una estación real.
func _build_fuel_station(centre: Vector3, rot: Basis, dir: Vector3, left: Vector3) -> void:
	var canopy_h: float = 5.4
	_b.box("canopy", MeshBatcher.along(rot, centre, Vector3(20.0, 0.45, 13.0), canopy_h))
	# el canto: una marquesina de 45 cm vista de perfil es una lámina
	for side: float in [-1.0, 1.0]:
		_b.box("canopy_band", MeshBatcher.along(rot, centre + left * (side * 10.0), Vector3(0.55, 1.0, 13.2), canopy_h - 0.2))
		_b.box("canopy_band", MeshBatcher.along(rot, centre + dir * (side * 6.5), Vector3(20.2, 1.0, 0.55), canopy_h - 0.2))
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var pillar: Vector3 = centre + left * (sx * 7.6) + dir * (sz * 4.6)
			_b.add("canopy_band", "cyl", Transform3D(Basis.from_scale(Vector3(0.62, canopy_h - 0.4, 0.62)), pillar + Vector3.UP * (canopy_h - 0.4) * 0.5))
	for sx2: float in [-1.0, 1.0]:
		var island: Vector3 = centre + left * (sx2 * 4.6)
		_b.box("pump_island", MeshBatcher.along(rot, island, Vector3(2.4, 0.22, 9.0), 0.11))
		for sz2: float in [-1.0, 1.0]:
			var pump: Vector3 = island + dir * (sz2 * 2.4)
			_b.box("pump", MeshBatcher.along(rot, pump, Vector3(1.1, 1.5, 0.75), 0.97))
			_b.box("pump_dark", MeshBatcher.along(rot, pump, Vector3(0.95, 0.5, 0.8), 1.62))
			_b.add("pump_dark", "cyl", Transform3D(Basis.from_scale(Vector3(1.15, 0.28, 0.82)), pump + Vector3.UP * 1.88))
			var nozzle: Vector3 = pump + left * (sx2 * 0.75) + Vector3.UP * 0.75
			_b.box("hose", MeshBatcher.between(pump + left * (sx2 * 0.5) + Vector3.UP * 1.55, nozzle, 0.09))
	var shop: Vector3 = centre + dir * 11.5
	_b.box("shop", MeshBatcher.along(rot, shop, Vector3(12.0, 3.6, 7.0), 1.8))
	_b.box("glass", MeshBatcher.along(rot, shop - dir * 3.55, Vector3(9.4, 2.0, 0.12), 1.7))
	_b.box("canopy_band", MeshBatcher.along(rot, shop, Vector3(12.6, 0.5, 7.6), 3.75))
	var totem: Vector3 = centre - dir * 11.0 + left * 8.5
	_b.add("pump_dark", "cyl", Transform3D(Basis.from_scale(Vector3(0.3, 4.4, 0.3)), totem + Vector3.UP * 2.2))
	_b.box("totem", MeshBatcher.along(rot, totem, Vector3(2.6, 2.2, 0.35), 5.3))


func _build_grass() -> void:
	_build_median_grass()
	_build_verge_grass()
	_build_field_grass()


## Pasto de campo (D79): el rectángulo del pueblo más `field_margin_m`, en tramos de
## FIELD_CHUNK_M para que la cámara descarte los que no mira, con matas grandes y ralas.
func _build_field_grass() -> void:
	if field_per_m2 <= 0.0 or data.axis.size() < 2:
		return
	var mask: RoadMask = RoadMask.shared(data, data_path)
	var lo: Vector3 = data.axis[0]
	var hi: Vector3 = data.axis[0]
	for p: Vector3 in data.axis:
		lo = lo.min(p)
		hi = hi.max(p)
	# El campo se desvanece hacia afuera (D79): la densidad baja con la distancia al borde
	# del pueblo hasta llegar a cero en `field_margin_m`. Con densidad uniforme el pasto
	# terminaba en una raya recta a 250 m, una costura tan visible como la losa de antes.
	var fade_from: Vector3 = lo
	var fade_to: Vector3 = hi
	lo -= Vector3(field_margin_m, 0.0, field_margin_m)
	hi += Vector3(field_margin_m, 0.0, field_margin_m)
	var fade_skip: Callable = func(p: Vector3) -> bool:
		if mask.is_paved(p, 0.5):
			return true
		var dx: float = maxf(fade_from.x - p.x, p.x - fade_to.x)
		var dz: float = maxf(fade_from.z - p.z, p.z - fade_to.z)
		var outside: float = maxf(0.0, maxf(dx, dz)) / field_margin_m
		# afuera del pueblo se conserva (1 - outside)^2 de las matas; el hash es determinista
		return MeshBatcher._hash01(p, 3.0) > (1.0 - outside) * (1.0 - outside)
	var root_node: Node3D = Node3D.new()
	root_node.name = "Field"
	add_child(root_node)
	var x: float = lo.x
	var k: int = 0
	while x < hi.x:
		var z: float = lo.z
		while z < hi.z:
			var strip: GrassStrip = GrassStrip.new()
			strip.name = "Field%03d" % k
			strip.base_colour = Color(0.24, 0.36, 0.16)
			strip.tip_colour = Color(0.58, 0.68, 0.3)
			strip.tuft_scale = 1.5
			root_node.add_child(strip)
			# una línea por el centro del tramo con medio ancho = medio tramo cubre el cuadrado
			var line: PackedVector3Array = PackedVector3Array([Vector3(x + FIELD_CHUNK_M * 0.5, 0.0, z), Vector3(x + FIELD_CHUNK_M * 0.5, 0.0, z + FIELD_CHUNK_M)])
			strip.build_along(line, FIELD_CHUNK_M * 0.5, field_per_m2, seed + 1000 + k, fade_skip)
			k += 1
			z += FIELD_CHUNK_M
		x += FIELD_CHUNK_M


## Matas de pasto de campo, sumando todos los tramos.
func field_tuft_count() -> int:
	var total: int = 0
	var root_node: Node = get_node_or_null("Field")
	if root_node == null:
		return 0
	for child: Node in root_node.get_children():
		if child is GrassStrip:
			var strip: GrassStrip = child
			if strip.multimesh != null:
				total += strip.multimesh.instance_count
	return total


func _build_median_grass() -> void:
	var pts: PackedVector3Array = PackedVector3Array()
	for i: int in data.axis.size():
		var s: float = data.project(data.axis[i]).x
		if data.section_at(s) == "avenue":
			pts.append(data.axis[i])
		elif pts.size() > 1:
			break
	if pts.size() < 2:
		return
	var strip: GrassStrip = GrassStrip.new()
	strip.name = "MedianGrass"
	add_child(strip)
	strip.build_along(pts, data.median_width * 0.5 - 0.35, grass_per_m2, seed)


## Pasto a los costados de todo el recorrido (D72), en tramos de VERGE_CHUNK puntos.
## En UN solo MultiMesh de 5 km la caja envolvente cubre el mapa entero y la tarjeta
## dibuja las 190.000 matas en cada cuadro aunque se vean veinte. Partido en tramos,
## la cámara descarta los que no mira.
func _build_verge_grass() -> void:
	if verge_per_m2 <= 0.0 or verge_half_width_m <= 0.0 or data.axis.size() < 2:
		return
	var mask: RoadMask = RoadMask.shared(data, data_path)
	var skip: Callable = func(p: Vector3) -> bool:
		return mask.is_paved(p, 0.5)
	var root_node: Node3D = Node3D.new()
	root_node.name = "Verge"
	add_child(root_node)
	for side: int in [-1, 1]:
		var line: PackedVector3Array = PackedVector3Array()
		for i: int in data.axis.size():
			var s_at: float = data.s_at(i)
			line.append(data.lateral_point(s_at, float(side) * (data.curb_at(s_at) + 3.5 + verge_half_width_m)))
		var chunk: int = 0
		var from: int = 0
		while from < line.size() - 1:
			var to: int = mini(from + VERGE_CHUNK, line.size() - 1)
			var piece: PackedVector3Array = line.slice(from, to + 1)
			var strip: GrassStrip = GrassStrip.new()
			strip.name = "Verge%s%02d" % ["L" if side > 0 else "R", chunk]
			strip.base_colour = Color(0.26, 0.38, 0.17)
			strip.tip_colour = Color(0.62, 0.7, 0.32)
			root_node.add_child(strip)
			strip.build_along(piece, verge_half_width_m, verge_per_m2, seed + 1 + side * 100 + chunk, skip)
			from = to
			chunk += 1


## Matas de pasto sembradas a los costados, sumando todos los tramos.
func verge_tuft_count() -> int:
	var total: int = 0
	var root_node: Node = get_node_or_null("Verge")
	if root_node == null:
		return 0
	for child: Node in root_node.get_children():
		if child is GrassStrip:
			var strip: GrassStrip = child
			if strip.multimesh != null:
				total += strip.multimesh.instance_count
	return total


# ---------- helpers ----------

func _sign(s: float, lateral: float, top_kind: String, bottom_kind: String) -> void:
	var p: Vector3 = data.lateral_point(s, lateral)
	_b.box("post", Transform3D(Basis.from_scale(Vector3(0.1, 2.4, 0.1)), p + Vector3.UP * 1.2))
	_b.box(top_kind, Transform3D(Basis.from_scale(Vector3(0.6, 0.6, 0.05)), p + Vector3.UP * 2.6))
	_b.box(bottom_kind, Transform3D(Basis.from_scale(Vector3(0.6, 0.6, 0.05)), p + Vector3.UP * 1.95))


func _body(body_name: String) -> StaticBody3D:
	var body: StaticBody3D = StaticBody3D.new()
	body.name = body_name
	add_child(body)
	return body


func _shape(body: StaticBody3D, size: Vector3, xform: Transform3D) -> void:
	var node: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = size
	node.shape = box
	body.add_child(node)
	node.global_transform = xform
