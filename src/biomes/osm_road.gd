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
	"ground": Color(0.45, 0.5, 0.42), "asphalt": Color(0.24, 0.25, 0.27), "asphalt_side": Color(0.3, 0.31, 0.33),
	"median": Color(0.35, 0.55, 0.3), "curb": Color(0.72, 0.72, 0.7), "sidewalk": Color(0.8, 0.78, 0.72),
	"hump": Color(0.85, 0.55, 0.15), "paint": Color(0.95, 0.85, 0.2), "paint_white": Color(0.93, 0.93, 0.9),
	"paint_yellow": Color(0.95, 0.8, 0.15), "concrete": Color(0.55, 0.52, 0.48), "warn": Color(0.95, 0.8, 0.1),
	"post": Color(0.6, 0.6, 0.62), "diamond": Color(0.95, 0.75, 0.1), "disc": Color(0.95, 0.95, 0.95), "dirt": Color(0.5, 0.38, 0.25),
	"car_a": Color(0.85, 0.85, 0.88), "car_b": Color(0.25, 0.3, 0.55), "car_c": Color(0.6, 0.15, 0.15),
}
const HUMP_H: float = 0.15
const HUMP_RAMP: float = 1.8
const HUMP_CREST: float = 5.0
const SIGN_BEFORE_M: float = 35.0
const CROSSWALK_OFFSET_M: float = 12.0

@export var data_path: String = "res://data/b0_departamental.json"
@export var grass_per_m2: float = 5.0
@export var seed: int = 5

var data: OsmMapData
var _b: MeshBatcher = MeshBatcher.new()
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	data = OsmMapData.load_from(data_path)
	if data != null:
		build()


func build() -> void:
	for child: Node in get_children():
		remove_child(child)
		child.free()
	_rng.seed = seed
	_build_ground()
	_build_segments()
	_build_crosswalks()
	_build_humps()
	_build_underpass()
	_build_pasaje()
	_build_grass()
	_b.flush(self, COLOURS)


func curb_shape_count() -> int:
	return _shape_count("Curbs")


func hump_shape_count() -> int:
	return _shape_count("Humps")


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
	var lo: Vector3 = data.axis[0]
	var hi: Vector3 = data.axis[0]
	for p: Vector3 in data.axis:
		lo = lo.min(p)
		hi = hi.max(p)
	var size: Vector3 = Vector3(hi.x - lo.x + 1200.0, 1.0, hi.z - lo.z + 1200.0)
	var center: Vector3 = Vector3((lo.x + hi.x) * 0.5, -0.5, (lo.z + hi.z) * 0.5)
	var body: StaticBody3D = _body("Ground")
	_shape(body, size, Transform3D(Basis.IDENTITY, center))
	_b.box("ground", Transform3D(Basis.from_scale(size), center))


func _build_segments() -> void:
	var curbs: StaticBody3D = _body("Curbs")
	for i: int in data.segment_count():
		var a: Vector3 = data.axis[i]
		var b: Vector3 = data.axis[i + 1]
		var seg_len: float = a.distance_to(b)
		var mid: Vector3 = (a + b) * 0.5
		var s_mid: float = data.project(mid).x
		var frame: Transform3D = data.sample(s_mid)
		var kind: String = data.section_at(s_mid)
		if kind == "gravel":
			continue  # OsmGravel draws the unpaved stretches
		if kind == "street":
			_street_segment(frame, mid, seg_len, s_mid)
		else:
			_avenue_segment(curbs, frame, mid, seg_len, s_mid)


## Avenue (D63): two carriageways, median, sidewalks, curbs with collision, markings, parked cars.
func _avenue_segment(curbs: StaticBody3D, frame: Transform3D, mid: Vector3, seg_len: float, s_mid: float) -> void:
	var lane: float = data.lane_offset
	var cw: float = data.carriageway_width
	var left: Vector3 = data.left_of(frame)
	var fwd: Vector3 = -frame.basis.z
	var rot: Basis = frame.basis
	for side: float in [-1.0, 1.0]:
		_b.box("asphalt", MeshBatcher.along(rot, mid + left * (side * lane), Vector3(cw, 0.02, seg_len + 0.4), 0.01))
		_b.box("paint_white", MeshBatcher.along(rot, mid + left * (side * (data.curb_lateral - 1.3)), Vector3(0.12, 0.02, seg_len + 0.2), 0.025))
		_b.box("paint_yellow", MeshBatcher.along(rot, mid + left * (side * (data.median_width * 0.5 + 0.3)), Vector3(0.12, 0.02, seg_len + 0.2), 0.025))
		for k: float in [-0.25, 0.25]:
			_b.box("paint_white", MeshBatcher.along(rot, mid + left * (side * lane) + fwd * (seg_len * k), Vector3(0.12, 0.02, 3.0), 0.025))
		_b.box("sidewalk", MeshBatcher.along(rot, mid + left * (side * data.sidewalk_lateral), Vector3(2.0, 0.15, seg_len + 0.2), 0.075))
		if not data.in_gap(int(side), s_mid):
			var curb_t: Transform3D = MeshBatcher.along(rot, mid + left * (side * data.curb_lateral), Vector3(2.0, 0.15, seg_len + 0.2), 0.075)
			_b.box("curb", curb_t)
			_shape(curbs, Vector3(2.0, 0.15, seg_len + 0.2), Transform3D(rot, curb_t.origin))
			if int(s_mid / 20.0) % 2 == 0 and _far_from_features(s_mid, 22.0):
				var colour: String = ["car_a", "car_b", "car_c"][_rng.randi() % 3]
				_b.box(colour, MeshBatcher.along(rot, mid + left * (side * (data.curb_lateral - 2.1)), Vector3(1.7, 1.5, 4.4), 0.75))
	_b.box("median", MeshBatcher.along(rot, mid, Vector3(data.median_width, 0.15, seg_len + 0.2), 0.075))


## Población street (D68): one two-way carriageway, dashed yellow centre line, curbs and sidewalks as mesh only
## (the D48 box would jam on a 15 cm curb this close to its lane; T1.1 gets real curbs here).
func _street_segment(frame: Transform3D, mid: Vector3, seg_len: float, s_mid: float) -> void:
	var left: Vector3 = data.left_of(frame)
	var fwd: Vector3 = -frame.basis.z
	var rot: Basis = frame.basis
	var curb: float = data.curb_at(s_mid)
	_b.box("asphalt", MeshBatcher.along(rot, mid, Vector3(curb * 2.0 - 2.0, 0.02, seg_len + 0.4), 0.01))
	for k: float in [-0.25, 0.25]:
		_b.box("paint_yellow", MeshBatcher.along(rot, mid + fwd * (seg_len * k), Vector3(0.12, 0.02, 3.0), 0.025))
	for side: float in [-1.0, 1.0]:
		_b.box("paint_white", MeshBatcher.along(rot, mid + left * (side * (curb - 1.5)), Vector3(0.1, 0.02, seg_len + 0.2), 0.025))
		if not data.in_gap(int(side), s_mid):
			_b.box("curb", MeshBatcher.along(rot, mid + left * (side * curb), Vector3(1.0, 0.15, seg_len + 0.2), 0.075))
		_b.box("sidewalk", MeshBatcher.along(rot, mid + left * (side * (curb + 1.4)), Vector3(1.8, 0.15, seg_len + 0.2), 0.075))


## Zebra crossing and stop line at every real side-street junction (gaps that are not the station or the pasaje).
func _build_crosswalks() -> void:
	for gap: Dictionary in data.curb_gaps:
		var gap_name: String = str(gap.get("name", ""))
		if gap_name == "estacion" or gap_name == "pasaje":
			continue
		var s_j: float = (float(gap.get("s0", 0.0)) + float(gap.get("s1", 0.0))) * 0.5 + CROSSWALK_OFFSET_M
		if s_j < 20.0 or s_j > data.length - 20.0 or absf(s_j - float(data.underpass.get("s", -1000.0))) < 30.0 or data.section_at(s_j) == "gravel":
			continue
		var frame: Transform3D = data.sample(s_j)
		var left: Vector3 = data.left_of(frame)
		var fwd: Vector3 = -frame.basis.z
		var avenue: bool = data.section_at(s_j) == "avenue"
		var inner: float = data.median_width * 0.5 + 0.75 if avenue else 0.25
		var bars: int = 10 if avenue else 6
		for side: float in [-1.0, 1.0]:
			for k: int in bars:
				var lat: float = side * (inner + float(k) * 1.0)
				_b.box("paint_white", MeshBatcher.along(frame.basis, frame.origin + left * lat, Vector3(0.5, 0.02, 4.0), 0.026))
			# stop line 3 m before the crossing, in the direction of travel of that carriageway (south = eastbound)
			var stop_pos: Vector3 = frame.origin + left * (side * data.lane_at(s_j)) + fwd * (-3.0 if side < 0.0 else 3.0)
			var stop_w: float = data.carriageway_width - 0.6 if avenue else data.curb_at(s_j) - 1.0
			_b.box("paint_white", MeshBatcher.along(frame.basis, stop_pos, Vector3(stop_w, 0.02, 0.4), 0.026))


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
		var center: Vector3 = frame.origin + data.left_of(frame) * (float(side) * data.lane_offset)
		if str(h.get("kind", "flat")) == "round":
			_ramps(body, frame, center, 0.075, 1.85, 0.0)
			_b.box("paint", MeshBatcher.along(frame.basis, center, Vector3(data.carriageway_width, 0.02, 0.15), 0.085))
		else:
			_flat_hump(body, frame, center)
		var sign_s: float = s - SIGN_BEFORE_M if side < 0 else s + SIGN_BEFORE_M
		_sign(sign_s, float(side) * (data.curb_lateral + 1.4), "diamond", "disc")


## Resalto plano (Decreto 200): 15 cm at curb level, 5 m plateau, 1.8 m ramps.
func _flat_hump(body: StaticBody3D, frame: Transform3D, center: Vector3) -> void:
	var cw: float = data.carriageway_width
	var fwd: Vector3 = -frame.basis.z
	var crest_t: Transform3D = Transform3D(frame.basis, center + Vector3.UP * (HUMP_H - 0.5))
	_shape(body, Vector3(cw, 1.0, HUMP_CREST), crest_t)
	_b.box("hump", Transform3D(frame.basis * Basis.from_scale(Vector3(cw, 1.0, HUMP_CREST)), crest_t.origin))
	_ramps(body, frame, center, HUMP_H, HUMP_RAMP, HUMP_CREST * 0.5)
	for dir: float in [1.0, -1.0]:
		_b.box("paint", MeshBatcher.along(frame.basis, center - fwd * ((HUMP_CREST * 0.5 - 0.1) * dir), Vector3(cw, 0.02, 0.15), HUMP_H + 0.01))


## Two ramps of horizontal run `run` rising `height`, starting `plateau_half` from the centre;
## the ramp behind (local +Z) pitches +ang, the one ahead pitches -ang (same as city_bumps.tscn).
func _ramps(body: StaticBody3D, frame: Transform3D, center: Vector3, height: float, run: float, plateau_half: float) -> void:
	var cw: float = data.carriageway_width
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
	_b.box("dirt", MeshBatcher.along(rot, mouth + dir * (lot_along + lot_depth * 0.5), Vector3(lot_half * 2.0, 0.02, lot_depth), 0.015))


func _build_grass() -> void:
	var strip: GrassStrip = GrassStrip.new()
	strip.name = "MedianGrass"
	add_child(strip)
	var pts: PackedVector3Array = PackedVector3Array()
	for i: int in data.axis.size():
		var s: float = data.project(data.axis[i]).x
		if data.section_at(s) == "avenue":
			pts.append(data.axis[i])
		elif pts.size() > 1:
			break
	if pts.size() > 1:
		strip.build_along(pts, data.median_width * 0.5 - 0.35, grass_per_m2, seed)


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
