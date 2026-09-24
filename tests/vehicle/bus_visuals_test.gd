extends GdUnitTestSuite

const BUS_SCENE: String = "res://src/vehicle/bus.tscn"
const EXPECTED_COLLIDERS: int = 16
const MAX_VISIBLE_TRIS: int = 25000


func test_final_visuals_are_separate_from_the_sixteen_bus_colliders() -> void:
	var bus: Bus = await _spawn_bus()
	if bus == null: return
	var shapes: Array[Node] = bus.get_children().filter(
		func(node: Node) -> bool: return node is CollisionShape3D)
	assert_int(shapes.size()).is_equal(EXPECTED_COLLIDERS)
	var blockers: Node = bus.get_node_or_null("BusDoors/Blockers")
	assert_bool(blockers is AnimatableBody3D).is_true()
	assert_int(blockers.get_child_count()).is_equal(2)
	var legacy: Node = bus.get_node_or_null("MeshInstance3D")
	assert_bool(legacy is MeshInstance3D).is_true()
	if legacy is MeshInstance3D: assert_bool(legacy.visible).is_false()
	var interior_grey: Node = bus.get_node_or_null("BusInterior/Visuals")
	assert_bool(interior_grey is Node3D).is_true()
	if interior_grey is Node3D: assert_bool(interior_grey.visible).is_false()
	var exterior: Node = bus.get_node_or_null("BusExteriorVisual")
	var interior: Node = bus.get_node_or_null("BusInterior/BusInteriorVisual")
	assert_object(exterior).is_not_null()
	assert_object(interior).is_not_null()
	assert_bool(VisualMaterialApplier.carries_collision(exterior)).is_false()
	assert_bool(VisualMaterialApplier.carries_collision(interior)).is_false()
	assert_int(_mesh_count(exterior)).is_greater(4)
	assert_int(_mesh_count(interior)).is_greater(4)
	assert_int(_triangle_count(exterior) + _triangle_count(interior)).is_less_equal(MAX_VISIBLE_TRIS)
	# D89 pane replaces the hidden greybox glass; the GLB leaves the openings empty.
	# r8: driver and copilot side windows are real see-through openings too.
	for pane_name: String in ["Windshield", "LeftCabWindowPane", "RightCabWindowPane"]:
		var glass: Node = bus.get_node_or_null("BusExteriorVisual/" + pane_name)
		assert_bool(glass is MeshInstance3D).override_failure_message(pane_name + " missing").is_true()
		if glass is MeshInstance3D:
			var pane: MeshInstance3D = glass
			assert_bool(pane.get_active_material(0) is StandardMaterial3D).is_true()
			if pane.get_active_material(0) is StandardMaterial3D:
				var glass_mat: StandardMaterial3D = pane.get_active_material(0)
				assert_int(glass_mat.transparency).is_not_equal(BaseMaterial3D.TRANSPARENCY_DISABLED)
			if pane_name != "Windshield":
				# Outboard of every wall collider (|x| 1.25) and above the cab eye line.
				assert_float(absf(pane.position.x)).is_greater(1.2)
				assert_float(pane.position.z).is_less(-2.2)


func test_exterior_interior_seats_racks_floor_and_wheels_use_the_external_atlases() -> void:
	var bus: Bus = await _spawn_bus()
	if bus == null: return
	var exterior: Node = bus.get_node_or_null("BusExteriorVisual")
	var interior: Node = bus.get_node_or_null("BusInterior/BusInteriorVisual")
	var exterior_mat: Material = _first_material(exterior)
	var interior_mat: Material = _first_material(interior)
	var wheel_mat: Material = _first_material(exterior.get_node_or_null("WheelFL"))
	for item: Array in [[exterior_mat, "res://assets/textures/bus_exterior_atlas_v1.png"],
		[interior_mat, "res://assets/textures/bus_interior_atlas_v1.png"],
		[wheel_mat, "res://assets/textures/bus_wheel_atlas_v1.png"]]:
		var material: Material = item[0]
		assert_bool(material is StandardMaterial3D).is_true()
		if material is StandardMaterial3D:
			var standard: StandardMaterial3D = material
			assert_object(standard.albedo_texture).is_not_null()
			if standard.albedo_texture != null:
				assert_str(standard.albedo_texture.resource_path).is_equal(item[1])
			assert_int(standard.texture_filter).is_equal(
				BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC)
	for path: String in ["BusExteriorVisual/Model", "BusInterior/BusInteriorVisual/Model",
		"BusExteriorVisual/WheelFL", "BusExteriorVisual/WheelFR",
		"BusExteriorVisual/WheelRL", "BusExteriorVisual/WheelRR"]:
		var visual: Node = bus.get_node_or_null(path)
		assert_object(visual).override_failure_message("missing visual " + path).is_not_null()
		assert_int(_mesh_count(visual)).is_greater(0)
	for name: String in ["FloorLiner", "LeftRackLowerCabinet", "RightRackLowerCabinet",
		"LeftRackUpperShelf_72", "RightRackUpperShelf_72", "DriverSeatCushion",
		"CopilotSeatCushion", "BenchBase", "StretcherDeck", "WheelWellDarkFL",
		"WheelWellDarkFR", "WheelWellDarkRR", "WheelWellDarkFLFascia",
		"WheelWellDarkFRFascia", "WheelWellDarkRRFascia", "RearDoorSill"]:
		assert_object(_find_name(interior, name)).override_failure_message(
			"missing interior part " + name).is_not_null()


func test_texture_imports_generate_mipmaps_for_the_anisotropic_materials() -> void:
	for path: String in [
			"res://assets/textures/bus_exterior_atlas_v1.png.import",
			"res://assets/textures/bus_interior_atlas_v1.png.import",
			"res://assets/textures/bus_wheel_atlas_v1.png.import"]:
		var text: String = FileAccess.get_file_as_string(path)
		assert_str(text).override_failure_message(path + " has no mipmaps; anisotropic floor filtering cannot work").contains("mipmaps/generate=true")


func test_two_named_seats_and_copilot_camera_are_authored() -> void:
	var runner: GdUnitSceneRunner = scene_runner("res://scenes/playground.tscn")
	var scene: Node = runner.scene()
	var driver: Seat = null
	var copilot: Seat = null
	for node: Node in scene.get_tree().get_nodes_in_group("seat"):
		if node is Seat:
			var seat: Seat = node
			if seat.seat_name == "driver": driver = seat
			if seat.seat_name == "copilot": copilot = seat
	assert_object(driver).is_not_null()
	assert_object(copilot).is_not_null()
	if driver != null: assert_bool(driver.drives_bus).is_true()
	if copilot != null:
		assert_bool(copilot.drives_bus).is_false()
		assert_object(copilot.seat_marker).is_not_null()
	var cam: Node = scene.get_node_or_null("Bus/CopilotCamera")
	assert_bool(cam is Camera3D).is_true()
	if cam is Camera3D:
		assert_float(cam.position.x).is_greater(0.0)
		assert_bool(cam.is_in_group("copilot_camera")).is_true()


func _spawn_bus() -> Bus:
	var packed: Resource = load(BUS_SCENE)
	assert_bool(packed is PackedScene).is_true()
	if not (packed is PackedScene): return null
	var scene: PackedScene = packed
	var node: Node = auto_free(scene.instantiate())
	add_child(node)
	await get_tree().process_frame
	assert_bool(node is Bus).is_true()
	return node as Bus


func _first_material(root: Node) -> Material:
	if root == null: return null
	if root is MeshInstance3D: return (root as MeshInstance3D).material_override
	for child: Node in root.get_children():
		var found: Material = _first_material(child)
		if found != null: return found
	return null


func _find_name(root: Node, wanted: String) -> Node:
	if root == null: return null
	if root.name == wanted: return root
	for child: Node in root.get_children():
		var found: Node = _find_name(child, wanted)
		if found != null: return found
	return null


func _mesh_count(root: Node) -> int:
	if root == null: return 0
	var total: int = 1 if root is MeshInstance3D else 0
	for child: Node in root.get_children(): total += _mesh_count(child)
	return total


func _triangle_count(root: Node) -> int:
	if root == null: return 0
	var total: int = 0
	if root is MeshInstance3D:
		var mi: MeshInstance3D = root
		if mi.mesh != null:
			for surface: int in mi.mesh.get_surface_count():
				var arrays: Array = mi.mesh.surface_get_arrays(surface)
				var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
				var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				total += (indices.size() if not indices.is_empty() else vertices.size()) / 3
	for child: Node in root.get_children(): total += _triangle_count(child)
	return total
