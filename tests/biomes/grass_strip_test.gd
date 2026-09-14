extends GdUnitTestSuite

## GrassStrip (D64): tuft count follows strip area and density, is deterministic
## for a seed, and every tuft lies inside the strip.


func test_count_follows_area_and_is_deterministic() -> void:
	var a: GrassStrip = auto_free(GrassStrip.new())
	var b: GrassStrip = auto_free(GrassStrip.new())
	add_child(a)
	add_child(b)
	var pts: PackedVector3Array = PackedVector3Array([Vector3(0, 0, 0), Vector3(100, 0, 0)])
	var n_a: int = a.build_along(pts, 1.5, 4.0, 3)
	var n_b: int = b.build_along(pts, 1.5, 4.0, 3)
	assert_int(n_a).is_equal(1200)
	assert_int(n_b).is_equal(n_a)
	assert_vector(a.positions[7]).is_equal(b.positions[7])
	assert_bool(a.positions[7] != Vector3.ZERO).is_true()


func test_tufts_stay_inside_strip() -> void:
	var g: GrassStrip = auto_free(GrassStrip.new())
	add_child(g)
	var pts: PackedVector3Array = PackedVector3Array([Vector3(0, 0, 0), Vector3(50, 0, 0), Vector3(50, 0, 50)])
	var n: int = g.build_along(pts, 2.0, 1.0, 9)
	assert_int(n).is_greater(300)
	var inside: bool = true
	assert_int(g.positions.size()).is_equal(n)
	for p: Vector3 in g.positions:
		var on_first: bool = p.x >= -0.01 and p.x <= 50.01 and absf(p.z) <= 2.01
		var on_second: bool = absf(p.x - 50.0) <= 2.01 and p.z >= -0.01 and p.z <= 50.01
		if not (on_first or on_second):
			inside = false
	assert_bool(inside).is_true()


func test_set_follow_joins_group_and_updates_material() -> void:
	var g: GrassStrip = auto_free(GrassStrip.new())
	add_child(g)
	assert_bool(g.is_in_group("grass")).is_true()
	g.build_along(PackedVector3Array([Vector3.ZERO, Vector3(10, 0, 0)]), 1.0, 2.0, 1)
	var bus: Node3D = auto_free(Node3D.new())
	add_child(bus)
	bus.global_position = Vector3(4.0, 0.0, 1.0)
	g.set_follow(bus)
	g._process(0.016)
	var mat: ShaderMaterial = g.material_override as ShaderMaterial
	var value: Variant = mat.get_shader_parameter("bus_position")
	assert_bool(value is Vector3).is_true()
	if value is Vector3:
		var v: Vector3 = value
		assert_vector(v).is_equal(Vector3(4.0, 0.0, 1.0))
