extends GdUnitTestSuite


func test_judge_rejects_one_tick_outside_the_hull_for_either_peer() -> void:
	for role: String in ["host", "client"]:
		var host: Dictionary = _reading()
		var client: Dictionary = _reading()
		var changed: Dictionary = host if role == "host" else client
		changed["hull_exit_ticks"] = 1
		assert_str(str(GateMetricsUtil.judge(host, client)["status"])).is_equal("failed")
		assert_bool(GateReadiness.evaluate(host, client)["ready"]).is_false()


func test_forty_five_push_ticks_are_allowed_but_forty_six_fail_for_either_peer() -> void:
	for role: String in ["host", "client"]:
		var host: Dictionary = _reading()
		var client: Dictionary = _reading()
		var changed: Dictionary = host if role == "host" else client
		changed["pushes"]["count"] = 1
		changed["pushes"]["max_duration_ticks"] = 45
		assert_str(str(GateMetricsUtil.judge(host, client)["status"])).is_equal("passed")
		assert_bool(GateReadiness.evaluate(host, client)["ready"]).is_true()
		changed["pushes"]["max_duration_ticks"] = 46
		assert_str(str(GateMetricsUtil.judge(host, client)["status"])).is_equal("failed")
		assert_bool(GateReadiness.evaluate(host, client)["ready"]).is_false()


func test_judge_uses_filtered_samples_instead_of_large_raw_displacements() -> void:
	var host: Dictionary = _reading()
	var client: Dictionary = _reading()
	host["slip"]["samples"] = 3000
	client["slip"]["samples"] = 1200
	client["slip"]["p99_m"] = 0.14
	client["slip_raw"]["p99_m"] = 100.0
	assert_str(str(GateMetricsUtil.judge(host, client)["status"])).is_equal("passed")
	assert_bool(GateReadiness.evaluate(host, client)["ready"]).is_true()
	client["slip"]["p99_m"] = 0.151
	assert_str(str(GateMetricsUtil.judge(host, client)["status"])).is_equal("failed")


func test_empty_filtered_samples_cannot_produce_a_passing_slip_ratio() -> void:
	var host: Dictionary = _reading()
	var client: Dictionary = _reading()
	client["slip"] = {"samples": 0, "p99_m": 0.0, "max_m": 0.0}
	var verdict: Dictionary = GateMetricsUtil.judge(host, client)
	assert_str(str(verdict["status"])).is_equal("invalid")
	assert_bool(GateMetricsUtil.boolean(verdict.get("slip_judged", true))).is_false()
	assert_bool(GateReadiness.evaluate(host, client)["ready"]).is_true()


func test_readiness_uses_travel_coverage_instead_of_penetration_shape_warnings() -> void:
	var host: Dictionary = _reading()
	var client: Dictionary = _reading()
	host["instrumentation_missing"] = ["cargo/Package_2: no supported active collision shape"]
	assert_bool(GateReadiness.evaluate(host, client)["ready"]).is_true()
	host["travel_observation_complete"] = false
	assert_bool(GateReadiness.evaluate(host, client)["ready"]).is_false()
	host["travel_observation_complete"] = true
	host["push_classification_complete"] = false
	assert_bool(GateReadiness.evaluate(host, client)["ready"]).is_false()


func test_readiness_rejects_legacy_and_incomplete_travel_records() -> void:
	var host: Dictionary = _reading()
	for field: String in ["metrics_version", "hull_exit_ticks", "pushes", "travel_samples",
			"cargo_contact_samples", "travel_observation_complete", "push_classification_complete", "slip_raw"]:
		var client: Dictionary = _reading()
		client.erase(field)
		assert_bool(GateReadiness.evaluate(host, client)["ready"]).is_false()
	for field: String in ["travel_samples", "cargo_contact_samples"]:
		var client: Dictionary = _reading()
		client[field] = 17999
		assert_bool(GateReadiness.evaluate(host, client)["ready"]).is_false()
	var client: Dictionary = _reading()
	client["slip_raw"]["samples"] = 17998
	assert_bool(GateReadiness.evaluate(host, client)["ready"]).is_false()


func test_readiness_accepts_half_support_and_an_open_push_within_the_limit() -> void:
	var host: Dictionary = _reading()
	var client: Dictionary = _reading()
	client["off_bus_support_ticks"] = 9000
	client["bus_support"] = {"percent": 50.0, "last_tick_supported": false, "max_off_run_ticks": 45}
	client["pushes"] = {"count": 200, "open_count": 1, "max_duration_ticks": 45,
		"max_local_displacement_m": 0.8}
	assert_bool(GateReadiness.evaluate(host, client)["ready"]).is_true()
	assert_str(str(GateMetricsUtil.judge(host, client)["status"])).is_equal("passed")


func test_judge_keeps_the_known_penetration_coverage_limitation() -> void:
	var host: Dictionary = _reading()
	var client: Dictionary = _reading()
	host["instrumentation_missing"] = ["cargo/Package_2: no supported active collision shape"]
	assert_str(str(GateMetricsUtil.judge(host, client)["status"])).is_equal("invalid")


## The push tick is the MOST contaminated sample, not the least. Excluding only
## the previous three left it eligible: in the 300 s run of 2026-09-17, 137 of
## the 152 filtered samples above the 1.5x limit were that very tick, which
## turned a 1.03x client into a 2.23x failure.
func test_the_cargo_contact_tick_itself_is_excluded_from_the_filtered_series() -> void:
	var travel: GateTravelMetrics = GateTravelMetrics.new()
	var quiet: Vector3 = Vector3(0.0, -0.6, 0.0)
	travel.observe(1, quiet, true, false, false, true)
	travel.observe(2, quiet + Vector3(0.0, 0.0, 0.03), true, false, false, true)
	assert_bool(travel.slip_eligible).is_true()
	# Contact on THIS tick, none in the previous three: must not be eligible.
	travel.observe(3, quiet + Vector3(0.0, 0.0, 0.53), true, true, false, true)
	assert_bool(travel.slip_eligible).is_false()
	# Contact only in the previous three: also excluded.
	travel.observe(4, quiet + Vector3(0.0, 0.0, 0.56), true, false, true, true)
	assert_bool(travel.slip_eligible).is_false()
	var summary: Dictionary = travel.summary()
	assert_int(GateMetricsUtil.integer(summary["slip"]["samples"])).is_equal(1)
	assert_float(GateMetricsUtil.number(summary["slip"]["max_m"])).is_equal_approx(0.03, 0.000001)
	# The raw series keeps every displacement, including the push.
	assert_int(GateMetricsUtil.integer(summary["slip_raw"]["samples"])).is_equal(3)
	assert_float(GateMetricsUtil.number(summary["slip_raw"]["max_m"])).is_equal_approx(0.5, 0.000001)
	assert_str(str(summary["slip_filter"])).contains("this_tick")


func _reading() -> Dictionary:
	var activity: Dictionary = {}
	for key: String in GateMetricsUtil.ACTIVITY_KEYS:
		activity[key] = 10
	return {"metrics_version": 5, "run_id": "v5_test", "ticks": 18000, "duration_s": 300.0,
		"sampling_phase": GateMetricsUtil.SAMPLING_PHASE, "sampling_process_physics_priority": 1000,
		"sampling_process_priority": 1000, "instrumentation_missing": [],
		"travel_samples": 18000, "cargo_contact_samples": 18000, "travel_observation_complete": true,
		"push_classification_complete": true, "hull_exit_ticks": 0,
		"pushes": {"count": 0, "max_duration_ticks": 0, "max_local_displacement_m": 0.0, "open_count": 0},
		"slip": {"samples": 17999, "p99_m": 0.1, "max_m": 0.2},
		"slip_raw": {"samples": 17999, "p99_m": 0.1, "max_m": 0.2},
		"bus_support": {"percent": 100.0, "last_tick_supported": true, "max_off_run_ticks": 0},
		"off_bus_support_ticks": 0, "activity": activity, "cameras": {"min": 1, "max": 1},
		"unauthorized_cargo_simulation_ticks": 0, "remote_crew_simulation_ticks": 0,
		"penetration": {"max_depth_m": 0.05, "max_run_ticks": 3},
		"bus_remote_error": {"applicable": false, "status": "not_applicable", "local_samples": 1},
		"crew_remote_error": {"applicable": true, "status": "measured", "matched": 1},
		"cargo_remote_error": {"applicable": true, "status": "measured", "matched": 1},
		"render_configuration": {"vsync_mode": 0, "max_fps": 0},
		"fps": {"windowed": true, "frames": 18000, "p1": 60.0, "percent_below_60": 0.0}}
