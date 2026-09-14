class_name OsmGravel
extends Node3D

## Unpaved stretches of a chained route (D68): dirt roadway with dust edges,
## thousands of pebbles, "calamina" washboard bumps with collision so the bus
## rattles, potholes, roadside ditches (acequias), and one GravelZone whose
## shapes cover the whole stretch. Everything else there (fences, poplars,
## orchards) is OsmFurniture's.

const COLOURS: Dictionary = {
	"dirt": Color(0.56, 0.45, 0.32), "dust": Color(0.66, 0.56, 0.42), "pebble": Color(0.5, 0.47, 0.42),
	"pebble_b": Color(0.62, 0.58, 0.5), "ditch": Color(0.28, 0.24, 0.18), "pothole": Color(0.3, 0.24, 0.17), "wash": Color(0.6, 0.49, 0.36),
}
const WASH_STEP_M: float = 2.5
const WASH_H: float = 0.035
const WASH_RUN: float = 0.6
const ROAD_W: float = 11.0

@export var data_path: String = "res://data/b0_rancagua.json"
@export var pebbles_per_m2: float = 1.1
@export var seed: int = 27

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
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed
	var zone: GravelZone = GravelZone.new()
	zone.name = "GravelZone"
	add_child(zone)
	var wash: StaticBody3D = StaticBody3D.new()
	wash.name = "Washboard"
	add_child(wash)
	for z: Dictionary in data.gravel_zones:
		var s0: float = float(z.get("s0", 0.0))
		var s1: float = float(z.get("s1", 0.0))
		var s: float = s0
		while s < s1:
			var seg_len: float = minf(10.0, s1 - s)
			var frame: Transform3D = data.sample(s + seg_len * 0.5)
			var left: Vector3 = data.left_of(frame)
			_b.box("dirt", MeshBatcher.along(frame.basis, frame.origin, Vector3(ROAD_W, 0.03, seg_len + 0.3), 0.012))
			for side: float in [-1.0, 1.0]:
				_b.box("dust", MeshBatcher.along(frame.basis, frame.origin + left * (side * (ROAD_W * 0.5 - 0.8)), Vector3(1.6, 0.032, seg_len + 0.3), 0.013))
				_b.box("ditch", MeshBatcher.along(frame.basis, frame.origin + left * (side * (ROAD_W * 0.5 + 1.2)), Vector3(1.4, 0.02, seg_len + 0.3), 0.005))
			var area_shape: CollisionShape3D = CollisionShape3D.new()
			var box: BoxShape3D = BoxShape3D.new()
			box.size = Vector3(ROAD_W + 2.0, 3.0, seg_len + 0.3)
			area_shape.shape = box
			zone.add_child(area_shape)
			area_shape.transform = Transform3D(frame.basis, frame.origin + Vector3.UP * 1.5)
			var count: int = int(round(seg_len * ROAD_W * pebbles_per_m2))
			for _k: int in count:
				var pos: Vector3 = frame.origin + (-frame.basis.z) * rng.randf_range(-seg_len * 0.5, seg_len * 0.5) + left * rng.randf_range(-ROAD_W * 0.5, ROAD_W * 0.5)
				var size: float = rng.randf_range(0.06, 0.14)
				_b.add("pebble" if rng.randf() < 0.6 else "pebble_b", "box", Transform3D(Basis(Vector3.UP, rng.randf() * TAU) * Basis.from_scale(Vector3(size, size * 0.6, size * 0.8)), pos + Vector3.UP * (size * 0.3 + 0.03)))
			s += seg_len
		_washboard(wash, s0 + 6.0, s1 - 6.0)
	for pothole: Dictionary in data.potholes:
		var r: float = float(pothole.get("r", 0.8))
		var p: Vector3 = Vector3(float(pothole.get("x", 0.0)), 0.045, float(pothole.get("z", 0.0)))
		_b.add("pothole", "cyl", Transform3D(Basis.from_scale(Vector3(r * 2.0, 0.02, r * 1.5)), p))
	_b.flush(self, COLOURS)


func washboard_shape_count() -> int:
	var node: Node = get_node_or_null("Washboard")
	return node.get_child_count() if node != null else 0


func zone_shape_count() -> int:
	var node: Node = get_node_or_null("GravelZone")
	return node.get_child_count() if node != null else 0


## Calamina: low twin ramps across the whole roadway every WASH_STEP_M metres.
func _washboard(body: StaticBody3D, s0: float, s1: float) -> void:
	var ang: float = atan2(WASH_H, WASH_RUN)
	var ramp_len: float = sqrt(WASH_RUN * WASH_RUN + WASH_H * WASH_H)
	var ramp_y: float = WASH_H * 0.5 - 0.5 * cos(ang)
	var s: float = s0
	while s < s1:
		var frame: Transform3D = data.sample(s)
		var fwd: Vector3 = -frame.basis.z
		for dir: float in [1.0, -1.0]:
			var basis: Basis = frame.basis * Basis(Vector3.RIGHT, ang * dir)
			var pos: Vector3 = frame.origin - fwd * (WASH_RUN * 0.5 * dir) + Vector3.UP * ramp_y
			var shape_node: CollisionShape3D = CollisionShape3D.new()
			var box: BoxShape3D = BoxShape3D.new()
			box.size = Vector3(ROAD_W, 1.0, ramp_len)
			shape_node.shape = box
			body.add_child(shape_node)
			shape_node.transform = Transform3D(basis, pos)
			_b.box("wash", Transform3D(basis * Basis.from_scale(Vector3(ROAD_W, 1.0, ramp_len)), pos))
		s += WASH_STEP_M
