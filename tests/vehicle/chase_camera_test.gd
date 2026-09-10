extends GdUnitTestSuite

## ChaseCamera: converges behind a static target and aims at it. Process
## frames are correct here: the camera moves in _process, no physics (§3).
## High smoothing makes the exponential lerp snap within the first frames.


func test_camera_sits_behind_target_and_aims_at_it() -> void:
	var target: Node3D = auto_free(Node3D.new())
	add_child(target)
	target.global_position = Vector3(0.0, 1.0, 0.0)
	var camera: ChaseCamera = auto_free(ChaseCamera.new())
	add_child(camera)
	camera.target = target
	camera.smoothing = 1000.0
	for i: int in 10:
		await get_tree().process_frame
	var offset: Vector3 = camera.global_position - target.global_position
	var flat_distance: float = Vector2(offset.x, offset.z).length()
	assert_float(flat_distance).is_between(13.0, 15.0)
	var to_target: Vector3 = (target.global_position - camera.global_position).normalized()
	assert_float((-camera.global_basis.z).dot(to_target)).is_greater(0.95)
