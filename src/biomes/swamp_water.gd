class_name SwampWater
extends Node3D

## El agua y la vegetación del pantano (D71, bioma B2). Del humedal del río Cruces:
## los paños de agua, el río San Ramón, los juncales, los troncos muertos que dejó
## el terremoto de 1960 al hundir estas riberas, y el hualve, el bosque pantanoso de
## temu y pitra de 7 a 15 m que crece con los pies en el agua.
##
## La decisión que evita cortes (medida en el pueblo, D69): el suelo NO se agujerea.
## Toda el agua es UNA malla triangulada de los polígonos reales, a un solo nivel de
## Y, dibujada encima del suelo plano. Dos paños que se pisan no se notan, no hay
## juntas donde el bus tropiece, y la profundidad es visual, no geométrica.

const COLOURS: Dictionary = {
	"reed": Color(0.36, 0.45, 0.25), "reed_dry": Color(0.55, 0.52, 0.32),
	"snag": Color(0.38, 0.33, 0.28), "snag_pale": Color(0.46, 0.42, 0.36),
	"trunk": Color(0.33, 0.26, 0.2), "crown": Color(0.16, 0.34, 0.22), "crown_b": Color(0.22, 0.42, 0.26),
	"scrub": Color(0.3, 0.42, 0.24),
	"trunk_dry": Color(0.38, 0.31, 0.24), "crown_dry": Color(0.27, 0.4, 0.24), "scrub_dry": Color(0.38, 0.44, 0.27),
}
const WATER_COLOUR: Color = Color(0.2, 0.31, 0.29, 0.78)
const CHANNEL_COLOUR: Color = Color(0.13, 0.22, 0.24, 0.85)

@export var data_path: String = "res://data/b2_pantano.json"
@export var reeds_visible: int = 16000

var data: OsmMapData
var _b: MeshBatcher = MeshBatcher.new()
var _water_y: float = 0.04


func _ready() -> void:
	data = OsmMapData.load_from(data_path)
	if data != null:
		build()


func build() -> void:
	for child: Node in get_children():
		remove_child(child)
		child.free()
	var swamp: Dictionary = data.swamp
	_water_y = float(swamp.get("water_y", 0.04))
	_build_water(swamp.get("bodies", []))
	_build_reeds(swamp.get("marsh", []))
	_build_snags(swamp.get("snags", []))
	_build_hualve(swamp.get("hualve", []))
	_build_pasture(swamp.get("pasture", []))
	_b.flush(self, COLOURS)


func batch_count(kind: String) -> int:
	var node: Node = get_node_or_null("Batch_" + kind)
	if node is MultiMeshInstance3D:
		var inst: MultiMeshInstance3D = node
		return inst.multimesh.instance_count
	return 0


func water_surface_count() -> int:
	var node: Node = get_node_or_null("Water")
	return node.get_child_count() if node != null else 0


## Una malla por paño, triangulada del polígono real. Todas a la misma Y: por eso
## dos paños que se solapan no dejan costura visible.
func _build_water(bodies: Array) -> void:
	var root: Node3D = Node3D.new()
	root.name = "Water"
	add_child(root)
	# Los paños que se pisan se FUNDEN antes de triangular: dos superficies
	# translúcidas encima de la otra oscurecían la juntura y dibujaban una línea
	# recta en medio del pantano (visto el 16 sep 2026 en la foto del vado).
	# marsh y flood son la MISMA agua: van en un solo grupo, si no el solape entre
	# grupos oscurece la juntura igual. El cauce va aparte, es más oscuro.
	for kind: String in ["marsh", "channel"]:
		var group: Array = []
		for item: Variant in bodies:
			if not (item is Dictionary):
				continue
			var body: Dictionary = item
			var es_cauce: bool = str(body.get("kind", "marsh")) == "channel"
			if es_cauce != (kind == "channel"):
				continue
			var flat: PackedVector2Array = PackedVector2Array()
			for p: Variant in _array(body.get("polygon")):
				var pair: Array = p
				if pair.size() >= 2:
					flat.append(Vector2(float(pair[0]), float(pair[1])))
			if flat.size() >= 3:
				group.append(flat)
		for flat: PackedVector2Array in _union(group):
			_add_water_mesh(root, flat, kind)


## Funde los polígonos que se solapan. Solo prueba pares cuyas cajas se pisan, y
## al fundir reinicia el barrido: el resultado puede alcanzar a un tercero.
func _union(polys: Array) -> Array:
	var acc: Array = []
	for poly: PackedVector2Array in polys:
		var cur: PackedVector2Array = poly
		var i: int = acc.size() - 1
		while i >= 0:
			var other: PackedVector2Array = acc[i]
			if not _aabb(cur).intersects(_aabb(other)):
				i -= 1
				continue
			var res: Array = Geometry2D.merge_polygons(cur, other)
			if res.size() == 1:
				cur = res[0]
				acc.remove_at(i)
				i = acc.size() - 1
				continue
			i -= 1
		acc.append(cur)
	return acc


static func _aabb(poly: PackedVector2Array) -> Rect2:
	var r: Rect2 = Rect2(poly[0], Vector2.ZERO)
	for v: Vector2 in poly:
		r = r.expand(v)
	return r


func _add_water_mesh(root: Node3D, flat: PackedVector2Array, kind: String) -> void:
	if Geometry2D.is_polygon_clockwise(flat):
		return
	var indices: PackedInt32Array = Geometry2D.triangulate_polygon(flat)
	if indices.is_empty():
		return
	var surface: SurfaceTool = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_normal(Vector3.UP)
	for i: int in indices.size():
		var v: Vector2 = flat[indices[i]]
		surface.set_uv(Vector2(v.x * 0.05, v.y * 0.05))
		surface.add_vertex(Vector3(v.x, 0.0, v.y))
	var mesh: ArrayMesh = surface.commit()
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = CHANNEL_COLOUR if kind == "channel" else WATER_COLOUR
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.metallic = 0.08
	material.roughness = 0.3
	mesh.surface_set_material(0, material)
	var inst: MeshInstance3D = MeshInstance3D.new()
	inst.mesh = mesh
	inst.position = Vector3(0.0, _water_y, 0.0)
	root.add_child(inst)


## Juncales: dos hojas cruzadas por mata, de altura despareja, un poco más secas
## cuanto más lejos del agua profunda. Sin colisión: se pisan.
func _build_reeds(marsh: Array) -> void:
	var step: int = maxi(1, int(ceil(float(marsh.size()) / float(maxi(1, reeds_visible)))))
	var i: int = 0
	for item: Variant in marsh:
		i += 1
		if i % step != 0:
			continue
		var pair: Array = item
		if pair.size() < 2:
			continue
		var p: Vector3 = Vector3(float(pair[0]), _water_y, float(pair[1]))
		var h: float = 0.8 + fmod(float(i) * 0.3739, 1.0) * 0.9
		var yaw: float = fmod(float(i) * 1.113, PI)
		var kind: String = "reed" if i % 5 != 0 else "reed_dry"
		# cinco cañas finas por mata: con tres se veían palitos sueltos, con hojas de
		# 50 cm se veían naipes clavados. Cinco a 2,2 m de paso ya leen como juncal.
		for k: int in 5:
			var ang: float = yaw + float(k) * 1.27
			var lean: float = 0.1 + 0.05 * float(k % 3)
			var basis: Basis = Basis(Vector3.UP, ang) * Basis(Vector3.BACK, lean) * Basis.from_scale(Vector3(0.055, h, 0.055))
			_b.box(kind, Transform3D(basis, p + Vector3.UP * (h * 0.5) + Vector3(cos(ang) * 0.2, 0.0, sin(ang) * 0.2)))


## Troncos muertos del 60: el agua subió y el bosque quedó en pie, sin hojas.
func _build_snags(snags: Array) -> void:
	for item: Variant in snags:
		var arr: Array = item
		if arr.size() < 3:
			continue
		var p: Vector3 = Vector3(float(arr[0]), _water_y, float(arr[1]))
		var h: float = float(arr[2])
		var lean: float = float(arr[3]) if arr.size() > 3 else 0.0
		var basis: Basis = Basis(Vector3.BACK, lean) * Basis.from_scale(Vector3(0.28, h, 0.28))
		_b.add("snag" if h > 4.0 else "snag_pale", "cyl", Transform3D(basis, p + Vector3.UP * (h * 0.45)))
		if h > 5.0:
			# una rama mocha, lo único que les queda
			_b.add("snag", "cyl", Transform3D(Basis(Vector3.BACK, 1.1) * Basis.from_scale(Vector3(0.14, 1.8, 0.14)), p + Vector3.UP * (h * 0.8) + Vector3(0.5, 0.0, 0.2)))


## Hualve: temu, pitra y chequén. Siempreverdes, copa cerrada y oscura, 7 a 15 m.
## Lo bajo (menos de 4 m) es el matorral del borde.
func _build_hualve(trees: Array) -> void:
	for item: Variant in trees:
		_tree(item, "trunk", "crown", "scrub")


## Los árboles del potrero seco: misma geometría, paleta más clara y polvorienta.
func _build_pasture(trees: Array) -> void:
	for item: Variant in trees:
		_tree(item, "trunk_dry", "crown_dry", "scrub_dry")


func _tree(item: Variant, trunk: String, crown: String, scrub: String) -> void:
		var arr: Array = item
		if arr.size() < 3:
			return
		var p: Vector3 = Vector3(float(arr[0]), 0.0, float(arr[1]))
		var h: float = float(arr[2])
		if h < 4.0:
			_b.add(scrub, "sph", Transform3D(Basis.from_scale(Vector3(h * 1.4, h, h * 1.4)), p + Vector3.UP * (h * 0.45)))
			return
		_b.add(trunk, "cyl", Transform3D(Basis.from_scale(Vector3(0.45, h * 0.62, 0.45)), p + Vector3.UP * (h * 0.31)))
		var top: Vector3 = p + Vector3.UP * (h * 0.72)
		var r: float = h * 0.3
		_b.add(crown, "sph", Transform3D(Basis.from_scale(Vector3(r * 2.0, r * 2.2, r * 2.0)), top))
		_b.add("crown_b" if crown == "crown" else crown, "sph", Transform3D(Basis.from_scale(Vector3(r * 1.4, r * 1.5, r * 1.4)), top + Vector3(r * 0.6, r * 0.5, -r * 0.3)))


static func _array(v: Variant) -> Array:
	return v if v is Array else []
