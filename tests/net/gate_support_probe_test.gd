extends GdUnitTestSuite


func test_loss_preserves_previous_contact_and_does_not_repeat_airborne_ticks() -> void:
	var probe: GateSupportProbe = GateSupportProbe.new()
	var previous: Dictionary = {"tick": 93, "bus_support": true,
		"floor_bodies": [{"body": "Bus/Floor", "velocity": [0.0, 0.0, 4.4]}],
		"crew_velocity": [0.0, -0.5, 0.0], "bus_write_m": 0.073,
		"snapshots": {"received_this_tick": 1, "last_transport_s": 0.033},
		"nearest_package": {"origin_distance_m": 1.5}}
	probe.push_sample(previous)
	previous["floor_bodies"][0]["body"] = "mutated_after_sampling"
	probe.push_sample({"tick": 94, "bus_support": false})
	probe.push_sample({"tick": 95, "bus_support": false})
	assert_int(probe.events.size()).is_equal(1)
	assert_int(GateMetricsUtil.integer(probe.events[0]["previous"]["tick"])).is_equal(93)
	assert_str(str(probe.events[0]["previous"]["floor_bodies"][0]["body"])).is_equal("Bus/Floor")
	assert_int(GateMetricsUtil.integer(probe.events[0]["lost"]["tick"])).is_equal(94)
	probe.push_sample({"tick": 96, "bus_support": true})
	assert_int(probe.max_off_run).is_equal(2)
	assert_bool(probe.last_supported).is_true()
	assert_bool(GateMetricsUtil.boolean(probe.events[0]["recovered"])).is_true()
	assert_int(GateMetricsUtil.integer(probe.events[0]["recovered_tick"])).is_equal(96)
	assert_int(GateMetricsUtil.integer(probe.events[0]["off_ticks"])).is_equal(2)
	probe.push_sample({"tick": 97, "bus_support": true})
	probe.push_sample({"tick": 98, "bus_support": false})
	var history: Array = probe.events[1]["previous_three"]
	assert_int(history.size()).is_equal(3)
	assert_int(GateMetricsUtil.integer(probe.events[1]["previous_three"][0]["tick"])).is_equal(95)
	probe.reset()
	probe.push_sample({"tick": 1, "bus_support": false})
	assert_array(probe.events).is_empty()
