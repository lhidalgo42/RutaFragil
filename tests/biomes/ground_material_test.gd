extends GdUnitTestSuite

## Suelo con textura (D73): el material del terreno mezcla dos juegos de ambientCG.
## Si alguien mueve o renombra un .jpg, el suelo se queda gris sin avisar — esto avisa.


func test_the_ground_material_has_both_texture_sets_loaded() -> void:
	var material: ShaderMaterial = MeshBatcher.ground_material()
	assert_object(material).is_not_null()
	assert_object(material.shader).is_not_null()
	for key: String in MeshBatcher.GROUND_TEXTURES:
		var texture: Variant = material.get_shader_parameter(key)
		assert_bool(texture is Texture2D).override_failure_message("falta la textura " + key).is_true()
		if texture is Texture2D:
			var image: Texture2D = texture
			# detalle a 512; el escaneo de terreno, que va estirado a 900 m, a 1024
			assert_int(image.get_width()).override_failure_message(key + " viene sin reducir").is_between(512, 1024)
	assert_bool(material.get_shader_parameter("blend_noise") is Texture2D).is_true()


func test_only_the_ground_uses_the_textured_material() -> void:
	var ground: Material = MeshBatcher.surface_material(Color.WHITE, "ground")
	assert_bool(ground is ShaderMaterial).is_true()
	# todo lo demás que sale en cajas sigue con el material de color plano más ruido —
	# también el asfalto en caja (puente, paso bajo nivel): su UV es de caja, no de metros
	for kind: String in ["asphalt", "curb", "stop", "fountain", "dirt"]:
		var other: Material = MeshBatcher.surface_material(Color.WHITE, kind)
		assert_bool(other is StandardMaterial3D).override_failure_message(kind + " no debería llevar el shader del suelo").is_true()


## Las cintas de calzada y de ripio llevan textura (D74); las demás cintas, el material común.
func test_ribbons_get_the_road_and_rock_textures() -> void:
	for kind: String in ["asphalt", "asphalt_plain", "street", "dirt", "street_dirt"]:
		var material: Material = MeshBatcher.ribbon_material(Color.WHITE, kind)
		assert_bool(material is ShaderMaterial).override_failure_message(kind + " sin textura").is_true()
		if material is ShaderMaterial:
			var shader_material: ShaderMaterial = material
			assert_bool(shader_material.get_shader_parameter("albedo_map") is Texture2D).is_true()
	# la avenida muestrea solo el asfalto liso: sin la línea central de la textura
	var avenue: ShaderMaterial = MeshBatcher.ribbon_material(Color.WHITE, "asphalt_plain")
	assert_float(avenue.get_shader_parameter("across_scale")).is_less(0.5)
	for plain: String in ["curb", "sidewalk", "median", "dust"]:
		assert_bool(MeshBatcher.ribbon_material(Color.WHITE, plain) is StandardMaterial3D).override_failure_message(plain + " no debería llevar textura de cinta").is_true()


func test_the_snow_dial_moves_and_stays_inside_range() -> void:
	MeshBatcher.set_ground_over_amount(0.42)
	assert_float(MeshBatcher.ground_material().get_shader_parameter("over_amount")).is_equal_approx(0.42, 0.001)
	MeshBatcher.set_ground_over_amount(5.0)
	assert_float(MeshBatcher.ground_material().get_shader_parameter("over_amount")).is_equal_approx(1.0, 0.001)
	MeshBatcher.set_ground_over_amount(-3.0)
	assert_float(MeshBatcher.ground_material().get_shader_parameter("over_amount")).is_equal_approx(0.0, 0.001)
	# las losas del terreno la dejan como diga el bioma
	var road: OsmRoad = auto_free(OsmRoad.new())
	road.data_path = "res://data/b0_requinoa.json"
	road.ground_snow = 0.25
	add_child(road)
	assert_float(MeshBatcher.ground_material().get_shader_parameter("over_amount")).is_equal_approx(0.25, 0.001)


func test_the_textures_tile_in_metres_not_in_mesh_uvs() -> void:
	# El suelo es una caja unitaria escalada a 2600 m: si el shader usara las UV de la
	# malla, una baldosa se estiraría el mapa entero. `tile_m` tiene que llegar al shader.
	MeshBatcher.set_ground_tile_m(4.5)
	assert_float(MeshBatcher.ground_material().get_shader_parameter("tile_m")).is_equal_approx(4.5, 0.001)
	MeshBatcher.set_ground_tile_m(0.0)
	assert_float(MeshBatcher.ground_material().get_shader_parameter("tile_m")).is_greater(0.0)
	assert_str(MeshBatcher.ground_material().shader.code).contains("MODEL_MATRIX")


## Un shader con un error de sintaxis se CARGA igual, solo que no declara ni un uniform.
## Headless no dibuja, así que esta lista es la única prueba de que compiló de verdad:
## sin ella, un error de tipeo en el shader recién se vería al abrir Godot.
func test_the_shaders_actually_compile() -> void:
	var ground: Array = MeshBatcher.ground_material().shader.get_shader_uniform_list(true)
	var names: Array[String] = []
	for u: Dictionary in ground:
		names.append(str(u.get("name", "")))
	for needed: String in ["base_albedo", "over_albedo", "blend_noise", "tile_m", "over_amount"]:
		assert_bool(names.has(needed)).override_failure_message("el shader del suelo no compiló: falta " + needed).is_true()
	var tuft: Shader = load("res://assets/shaders/grass_tuft.gdshader")
	assert_object(tuft).is_not_null()
	assert_int(tuft.get_shader_uniform_list(true).size()).override_failure_message("el shader del pasto no compiló").is_greater(0)
	var ribbon: Shader = load("res://assets/shaders/ribbon.gdshader")
	assert_object(ribbon).is_not_null()
	var ribbon_names: Array[String] = []
	for u: Dictionary in ribbon.get_shader_uniform_list(true):
		ribbon_names.append(str(u.get("name", "")))
	for needed: String in ["albedo_map", "tile_m", "across_scale", "across_offset"]:
		assert_bool(ribbon_names.has(needed)).override_failure_message("el shader de cinta no compiló: falta " + needed).is_true()
	var water: Array = MeshBatcher.water_material("fountain_water").shader.get_shader_uniform_list(true)
	assert_int(water.size()).override_failure_message("el shader de agua no compiló").is_greater(3)


## Vegetación con textura (D76): corteza en el tronco, hojas recortadas en la copa.
func test_trees_get_bark_and_cutout_leaves() -> void:
	var bark: Material = MeshBatcher.surface_material(Color.WHITE, "trunk")
	assert_bool(bark is StandardMaterial3D).is_true()
	if bark is StandardMaterial3D:
		var bark_material: StandardMaterial3D = bark
		assert_bool(bark_material.albedo_texture is Texture2D).override_failure_message("el tronco no lleva corteza").is_true()
		assert_bool(bark_material.normal_enabled).is_true()
	for kind: String in ["crown", "poplar", "orchard", "fern", "vine"]:
		var leaves: Material = MeshBatcher.surface_material(Color.WHITE, kind)
		assert_bool(leaves is StandardMaterial3D).is_true()
		if leaves is StandardMaterial3D:
			var leaf_material: StandardMaterial3D = leaves
			assert_int(leaf_material.transparency).override_failure_message(kind + " no recorta por alfa").is_equal(BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR)
			assert_bool(leaf_material.albedo_texture is Texture2D).is_true()
			assert_int(leaf_material.cull_mode).is_equal(BaseMaterial3D.CULL_DISABLED)
	# la tarjeta: tres quads cruzados = 18 vértices, todos con la normal hacia arriba
	var card: ArrayMesh = MeshBatcher.card_mesh()
	var arrays: Array = card.surface_get_arrays(0)
	assert_int((arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()).is_equal(18)
	for n: Vector3 in (arrays[Mesh.ARRAY_NORMAL] as PackedVector3Array):
		assert_float(n.y).is_greater(0.99)


## Un árbol deja anotada su copa y el suelo recibe la máscara: hojas y musgo bajo los árboles.
func test_trees_paint_the_canopy_mask_for_the_forest_floor() -> void:
	MeshBatcher.reset_canopy()
	assert_object(MeshBatcher.canopy_texture()).is_null()
	var batcher: MeshBatcher = MeshBatcher.new()
	batcher.tree(Vector3(100.0, 0.0, 50.0), 4.0, 2.0)
	assert_int(batcher.count("trunk")).is_equal(1)
	assert_int(batcher.count("crown")).is_equal(7)
	assert_int(batcher.count("fern")).is_equal(2)
	var texture: ImageTexture = MeshBatcher.update_canopy()
	assert_object(texture).is_not_null()
	var origin: Vector2 = MeshBatcher.ground_material().get_shader_parameter("canopy_origin")
	var size: Vector2 = MeshBatcher.ground_material().get_shader_parameter("canopy_size")
	assert_float(size.x).is_greater(4.0)
	# bajo el tronco la máscara está encendida; en la esquina, apagada
	var image: Image = texture.get_image()
	var under: Vector2i = Vector2i(int((100.0 - origin.x) / 2.0), int((50.0 - origin.y) / 2.0))
	assert_float(image.get_pixel(under.x, under.y).r).is_greater(0.8)
	assert_float(image.get_pixel(0, 0).r).is_less(0.05)


## El agua se mueve: un ShaderMaterial con `flow` distinto para el estanque y el chorro.
func test_water_flows_differently_in_the_pool_and_the_stream() -> void:
	var pool: Material = MeshBatcher.surface_material(Color.WHITE, "fountain_water")
	var stream: Material = MeshBatcher.surface_material(Color.WHITE, "fountain_stream")
	assert_bool(pool is ShaderMaterial and stream is ShaderMaterial).is_true()
	if pool is ShaderMaterial and stream is ShaderMaterial:
		assert_float((pool as ShaderMaterial).get_shader_parameter("flow")).is_equal_approx(0.0, 0.001)
		assert_float((stream as ShaderMaterial).get_shader_parameter("flow")).is_equal_approx(1.0, 0.001)
