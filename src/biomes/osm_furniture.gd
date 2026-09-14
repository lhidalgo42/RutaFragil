class_name OsmFurniture
extends Node3D

## Street furniture for the real avenue (D65, D67), all mesh only: real bus
## stops, traffic signals and trees from OSM, median trees and double-arm
## street lights, concrete power poles with sagging cables on both sidewalks,
## and sidewalk trees every 12 m where nothing else stands.

const COLOURS: Dictionary = {
	"stop": Color(0.85, 0.25, 0.25), "stop_roof": Color(0.95, 0.95, 0.93), "signal": Color(0.15, 0.15, 0.15), "post": Color(0.6, 0.6, 0.62),
	"trunk": Color(0.4, 0.28, 0.18), "crown": Color(0.25, 0.5, 0.25), "crown_b": Color(0.32, 0.56, 0.24),
	"pole": Color(0.62, 0.6, 0.56), "cable": Color(0.12, 0.12, 0.12), "lamp": Color(0.98, 0.95, 0.8), "light_pole": Color(0.35, 0.36, 0.38),
}
const POLE_STEP_M: float = 35.0
const TREE_STEP_M: float = 12.0

@export var data_path: String = "res://data/b0_departamental.json"

var data: OsmMapData
var _b: MeshBatcher = MeshBatcher.new()
var _occupied: Array[Vector2] = []


func _ready() -> void:
	data = OsmMapData.load_from(data_path)
	if data != null:
		build()


func build() -> void:
	for child: Node in get_children():
		remove_child(child)
		child.free()
	_occupied.clear()
	for stop: Dictionary in data.bus_stops:
		var p: Vector3 = _pt(stop)
		var rot: Basis = data.sample(float(stop.get("s", 0.0))).basis
		_b.box("stop", MeshBatcher.along(rot, p, Vector3(1.6, 2.3, 3.6), 1.15))
		_b.box("stop_roof", MeshBatcher.along(rot, p, Vector3(2.2, 0.15, 4.0), 2.5))
		_occupy(stop)
	for sig: Dictionary in data.traffic_signals:
		var p: Vector3 = _pt(sig)
		_b.box("post", Transform3D(Basis.from_scale(Vector3(0.15, 3.6, 0.15)), p + Vector3.UP * 1.8))
		_b.box("signal", Transform3D(Basis.from_scale(Vector3(0.3, 0.9, 0.3)), p + Vector3.UP * 3.4))
		_occupy(sig)
	for tree: Dictionary in data.trees:
		_tree(_pt(tree), 4.0, 1.6)
		_occupy(tree)
	for tree: Dictionary in data.median_trees:
		_tree(_pt(tree), 5.4, 1.7)
	_build_lights_and_poles()
	_build_sidewalk_trees()
	_b.flush(self, COLOURS)


func batch_count(kind: String) -> int:
	var node: Node = get_node_or_null("Batch_" + kind)
	if node is MultiMeshInstance3D:
		var inst: MultiMeshInstance3D = node
		return inst.multimesh.instance_count
	return 0


func _build_lights_and_poles() -> void:
	var s: float = 20.0
	var prev_top: Dictionary = {1: Vector3.INF, -1: Vector3.INF}
	while s < data.length - 20.0:
		if absf(s - float(data.underpass.get("s", -1000.0))) > 24.0:
			var frame: Transform3D = data.sample(s)
			var left: Vector3 = data.left_of(frame)
			var base: Vector3 = frame.origin
			_b.add("light_pole", "cyl", Transform3D(Basis.from_scale(Vector3(0.3, 9.0, 0.3)), base + Vector3.UP * 4.5))
			for side: float in [-1.0, 1.0]:
				_b.box("light_pole", MeshBatcher.along(frame.basis, base + left * (side * 1.6) + Vector3.UP * 8.8, Vector3(3.0, 0.14, 0.14), 0.0))
				_b.box("lamp", Transform3D(Basis.from_scale(Vector3(0.7, 0.2, 0.35)), base + left * (side * 3.2) + Vector3.UP * 8.7))
		var s_pole: float = s + POLE_STEP_M * 0.5
		if s_pole < data.length - 20.0:
			for side: int in [-1, 1]:
				var top: Vector3 = _pole(s_pole, side)
				var prev: Vector3 = prev_top[side]
				if prev != Vector3.INF and top.distance_to(prev) < POLE_STEP_M * 1.6:
					_cables(prev, top)
				prev_top[side] = top
		s += POLE_STEP_M


func _pole(s: float, side: int) -> Vector3:
	var p: Vector3 = data.lateral_point(s, float(side) * (data.sidewalk_lateral + 0.7))
	_b.add("pole", "cyl", Transform3D(Basis.from_scale(Vector3(0.32, 8.7, 0.32)), p + Vector3.UP * 4.35))
	var rot: Basis = data.sample(s).basis
	_b.box("pole", MeshBatcher.along(rot, p, Vector3(1.6, 0.12, 0.12), 8.2))
	_occupied.append(Vector2(s, float(side)))
	return p + Vector3.UP * 8.3


func _cables(a: Vector3, b: Vector3) -> void:
	for drop: float in [0.0, -0.5]:
		var mid: Vector3 = (a + b) * 0.5 + Vector3.UP * (drop - 0.8)
		var a2: Vector3 = a + Vector3.UP * drop
		var b2: Vector3 = b + Vector3.UP * drop
		_b.box("cable", MeshBatcher.between(a2, mid, 0.06))
		_b.box("cable", MeshBatcher.between(mid, b2, 0.06))


func _build_sidewalk_trees() -> void:
	var s: float = 26.0
	var k: int = 0
	while s < data.length - 26.0:
		for side: int in [-1, 1]:
			if _free(s, side) and not data.in_gap(side, s) and absf(s - float(data.underpass.get("s", -1000.0))) > 30.0:
				var p: Vector3 = data.lateral_point(s, float(side) * (data.sidewalk_lateral + 0.6))
				_tree(p, 3.6 + 0.4 * float(k % 3), 1.4 + 0.2 * float((k + side) % 3))
		s += TREE_STEP_M
		k += 1


func _free(s: float, side: int) -> bool:
	for o: Vector2 in _occupied:
		if int(o.y) == side and absf(o.x - s) < 6.0:
			return false
	return true


func _occupy(d: Dictionary) -> void:
	_occupied.append(Vector2(float(d.get("s", 0.0)), float(int(d.get("side", 1)))))


func _tree(p: Vector3, trunk_h: float, crown_r: float) -> void:
	_b.add("trunk", "cyl", Transform3D(Basis.from_scale(Vector3(0.4, trunk_h, 0.4)), p + Vector3.UP * (trunk_h * 0.5)))
	var top: Vector3 = p + Vector3.UP * (trunk_h + crown_r * 0.8)
	_b.add("crown", "sph", Transform3D(Basis.from_scale(Vector3.ONE * crown_r * 2.0), top))
	_b.add("crown_b", "sph", Transform3D(Basis.from_scale(Vector3.ONE * crown_r * 1.4), top + Vector3(crown_r * 0.7, crown_r * 0.35, 0.2)))
	_b.add("crown", "sph", Transform3D(Basis.from_scale(Vector3.ONE * crown_r * 1.2), top + Vector3(-crown_r * 0.5, crown_r * 0.5, -crown_r * 0.5)))


func _pt(d: Dictionary) -> Vector3:
	return Vector3(float(d.get("x", 0.0)), 0.0, float(d.get("z", 0.0)))
