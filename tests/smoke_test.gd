extends GdUnitTestSuite


func test_engine_is_pinned_to_4_7_2() -> void:
	var version_info: Dictionary = Engine.get_version_info()
	# get_version_info()["string"] uses a hyphen before the status
	# ("4.7.2-stable (official)"), unlike the dotted `godot --version` output.
	var version_string: String = str(version_info["string"])
	assert_str(version_string).starts_with("4.7.2-stable")
	# ADR-000 pins the exact build: short hash ed1daf0bf.
	var version_hash: String = str(version_info["hash"])
	assert_str(version_hash).starts_with("ed1daf0bf")


func test_physics_engine_is_jolt() -> void:
	var physics_engine: String = str(ProjectSettings.get_setting("physics/3d/physics_engine"))
	assert_str(physics_engine).is_equal("Jolt Physics")


func test_rendering_method_is_forward_plus() -> void:
	var rendering_method: String = str(ProjectSettings.get_setting("rendering/renderer/rendering_method"))
	assert_str(rendering_method).is_equal("forward_plus")
