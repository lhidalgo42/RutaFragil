class_name OsmFurniture
extends Node3D

## Street furniture for the real avenue (D65, D67), all mesh only: real bus
## stops, traffic signals and trees from OSM, median trees and double-arm
## street lights, concrete power poles with sagging cables on both sidewalks,
## and sidewalk trees every 12 m where nothing else stands.

const COLOURS: Dictionary = {
	"stop": Color(0.29, 0.33, 0.35), "stop_roof": Color(0.93, 0.93, 0.9),
	"shelter_frame": Color(0.17, 0.19, 0.2), "shelter_glass": Color(0.6, 0.71, 0.73),
	"shelter_bench": Color(0.44, 0.32, 0.19), "shelter_sign": Color(0.93, 0.56, 0.12), "signal": Color(0.15, 0.15, 0.15), "post": Color(0.6, 0.6, 0.62),
	"trunk": Color(0.4, 0.28, 0.18), "crown": Color(0.25, 0.5, 0.25), "crown_b": Color(0.32, 0.56, 0.24),
	"pole": Color(0.62, 0.6, 0.56), "cable": Color(0.12, 0.12, 0.12), "lamp": Color(0.98, 0.95, 0.8), "light_pole": Color(0.35, 0.36, 0.38),
	"fence_post": Color(0.4, 0.3, 0.2), "wire": Color(0.35, 0.35, 0.36), "poplar_trunk": Color(0.55, 0.5, 0.42), "poplar": Color(0.36, 0.55, 0.22), "orchard": Color(0.3, 0.5, 0.2),
}
const POLE_STEP_M: float = 35.0
const TREE_STEP_M: float = 12.0

@export var data_path: String = "res://data/b0_departamental.json"

var data: OsmMapData
var _b: MeshBatcher = MeshBatcher.new()
var _occupied: Array[Vector2] = []
## La misma máscara que consulta el pasto: nada de árboles ni postes sobre el asfalto.
var _mask: RoadMask


func _ready() -> void:
	data = OsmMapData.load_from(data_path)
	if data != null:
		build()


func build() -> void:
	for child: Node in get_children():
		remove_child(child)
		child.free()
	_occupied.clear()
	_mask = RoadMask.shared(data, data_path)
	for stop: Dictionary in data.bus_stops:
		var p: Vector3 = _pt(stop)
		var rot: Basis = data.sample(float(stop.get("s", 0.0))).basis
		_shelter(p, rot, float(stop.get("side", 1.0)))
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
	_build_rural()
	_b.flush(self, COLOURS)
	MeshBatcher.update_canopy()


func batch_count(kind: String) -> int:
	var node: Node = get_node_or_null("Batch_" + kind)
	if node is MultiMeshInstance3D:
		var inst: MultiMeshInstance3D = node
		return inst.multimesh.instance_count
	return 0


## Refugio de paradero, el "Trepaluz" (D72). Antes era una caja roja con una tapa
## blanca encima. Ahora: muro corrido al fondo, UN pilar grueso en la punta contraria,
## un tabique en un solo costado y el techo en voladizo, caído 9° hacia el fondo y
## volando casi un metro sobre la vereda. La asimetría es a propósito: un refugio
## simétrico vuelve a leerse como una caja.
func _shelter(p: Vector3, rot: Basis, side: float) -> void:
	var out: float = signf(side) if absf(side) > 0.01 else 1.0
	var along: Vector3 = -rot.z
	var across: Vector3 = rot.x * out
	var back: Vector3 = p + across * 1.05
	_b.box("stop", MeshBatcher.along(rot, back, Vector3(0.14, 2.3, 4.2), 1.15))
	_b.box("shelter_glass", MeshBatcher.along(rot, p + along * 1.95 + across * 0.4, Vector3(1.4, 1.9, 0.1), 0.95))
	_b.add("shelter_frame", "cyl", Transform3D(Basis.from_scale(Vector3(0.26, 2.55, 0.26)), p - along * 1.85 - across * 0.8 + Vector3.UP * 1.28))
	var roof_rot: Basis = rot * Basis(Vector3.BACK, deg_to_rad(9.0) * out)
	_b.box("stop_roof", Transform3D(roof_rot * Basis.from_scale(Vector3(3.1, 0.13, 5.0)), p + across * 0.1 + Vector3.UP * 2.62))
	# canto grueso del alero: un techo de 13 cm visto de canto es una lámina
	_b.box("stop_roof", Transform3D(roof_rot * Basis.from_scale(Vector3(0.16, 0.34, 5.0)), p - across * 1.38 + Vector3.UP * 2.48))
	_b.box("shelter_bench", MeshBatcher.along(rot, p + across * 0.72, Vector3(0.52, 0.09, 3.1), 0.47))
	for k: float in [-1.0, 1.0]:
		_b.box("shelter_frame", MeshBatcher.along(rot, p + across * 0.72 + along * (k * 1.25), Vector3(0.09, 0.45, 0.09), 0.22))
	_b.add("shelter_frame", "cyl", Transform3D(Basis.from_scale(Vector3(0.1, 2.9, 0.1)), p - along * 2.7 - across * 1.15 + Vector3.UP * 1.45))
	_b.box("shelter_sign", MeshBatcher.along(rot, p - along * 2.7 - across * 1.15, Vector3(0.06, 0.5, 0.88), 2.45))


func _build_lights_and_poles() -> void:
	var s: float = 20.0
	var prev_top: Dictionary = {1: Vector3.INF, -1: Vector3.INF}
	while s < data.length - 20.0:
		if absf(s - float(data.underpass.get("s", -1000.0))) > 24.0 and data.section_at(s) == "avenue":
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
	var lateral: float = float(side) * (data.property_at(s) - 0.4)
	var p: Vector3 = data.lateral_point(s, lateral)
	var rot: Basis = data.sample(s).basis
	# one pole in ten leans a few degrees (D68: worn city)
	var lean: float = 0.0
	if int(s * 0.37) % 10 == 3:
		lean = deg_to_rad(5.0) * (1.0 if int(s) % 2 == 0 else -1.0)
	var pole_basis: Basis = rot * Basis(Vector3.BACK, lean)
	var top: Vector3 = p + pole_basis.y * 8.3
	_b.add("pole", "cyl", Transform3D(pole_basis * Basis.from_scale(Vector3(0.32, 8.7, 0.32)), p + pole_basis.y * 4.35))
	_b.box("pole", Transform3D(pole_basis * Basis.from_scale(Vector3(1.6, 0.12, 0.12)), p + pole_basis.y * 8.2))
	_occupied.append(Vector2(s, float(side)))
	return top


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
			if _free(s, side) and not data.in_gap(side, s) and absf(s - float(data.underpass.get("s", -1000.0))) > 30.0 and data.section_at(s) != "gravel":
				var p: Vector3 = data.lateral_point(s, float(side) * (data.property_at(s) - 0.6))
				if not _on_road(p, 0.0):
					_tree(p, 3.6 + 0.4 * float(k % 3), 1.4 + 0.2 * float((k + side) % 3))
		s += TREE_STEP_M
		k += 1


## Rural dressing of the unpaved stretches (D68): wire fences at the property line, a row of
## poplars on one side, and the fruit orchards behind, all from the data.
func _build_rural() -> void:
	for fence: Dictionary in data.fences:
		var s0: float = float(fence.get("s0", 0.0))
		var s1: float = float(fence.get("s1", 0.0))
		var side: float = float(int(fence.get("side", 1)))
		var lateral: float = side * data.property_at((s0 + s1) * 0.5)
		var prev: Vector3 = Vector3.INF
		var s: float = s0
		while s <= s1:
			var p: Vector3 = data.lateral_point(s, lateral)
			_b.box("fence_post", Transform3D(Basis.from_scale(Vector3(0.12, 1.5, 0.12)), p + Vector3.UP * 0.75))
			if prev != Vector3.INF:
				for h: float in [0.5, 0.9, 1.3]:
					_b.box("wire", MeshBatcher.between(prev + Vector3.UP * h, p + Vector3.UP * h, 0.02))
			prev = p
			s += 3.0
	for pop: Dictionary in data.poplars:
		var p: Vector3 = _pt(pop)
		if _on_road(p, 1.0):
			continue
		# álamo: columna de mechones de hojas de 10 m sobre un tronco con corteza (D76)
		_b.tree(p, 4.0, 1.5, 6, 1, "poplar_trunk", "poplar", 0.35, 10.0)
	for o: Vector3 in data.orchards:
		if _on_road(o, 1.0):
			continue
		# frutal bajo y redondo, sin helechos al pie: es un huerto trabajado
		_b.tree(o, 1.4, 1.5, 4, 0, "trunk", "orchard", 0.22)


## Un árbol en medio de una calle lateral es de las cosas que más saltan a la vista.
## Se mira la CALZADA, no la vereda: el árbol de vereda va justo sobre el pavimento.
func _on_road(p: Vector3, margin_m: float) -> bool:
	return _mask != null and _mask.is_roadway(p, margin_m)


func _free(s: float, side: int) -> bool:
	for o: Vector2 in _occupied:
		if int(o.y) == side and absf(o.x - s) < 6.0:
			return false
	return true


func _occupy(d: Dictionary) -> void:
	_occupied.append(Vector2(float(d.get("s", 0.0)), float(int(d.get("side", 1)))))


## Árbol de vereda o de OSM: tronco con corteza y copa de mechones de hojas (D76). Antes
## eran tres esferas verdes sobre un cilindro café — «Mickey», dijo el dueño.
func _tree(p: Vector3, trunk_h: float, crown_r: float) -> void:
	_b.tree(p, trunk_h, crown_r)


func _pt(d: Dictionary) -> Vector3:
	return Vector3(float(d.get("x", 0.0)), 0.0, float(d.get("z", 0.0)))
