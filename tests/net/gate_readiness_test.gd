extends GdUnitTestSuite


func test_low_support_and_an_open_short_push_do_not_fail_v5_readiness() -> void:
	var host: Dictionary = _reading()
	var client: Dictionary = _reading()
	client["bus_support"]["percent"] = 50.0
	client["bus_support"]["last_tick_supported"] = false
	client["bus_support"]["max_off_run_ticks"] = 45
	client["pushes"]["count"] = 1
	client["pushes"]["open_count"] = 1
	client["pushes"]["max_duration_ticks"] = 45
	assert_bool(GateReadiness.evaluate(host, client)["ready"]).is_true()


func test_hull_exit_long_push_insufficient_cycles_and_short_duration_fail_readiness() -> void:
	var host: Dictionary = _reading()
	var client: Dictionary = _reading()
	assert_bool(GateReadiness.evaluate(host, client)["ready"]).is_true()
	client["hull_exit_ticks"] = 1
	assert_bool(GateReadiness.evaluate(host, client)["ready"]).is_false()
	client = _reading()
	client["pushes"]["count"] = 1
	client["pushes"]["max_duration_ticks"] = 46
	assert_bool(GateReadiness.evaluate(host, client)["ready"]).is_false()
	client = _reading()
	client["activity"]["complete_cycles"] = 9
	assert_bool(GateReadiness.evaluate(host, client)["ready"]).is_false()
	client = _reading()
	host["duration_s"] = 60.0
	host["ticks"] = 3600
	assert_bool(GateReadiness.evaluate(host, client)["ready"]).is_false()


func test_gate_requires_same_clean_commit_and_configuration_as_completed_experiment() -> void:
	var config: Dictionary = {"seconds": 300, "cargo": true, "vsync": false}
	var previous: Dictionary = {"kind": "experiment", "status": "completed", "source_clean": true,
		"source_commit": "abc", "configuration": config.duplicate(), "host": _reading(), "client": _reading()}
	assert_bool(GateReadiness.allows_gate(previous, "abc", config)).is_true()
	var reloaded: Dictionary = JSON.parse_string(JSON.stringify(previous))
	assert_bool(GateReadiness.allows_gate(reloaded, "abc", config)).is_true()
	assert_bool(GateReadiness.allows_gate(previous, "def", config)).is_false()
	config["cargo"] = false
	assert_bool(GateReadiness.allows_gate(previous, "abc", config)).is_false()
	config["cargo"] = true
	previous["source_clean"] = false
	assert_bool(GateReadiness.allows_gate(previous, "abc", config)).is_false()


func _reading() -> Dictionary:
	return {"metrics_version": 5, "ticks": 18000, "duration_s": 300.0,
		"sampling_phase": GateMetricsUtil.SAMPLING_PHASE, "sampling_process_physics_priority": 1000,
		"sampling_process_priority": 1000, "instrumentation_missing": [],
		"travel_samples": 18000, "cargo_contact_samples": 18000, "travel_observation_complete": true,
		"push_classification_complete": true, "hull_exit_ticks": 0,
		"pushes": {"count": 0, "max_duration_ticks": 0, "max_local_displacement_m": 0.0, "open_count": 0},
		"slip": {"samples": 17999}, "slip_raw": {"samples": 17999},
		"activity": {"complete_cycles": 10},
		"bus_support": {"percent": 100.0, "last_tick_supported": true, "max_off_run_ticks": 0}}
