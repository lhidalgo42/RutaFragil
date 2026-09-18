class_name MeshBatcher
extends RefCounted

## Collects transforms per kind and emits one MultiMeshInstance3D per kind
## ("Batch_<kind>") under a parent. Shared by OsmRoad, OsmFurniture and
## CityBackdrop so the greybox draws thousands de cajas en unas pocas llamadas.
##
## D72: el material ya no es un color plano. Todo sale de `surface_material()`, con
## una textura de ruido en triplanar (nadie tiene que hacer UVs) y un tono distinto
## por instancia. Mil cajas del mismo color se leían como mil cajas iguales: eso era
## la mitad de lo "cuadrado" del mapa, y se arregla una vez para todos.

## Superficies grandes: el ruido se estira mucho más, si no se ve el mosaico.
const BIG_SURFACES: Array[String] = [
	"ground", "dirt", "asphalt", "asphalt_side", "street", "street_dirt", "paving",
	"sidewalk", "median", "concrete", "ballast", "platform", "dust", "water", "plaza_lawn",
]
## Lo poco que brilla: vidrio, pintura de auto, agua.
const GLOSSY: Array[String] = ["car_a", "car_b", "car_c", "glass", "water", "fountain_water"]

## El suelo lleva texturas de verdad (D73, D74): pasto, piedra y nieve de ambientCG, y el
## escaneo de terreno Terrain001 estirado a gran escala decidiendo dónde va cada una.
const GROUND_SHADER: Shader = preload("res://assets/shaders/ground.gdshader")
const GROUND_TEXTURES: Dictionary = {
	"base_albedo": "res://assets/textures/ground/grass_color.jpg",
	"base_normal": "res://assets/textures/ground/grass_normal.jpg",
	"base_rough": "res://assets/textures/ground/grass_rough.jpg",
	"rock_albedo": "res://assets/textures/ground/rock_color.jpg",
	"rock_normal": "res://assets/textures/ground/rock_normal.jpg",
	"rock_rough": "res://assets/textures/ground/rock_rough.jpg",
	"over_albedo": "res://assets/textures/ground/snow_color.jpg",
	"over_normal": "res://assets/textures/ground/snow_normal.jpg",
	"over_rough": "res://assets/textures/ground/snow_rough.jpg",
	"terrain_color": "res://assets/textures/ground/terrain_color.jpg",
	"terrain_soil": "res://assets/textures/ground/terrain_soil.jpg",
	"terrain_protrusion": "res://assets/textures/ground/terrain_protrusion.jpg",
	"forest_albedo": "res://assets/textures/ground/forest_color.jpg",
	"forest_normal": "res://assets/textures/ground/forest_normal.jpg",
	"forest_rough": "res://assets/textures/ground/forest_rough.jpg",
}
## Los colores que pasan a llevar textura: el color plano del diccionario deja de mandar.
const TEXTURED: Array[String] = ["ground"]

## Cintas con textura (D74): la calzada con Road008B —que trae sus marcas pintadas— y el
## ripio con las piedras de río de Rocks005. Solo para RoadRibbon: una caja del batcher
## tiene UV de caja, no metros, y la textura se estiraría sobre ella.
const RIBBON_SHADER: Shader = preload("res://assets/shaders/ribbon.gdshader")
const ROAD_TEXTURES: Array[String] = [
	"res://assets/textures/road/road_color.jpg", "res://assets/textures/road/road_normal.jpg", "res://assets/textures/road/road_rough.jpg",
]
const ROCK_TEXTURES: Array[String] = [
	"res://assets/textures/ground/rock_color.jpg", "res://assets/textures/ground/rock_normal.jpg", "res://assets/textures/ground/rock_rough.jpg",
]
## kind -> [texturas, metros por baldosa, franja a lo ancho (escala, corrimiento)].
## "asphalt_plain" es la avenida: dos calzadas de un sentido, sin la línea central de la
## textura — se muestrea solo el asfalto liso entre la línea central y la de borde.
## El quinto valor es el tinte. El ripio usa las piedras de río de Rocks005 pero a 0,9 m
## por baldosa y teñidas de tierra: a 2,5 m y sin teñir salían moradas y del tamaño de un
## plato (D77). Piedra chica y café es ripio; piedra grande y lila es un lecho de río.
const RIBBON_MATERIALS: Dictionary = {
	"asphalt": [ROAD_TEXTURES, 9.0, 1.0, 0.0, Color(1.0, 1.0, 1.0)],
	"asphalt_plain": [ROAD_TEXTURES, 9.0, 0.3, 0.12, Color(1.0, 1.0, 1.0)],
	"street": [ROAD_TEXTURES, 7.0, 1.0, 0.0, Color(1.0, 1.0, 1.0)],
	"dirt": [ROCK_TEXTURES, 0.9, 1.0, 0.0, Color(0.82, 0.66, 0.5)],
	"street_dirt": [ROCK_TEXTURES, 0.9, 1.0, 0.0, Color(0.82, 0.66, 0.5)],
}

## Vegetación con textura (D76): corteza real en los troncos y mechones de hojas
## recortadas en las copas, en vez de cilindros cafés con esferas verdes encima.
## kind -> [color, normal, roughness, escala UV]. Los troncos son cilindros escalados a
## su altura, así que la escala UV en Y es cuántas baldosas de corteza caben a lo alto.
const BARK_MATERIALS: Dictionary = {
	"trunk": ["res://assets/textures/tree/bark_color.jpg", "res://assets/textures/tree/bark_normal.jpg", "res://assets/textures/tree/bark_rough.jpg", Vector3(2.0, 3.0, 1.0)],
	"poplar_trunk": ["res://assets/textures/tree/bark_color.jpg", "res://assets/textures/tree/bark_normal.jpg", "res://assets/textures/tree/bark_rough.jpg", Vector3(2.0, 6.0, 1.0)],
}
## kind -> [atlas con alfa, repeticiones por tarjeta, tinte]. El recorte es `alpha_scissor`:
## sin mezcla de transparencia, así que las tarjetas se ordenan solas en profundidad.
## La MATA, no el atlas (D77): el atlas son cuatro hojas sueltas sobre transparente y
## repetido en la tarjeta se veía a través —«hojas separadas en un palo»—; la mata es el
## mismo atlas estampado 110 veces encimado (`shrink_texture.gd ++ stamp=`), una masa de
## follaje con borde roto. Una tarjeta = una mata, sin repetir (escala UV 1).
const LEAF_ATLAS: String = "res://assets/textures/tree/leaf_atlas.png"
const LEAF_CLUMP: String = "res://assets/textures/tree/leaf_clump.png"
const CUTOUT_MATERIALS: Dictionary = {
	"crown": [LEAF_CLUMP, 1.0, Color(0.62, 0.74, 0.46)],
	"crown_b": [LEAF_CLUMP, 1.0, Color(0.55, 0.7, 0.4)],
	"poplar": [LEAF_CLUMP, 1.0, Color(0.66, 0.78, 0.42)],
	"orchard": [LEAF_CLUMP, 1.0, Color(0.56, 0.72, 0.42)],
	"fern": ["res://assets/textures/tree/fern_card.png", 1.0, Color(0.85, 0.95, 0.8)],
	"vine": [LEAF_CLUMP, 1.0, Color(0.36, 0.56, 0.28)],
}

## Colores que `tree()` emite por su cuenta, para que ningún constructor tenga que saber de
## ellos (D80). El diccionario del constructor manda si los trae.
const DEFAULT_COLOURS: Dictionary = {
	"crown_core": Color(0.17, 0.33, 0.13), "poplar_core": Color(0.2, 0.38, 0.14), "orchard_core": Color(0.19, 0.36, 0.15),
}

static var _grain: NoiseTexture2D
static var _blend: NoiseTexture2D
static var _ground: ShaderMaterial
static var _ribbons: Dictionary = {}
static var _pbr: Dictionary = {}
static var _cutouts: Dictionary = {}
static var _waters: Dictionary = {}
## Agua en movimiento (D76): kind -> flow (0 superficie quieta, 1 chorro que cae).
const WATER_SHADER: Shader = preload("res://assets/shaders/water.gdshader")
const WATER_MATERIALS: Dictionary = {"fountain_water": 0.0, "fountain_stream": 1.0, "water": 0.0}
## Máscara de copas: dónde hay sombra de árbol, para que el suelo ponga hojas y musgo.
static var _canopy_points: PackedVector3Array = PackedVector3Array()
static var _canopy_radii: PackedFloat32Array = PackedFloat32Array()
static var _canopy_texture: ImageTexture

var _batches: Dictionary = {}
var _flushed: Dictionary = {}


func add(kind: String, mesh_kind: String, xform: Transform3D) -> void:
	if not _batches.has(kind):
		_batches[kind] = {"mesh": mesh_kind, "xforms": [], "colours": []}
	var entry: Dictionary = _batches[kind]
	var xforms: Array = entry["xforms"]
	xforms.append(xform)
	var colours: Array = entry["colours"]
	colours.append(Color.TRANSPARENT)   # transparente = «usa el tono por posición»


## Como `add`, con un tono propio para esa instancia (D78): las matas de una copa se
## sombrean según dónde están en ella, y eso no lo puede saber el tono por posición.
func add_coloured(kind: String, mesh_kind: String, xform: Transform3D, colour: Color) -> void:
	add(kind, mesh_kind, xform)
	var entry: Dictionary = _batches[kind]
	var colours: Array = entry["colours"]
	colours[colours.size() - 1] = colour


func box(kind: String, xform: Transform3D) -> void:
	add(kind, "box", xform)


func count(kind: String) -> int:
	if not _batches.has(kind):
		return 0
	var entry: Dictionary = _batches[kind]
	var xforms: Array = entry["xforms"]
	return xforms.size()


## Origins of the instances emitted at the last flush for `kind`. Tests read
## this: MultiMesh.get_instance_transform() returns identity under the headless
## (dummy) renderer, so buffers cannot be read back there.
func positions(kind: String) -> PackedVector3Array:
	if _flushed.has(kind):
		return _flushed[kind]
	return PackedVector3Array()


func flush(parent: Node, colours: Dictionary) -> void:
	for kind: String in _batches.keys():
		var entry: Dictionary = _batches[kind]
		var xforms: Array = entry["xforms"]
		var mm: MultiMesh = MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = unit_mesh(str(entry["mesh"]), colours.get(kind, DEFAULT_COLOURS.get(kind, Color.MAGENTA)), kind)
		mm.instance_count = xforms.size()
		var own_colours: Array = entry.get("colours", [])
		for i: int in xforms.size():
			var xf: Transform3D = xforms[i]
			mm.set_instance_transform(i, xf)
			var own: Color = own_colours[i] if i < own_colours.size() else Color.TRANSPARENT
			mm.set_instance_color(i, own if own.a > 0.0 else tint_at(xf.origin))
		var origins: PackedVector3Array = PackedVector3Array()
		for xf: Transform3D in xforms:
			origins.append(xf.origin)
		_flushed[kind] = origins
		var inst: MultiMeshInstance3D = MultiMeshInstance3D.new()
		inst.name = "Batch_" + kind
		inst.multimesh = mm
		parent.add_child(inst)
	_batches.clear()


## Box of `size` (x across, y up, z along) laid along basis `rot` at `pos`, lifted by `y`.
static func along(rot: Basis, pos: Vector3, size: Vector3, y: float) -> Transform3D:
	return Transform3D(rot * Basis.from_scale(size), pos + Vector3.UP * y)


## Thin box from `a` to `b` with square section `thickness` (cables, rails).
static func between(a: Vector3, b: Vector3, thickness: float) -> Transform3D:
	var dir: Vector3 = b - a
	var length: float = dir.length()
	if length < 0.001:
		return Transform3D(Basis.from_scale(Vector3.ONE * thickness), a)
	var basis: Basis = Basis.looking_at(dir / length, Vector3.UP if absf(dir.normalized().y) < 0.99 else Vector3.RIGHT)
	return Transform3D(basis * Basis.from_scale(Vector3(thickness, thickness, length)), (a + b) * 0.5)


static func unit_mesh(mesh_kind: String, colour: Color, kind: String = "") -> Mesh:
	var material: Material = surface_material(colour, kind)
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
		"prism":
			var prism: PrismMesh = PrismMesh.new()
			prism.size = Vector3.ONE
			prism.left_to_right = 0.5
			mesh = prism
		"wedge":
			# Media caja cortada en diagonal: el faldón de un techo, una rampa.
			mesh = wedge_mesh()
		"card":
			# Tres tarjetas cruzadas: un mechón de hojas, un helecho.
			mesh = card_mesh()
		"blob":
			# Bulto facetado: el NÚCLEO sólido de una copa (D80).
			mesh = blob_mesh()
		_:
			var box: BoxMesh = BoxMesh.new()
			box.size = Vector3.ONE
			mesh = box
	mesh.surface_set_material(0, material)
	return mesh


## Material común de todo el mapa: el color pedido, apagado con una textura de ruido
## en triplanar y con el tono de cada instancia (o de cada vértice) encima. Lo usan
## tanto MeshBatcher como RoadRibbon, para que la cinta de asfalto y las cajas que
## quedan se vean del mismo material.
static func surface_material(colour: Color, kind: String = "") -> Material:
	if kind in TEXTURED:
		return ground_material()
	if BARK_MATERIALS.has(kind):
		return bark_material(kind)
	if CUTOUT_MATERIALS.has(kind):
		return cutout_material(kind)
	if WATER_MATERIALS.has(kind):
		return water_material(kind)
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = colour
	material.albedo_texture = grain_texture()
	material.uv1_triplanar = true
	material.uv1_scale = Vector3.ONE * (0.012 if kind in BIG_SURFACES else 0.06)
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.5 if kind in GLOSSY else 0.94
	material.metallic_specular = 0.35 if kind in GLOSSY else 0.12
	return material


## Tono determinista de un punto: la misma caja en el mismo sitio saca siempre el
## mismo tono, corrida tras corrida (las pruebas lo exigen).
static func tint_at(p: Vector3) -> Color:
	var v: float = 0.87 + 0.26 * _hash01(p, 0.0)
	return Color(v * (0.98 + 0.04 * _hash01(p, 11.0)), v * (0.97 + 0.06 * _hash01(p, 23.0)), v * (0.96 + 0.08 * _hash01(p, 37.0)), 1.0)


## Material del suelo, uno solo y compartido: las siete losas del terreno son la misma
## superficie, y así cambiar la nieve es cambiar un parámetro en un sitio.
static func ground_material() -> ShaderMaterial:
	if _ground == null:
		var material: ShaderMaterial = ShaderMaterial.new()
		material.shader = GROUND_SHADER
		for key: String in GROUND_TEXTURES:
			material.set_shader_parameter(key, load(GROUND_TEXTURES[key]))
		material.set_shader_parameter("blend_noise", blend_texture())
		_ground = material
	return _ground


## Agua que se mueve: mismo shader para el estanque, el chorro y los canales; cambia `flow`.
static func water_material(kind: String) -> ShaderMaterial:
	if not _waters.has(kind):
		var material: ShaderMaterial = ShaderMaterial.new()
		material.shader = WATER_SHADER
		material.set_shader_parameter("noise_map", blend_texture())
		material.set_shader_parameter("flow", float(WATER_MATERIALS[kind]))
		_waters[kind] = material
	return _waters[kind]


## Corteza sobre el cilindro del tronco: el CylinderMesh ya trae UV que dan la vuelta, así
## que basta un StandardMaterial3D con las tres texturas. Uno por tipo, compartido.
static func bark_material(kind: String) -> StandardMaterial3D:
	if not _pbr.has(kind):
		var spec: Array = BARK_MATERIALS[kind]
		var material: StandardMaterial3D = StandardMaterial3D.new()
		material.albedo_texture = load(spec[0])
		material.normal_enabled = true
		material.normal_texture = load(spec[1])
		material.roughness_texture = load(spec[2])
		material.uv1_scale = spec[3]
		material.vertex_color_use_as_albedo = true
		_pbr[kind] = material
	return _pbr[kind]


## Hojas recortadas por alfa sobre las tarjetas. Sin culling: una tarjeta se ve por los
## dos lados. El tinte por tipo separa un huerto de un álamo con el mismo atlas.
static func cutout_material(kind: String) -> StandardMaterial3D:
	if not _cutouts.has(kind):
		var spec: Array = CUTOUT_MATERIALS[kind]
		var material: StandardMaterial3D = StandardMaterial3D.new()
		material.albedo_texture = load(spec[0])
		material.albedo_color = spec[2]
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		material.alpha_scissor_threshold = 0.45
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		material.uv1_scale = Vector3(spec[1], spec[1], 1.0)
		material.roughness = 0.85
		material.vertex_color_use_as_albedo = true
		_cutouts[kind] = material
	return _cutouts[kind]


## Un árbol (D76): tronco con corteza y una copa de `clumps` mechones de hojas repartidos
## dentro del elipsoide de la copa, más `ferns` helechos al pie. Determinista por posición,
## como todo lo demás. Deja la copa anotada en la máscara para el suelo de bosque.
func tree(p: Vector3, trunk_h: float, crown_r: float, clumps: int = 14, ferns: int = 2, trunk_kind: String = "trunk", crown_kind: String = "crown", trunk_w: float = 0.4, column_h: float = 0.0) -> void:
	add(trunk_kind, "cyl", Transform3D(Basis.from_scale(Vector3(trunk_w, trunk_h, trunk_w)), p + Vector3.UP * (trunk_h * 0.5)))
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = int(p.x * 73.0 + p.z * 131.0)
	var top: Vector3 = p + Vector3.UP * (trunk_h + crown_r * 0.7)
	# Ramas (D78): tres o cuatro cilindros de corteza que salen del tronco hacia la copa.
	# Sin ramas las matas flotaban alrededor de un palo — «planchas pegadas», dijo el dueño.
	# Núcleo sólido (D80): dos o tres bultos facetados que llenan el interior de la copa. Las
	# tarjetas de hojas van por fuera; por dentro ya no hay aire, así que desde ningún ángulo
	# se ve a través del árbol. Para el álamo es un solo bulto alargado.
	var core_kind: String = crown_kind + "_core"
	if column_h > 0.0:
		add(core_kind, "blob", Transform3D(Basis(Vector3.UP, rng.randf() * TAU) * Basis.from_scale(Vector3(crown_r * 1.7, column_h * 0.95, crown_r * 1.7)), p + Vector3.UP * (trunk_h * 0.5 + column_h * 0.5)))
	else:
		var cores: int = 3 if crown_r > 1.8 else 2
		for kc: int in cores:
			var c_off: Vector3 = Vector3(rng.randf_range(-0.35, 0.35), rng.randf_range(-0.15, 0.3), rng.randf_range(-0.35, 0.35)) * crown_r
			var c_size: float = crown_r * rng.randf_range(1.5, 1.9)
			add(core_kind, "blob", Transform3D(Basis(Vector3.UP, rng.randf() * TAU) * Basis.from_scale(Vector3(c_size, c_size * 0.9, c_size)), top + c_off))
	var branches: int = 0 if (column_h > 0.0 or trunk_h < 2.0) else 4
	for _br: int in branches:
		var ang_b: float = rng.randf() * TAU
		var reach: Vector3 = Vector3(cos(ang_b), 0.0, sin(ang_b)) * (crown_r * rng.randf_range(0.5, 0.85)) + Vector3.UP * (crown_r * rng.randf_range(0.2, 0.7))
		add(trunk_kind, "cyl", between(p + Vector3.UP * (trunk_h * rng.randf_range(0.8, 0.98)), top + reach, trunk_w * 0.45))
	for k: int in clumps:
		# Las matas van sobre un CASCARÓN esférico, no repartidas por todo el volumen: así se
		# solapan en una copa cerrada y ninguna queda suelta hacia adentro.
		var dir_k: Vector3 = Vector3(rng.randf_range(-1.0, 1.0), rng.randf_range(-0.35, 1.0), rng.randf_range(-1.0, 1.0)).normalized()
		var off: Vector3 = dir_k * (crown_r * rng.randf_range(0.55, 0.8))
		if column_h > 0.0:
			# álamo: la copa es una columna, los mechones suben apilados desde media altura
			off = Vector3(rng.randf_range(-0.4, 0.4), 0.0, rng.randf_range(-0.4, 0.4)) * crown_r + Vector3.UP * (column_h * (float(k) + 0.5) / float(clumps) - crown_r * 0.7 - trunk_h * 0.5)
		var size: float = crown_r * rng.randf_range(1.05, 1.4)
		var basis: Basis = Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, rng.randf_range(-0.4, 0.4)) * Basis.from_scale(Vector3(size, size * 0.9, size))
		# Sombreado de volumen por mata: las de arriba y afuera al sol, las de abajo y adentro
		# en sombra. Es lo que convierte un montón de tarjetas en una copa con bulto.
		var height_k: float = clampf(off.y / maxf(crown_r, 0.1) * 0.5 + 0.5, 0.0, 1.0)
		var outer_k: float = clampf(off.length() / maxf(crown_r * 0.8, 0.1), 0.0, 1.0)
		var shade: float = 0.55 + 0.3 * height_k + 0.15 * outer_k
		var jitter: float = 0.92 + 0.16 * _hash01(top + off, 5.0)
		add_coloured(crown_kind, "card", Transform3D(basis, top + off), Color(shade * jitter, shade * (0.97 + 0.06 * _hash01(top + off, 9.0)), shade * 0.95, 1.0))
	for _f: int in ferns:
		var ang: float = rng.randf() * TAU
		var foot: Vector3 = p + Vector3(cos(ang), 0.0, sin(ang)) * rng.randf_range(0.8, crown_r * 1.2)
		var fsize: float = rng.randf_range(0.7, 1.2)
		# la fronda de Poly Haven viene apretada a lo ancho: la tarjeta va alta y angosta
		add("fern", "card", Transform3D(Basis(Vector3.UP, rng.randf() * TAU) * Basis.from_scale(Vector3(fsize * 0.7, fsize * 1.1, fsize * 0.7)), foot + Vector3.UP * (fsize * 0.5)))
	# Solo los árboles de verdad dejan sombra de bosque en el suelo (D79): bajo los 1100
	# frutales de 1,4 m los parches oscuros se leían como manchas sin sentido por el campo.
	if trunk_h >= 2.0:
		add_canopy(p, crown_r * 1.8)


## Bulto facetado de radio 0,5 (D80): un icosaedro subdividido una vez (80 caras) con cada
## vértice empujado al azar entre 0,72 y 1,0 del radio, emitido sin índices para que cada
## cara tenga su propia normal (sombreado plano, aire low-poly). Es el NÚCLEO sólido de la
## copa: las tarjetas de hojas van por fuera y esto tapa el interior, así nunca más se ve a
## través del árbol — «planchas pegadas», dijo el dueño cuatro rondas seguidas.
static func blob_mesh() -> ArrayMesh:
	var t: float = (1.0 + sqrt(5.0)) * 0.5
	var base: Array[Vector3] = [
		Vector3(-1, t, 0), Vector3(1, t, 0), Vector3(-1, -t, 0), Vector3(1, -t, 0),
		Vector3(0, -1, t), Vector3(0, 1, t), Vector3(0, -1, -t), Vector3(0, 1, -t),
		Vector3(t, 0, -1), Vector3(t, 0, 1), Vector3(-t, 0, -1), Vector3(-t, 0, 1),
	]
	var faces: Array[Vector3i] = [
		Vector3i(0, 11, 5), Vector3i(0, 5, 1), Vector3i(0, 1, 7), Vector3i(0, 7, 10), Vector3i(0, 10, 11),
		Vector3i(1, 5, 9), Vector3i(5, 11, 4), Vector3i(11, 10, 2), Vector3i(10, 7, 6), Vector3i(7, 1, 8),
		Vector3i(3, 9, 4), Vector3i(3, 4, 2), Vector3i(3, 2, 6), Vector3i(3, 6, 8), Vector3i(3, 8, 9),
		Vector3i(4, 9, 5), Vector3i(2, 4, 11), Vector3i(6, 2, 10), Vector3i(8, 6, 7), Vector3i(9, 8, 1),
	]
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for f: Vector3i in faces:
		var a: Vector3 = base[f.x].normalized()
		var b: Vector3 = base[f.y].normalized()
		var c: Vector3 = base[f.z].normalized()
		var ab: Vector3 = ((a + b) * 0.5).normalized()
		var bc: Vector3 = ((b + c) * 0.5).normalized()
		var ca: Vector3 = ((c + a) * 0.5).normalized()
		for tri: Array in [[a, ab, ca], [ab, b, bc], [ca, bc, c], [ab, bc, ca]]:
			for v: Vector3 in tri:
				st.add_vertex(v * (0.5 * (0.72 + 0.28 * _hash01(v * 7.0, 13.0))))
	st.generate_normals()
	return st.commit()


## Tres tarjetas verticales cruzadas de 1x1, centradas, normal hacia arriba (así la luz
## las trata como follaje y no como paredes). Con `cull_disabled` el orden no importa.
static func card_mesh() -> ArrayMesh:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for q: int in 3:
		var angle: float = float(q) * PI / 3.0
		var side: Vector3 = Vector3(cos(angle), 0.0, sin(angle)) * 0.5
		var lo_a: Vector3 = -side - Vector3.UP * 0.5
		var lo_b: Vector3 = side - Vector3.UP * 0.5
		var hi_b: Vector3 = side + Vector3.UP * 0.5
		var hi_a: Vector3 = -side + Vector3.UP * 0.5
		for v: Array in [[lo_a, Vector2(0, 1)], [hi_b, Vector2(1, 0)], [lo_b, Vector2(1, 1)], [lo_a, Vector2(0, 1)], [hi_a, Vector2(0, 0)], [hi_b, Vector2(1, 0)]]:
			st.set_normal(Vector3.UP)
			st.set_uv(v[1])
			st.add_vertex(v[0])
	# Dos TAPAS casi horizontales, inclinadas ±22° (D79). El dueño mira el mapa desde arriba
	# volando, y desde arriba tres tarjetas verticales son tres láminas en estrella: «planchas
	# de hojas». Con las tapas la mata se cierra por arriba y la copa se ve llena.
	for cap: int in 2:
		var tilt: float = deg_to_rad(22.0) * (1.0 if cap == 0 else -1.0)
		var yaw: float = float(cap) * PI * 0.5
		var basis: Basis = Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, tilt)
		var c_a: Vector3 = basis * Vector3(-0.5, 0.0, -0.5)
		var c_b: Vector3 = basis * Vector3(0.5, 0.0, -0.5)
		var c_c: Vector3 = basis * Vector3(0.5, 0.0, 0.5)
		var c_d: Vector3 = basis * Vector3(-0.5, 0.0, 0.5)
		for v: Array in [[c_a, Vector2(0, 0)], [c_c, Vector2(1, 1)], [c_b, Vector2(1, 0)], [c_a, Vector2(0, 0)], [c_d, Vector2(0, 1)], [c_c, Vector2(1, 1)]]:
			st.set_normal(Vector3.UP)
			st.set_uv(v[1])
			st.add_vertex(v[0])
	return st.commit()


## Anota una copa en la máscara del suelo. `update_canopy()` la vuelca al shader.
static func add_canopy(p: Vector3, radius_m: float) -> void:
	_canopy_points.append(p)
	_canopy_radii.append(radius_m)


## Un mapa nuevo empieza sin copas anotadas. Lo llama el primer constructor del bioma.
static func reset_canopy() -> void:
	_canopy_points = PackedVector3Array()
	_canopy_radii = PackedFloat32Array()
	_canopy_texture = null
	ground_material().set_shader_parameter("canopy_size", Vector2.ZERO)


## Vuelca las copas anotadas a una imagen de 2 m por píxel y se la pasa al shader del
## suelo: donde hay sombra de árbol, el suelo pone hojas y musgo (Ground068).
static func update_canopy() -> ImageTexture:
	if _canopy_points.is_empty():
		return null
	var cell: float = 2.0
	var lo: Vector3 = _canopy_points[0]
	var hi: Vector3 = _canopy_points[0]
	for i: int in _canopy_points.size():
		var r: float = _canopy_radii[i]
		lo = lo.min(_canopy_points[i] - Vector3(r, 0.0, r))
		hi = hi.max(_canopy_points[i] + Vector3(r, 0.0, r))
	var origin: Vector2 = Vector2(lo.x, lo.z) - Vector2.ONE * cell
	var size: Vector2 = Vector2(hi.x - lo.x, hi.z - lo.z) + Vector2.ONE * (cell * 2.0)
	var w: int = clampi(int(ceil(size.x / cell)), 1, 4096)
	var h: int = clampi(int(ceil(size.y / cell)), 1, 4096)
	var image: Image = Image.create(w, h, false, Image.FORMAT_R8)
	for i: int in _canopy_points.size():
		var p: Vector3 = _canopy_points[i]
		var r: float = _canopy_radii[i]
		var cx: int = int((p.x - origin.x) / cell)
		var cy: int = int((p.z - origin.y) / cell)
		var reach: int = int(ceil(r / cell))
		for dy: int in range(-reach, reach + 1):
			for dx: int in range(-reach, reach + 1):
				var x: int = cx + dx
				var y: int = cy + dy
				if x < 0 or y < 0 or x >= w or y >= h:
					continue
				var d: float = Vector2(dx, dy).length() * cell
				# borde suave: pleno bajo la copa, se apaga hacia el radio
				var v: float = clampf(1.0 - (d / r) * 0.85, 0.0, 1.0)
				if v > image.get_pixel(x, y).r:
					image.set_pixel(x, y, Color(v, v, v, 1.0))
	_canopy_texture = ImageTexture.create_from_image(image)
	var material: ShaderMaterial = ground_material()
	material.set_shader_parameter("canopy_mask", _canopy_texture)
	material.set_shader_parameter("canopy_origin", origin)
	material.set_shader_parameter("canopy_size", size)
	return _canopy_texture


static func canopy_texture() -> ImageTexture:
	return _canopy_texture


## Material de una cinta: con textura si el color está en RIBBON_MATERIALS, si no el
## material común. Lo llama RoadRibbon.flush; MeshBatcher.flush nunca (ver arriba).
static func ribbon_material(colour: Color, kind: String) -> Material:
	if not RIBBON_MATERIALS.has(kind):
		return surface_material(colour, kind)
	if not _ribbons.has(kind):
		var spec: Array = RIBBON_MATERIALS[kind]
		var textures: Array = spec[0]
		var material: ShaderMaterial = ShaderMaterial.new()
		material.shader = RIBBON_SHADER
		material.set_shader_parameter("albedo_map", load(textures[0]))
		material.set_shader_parameter("normal_map", load(textures[1]))
		material.set_shader_parameter("rough_map", load(textures[2]))
		material.set_shader_parameter("grain_noise", grain_texture())
		material.set_shader_parameter("tile_m", float(spec[1]))
		material.set_shader_parameter("across_scale", float(spec[2]))
		material.set_shader_parameter("across_offset", float(spec[3]))
		if spec.size() > 4:
			# como Color, no Vector3: el uniform es `source_color` y solo así convierte de sRGB
			material.set_shader_parameter("tint", spec[4])
		_ribbons[kind] = material
	return _ribbons[kind]


## Cuánto del segundo juego (la nieve) se ve en el suelo, de 0 a 1.
static func set_ground_over_amount(amount: float) -> void:
	ground_material().set_shader_parameter("over_amount", clampf(amount, 0.0, 1.0))


## Metros que mide una baldosa del suelo.
static func set_ground_tile_m(metres: float) -> void:
	ground_material().set_shader_parameter("tile_m", maxf(0.2, metres))


static func grain_texture() -> NoiseTexture2D:
	if _grain == null:
		var noise: FastNoiseLite = FastNoiseLite.new()
		noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		noise.frequency = 0.012
		noise.fractal_octaves = 4
		var ramp: Gradient = Gradient.new()
		ramp.set_color(0, Color(0.74, 0.74, 0.74))
		ramp.set_color(1, Color(1.06, 1.06, 1.06))
		var texture: NoiseTexture2D = NoiseTexture2D.new()
		texture.noise = noise
		texture.width = 256
		texture.height = 256
		texture.seamless = true
		texture.color_ramp = ramp
		_grain = texture
	return _grain


## Techo a cuatro aguas: base de 1x1, cumbrera corta arriba a lo largo de Z. Un prisma
## escalado da dos aguas y nada más; con este y el prisma alternados, una calle de casas
## deja de tener el mismo techo repetido 700 veces.
static func hip_mesh() -> ArrayMesh:
	var b: float = 0.5
	var r: float = 0.22
	var base: PackedVector3Array = PackedVector3Array([
		Vector3(-b, -b, -b), Vector3(b, -b, -b), Vector3(b, -b, b), Vector3(-b, -b, b),
	])
	var ridge_a: Vector3 = Vector3(0.0, b, -r)
	var ridge_b: Vector3 = Vector3(0.0, b, r)
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# los dos faldones largos
	_tri(st, base[0], ridge_a, base[1])
	_tri(st, base[0], ridge_b, ridge_a)
	_tri(st, base[0], base[3], ridge_b)
	_tri(st, base[1], ridge_a, ridge_b)
	_tri(st, base[1], ridge_b, base[2])
	_tri(st, base[2], ridge_b, base[3])
	# tapa de abajo, para que no se vea hueco desde el patio
	_tri(st, base[0], base[1], base[2])
	_tri(st, base[0], base[2], base[3])
	st.generate_normals()
	return st.commit()


static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	st.add_vertex(a)
	st.add_vertex(b)
	st.add_vertex(c)


## Ruido de MEZCLA, de 0 a 1 de verdad. No confundir con `grain_texture()`, que va de
## 0,74 a 1,06 porque es un multiplicador de color: usado como máscara, cualquier umbral
## bajo 0,74 lo pasa entero — así salió el pueblo nevado con el dial en 0,3 (D75).
static func blend_texture() -> NoiseTexture2D:
	if _blend == null:
		var noise: FastNoiseLite = FastNoiseLite.new()
		noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		noise.frequency = 0.02
		noise.fractal_octaves = 3
		var texture: NoiseTexture2D = NoiseTexture2D.new()
		texture.noise = noise
		texture.width = 256
		texture.height = 256
		texture.seamless = true
		texture.normalize = true
		_blend = texture
	return _blend


## Cuña: caja partida por la diagonal, con la cara inclinada mirando a +X.
static func wedge_mesh() -> ArrayMesh:
	var v: PackedVector3Array = PackedVector3Array([
		Vector3(-0.5, -0.5, -0.5), Vector3(0.5, -0.5, -0.5), Vector3(-0.5, 0.5, -0.5),
		Vector3(-0.5, -0.5, 0.5), Vector3(0.5, -0.5, 0.5), Vector3(-0.5, 0.5, 0.5),
	])
	var tris: Array[int] = [
		0, 2, 1, 3, 4, 5, 0, 1, 4, 0, 4, 3, 1, 2, 5, 1, 5, 4, 0, 3, 5, 0, 5, 2,
	]
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i: int in tris:
		st.add_vertex(v[i])
	st.generate_normals()
	return st.commit()


static func _hash01(p: Vector3, salt: float) -> float:
	var v: float = sin(p.x * 12.9898 + p.z * 78.233 + p.y * 37.719 + salt) * 43758.5453
	return v - floor(v)
