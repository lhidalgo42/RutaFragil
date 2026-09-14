extends GdUnitTestSuite

## OverviewCamera: orthographic top-down on ready; toggle hands the view back
## and forth with the chase camera (input is exercised through toggle():
## headless delivers no InputEvents).


func test_ready_is_orthographic_top_down_and_not_current() -> void:
	var cam: OverviewCamera = auto_free(OverviewCamera.new())
	cam.size_m = 100.0
	add_child(cam)
	assert_int(cam.projection).is_equal(Camera3D.PROJECTION_ORTHOGONAL)
	assert_float(cam.size).is_equal(100.0)
	assert_float(cam.rotation_degrees.x).is_equal_approx(-90.0, 0.01)
	assert_bool(cam.current).is_false()


func test_toggle_swaps_with_chase_camera() -> void:
	var chase: Camera3D = auto_free(Camera3D.new())
	add_child(chase)
	chase.make_current()
	var cam: OverviewCamera = auto_free(OverviewCamera.new())
	cam.chase = chase
	add_child(cam)
	cam.toggle()
	assert_bool(cam.current).is_true()
	assert_bool(chase.current).is_false()
	cam.toggle()
	assert_bool(cam.current).is_false()
	assert_bool(chase.current).is_true()
