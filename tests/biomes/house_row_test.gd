extends GdUnitTestSuite

## HouseRow (D63): one facade per house, one fence per house, one collision
## box spanning the row on the requested side; deterministic for a seed.


func test_builds_count_facades_and_one_body() -> void:
	var row: HouseRow = auto_free(HouseRow.new())
	row.count = 4
	row.side = 1
	add_child(row)
	assert_int(row.facade_count()).is_equal(4)
	var fences: Node = row.get_node_or_null("Fences")
	assert_bool(fences is MultiMeshInstance3D).is_true()
	var body: Node = row.get_node_or_null("Body")
	assert_bool(body is StaticBody3D).is_true()
	if body is StaticBody3D:
		var shape_node: CollisionShape3D = body.get_child(0) as CollisionShape3D
		var box: BoxShape3D = shape_node.shape as BoxShape3D
		assert_float(box.size.z).is_equal(32.0)
		assert_float(shape_node.position.x).is_greater(0.0)


func test_mirrored_side_puts_body_on_negative_x() -> void:
	var row: HouseRow = auto_free(HouseRow.new())
	row.count = 3
	row.side = -1
	add_child(row)
	var body: StaticBody3D = row.get_node("Body") as StaticBody3D
	var shape_node: CollisionShape3D = body.get_child(0) as CollisionShape3D
	assert_float(shape_node.position.x).is_less(0.0)


func test_same_seed_same_colours() -> void:
	var a: HouseRow = auto_free(HouseRow.new())
	var b: HouseRow = auto_free(HouseRow.new())
	a.seed = 7
	b.seed = 7
	add_child(a)
	add_child(b)
	var ma: MultiMeshInstance3D = a.get_node("Facades") as MultiMeshInstance3D
	var mb: MultiMeshInstance3D = b.get_node("Facades") as MultiMeshInstance3D
	for i: int in a.count:
		assert_bool(ma.multimesh.get_instance_color(i) == mb.multimesh.get_instance_color(i)).is_true()
