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


## D97's human gate is a play session, not a D96 attempt. Treating any 300 s
## run as an iteration made the launcher demand a precondition for the owner's
## own session and refuse it with exit 3 — and the precondition could never
## match anyway, because human=client changes the configuration signature.
func test_the_human_gate_is_a_session_not_a_d96_attempt() -> void:
	var scripted: GateConfig = GateConfig.new()
	scripted.parse(PackedStringArray(["mode=gate", "role=launcher", "seconds=300", "human=none"]))
	assert_bool(scripted.counts_for_d96()).is_true()
	assert_str(scripted.kind()).is_equal("gate")
	var human: GateConfig = GateConfig.new()
	human.parse(PackedStringArray(["mode=gate", "role=launcher", "seconds=300", "human=client"]))
	assert_bool(human.counts_for_d96()).is_false()
	assert_str(human.kind()).is_equal("human")
	var experiment: GateConfig = GateConfig.new()
	experiment.parse(PackedStringArray(["mode=gate", "role=launcher", "seconds=300", "experiment=1"]))
	assert_bool(experiment.counts_for_d96()).is_false()
	assert_str(experiment.kind()).is_equal("experiment")
	var preflight: GateConfig = GateConfig.new()
	preflight.parse(PackedStringArray(["mode=gate", "role=launcher", "seconds=60", "human=none"]))
	assert_bool(preflight.counts_for_d96()).is_false()
	assert_str(preflight.kind()).is_equal("preflight")
