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
	"bench": Color(0.45, 0.32, 0.2), "trunk": Color(0.4, 0.28, 0.18), "crown": Color(0.26, 0.48, 0.24),
	"tower": Color(0.85, 0.8, 0.72), "cross_church": Color(0.9, 0.88, 0.84),
	"water": Color(0.32, 0.42, 0.45), "bank": Color(0.46, 0.4, 0.3),
	"vine": Color(0.3, 0.42, 0.22), "vine_post": Color(0.5, 0.42, 0.32),
	"motorway": Color(0.26, 0.27, 0.29), "motorway_paint": Color(0.92, 0.92, 0.88),
	"truck_a": Color(0.85, 0.85, 0.85), "truck_b": Color(0.2, 0.35, 0.6),
}
const RAIL_GAUGE_M: float = 1.676        # trocha chilena
const SLEEPER_STEP_M: float = 5.0
const MAX_SLEEPERS: int = 1400
const RAIL_RANGE_M: float = 900.0

@export var data_path: String = "res://data/b0_requinoa.json"

var data: OsmMapData
var _b: MeshBatcher = MeshBatcher.new()


func _ready() -> void:
	data = OsmMapData.load_from(data_path)
	if data != null:
		build()


func build() -> void:
	for child: Node in get_children():
		remove_child(child)
		child.free()
	_build_rail()
	_build_crossings()
	_build_station()
	_build_plaza()
	_build_churches()
	_build_water()
	_build_vines()
	_build_motorway()
	_b.flush(self, COLOURS)


func batch_count(kind: String) -> int:
	var node: Node = get_node_or_null("Batch_" + kind)
	if node is MultiMeshInstance3D:
		var inst: MultiMeshInstance3D = node
		return inst.multimesh.instance_count
	return 0


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
	_b.box("paving", Transform3D(Basis.from_scale(Vector3(size.x, 0.12, size.z)), centre + Vector3.UP * 0.06))
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var quad: Vector3 = centre + Vector3(sx * size.x * 0.24, 0.0, sz * size.z * 0.24)
			_b.box("grass", Transform3D(Basis.from_scale(Vector3(size.x * 0.34, 0.16, size.z * 0.34)), quad + Vector3.UP * 0.1))
			_tree(quad + Vector3(sx * size.x * 0.14, 0.0, sz * size.z * 0.14), 4.4, 2.2)
	_b.add("kiosk", "cyl", Transform3D(Basis.from_scale(Vector3(7.0, 0.4, 7.0)), centre + Vector3.UP * 0.25))
	for k: int in 8:
		var ang: float = TAU * float(k) / 8.0
		_b.add("kiosk", "cyl", Transform3D(Basis.from_scale(Vector3(0.22, 3.2, 0.22)), centre + Vector3(cos(ang), 0.0, sin(ang)) * 3.2 + Vector3.UP * 1.8))
	_b.add("roof", "cyl", Transform3D(Basis.from_scale(Vector3(8.2, 0.9, 8.2)), centre + Vector3.UP * 3.8))
	for k: int in 6:
		var a2: float = TAU * float(k) / 6.0
		_b.box("bench", Transform3D(Basis(Vector3.UP, a2) * Basis.from_scale(Vector3(0.5, 0.12, 1.8)), centre + Vector3(cos(a2), 0.0, sin(a2)) * 11.0 + Vector3.UP * 0.5))


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
		var mid: Vector3 = (a + b) * 0.5
		_b.box("vine", Transform3D(Basis.from_scale(Vector3(seg, 1.1, 0.7)), mid + Vector3.UP * 1.0))
		for end: Vector3 in [a, b]:
			_b.add("vine_post", "cyl", Transform3D(Basis.from_scale(Vector3(0.14, 1.9, 0.14)), end + Vector3.UP * 0.95))


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


func _tree(p: Vector3, trunk_h: float, crown_r: float) -> void:
	_b.add("trunk", "cyl", Transform3D(Basis.from_scale(Vector3(0.45, trunk_h, 0.45)), p + Vector3.UP * (trunk_h * 0.5)))
	var top: Vector3 = p + Vector3.UP * (trunk_h + crown_r * 0.7)
	_b.add("crown", "sph", Transform3D(Basis.from_scale(Vector3.ONE * crown_r * 2.0), top))
	_b.add("crown", "sph", Transform3D(Basis.from_scale(Vector3.ONE * crown_r * 1.3), top + Vector3(crown_r * 0.6, crown_r * 0.4, 0.0)))


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
