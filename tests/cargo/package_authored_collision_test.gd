extends GdUnitTestSuite

## Section 10.1 point 3 (M-ART): the physics NEVER uses a generated mesh as
## collision. Whatever MeshInstance3D package.tscn carries — greybox BoxMesh
## today, a TRELLIS.2 .glb once it passes the checklist — the CollisionShape3D
## stays an authored primitive of D81's 0.4 m, and there is exactly one. This
## is the line that keeps "validate physics on greybox" and "use AI assets"
## compatible: M2 measured the carry against THIS box, so the art may change
## the look and must not change the collider.

const PACKAGE_SCENE: String = "res://src/cargo/package.tscn"
const BOX_SIZE_M: float = 0.4

func _instantiate() -> Package:
	var packed: Resource = load(PACKAGE_SCENE)
	assert_bool(packed is PackedScene).override_failure_message("package.tscn did not load").is_true()
	if not (packed is PackedScene):
		return null
	var scene: PackedScene = packed
	var node: Node = scene.instantiate()
	if not (node is Package):
		assert_bool(false).override_failure_message("package.tscn root must be a Package").is_true()
		return null
	var package: Package = node
	return auto_free(package)

func test_collision_is_one_authored_box_not_the_mesh() -> void:
	var package: Package = _instantiate()
	if package == null:
		return
	var shapes: Array[CollisionShape3D] = []
	var meshes: Array[MeshInstance3D] = []
	for child: Node in package.get_children():
		if child is CollisionShape3D:
			shapes.append(child)
		if child is MeshInstance3D:
			meshes.append(child)
		# A generated mesh imported with "Generate > Physics" arrives as a
		# StaticBody3D/CollisionShape3D subtree under the mesh: forbidden here.
		for grandchild: Node in child.get_children():
			assert_bool(grandchild is CollisionObject3D or grandchild is CollisionShape3D) \
				.override_failure_message("collision nested under %s: the mesh must not carry its own collider" % child.name) \
				.is_false()
	assert_int(shapes.size()).override_failure_message("exactly one CollisionShape3D on the package").is_equal(1)
	assert_int(meshes.size()).override_failure_message("exactly one MeshInstance3D on the package").is_equal(1)
	if shapes.is_empty():
		return
	var shape: Shape3D = shapes[0].shape
	assert_bool(shape is BoxShape3D) \
		.override_failure_message("the collider is a BoxShape3D primitive, never ConcavePolygonShape3D/ConvexPolygonShape3D from a mesh") \
		.is_true()
	if shape is BoxShape3D:
		var box: BoxShape3D = shape
		assert_vector(box.size).is_equal(Vector3(BOX_SIZE_M, BOX_SIZE_M, BOX_SIZE_M))
	assert_bool(shapes[0].transform.is_equal_approx(Transform3D.IDENTITY)) \
		.override_failure_message("the collider sits at the body origin, unmoved by the art") \
		.is_true()

func test_visual_mesh_fits_inside_the_collider() -> void:
	# The art may be smaller than the box (a dented parcel), never larger:
	# a mesh poking out of its collider is what looks like tunnelling.
	var package: Package = _instantiate()
	if package == null:
		return
	var mesh_node: MeshInstance3D = null
	for child: Node in package.get_children():
		if child is MeshInstance3D:
			mesh_node = child
	assert_object(mesh_node).is_not_null()
	if mesh_node == null or mesh_node.mesh == null:
		return
	var aabb: AABB = mesh_node.transform * mesh_node.mesh.get_aabb()
	var half: float = BOX_SIZE_M * 0.5 + 0.005
	assert_bool(aabb.position.x >= -half and aabb.end.x <= half
		and aabb.position.y >= -half and aabb.end.y <= half
		and aabb.position.z >= -half and aabb.end.z <= half) \
		.override_failure_message("mesh AABB %s exceeds the 0.4 m collider" % str(aabb)) \
		.is_true()
