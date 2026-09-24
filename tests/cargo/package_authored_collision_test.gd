extends GdUnitTestSuite

## Section 10.1 point 3 (M-ART): the physics NEVER uses a generated mesh as
## collision. The cleaned TRELLIS.2 visual is instanced separately; CollisionShape3D
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
	# In the tree, so global_transform composes through the .glb's root node;
	# positioned BEFORE add_child (the measured rule) and far from anything.
	package.position = Vector3(0.0, 50.0, 0.0)
	package.freeze = true
	add_child(package)
	return auto_free(package)

## Every MeshInstance3D under `node`, depth-first. A .glb instances as a
## Node3D root with the MeshInstance3D one level down, so the visual is a
## SUBTREE, not one child.
func _mesh_instances_under(node: Node, out: Array[MeshInstance3D]) -> void:
	for child: Node in node.get_children():
		if child is MeshInstance3D:
			out.append(child)
		_mesh_instances_under(child, out)

## True if any CollisionObject3D or CollisionShape3D lives under `node`.
## A generated mesh imported with "Generate > Physics" arrives with a
## StaticBody3D/CollisionShape3D subtree: that is exactly what must not exist.
func _carries_collision(node: Node) -> bool:
	for child: Node in node.get_children():
		if child is CollisionObject3D or child is CollisionShape3D:
			return true
		if _carries_collision(child):
			return true
	return false

func test_collision_is_one_authored_box_not_the_mesh() -> void:
	var package: Package = _instantiate()
	if package == null:
		return
	var shapes: Array[CollisionShape3D] = []
	var visuals: Array[Node] = []
	for child: Node in package.get_children():
		if child is CollisionShape3D:
			shapes.append(child)
		else:
			visuals.append(child)
	assert_int(shapes.size()).override_failure_message("exactly one CollisionShape3D on the package").is_equal(1)
	assert_int(visuals.size()).override_failure_message("exactly one visual subtree on the package").is_equal(1)
	if not visuals.is_empty():
		assert_str(visuals[0].scene_file_path) \
			.override_failure_message("the package visual must instance the validated GLB") \
			.is_equal("res://assets/models/package_clean_v1.glb")
		var meshes: Array[MeshInstance3D] = []
		_mesh_instances_under(visuals[0], meshes)
		if visuals[0] is MeshInstance3D:
			meshes.append(visuals[0])
		assert_int(meshes.size()).override_failure_message("the visual subtree has at least one MeshInstance3D").is_greater_equal(1)
		assert_bool(visuals[0] is CollisionObject3D or _carries_collision(visuals[0])) \
			.override_failure_message("collision nested under %s: the mesh must not carry its own collider" % visuals[0].name) \
			.is_false()
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
	var meshes: Array[MeshInstance3D] = []
	_mesh_instances_under(package, meshes)
	assert_int(meshes.size()).override_failure_message("no MeshInstance3D under the package").is_greater_equal(1)
	var half: float = BOX_SIZE_M * 0.5 + 0.005
	var measured: int = 0
	var bottom: float = INF
	for mesh_node: MeshInstance3D in meshes:
		if mesh_node.mesh == null:
			continue
		measured += 1
		# Transform relative to the BODY, composed through the .glb's root node.
		var local: Transform3D = package.global_transform.affine_inverse() * mesh_node.global_transform
		var aabb: AABB = local * mesh_node.mesh.get_aabb()
		bottom = minf(bottom, aabb.position.y)
		assert_bool(aabb.position.x >= -half and aabb.end.x <= half
			and aabb.position.y >= -half and aabb.end.y <= half
			and aabb.position.z >= -half and aabb.end.z <= half) \
			.override_failure_message("mesh %s AABB %s exceeds the 0.4 m collider" % [mesh_node.name, str(aabb)]) \
			.is_true()
	# A visual subtree whose meshes are all null would skip every check above.
	assert_int(measured).override_failure_message("no MeshInstance3D had a mesh to measure").is_greater_equal(1)
	# The art rests on the collider's floor: a package sitting upright must not
	# hover. "Fits inside" alone lets a model float anywhere in the box.
	assert_float(bottom).override_failure_message("the visual's base is %.3f m, not on the collider floor at -0.2 m" % bottom) \
		.is_equal_approx(-BOX_SIZE_M * 0.5, 0.01)
