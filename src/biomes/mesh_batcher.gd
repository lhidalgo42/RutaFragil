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
const RIBBON_MATERIALS: Dictionary = {
	"asphalt": [ROAD_TEXTURES, 9.0, 1.0, 0.0],
	"asphalt_plain": [ROAD_TEXTURES, 9.0, 0.3, 0.12],
	"street": [ROAD_TEXTURES, 7.0, 1.0, 0.0],
	"dirt": [ROCK_TEXTURES, 2.5, 1.0, 0.0],
	"street_dirt": [ROCK_TEXTURES, 2.5, 1.0, 0.0],
}

static var _grain: NoiseTexture2D
static var _ground: ShaderMaterial
static var _ribbons: Dictionary = {}

var _batches: Dictionary = {}
var _flushed: Dictionary = {}


func add(kind: String, mesh_kind: String, xform: Transform3D) -> void:
	if not _batches.has(kind):
		_batches[kind] = {"mesh": mesh_kind, "xforms": []}
	var entry: Dictionary = _batches[kind]
	var xforms: Array = entry["xforms"]
	xforms.append(xform)


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
		mm.mesh = unit_mesh(str(entry["mesh"]), colours.get(kind, Color.MAGENTA), kind)
		mm.instance_count = xforms.size()
		for i: int in xforms.size():
			var xf: Transform3D = xforms[i]
			mm.set_instance_transform(i, xf)
			mm.set_instance_color(i, tint_at(xf.origin))
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
		material.set_shader_parameter("blend_noise", grain_texture())
		_ground = material
	return _ground


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
