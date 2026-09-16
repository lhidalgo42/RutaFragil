class_name SwampRoad
extends Node3D

## La huella del pantano (D71, bioma B2): el barro, el vado del río San Ramón, la
## pasarela de tablas sobre el tramo más hundido, el muelle de la entrega, las lianas
## que cierran el camino y los portones de los fundos.
##
## Reparto con los demás: OsmRoad hace el asfalto de la Ruta T-360 y el puente real,
## OsmGravel hace los tramos de ripio, SwampWater hace el agua y el hualve. Acá va
## solo lo que el pantano le hace al camión.
##
## Regla de colisión heredada del pueblo (D69): en el corredor de circulación no entra
## ninguna cara vertical. El barro y la pasarela son malla; lo único con colisión son
## los tablones de la pasarela, que son planos, y los postes, que van fuera de la pista.

const COLOURS: Dictionary = {
	"mud": Color(0.36, 0.29, 0.22), "mud_wet": Color(0.27, 0.23, 0.19), "rut": Color(0.22, 0.18, 0.15),
	"puddle": Color(0.2, 0.28, 0.27), "verge": Color(0.34, 0.38, 0.24),
	"plank": Color(0.45, 0.36, 0.26), "plank_dark": Color(0.33, 0.27, 0.2), "rail": Color(0.4, 0.33, 0.24),
	"post": Color(0.38, 0.31, 0.23), "stone": Color(0.5, 0.48, 0.45),
	"liana": Color(0.24, 0.36, 0.2), "leaf": Color(0.2, 0.38, 0.22),
	"gate": Color(0.5, 0.42, 0.3), "sign": Color(0.9, 0.86, 0.75),
	"ford_water": Color(0.18, 0.27, 0.28),
	"wire": Color(0.55, 0.53, 0.48),
}
const MUD_GRIP: float = 0.35
const RUT_STEP_M: float = 3.0

@export var data_path: String = "res://data/b2_pantano.json"
@export var seed: int = 1960

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
	var swamp: Dictionary = data.swamp
	_build_mud(swamp.get("mud_zones", []))
	_build_fords(swamp.get("fords", []))
	_build_causeway(swamp.get("causeway", {}))
	_build_pier(swamp.get("pier", {}))
	_build_lianas(swamp.get("lianas", []))
	_build_gates(swamp.get("gates", []))
	_build_fences(swamp.get("fences", []))
	_b.flush(self, COLOURS)


func batch_count(kind: String) -> int:
	var node: Node = get_node_or_null("Batch_" + kind)
	if node is MultiMeshInstance3D:
		var inst: MultiMeshInstance3D = node
		return inst.multimesh.instance_count
	return 0


func zone_shape_count() -> int:
	var node: Node = get_node_or_null("MudZone")
	var n: int = 0
	if node != null:
		for child: Node in node.get_children():
			if child is CollisionShape3D:
				n += 1
	return n


## Barro: huella oscura, dos surcos marcados, charcos y una zona que le avisa al bus.
## El barro no lleva colisión propia: es la misma cota del suelo, mojada.
func _build_mud(zones: Array) -> void:
	var zone: GravelZone = GravelZone.new()
	zone.name = "MudZone"
	zone.grip_multiplier = MUD_GRIP
	zone.surface = "mud"
	add_child(zone)
	for item: Variant in zones:
		if not (item is Dictionary):
			continue
		var z: Dictionary = item
		var s0: float = float(z.get("s0", 0.0))
		var s1: float = float(z.get("s1", 0.0))
		var s: float = s0
		while s < s1:
			var step: float = minf(RUT_STEP_M, s1 - s)
			var frame: Transform3D = data.sample(s + step * 0.5)
			var rot: Basis = frame.basis
			var left: Vector3 = data.left_of(frame)
			var half: float = data.curb_at(s) - 0.6
			_b.box("mud", MeshBatcher.along(rot, frame.origin, Vector3(half * 2.0, 0.03, step + 0.3), 0.015))
			for side: float in [-1.0, 1.0]:
				_b.box("rut", MeshBatcher.along(rot, frame.origin + left * (side * data.lane_at(s) * 0.55), Vector3(0.5, 0.02, step + 0.3), 0.02))
				_b.box("verge", MeshBatcher.along(rot, frame.origin + left * (side * (half + 0.9)), Vector3(1.8, 0.04, step + 0.3), 0.02))
			if _rng.randf() < 0.22:
				var p: Vector3 = frame.origin + left * _rng.randf_range(-1.6, 1.6)
				_b.add("puddle", "cyl", Transform3D(Basis.from_scale(Vector3(_rng.randf_range(1.6, 3.4), 0.04, _rng.randf_range(1.2, 2.2))), p + Vector3.UP * 0.025))
			# la zona de aviso, una caja por tramo de 12 m
			if int(s / 12.0) != int((s - step) / 12.0):
				var shape_node: CollisionShape3D = CollisionShape3D.new()
				var box: BoxShape3D = BoxShape3D.new()
				box.size = Vector3(half * 2.0, 3.0, 12.0)
				shape_node.shape = box
				zone.add_child(shape_node)
				shape_node.global_transform = Transform3D(rot, frame.origin + Vector3.UP * 1.4)
			s += step


## Vado: el camión cruza el agua. Lámina oscura sobre la huella, piedras en las dos
## orillas y una regla de profundidad, que es lo que hay en los vados de verdad.
func _build_fords(fords: Array) -> void:
	for item: Variant in fords:
		if not (item is Dictionary):
			continue
		var f: Dictionary = item
		var s: float = float(f.get("s", 0.0))
		var w: float = float(f.get("w", 8.0))
		var frame: Transform3D = data.sample(s)
		var rot: Basis = frame.basis
		var left: Vector3 = data.left_of(frame)
		var half: float = data.curb_at(s)
		_b.box("ford_water", MeshBatcher.along(rot, frame.origin, Vector3(half * 2.0 + 2.0, 0.05, w), 0.03))
		for side: float in [-1.0, 1.0]:
			for k: int in 7:
				var along: float = (float(k) / 6.0 - 0.5) * (w + 3.0)
				var p: Vector3 = frame.origin - frame.basis.z * along + left * (side * (half + 0.4))
				_b.add("stone", "sph", Transform3D(Basis.from_scale(Vector3(_rng.randf_range(0.5, 1.0), 0.5, _rng.randf_range(0.5, 1.0))), p + Vector3.UP * 0.12))
		var post: Vector3 = frame.origin - frame.basis.z * (w * 0.5 + 1.5) + left * (half + 1.2)
		_b.box("post", Transform3D(Basis.from_scale(Vector3(0.14, 2.2, 0.14)), post + Vector3.UP * 1.1))
		for k: int in 4:
			_b.box("sign", Transform3D(Basis.from_scale(Vector3(0.22, 0.12, 0.16)), post + Vector3.UP * (0.5 + 0.4 * float(k))))


## Pasarela de tablas sobre el tramo más hundido: tablones cruzados, dos vigas y
## barandas bajas. Los tablones SÍ llevan colisión, planos y sin canto de ataque.
func _build_causeway(causeway: Dictionary) -> void:
	if causeway.is_empty():
		return
	var body: StaticBody3D = StaticBody3D.new()
	body.name = "Causeway"
	add_child(body)
	var s0: float = float(causeway.get("s0", 0.0))
	var s1: float = float(causeway.get("s1", 0.0))
	var s: float = s0
	while s < s1:
		var frame: Transform3D = data.sample(s)
		var rot: Basis = frame.basis
		var left: Vector3 = data.left_of(frame)
		var width: float = data.curb_at(s) * 2.0 - 1.0
		_b.box("plank" if int(s) % 2 == 0 else "plank_dark", MeshBatcher.along(rot, frame.origin, Vector3(width, 0.1, 0.55), 0.1))
		if int(s - s0) % 3 == 0:
			for side: float in [-1.0, 1.0]:
				_b.box("rail", MeshBatcher.along(rot, frame.origin + left * (side * width * 0.5), Vector3(0.12, 0.5, 3.0), 0.45))
		s += 0.6
	# una sola caja de colisión por la pasarela completa: ni una junta en el corredor
	var mid: float = (s0 + s1) * 0.5
	var frame_mid: Transform3D = data.sample(mid)
	var shape_node: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(data.curb_at(mid) * 2.0, 0.3, s1 - s0)
	shape_node.shape = box
	body.add_child(shape_node)
	shape_node.global_transform = Transform3D(frame_mid.basis, frame_mid.origin + Vector3.UP * 0.0)


## El muelle de la entrega: tablones sobre pilotes, metido en el juncal.
func _build_pier(pier: Dictionary) -> void:
	if pier.is_empty():
		return
	var base: Vector3 = Vector3(float(pier.get("x", 0.0)), 0.0, float(pier.get("z", 0.0)))
	var yaw: float = float(pier.get("yaw", 0.0))
	var length_m: float = float(pier.get("length", 26.0))
	var rot: Basis = Basis(Vector3.UP, yaw)
	var fwd: Vector3 = -rot.z
	_b.box("plank", Transform3D(rot * Basis.from_scale(Vector3(2.4, 0.12, length_m)), base + fwd * (length_m * 0.5) + Vector3.UP * 0.34))
	var n: int = int(length_m / 3.0)
	for k: int in n + 1:
		var p: Vector3 = base + fwd * (float(k) * 3.0)
		for side: float in [-1.0, 1.0]:
			_b.box("post", Transform3D(Basis.from_scale(Vector3(0.18, 1.2, 0.18)), p + rot.x * (side * 1.1) + Vector3.DOWN * 0.2))
			if k % 2 == 0:
				_b.box("rail", Transform3D(rot * Basis.from_scale(Vector3(0.1, 0.45, 3.0)), p + rot.x * (side * 1.1) + Vector3.UP * 0.62))


## Lianas: el hualve se cierra sobre la huella. Una rama cruzada y sus colgantes,
## todo malla: cortarlas es lógica de juego, no geometría.
func _build_lianas(lianas: Array) -> void:
	for item: Variant in lianas:
		if not (item is Dictionary):
			continue
		var s: float = float((item as Dictionary).get("s", 0.0))
		var frame: Transform3D = data.sample(s)
		var rot: Basis = frame.basis
		var left: Vector3 = data.left_of(frame)
		var width: float = data.curb_at(s) * 2.0
		_b.box("liana", MeshBatcher.along(rot.rotated(Vector3.UP, PI * 0.5), frame.origin, Vector3(0.22, 0.22, width), 3.6))
		for k: int in 9:
			var lat: float = (float(k) / 8.0 - 0.5) * width
			var length_m: float = _rng.randf_range(1.2, 2.9)
			var p: Vector3 = frame.origin + left * lat
			_b.box("liana", Transform3D(Basis.from_scale(Vector3(0.06, length_m, 0.06)), p + Vector3.UP * (3.6 - length_m * 0.5)))
			# la hoja del extremo iba en 50 cm y la liana quedaba como un chupete
			_b.add("leaf", "sph", Transform3D(Basis.from_scale(Vector3(0.22, 0.3, 0.22)), p + Vector3.UP * (3.6 - length_m)))


func _build_gates(gates: Array) -> void:
	for item: Variant in gates:
		if not (item is Dictionary):
			continue
		var gate: Dictionary = item
		var p: Vector3 = Vector3(float(gate.get("x", 0.0)), 0.0, float(gate.get("z", 0.0)))
		var rot: Basis = Basis(Vector3.UP, float(gate.get("yaw", 0.0)))
		for side: float in [-1.0, 1.0]:
			_b.box("post", Transform3D(Basis.from_scale(Vector3(0.2, 1.8, 0.2)), p + rot.x * (side * 2.2) + Vector3.UP * 0.9))
		for h: float in [0.6, 1.0, 1.4]:
			_b.box("gate", Transform3D(rot * Basis.from_scale(Vector3(4.4, 0.1, 0.08)), p + Vector3.UP * h))


## Cerco de alambre del potrero: poste cada 5 m y tres hebras. Es lo que le da
## escala al camino en los 4 km que NO van por el humedal. Sin colisión: el
## camión lo atropella, como en el campo.
func _build_fences(fences: Array) -> void:
	for item: Variant in fences:
		if not (item is Dictionary):
			continue
		var pts: Array = item.get("pts", [])
		for i: int in range(pts.size() - 1):
			var a: Array = pts[i]
			var b: Array = pts[i + 1]
			if a.size() < 2 or b.size() < 2:
				continue
			var p0: Vector3 = Vector3(float(a[0]), 0.0, float(a[1]))
			var p1: Vector3 = Vector3(float(b[0]), 0.0, float(b[1]))
			var d: Vector3 = p1 - p0
			var length_m: float = d.length()
			if length_m < 0.5:
				continue
			var yaw: float = atan2(d.x, d.z)
			var basis: Basis = Basis(Vector3.UP, yaw)
			for h: float in [0.45, 0.85, 1.2]:
				_b.box("wire", Transform3D(basis * Basis.from_scale(Vector3(0.03, 0.03, length_m)), p0 + d * 0.5 + Vector3.UP * h))
			_b.box("post", Transform3D(Basis(Vector3.UP, yaw) * Basis.from_scale(Vector3(0.12, 1.35, 0.12)), p0 + Vector3.UP * 0.675))
			if length_m > 7.0:
				_b.box("post", Transform3D(Basis(Vector3.UP, yaw) * Basis.from_scale(Vector3(0.12, 1.35, 0.12)), p0 + d * 0.5 + Vector3.UP * 0.675))
