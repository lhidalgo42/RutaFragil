class_name OsmRoad
extends Node3D

## Builds the real-avenue greybox from OsmMapData at runtime (D65): ground,
## two carriageways, median with grass and trees, sidewalks, curbs with
## collision (open at side streets, the station and the pasaje), flat speed
## humps in series with their signs, the crossing avenue's deck over the
## underpass with RR-6/PF-5 signs, bus stops, traffic signals, real trees,
## parked cars (mesh only) and the side pasaje with its fuel lot.
## Collision only on: ground, curbs, humps, underpass, pasaje curbs.

const COLOURS: Dictionary = {
	"ground": Color(0.45, 0.5, 0.42), "asphalt": Color(0.24, 0.25, 0.27), "asphalt_side": Color(0.3, 0.31, 0.33),
	"median": Color(0.35, 0.55, 0.3), "curb": Color(0.72, 0.72, 0.7), "sidewalk": Color(0.8, 0.78, 0.72),
	"hump": Color(0.85, 0.55, 0.15), "paint": Color(0.95, 0.85, 0.2), "concrete": Color(0.55, 0.52, 0.48),
	"warn": Color(0.95, 0.8, 0.1), "post": Color(0.6, 0.6, 0.62), "diamond": Color(0.95, 0.75, 0.1),
	"disc": Color(0.95, 0.95, 0.95), "stop": Color(0.85, 0.25, 0.25), "signal": Color(0.15, 0.15, 0.15),
	"trunk": Color(0.4, 0.28, 0.18), "crown": Color(0.25, 0.5, 0.25), "dirt": Color(0.5, 0.38, 0.25),
	"car_a": Color(0.85, 0.85, 0.88), "car_b": Color(0.25, 0.3, 0.55), "car_c": Color(0.6, 0.15, 0.15),
}
const HUMP_H: float = 0.15
const HUMP_RAMP: float = 1.8
const HUMP_CREST: float = 5.0
const SIGN_BEFORE_M: float = 35.0

@export var data_path: String = "res://data/b0_departamental.json"
@export var grass_per_m2: float = 5.0
@export var seed: int = 5

var data: OsmMapData
var _batches: Dictionary = {}
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	data = OsmMapData.load_from(data_path)
	if data != null:
		build()


func build() -> void:
	for child: Node in get_children():
		remove_child(child)
		child.free()
	_batches.clear()
	_rng.seed = seed
	_build_ground()
	_build_segments()
	_build_humps()
	_build_underpass()
	_build_furniture()
	_build_pasaje()
	_build_grass()
	_flush()


func curb_shape_count() -> int:
	return _shape_count("Curbs")


func hump_shape_count() -> int:
	return _shape_count("Humps")


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
	var size: Vector3 = Vector3(hi.x - lo.x + 600.0, 1.0, hi.z - lo.z + 600.0)
	var center: Vector3 = Vector3((lo.x + hi.x) * 0.5, -0.5, (lo.z + hi.z) * 0.5)
	var body: StaticBody3D = _body("Ground")
	_shape(body, size, Transform3D(Basis.IDENTITY, center))
	_box("ground", Transform3D(Basis.from_scale(size), center))


func _build_segments() -> void:
	var curbs: StaticBody3D = _body("Curbs")
	var lane: float = data.lane_offset
	var cw: float = data.carriageway_width
	for i: int in data.segment_count():
		var a: Vector3 = data.axis[i]
		var b: Vector3 = data.axis[i + 1]
		var seg_len: float = a.distance_to(b)
		var frame: Transform3D = data.sample(data.project((a + b) * 0.5).x)
		var s_mid: float = data.project((a + b) * 0.5).x
		var mid: Vector3 = (a + b) * 0.5
		var left: Vector3 = data.left_of(frame)
		var rot: Basis = frame.basis
		_box("asphalt", _along(rot, mid + left * -lane, Vector3(cw, 0.02, seg_len + 0.4), 0.01))
		_box("asphalt", _along(rot, mid + left * lane, Vector3(cw, 0.02, seg_len + 0.4), 0.01))
		_box("median", _along(rot, mid, Vector3(data.median_width, 0.15, seg_len + 0.2), 0.075))
		for side: int in [-1, 1]:
			var lat: float = float(side)
			_box("sidewalk", _along(rot, mid + left * (lat * data.sidewalk_lateral), Vector3(2.0, 0.15, seg_len + 0.2), 0.075))
			if not data.in_gap(side, s_mid):
				var curb_t: Transform3D = _along(rot, mid + left * (lat * data.curb_lateral), Vector3(2.0, 0.15, seg_len + 0.2), 0.075)
				_box("curb", curb_t)
				_shape(curbs, Vector3(2.0, 0.15, seg_len + 0.2), Transform3D(rot, curb_t.origin))
				if i % 2 == 0 and _far_from_features(s_mid, 22.0):
					var car_lat: float = lat * (data.curb_lateral - 2.1)
					var colour: String = ["car_a", "car_b", "car_c"][_rng.randi() % 3]
					_box(colour, _along(rot, mid + left * car_lat, Vector3(1.7, 1.5, 4.4), 0.75))


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
			_round_hump(body, frame, center)
		else:
			_flat_hump(body, frame, center)
		# PG-8a (yellow diamond) + RR-1 (white disc), 35 m before the hump in the direction of travel
		var sign_s: float = s - SIGN_BEFORE_M if side < 0 else s + SIGN_BEFORE_M
		_sign(sign_s, float(side) * (data.curb_lateral + 1.4), "diamond", "disc")


## Resalto plano (Decreto 200): 15 cm at curb level, 5 m plateau, 1.8 m ramps.
func _flat_hump(body: StaticBody3D, frame: Transform3D, center: Vector3) -> void:
	var cw: float = data.carriageway_width
	var fwd: Vector3 = -frame.basis.z
	var crest_t: Transform3D = Transform3D(frame.basis, center + Vector3.UP * (HUMP_H - 0.5))
	_shape(body, Vector3(cw, 1.0, HUMP_CREST), crest_t)
	_box("hump", Transform3D(frame.basis * Basis.from_scale(Vector3(cw, 1.0, HUMP_CREST)), crest_t.origin))
	_ramps(body, frame, center, HUMP_H, HUMP_RAMP, HUMP_CREST * 0.5)
	for dir: float in [1.0, -1.0]:
		_box("paint", _along(frame.basis, center - fwd * ((HUMP_CREST * 0.5 - 0.1) * dir), Vector3(cw, 0.02, 0.15), HUMP_H + 0.01))


## Resalto redondeado (Decreto 200): 7.5 cm high, 3.7 m long, no plateau. Two
## ramps meeting at the middle; the placeholder box rides it without lifting off.
func _round_hump(body: StaticBody3D, frame: Transform3D, center: Vector3) -> void:
	_ramps(body, frame, center, 0.075, 1.85, 0.0)
	_box("paint", _along(frame.basis, center, Vector3(data.carriageway_width, 0.02, 0.15), 0.085))


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
		_box("hump", Transform3D(basis * Basis.from_scale(Vector3(cw, 1.0, ramp_len)), pos))


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
	_box("concrete", Transform3D(frame.basis * Basis.from_scale(Vector3(across, 1.0, along)), deck_t.origin))
	for side: float in [-1.0, 1.0]:
		var wall_pos: Vector3 = frame.origin + data.left_of(frame) * (side * (data.curb_lateral + 1.0)) + Vector3.UP * (clearance * 0.5)
		_shape(body, Vector3(1.0, clearance, along), Transform3D(frame.basis, wall_pos))
		_box("concrete", Transform3D(frame.basis * Basis.from_scale(Vector3(1.0, clearance, along)), wall_pos))
		var fwd: Vector3 = -frame.basis.z
		_box("warn", _along(frame.basis, frame.origin + fwd * (side * (along * 0.5 + 0.04)), Vector3(across, 0.35, 0.06), clearance - 0.12))
	_sign(s - SIGN_BEFORE_M, -(data.curb_lateral + 1.4), "diamond", "disc")
	_sign(s + SIGN_BEFORE_M, data.curb_lateral + 1.4, "diamond", "disc")


func _build_furniture() -> void:
	for stop: Dictionary in data.bus_stops:
		var p: Vector3 = _pt(stop)
		var rot: Basis = data.sample(float(stop.get("s", 0.0))).basis
		_box("stop", _along(rot, p, Vector3(2.0, 2.56, 3.6), 1.28))
	for sig: Dictionary in data.traffic_signals:
		var p: Vector3 = _pt(sig)
		_box("post", Transform3D(Basis.from_scale(Vector3(0.15, 3.6, 0.15)), p + Vector3.UP * 1.8))
		_box("signal", Transform3D(Basis.from_scale(Vector3(0.3, 0.9, 0.3)), p + Vector3.UP * 3.4))
	for tree: Dictionary in data.trees:
		_tree(_pt(tree), 4.0, 1.6)
	for tree: Dictionary in data.median_trees:
		_tree(_pt(tree), 5.4, 1.7)


func _tree(p: Vector3, trunk_h: float, crown_r: float) -> void:
	_batch("trunk", "cyl", Transform3D(Basis.from_scale(Vector3(0.4, trunk_h, 0.4)), p + Vector3.UP * (trunk_h * 0.5)))
	var top: Vector3 = p + Vector3.UP * (trunk_h + crown_r * 0.8)
	_batch("crown", "sph", Transform3D(Basis.from_scale(Vector3.ONE * crown_r * 2.0), top))
	_batch("crown", "sph", Transform3D(Basis.from_scale(Vector3.ONE * crown_r * 1.4), top + Vector3(crown_r * 0.7, crown_r * 0.35, 0.2)))
	_batch("crown", "sph", Transform3D(Basis.from_scale(Vector3.ONE * crown_r * 1.2), top + Vector3(-crown_r * 0.5, crown_r * 0.5, -crown_r * 0.5)))


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
	_box("asphalt_side", _along(rot, mouth + dir * (length * 0.5), Vector3(width, 0.02, length), 0.01))
	for side: float in [-1.0, 1.0]:
		var pos: Vector3 = mouth + dir * (start + road_len * 0.5) + left * (side * (width * 0.5 + 1.0))
		_box("curb", _along(rot, pos, Vector3(2.0, 0.15, road_len), 0.075))
		_shape(curbs, Vector3(2.0, 0.15, road_len), Transform3D(rot, pos + Vector3.UP * 0.075))
	var lot_along: float = float(pz.get("lot_along", 60.0))
	var lot_depth: float = float(pz.get("lot_depth", 44.0))
	var lot_half: float = float(pz.get("lot_half_width", 26.0))
	_box("dirt", _along(rot, mouth + dir * (lot_along + lot_depth * 0.5), Vector3(lot_half * 2.0, 0.02, lot_depth), 0.015))


func _build_grass() -> void:
	var strip: GrassStrip = GrassStrip.new()
	strip.name = "MedianGrass"
	add_child(strip)
	strip.build_along(data.axis, data.median_width * 0.5 - 0.2, grass_per_m2, seed)


# ---------- helpers ----------

func _pt(d: Dictionary) -> Vector3:
	return Vector3(float(d.get("x", 0.0)), 0.0, float(d.get("z", 0.0)))


func _sign(s: float, lateral: float, top_kind: String, bottom_kind: String) -> void:
	var p: Vector3 = data.lateral_point(s, lateral)
	_box("post", Transform3D(Basis.from_scale(Vector3(0.1, 2.4, 0.1)), p + Vector3.UP * 1.2))
	_box(top_kind, Transform3D(Basis.from_scale(Vector3(0.6, 0.6, 0.05)), p + Vector3.UP * 2.6))
	_box(bottom_kind, Transform3D(Basis.from_scale(Vector3(0.6, 0.6, 0.05)), p + Vector3.UP * 1.95))


## Box of `size` (x across, y up, z along) laid along basis `rot` at `pos`, lifted by `y`.
func _along(rot: Basis, pos: Vector3, size: Vector3, y: float) -> Transform3D:
	return Transform3D(rot * Basis.from_scale(size), pos + Vector3.UP * y)


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


func _box(kind: String, xform: Transform3D) -> void:
	_batch(kind, "box", xform)


func _batch(kind: String, mesh_kind: String, xform: Transform3D) -> void:
	if not _batches.has(kind):
		_batches[kind] = {"mesh": mesh_kind, "xforms": []}
	var entry: Dictionary = _batches[kind]
	var xforms: Array = entry["xforms"]
	xforms.append(xform)


func _flush() -> void:
	for kind: String in _batches.keys():
		var entry: Dictionary = _batches[kind]
		var xforms: Array = entry["xforms"]
		var mm: MultiMesh = MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = _unit_mesh(str(entry["mesh"]), COLOURS.get(kind, Color.MAGENTA))
		mm.instance_count = xforms.size()
		for i: int in xforms.size():
			var xf: Transform3D = xforms[i]
			mm.set_instance_transform(i, xf)
		var inst: MultiMeshInstance3D = MultiMeshInstance3D.new()
		inst.name = "Batch_" + kind
		inst.multimesh = mm
		add_child(inst)


func _unit_mesh(mesh_kind: String, colour: Color) -> Mesh:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = colour
	var mesh: Mesh
	match mesh_kind:
		"cyl":
			var cyl: CylinderMesh = CylinderMesh.new()
			cyl.top_radius = 0.5
			cyl.bottom_radius = 0.5
			cyl.height = 1.0
			mesh = cyl
		"sph":
			var sph: SphereMesh = SphereMesh.new()
			sph.radius = 0.5
			sph.height = 1.0
			mesh = sph
		_:
			var box: BoxMesh = BoxMesh.new()
			box.size = Vector3.ONE
			mesh = box
	mesh.surface_set_material(0, material)
	return mesh
