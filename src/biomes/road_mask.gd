class_name RoadMask
extends RefCounted

## "¿Este punto cae sobre algo pavimentado?" — una sola respuesta para todos los que
## siembran cosas encima del mundo (pasto, piedrecillas, árboles, muebles, postes).
## Antes cada constructor tenía su propio criterio, o ninguno, y salían árboles y
## matas en medio del asfalto. Ahora la guarda es compartida: se arregla una vez.
##
## Rasteriza el corredor de la ruta, las calles del pueblo, la plaza y la rotonda en
## una grilla de CELL_M metros; la consulta queda O(1) y se puede llamar cien mil
## veces al construir sin que se note.
##
## Dos niveles, porque no es lo mismo: CALZADA es por donde pasan las ruedas y ahí no
## va nada; PAVIMENTO incluye vereda y plaza, donde el pasto no crece pero un árbol sí
## va (los árboles de vereda van justo ahí, en su tacita). La grilla de 2 m no alcanza
## a resolver la mediana de 3 m: por eso el pasto de la mediana no consulta la máscara.

const CALZADA: int = 1
const PAVIMENTO: int = 2

const CELL_M: float = 2.0
## La vereda y un poco de franja de propiedad: tampoco se siembra ahí.
const SIDEWALK_EXTRA_M: float = 2.5
const PAD_M: float = 60.0

## Una sola máscara por archivo de datos: los cinco constructores de un bioma cargan
## el mismo mapa y rasterizarla cinco veces costaba medio segundo cada vez.
static var _shared: Dictionary = {}

var _cells: PackedByteArray = PackedByteArray()
var _cols: int = 0
var _rows: int = 0
var _origin: Vector2 = Vector2.ZERO


static func shared(data: OsmMapData, key: String) -> RoadMask:
	if not _shared.has(key):
		var mask: RoadMask = RoadMask.new()
		mask.build(data)
		_shared[key] = mask
	return _shared[key]


func build(data: OsmMapData) -> void:
	var lo: Vector2 = Vector2(INF, INF)
	var hi: Vector2 = Vector2(-INF, -INF)
	for p: Vector3 in data.axis:
		lo = lo.min(Vector2(p.x, p.z))
		hi = hi.max(Vector2(p.x, p.z))
	for item: Variant in data.streets:
		if not (item is Dictionary):
			continue
		for q: Variant in ((item as Dictionary).get("pts", []) as Array):
			var pair: Array = q
			if pair.size() >= 2:
				var v: Vector2 = Vector2(float(pair[0]), float(pair[1]))
				lo = lo.min(v)
				hi = hi.max(v)
	if lo.x == INF:
		return
	_origin = lo - Vector2.ONE * PAD_M
	var span: Vector2 = (hi - lo) + Vector2.ONE * (PAD_M * 2.0)
	_cols = int(ceil(span.x / CELL_M)) + 1
	_rows = int(ceil(span.y / CELL_M)) + 1
	_cells.resize(_cols * _rows)
	_cells.fill(0)
	_stamp_route(data)
	_stamp_streets(data)
	_stamp_plaza(data)
	_stamp_roundabout(data)


## Calzada, vereda, plaza o rotonda: ahí no se siembra pasto.
func is_paved(p: Vector3, margin_m: float = 0.0) -> bool:
	return _lookup(p, margin_m) > 0


## Solo la calzada: ahí no va NADA. La vereda no cuenta — el árbol de vereda va en ella.
func is_roadway(p: Vector3, margin_m: float = 0.0) -> bool:
	return _lookup(p, margin_m) == CALZADA


func _lookup(p: Vector3, margin_m: float) -> int:
	if _cols == 0:
		return 0
	var reach: int = int(ceil(margin_m / CELL_M))
	var cx: int = int(floor((p.x - _origin.x) / CELL_M))
	var cy: int = int(floor((p.z - _origin.y) / CELL_M))
	var best: int = 0
	for dy: int in range(-reach, reach + 1):
		for dx: int in range(-reach, reach + 1):
			var v: int = _cell(cx + dx, cy + dy)
			if v == CALZADA:
				return CALZADA
			best = maxi(best, v)
	return best


func paved_cells() -> int:
	var n: int = 0
	for b: int in _cells:
		if b > 0:
			n += 1
	return n


# ---------- interno ----------

func _stamp_route(data: OsmMapData) -> void:
	var s: float = 0.0
	for i: int in data.segment_count():
		var a: Vector3 = data.axis[i]
		var b: Vector3 = data.axis[i + 1]
		var seg: Vector3 = Vector3(b.x - a.x, 0.0, b.z - a.z)
		var seg_len: float = seg.length()
		if seg_len < 0.01:
			continue
		var tangent: Vector3 = seg / seg_len
		var left: Vector3 = Vector3.UP.cross(tangent)
		var t: float = 0.0
		while t < seg_len:
			var here: float = s + t
			var kind: String = data.section_at(here)
			var inner: float = data.median_width * 0.5 if kind == "avenue" else 0.0
			var outer: float = data.curb_at(here) + SIDEWALK_EXTRA_M
			var pos: Vector3 = a + tangent * t
			var drive: float = data.curb_at(here)
			var lat: float = inner
			while lat <= outer:
				var level: int = CALZADA if lat <= drive else PAVIMENTO
				_mark(pos + left * lat, level)
				_mark(pos - left * lat, level)
				lat += 1.0
			t += 1.0
		s += seg_len


func _stamp_streets(data: OsmMapData) -> void:
	for item: Variant in data.streets:
		if not (item is Dictionary):
			continue
		var street: Dictionary = item
		var raw: Array = street.get("pts", []) as Array
		var half: float = float(street.get("w", 6.0)) * 0.5 + 1.0
		for i: int in maxi(0, raw.size() - 1):
			var pa: Array = raw[i]
			var pb: Array = raw[i + 1]
			if pa.size() < 2 or pb.size() < 2:
				continue
			var a: Vector3 = Vector3(float(pa[0]), 0.0, float(pa[1]))
			var b: Vector3 = Vector3(float(pb[0]), 0.0, float(pb[1]))
			var seg: Vector3 = b - a
			var seg_len: float = seg.length()
			if seg_len < 0.01:
				continue
			var tangent: Vector3 = seg / seg_len
			var left: Vector3 = Vector3.UP.cross(tangent)
			var t: float = 0.0
			while t < seg_len:
				var pos: Vector3 = a + tangent * t
				var lat: float = 0.0
				while lat <= half:
					_mark(pos + left * lat, CALZADA)
					_mark(pos - left * lat, CALZADA)
					lat += 1.0
				t += 1.0


func _stamp_plaza(data: OsmMapData) -> void:
	var poly: PackedVector2Array = PackedVector2Array()
	for q: Variant in (data.plaza.get("polygon", []) as Array):
		var pair: Array = q
		if pair.size() >= 2:
			poly.append(Vector2(float(pair[0]), float(pair[1])))
	if poly.size() < 3:
		return
	var lo: Vector2 = poly[0]
	var hi: Vector2 = poly[0]
	for v: Vector2 in poly:
		lo = lo.min(v)
		hi = hi.max(v)
	var y: float = lo.y
	while y <= hi.y:
		var x: float = lo.x
		while x <= hi.x:
			if Geometry2D.is_point_in_polygon(Vector2(x, y), poly):
				_mark(Vector3(x, 0.0, y), PAVIMENTO)
			x += 1.0
		y += 1.0


func _stamp_roundabout(data: OsmMapData) -> void:
	if data.roundabout.is_empty():
		return
	var centre: Vector2 = Vector2(float(data.roundabout.get("x", 0.0)), float(data.roundabout.get("z", 0.0)))
	var radius: float = float(data.roundabout.get("radius", 12.0)) + 2.0
	var y: float = -radius
	while y <= radius:
		var x: float = -radius
		while x <= radius:
			if Vector2(x, y).length() <= radius:
				_mark(Vector3(centre.x + x, 0.0, centre.y + y), CALZADA)
			x += 1.0
		y += 1.0


## La calzada manda sobre la vereda: donde se pisan las dos, queda calzada.
func _mark(p: Vector3, level: int) -> void:
	var cx: int = int(floor((p.x - _origin.x) / CELL_M))
	var cy: int = int(floor((p.z - _origin.y) / CELL_M))
	if cx < 0 or cy < 0 or cx >= _cols or cy >= _rows:
		return
	var at: int = cy * _cols + cx
	if _cells[at] == 0 or level == CALZADA:
		_cells[at] = level


func _cell(cx: int, cy: int) -> int:
	if cx < 0 or cy < 0 or cx >= _cols or cy >= _rows:
		return 0
	return _cells[cy * _cols + cx]
