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
			assert_int(image.get_width()).override_failure_message(key + " no mide 512").is_equal(512)
	assert_bool(material.get_shader_parameter("blend_noise") is Texture2D).is_true()


func test_only_the_ground_uses_the_textured_material() -> void:
	var ground: Material = MeshBatcher.surface_material(Color.WHITE, "ground")
	assert_bool(ground is ShaderMaterial).is_true()
	# todo lo demás sigue con el material de color plano más ruido
	for kind: String in ["asphalt", "curb", "stop", "fountain"]:
		var other: Material = MeshBatcher.surface_material(Color.WHITE, kind)
		assert_bool(other is StandardMaterial3D).override_failure_message(kind + " no debería llevar el shader del suelo").is_true()


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
