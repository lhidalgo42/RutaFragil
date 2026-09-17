extends GdUnitTestSuite


func test_reduction_propagates_no_cargo_and_does_not_enable_a_gate() -> void:
	var config: GateConfig = GateConfig.new()
	config.parse(["experiment=1", "cargo=off", "seconds=60", "output=user://gate_unit"])
	assert_bool(config.experiment).is_true()
	assert_bool(config.cargo_spawn).is_false()
	assert_bool(config.vsync).is_false()
	for role: String in ["host", "client"]:
		assert_bool(config.child_args(role).has("experiment=1")).is_true()
		assert_bool(config.child_args(role).has("cargo=off")).is_true()
		assert_bool(config.child_args(role).has("seconds=60.0")).is_true()


func test_gate_deadline_covers_300_seconds_independently_of_waypoints() -> void:
	var config: GateConfig = GateConfig.new()
	config.parse(["seconds=300", "waypoints=16", "output=user://gate_unit"])
	assert_float(config.budget_s()).is_greater(300.0)
	assert_float(config.budget_s()).is_equal(390.0)
	var duration_arg: String = ""
	for arg: String in config.child_args("host"):
		if arg.begins_with("seconds="):
			duration_arg = arg.get_slice("=", 1)
	assert_float(duration_arg.to_float()).is_equal(300.0)


func test_human_client_is_windowed_while_host_is_headless() -> void:
	var config: GateConfig = GateConfig.new()
	config.parse(["human=client", "windowed=both", "vsync=off", "output=user://gate_unit"])
	assert_bool(config.child_args("host").has("--headless")).is_true()
	assert_bool(config.child_args("client").has("--headless")).is_false()
	assert_bool(config.child_args("client").has("human=client")).is_true()
	assert_bool(config.child_args("host").has("vsync=off")).is_true()
	assert_bool(config.child_args("client").has("vsync=off")).is_true()
