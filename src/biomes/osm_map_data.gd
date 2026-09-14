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
	var seg_len: float = maxf(0.001, a.distance_to(b))
	var t: Vector3 = (b - a) / seg_len
	var origin: Vector3 = a + t * (s - _cum[i])
	return Transform3D(Basis(Vector3.UP, yaw_facing(t)), origin)


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
		var a: Vector3 = axis[i]
		var b: Vector3 = axis[i + 1]
		var ab: Vector3 = b - a
		var ll: float = maxf(0.001, ab.length_squared())
		var t: float = clampf((p - a).dot(ab) / ll, 0.0, 1.0)
		var q: Vector3 = a + ab * t
		var d: float = p.distance_to(q)
		if d < best_d:
			best_d = d
			var tangent: Vector3 = ab / sqrt(ll)
			var left: Vector3 = Vector3.UP.cross(tangent)
			best = Vector2(_cum[i] + sqrt(ll) * t, (p - q).dot(left))
	return best


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
		axis.append(Vector3(float(pair[0]), 0.0, float(pair[1])))
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
	_cum = PackedFloat32Array([0.0])
	for i: int in segment_count():
		_cum.append(_cum[i] + axis[i].distance_to(axis[i + 1]))


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
