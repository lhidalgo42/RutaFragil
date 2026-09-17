class_name OsmMapData
extends RefCounted

## Map data for a real-avenue biome segment (D65), precomputed by
## tools/osm_to_b0.py from OpenStreetMap (ODbL) into Godot metres: x east,
## z = -north, y up. Builders read it; nothing here touches the scene tree.

var source: String = ""
var length: float = 0.0
var lane_offset: float = 6.75
var carriageway_width: float = 10.5
var median_width: float = 3.0
var curb_lateral: float = 12.0
var sidewalk_lateral: float = 14.0
var axis: PackedVector3Array = PackedVector3Array()
var waypoints: PackedVector3Array = PackedVector3Array()
var entry: Transform3D = Transform3D.IDENTITY
var curb_gaps: Array[Dictionary] = []
var humps: Array[Dictionary] = []
var station: Dictionary = {}
var fuel_lot: Dictionary = {}
var pasaje: Dictionary = {}
var underpass: Dictionary = {}
var buildings: Array[Dictionary] = []
var bus_stops: Array[Dictionary] = []
var traffic_signals: Array[Dictionary] = []
var trees: Array[Dictionary] = []
var median_trees: Array[Dictionary] = []
## Chained routes (D68): section per stretch ("avenue" | "street" | "gravel") and per-type widths.
var sections: Array[Dictionary] = []
var lane_by_type: Dictionary = {"avenue": 6.75, "street": 3.75, "gravel": 2.8}
var curb_by_type: Dictionary = {"avenue": 12.0, "street": 8.0, "gravel": 6.5}
var property_by_type: Dictionary = {"avenue": 15.0, "street": 10.0, "gravel": 9.0}
var lots: Array[Dictionary] = []
var gravel_zones: Array[Dictionary] = []
var potholes: Array[Dictionary] = []
var fences: Array[Dictionary] = []
var poplars: Array[Dictionary] = []
var orchards: PackedVector3Array = PackedVector3Array()
## Small town (D69): raised bridge decks, the motorway underneath, the roundabout,
## the railway with its level crossings, the plaza, the churches, the canals and the fields.
var bridges: Array[Dictionary] = []
var motorway: Array = []
var trench: Dictionary = {}
var roundabout: Dictionary = {}
var rail_lines: Array = []
var rail_platforms: Array[Dictionary] = []
var rail_station: Dictionary = {}
var crossings: Array[Dictionary] = []
var plaza: Dictionary = {}
var parks: Array[Dictionary] = []
var churches: Array[Dictionary] = []
var water: Array = []
var fields: Array[Dictionary] = []
var vine_rows: Array = []
var streets: Array = []
## Bioma B2 Pantano (D71): agua, juncales, troncos, hualve, vados, pasarela, muelle.
var swamp: Dictionary = {}

var _cum: PackedFloat32Array = PackedFloat32Array()


static func load_from(path: String) -> OsmMapData:
	var text: String = FileAccess.get_file_as_string(path)
	if text.is_empty():
		push_error("OsmMapData: cannot read %s" % path)
		return null
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		push_error("OsmMapData: %s is not a JSON object" % path)
		return null
	var data: OsmMapData = OsmMapData.new()
	data._fill(parsed)
	return data


## Yaw for Basis(UP, yaw) so that local -Z points along `t` (the bus forward).
static func yaw_facing(t: Vector3) -> float:
	return atan2(-t.x, -t.z)


func segment_count() -> int:
	return axis.size() - 1


## Distancia acumulada hasta el punto `index` del eje. `project()` no sirve para esto en
## un circuito cerrado: el punto de ida cae igual de cerca del tramo de vuelta.
func s_at(index: int) -> float:
	if _cum.is_empty():
		return 0.0
	return _cum[clampi(index, 0, _cum.size() - 1)]


## Frame at distance `s` along the axis (extrapolated past both ends):
## origin on the axis, local -Z = tangent, left side = -basis.x.
func sample(s: float) -> Transform3D:
	var n: int = segment_count()
	if n < 1:
		return Transform3D.IDENTITY
	var i: int = 0
	if s >= length:
		i = n - 1
	elif s > 0.0:
		while i < n - 1 and s > _cum[i + 1]:
			i += 1
	var a: Vector3 = axis[i]
	var b: Vector3 = axis[i + 1]
	var seg_len: float = maxf(0.001, _flat(a).distance_to(_flat(b)))
	var t: Vector3 = (b - a) / seg_len
	var origin: Vector3 = a + t * (s - _cum[i])
	# Pitched frame so decks, ramps and their collision follow the climb (D69).
	var dir: Vector3 = t.normalized()
	var basis: Basis = Basis(Vector3.UP, yaw_facing(dir)) * Basis(Vector3.RIGHT, asin(clampf(dir.y, -1.0, 1.0)))
	return Transform3D(basis, origin)


static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


## Trench frame: x across the motorway (half_width), y along it (half_length). `yaw` is the
## motorway heading, so its direction is (cos yaw, 0, -sin yaw) and the cutting runs along it.
func trench_along() -> Vector3:
	var yaw: float = float(trench.get("yaw", 0.0))
	return Vector3(cos(yaw), 0.0, -sin(yaw))


func trench_across() -> Vector3:
	var yaw: float = float(trench.get("yaw", 0.0))
	return Vector3(sin(yaw), 0.0, cos(yaw))


func trench_centre() -> Vector3:
	return Vector3(float(trench.get("x", 0.0)), 0.0, float(trench.get("z", 0.0)))


func trench_local(p: Vector3) -> Vector2:
	if trench.is_empty():
		return Vector2(1e9, 1e9)
	var d: Vector3 = _flat(p) - trench_centre()
	return Vector2(d.dot(trench_across()), d.dot(trench_along()))


func over_trench(p: Vector3) -> bool:
	var l: Vector2 = trench_local(p)
	return absf(l.x) < float(trench.get("half_width", 0.0)) and absf(l.y) < float(trench.get("half_length", 0.0))


func left_of(frame: Transform3D) -> Vector3:
	return -frame.basis.x


## Point at distance `s` and signed lateral offset (positive = left of the
## eastbound direction, i.e. the north side).
func lateral_point(s: float, lateral: float) -> Vector3:
	var frame: Transform3D = sample(s)
	return frame.origin + left_of(frame) * lateral


## Distance along the axis and signed lateral offset of a world point.
func project(p: Vector3) -> Vector2:
	var best_d: float = INF
	var best: Vector2 = Vector2.ZERO
	for i: int in segment_count():
		var a: Vector3 = _flat(axis[i])
		var b: Vector3 = _flat(axis[i + 1])
		var ab: Vector3 = b - a
		var ll: float = maxf(0.001, ab.length_squared())
		var t: float = clampf((p - a).dot(ab) / ll, 0.0, 1.0)
		var q: Vector3 = a + ab * t
		var d: float = _flat(p).distance_to(q)
		if d < best_d:
			best_d = d
			var tangent: Vector3 = ab / sqrt(ll)
			var left: Vector3 = Vector3.UP.cross(tangent)
			# El costado firmado se saca de la DISTANCIA, con el signo de la normal: si el punto
			# más cercano cae en un extremo del eje, la componente normal es menor que la
			# distancia real y un edificio lejano se lee como pegado a la pista (medido en B2).
			var perp: float = (_flat(p) - q).dot(left)
			best = Vector2(_cum[i] + sqrt(ll) * t, d if perp >= 0.0 else -d)
	return best


## Section type at distance s ("avenue" when the route has no sections, i.e. a single avenue).
func section_at(s: float) -> String:
	for sec: Dictionary in sections:
		if s >= float(sec.get("s0", 0.0)) - 0.01 and s <= float(sec.get("s1", 0.0)) + 0.01:
			return str(sec.get("type", "avenue"))
	return "avenue"


func lane_at(s: float) -> float:
	return float(lane_by_type.get(section_at(s), lane_offset))


func curb_at(s: float) -> float:
	return float(curb_by_type.get(section_at(s), curb_lateral))


func property_at(s: float) -> float:
	return float(property_by_type.get(section_at(s), sidewalk_lateral + 1.0))


func in_gravel(s: float) -> bool:
	for zone: Dictionary in gravel_zones:
		if s >= float(zone.get("s0", 0.0)) and s <= float(zone.get("s1", 0.0)):
			return true
	return false


## ¿Esta calle tiene casas? (D78). OSM trae 217 calles y muchas cruzan campo vacío: una
## cuadrícula de ripio sobre pasto que no lleva a ninguna parte. Se mira la calle cada 20 m
## y se cuenta cuánta parte tiene algún edificio a `radius_m`; con menos de `min_share` es
## una calle de campo y no se dibuja. La grilla de edificios se arma una vez, perezosa.
func street_is_inhabited(street: Dictionary, radius_m: float = 45.0, min_share: float = 0.3) -> bool:
	var raw: Array = street.get("pts", []) as Array
	if raw.size() < 2:
		return false
	_ensure_building_grid()
	var samples: int = 0
	var near: int = 0
	for i: int in raw.size() - 1:
		var pa: Array = raw[i]
		var pb: Array = raw[i + 1]
		if pa.size() < 2 or pb.size() < 2:
			continue
		var a: Vector2 = Vector2(float(pa[0]), float(pa[1]))
		var b: Vector2 = Vector2(float(pb[0]), float(pb[1]))
		var seg_len: float = a.distance_to(b)
		var t: float = 0.0
		while t <= seg_len:
			samples += 1
			if _building_near(a.lerp(b, t / maxf(seg_len, 0.001)), radius_m):
				near += 1
			t += 20.0
	if samples == 0:
		return false
	return float(near) / float(samples) >= min_share


var _building_cells: Dictionary = {}
const BUILDING_CELL_M: float = 50.0


func _ensure_building_grid() -> void:
	if not _building_cells.is_empty() or buildings.is_empty():
		return
	for b: Dictionary in buildings:
		var p: Vector2 = Vector2(float(b.get("x", 0.0)), float(b.get("z", 0.0)))
		var key: Vector2i = Vector2i(int(floor(p.x / BUILDING_CELL_M)), int(floor(p.y / BUILDING_CELL_M)))
		if not _building_cells.has(key):
			_building_cells[key] = PackedVector2Array()
		var cell: PackedVector2Array = _building_cells[key]
		cell.append(p)
		_building_cells[key] = cell


func _building_near(p: Vector2, radius_m: float) -> bool:
	var reach: int = int(ceil(radius_m / BUILDING_CELL_M))
	var centre: Vector2i = Vector2i(int(floor(p.x / BUILDING_CELL_M)), int(floor(p.y / BUILDING_CELL_M)))
	for dy: int in range(-reach, reach + 1):
		for dx: int in range(-reach, reach + 1):
			var key: Vector2i = centre + Vector2i(dx, dy)
			if not _building_cells.has(key):
				continue
			for q: Vector2 in (_building_cells[key] as PackedVector2Array):
				if q.distance_to(p) <= radius_m:
					return true
	return false


## Las cuatro SALIDAS del pueblo (D78): por cada cuadrante (E, N, O, S respecto al centro
## del eje) la calle cuyo extremo llega más lejos del pueblo. Son las que llevarán a los
## otros biomas cuando el mapa los junte; se dibujan aunque no tengan casas, y al final de
## cada una BiomeHints pone la silueta del bioma que viene.
var _exits: Array[Dictionary] = []


func exit_streets() -> Array[Dictionary]:
	if not _exits.is_empty() or streets.is_empty():
		return _exits
	var centre: Vector2 = axis_centre()
	var best: Array = [null, null, null, null]
	var best_d: Array[float] = [0.0, 0.0, 0.0, 0.0]
	for item: Variant in streets:
		if not (item is Dictionary):
			continue
		var street: Dictionary = item
		var raw: Array = street.get("pts", []) as Array
		for end: int in [0, raw.size() - 1]:
			if end < 0 or end >= raw.size():
				continue
			var pe: Array = raw[end]
			if pe.size() < 2:
				continue
			var p: Vector2 = Vector2(float(pe[0]), float(pe[1]))
			var d: float = p.distance_to(centre)
			var q: int = exit_quadrant(p - centre)
			if d > best_d[q]:
				best_d[q] = d
				best[q] = street
	for q: int in 4:
		if best[q] != null:
			_exits.append(best[q])
	return _exits


func is_exit_street(street: Dictionary) -> bool:
	for e: Dictionary in exit_streets():
		if e == street:
			return true
	return false


## 0 = este (+x), 1 = norte (−z), 2 = oeste (−x), 3 = sur (+z).
static func exit_quadrant(v: Vector2) -> int:
	if absf(v.x) >= absf(v.y):
		return 0 if v.x >= 0.0 else 2
	return 1 if v.y < 0.0 else 3


func axis_centre() -> Vector2:
	var sum: Vector2 = Vector2.ZERO
	for p: Vector3 in axis:
		sum += Vector2(p.x, p.z)
	return sum / maxf(1.0, float(axis.size()))


## El tramo HABITADO de una calle (D79): los puntos entre la primera y la última muestra
## que tiene casa a `radius_m`, con 25 m de gracia a cada lado. Una calle con casas en su
## primer tercio ya no sigue 400 m hasta morir en un potrero. Las salidas van enteras.
## Devuelve pares [x, z] como los de OSM, para que los tres consumidores no cambien.
func inhabited_span(street: Dictionary, radius_m: float = 45.0) -> Array:
	var raw: Array = street.get("pts", []) as Array
	if raw.size() < 2 or is_exit_street(street):
		return raw
	_ensure_building_grid()
	var pts: Array[Vector2] = []
	for pair: Variant in raw:
		var arr: Array = pair
		if arr.size() >= 2:
			pts.append(Vector2(float(arr[0]), float(arr[1])))
	if pts.size() < 2:
		return []
	var cum: Array[float] = [0.0]
	for i: int in range(1, pts.size()):
		cum.append(cum[i - 1] + pts[i - 1].distance_to(pts[i]))
	var total: float = cum[cum.size() - 1]
	var first: float = -1.0
	var last: float = -1.0
	var s: float = 0.0
	while s <= total:
		if _building_near(_point_at(pts, cum, s), radius_m):
			if first < 0.0:
				first = s
			last = s
		s += 20.0
	if first < 0.0:
		return []
	first = maxf(0.0, first - 25.0)
	last = minf(total, last + 25.0)
	if last - first < 30.0:
		return []
	var out: Array = []
	var a: Vector2 = _point_at(pts, cum, first)
	out.append([a.x, a.y])
	for i: int in pts.size():
		if cum[i] > first and cum[i] < last:
			out.append([pts[i].x, pts[i].y])
	var b: Vector2 = _point_at(pts, cum, last)
	out.append([b.x, b.y])
	return out


static func _point_at(pts: Array[Vector2], cum: Array[float], s: float) -> Vector2:
	for i: int in range(1, pts.size()):
		if s <= cum[i]:
			var seg: float = maxf(cum[i] - cum[i - 1], 0.001)
			return pts[i - 1].lerp(pts[i], (s - cum[i - 1]) / seg)
	return pts[pts.size() - 1]


func in_gap(side: int, s: float) -> bool:
	for gap: Dictionary in curb_gaps:
		if int(gap.get("side", 0)) == side and s >= float(gap.get("s0", 0.0)) and s <= float(gap.get("s1", 0.0)):
			return true
	return false


func _fill(d: Dictionary) -> void:
	source = str(d.get("source", ""))
	length = float(d.get("length", 0.0))
	lane_offset = float(d.get("lane_offset", lane_offset))
	carriageway_width = float(d.get("carriageway_width", carriageway_width))
	median_width = float(d.get("median_width", median_width))
	curb_lateral = float(d.get("curb_lateral", curb_lateral))
	sidewalk_lateral = float(d.get("sidewalk_lateral", sidewalk_lateral))
	for item: Variant in _array(d.get("axis")):
		var pair: Array = item
		# [x, z] on the flat routes, [x, z, y] where the route climbs over a bridge (D69).
		axis.append(Vector3(float(pair[0]), float(pair[2]) if pair.size() > 2 else 0.0, float(pair[1])))
	for item: Variant in _array(d.get("waypoints")):
		var pair: Array = item
		waypoints.append(Vector3(float(pair[0]), 1.2, float(pair[1])))
	var e: Dictionary = d.get("entry", {})
	entry = Transform3D(Basis(Vector3.UP, float(e.get("yaw", 0.0))), Vector3(float(e.get("x", 0.0)), 1.2, float(e.get("z", 0.0))))
	curb_gaps = _dicts(d.get("curb_gaps"))
	humps = _dicts(d.get("humps"))
	station = d.get("station", {})
	fuel_lot = d.get("fuel_lot", {})
	pasaje = d.get("pasaje", {})
	underpass = d.get("underpass", {})
	buildings = _dicts(d.get("buildings"))
	bus_stops = _dicts(d.get("bus_stops"))
	traffic_signals = _dicts(d.get("traffic_signals"))
	trees = _dicts(d.get("trees"))
	median_trees = _dicts(d.get("median_trees"))
	sections = _dicts(d.get("sections"))
	if d.get("lane_by_type") is Dictionary:
		lane_by_type = d.get("lane_by_type")
	if d.get("curb_by_type") is Dictionary:
		curb_by_type = d.get("curb_by_type")
	if d.get("property_by_type") is Dictionary:
		property_by_type = d.get("property_by_type")
	lots = _dicts(d.get("lots"))
	gravel_zones = _dicts(d.get("gravel_zones"))
	potholes = _dicts(d.get("potholes"))
	fences = _dicts(d.get("fences"))
	poplars = _dicts(d.get("poplars"))
	for item: Variant in _array(d.get("orchards")):
		var pair: Array = item
		orchards.append(Vector3(float(pair[0]), 0.0, float(pair[1])))
	bridges = _dicts(d.get("bridges"))
	motorway = _array(d.get("motorway"))
	if d.get("trench") is Dictionary:
		trench = d.get("trench")
	if d.get("roundabout") is Dictionary:
		roundabout = d.get("roundabout")
	var rail: Dictionary = d.get("rail", {}) if d.get("rail") is Dictionary else {}
	rail_lines = _array(rail.get("lines"))
	rail_platforms = _dicts(rail.get("platforms"))
	if rail.get("station") is Dictionary:
		rail_station = rail.get("station")
	crossings = _dicts(rail.get("crossings"))
	if d.get("plaza") is Dictionary:
		plaza = d.get("plaza")
	parks = _dicts(d.get("parks"))
	churches = _dicts(d.get("churches"))
	water = _array(d.get("water"))
	fields = _dicts(d.get("fields"))
	vine_rows = _array(d.get("vine_rows"))
	streets = _array(d.get("streets"))
	if d.get("swamp") is Dictionary:
		swamp = d.get("swamp")
	_cum = PackedFloat32Array([0.0])
	for i: int in segment_count():
		_cum.append(_cum[i] + _flat(axis[i]).distance_to(_flat(axis[i + 1])))


static func _array(v: Variant) -> Array:
	if v is Array:
		return v
	return []


static func _dicts(v: Variant) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for item: Variant in _array(v):
		if item is Dictionary:
			out.append(item)
	return out
