extends GdUnitTestSuite



class ActivitySource extends Node:
	func activity_for_peer(_peer_id: int) -> Dictionary:
		var activity: Dictionary = {}
		for key: String in GateMetricsUtil.ACTIVITY_KEYS:
			activity[key] = 0
		return activity


func test_percentiles_and_fps_report_tails_not_average() -> void:
	var values: Array[float] = []
	for index: int in range(1, 1001):
		values.append(GateMetricsUtil.number(index))
	var summary: Dictionary = GateMetricsUtil.slip_summary(values)
	assert_float(GateMetricsUtil.number(summary["p95_m"])).is_equal(950.0)
	assert_float(GateMetricsUtil.number(summary["p99_m"])).is_equal(990.0)
	assert_float(GateMetricsUtil.number(summary["p999_m"])).is_equal(999.0)
	assert_float(GateMetricsUtil.number(summary["max_m"])).is_equal(1000.0)
	var frames: Array[float] = [1.0 / 30.0, 1.0 / 30.0]
	for index: int in range(99):
		frames.append(1.0 / 120.0)
	var fps: Dictionary = GateMetricsUtil.fps_summary(frames, true)
	assert_float(GateMetricsUtil.number(fps["p1"])).is_equal(30.0)
	assert_float(GateMetricsUtil.number(fps["percent_below_60"])).is_equal_approx(200.0 / 101.0, 0.00001)


func test_capsule_height_and_rotated_cargo_measure_real_shape_extents() -> void:
	var floor_half: Vector3 = Vector3(1.25, 0.05, 3.9)
	var capsule_at: Transform3D = Transform3D(Basis.IDENTITY, Vector3(0.0, 0.925, 0.0))
	assert_float(GateHullProbe.capsule_box_depth(capsule_at, 0.3, 1.75, floor_half)).is_equal_approx(0.0, 0.000001)
	capsule_at.origin.y -= 0.04
	assert_float(GateHullProbe.capsule_box_depth(capsule_at, 0.3, 1.75, floor_half)).is_equal_approx(0.04, 0.000001)
	var cargo_at: Transform3D = Transform3D(Basis(Vector3.UP, PI / 4.0), Vector3(0.3, 0.0, 0.0))
	var depth: float = GateHullProbe.box_box_depth(cargo_at, Vector3.ONE * 0.2, Vector3(0.05, 0.95, 3.8))
	assert_float(depth).is_equal_approx(sqrt(2.0) * 0.2 + 0.05 - 0.3, 0.000001)
	cargo_at.origin.x = 0.4
	assert_float(GateHullProbe.box_box_depth(cargo_at, Vector3.ONE * 0.2, Vector3(0.05, 0.95, 3.8))).is_equal(0.0)


func test_authored_door_hole_excludes_air_but_keeps_floor_and_jamb() -> void:
	var bus: RigidBody3D = _bus()
	var body: CharacterBody3D = auto_free(CharacterBody3D.new())
	body.collision_layer = 0
	body.collision_mask = 0
	body.position = Vector3(1.2, -0.59, -1.75)
	var collision: CollisionShape3D = CollisionShape3D.new()
	var capsule: CapsuleShape3D = CapsuleShape3D.new()
	capsule.radius = 0.3
	capsule.height = 1.75
	collision.shape = capsule
	collision.position.y = 0.875
	body.add_child(collision)
	add_child(body)
	var hull: GateHullProbe = GateHullProbe.new()
	hull.configure(bus)
	assert_array(hull.missing).is_empty()
	assert_int(hull.pieces.size()).is_equal(9)
	var hole: Dictionary = hull.measure(body, bus.global_transform)
	assert_float(GateMetricsUtil.number(hole["depth_m"])).is_equal_approx(0.0, 0.000001)
	body.position.z = -1.2
	var jamb: Dictionary = hull.measure(body, bus.global_transform)
	assert_float(GateMetricsUtil.number(jamb["depth_m"])).is_greater(0.05)
	body.position = Vector3(1.0, -0.66, -1.75)
	var floor_hit: Dictionary = hull.measure(body, bus.global_transform)
	assert_float(GateMetricsUtil.number(floor_hit["depth_m"])).is_equal_approx(0.06, 0.000001)
	assert_str(str(floor_hit["piece"])).is_equal("Floor")


func test_penetration_run_resets_without_losing_peak_or_total() -> void:
	var record: Dictionary = {}
	for depth: float in [0.031, 0.04, 0.032, 0.0, 0.04, 0.0]:
		record = GateMetricsUtil.penetration_step(record, depth)
	assert_int(GateMetricsUtil.integer(record["max_run_ticks"])).is_equal(3)
	assert_int(GateMetricsUtil.integer(record["current_run_ticks"])).is_equal(0)
	assert_int(GateMetricsUtil.integer(record["penetrating_ticks"])).is_equal(4)
	assert_float(GateMetricsUtil.number(record["max_depth_m"])).is_equal(0.04)


func test_resting_penetration_does_not_extend_a_run_or_pollute_excluded_histogram() -> void:
	var record: Dictionary = {}
	for tick: int in range(100):
		record = GateMetricsUtil.penetration_step(record, 0.0255)
	record = GateMetricsUtil.penetration_step(record, 0.03)
	assert_int(GateMetricsUtil.integer(record["max_run_ticks"])).is_equal(0)
	for tick: int in range(4):
		record = GateMetricsUtil.penetration_step(record, 0.031)
	assert_int(GateMetricsUtil.integer(record["max_run_ticks"])).is_equal(4)
	assert_float(GateMetricsUtil.number(record["max_depth_m"])).is_equal(0.031)
	record = GateMetricsUtil.penetration_step(record, 0.0, false)
	assert_int(GateMetricsUtil.integer(record["current_run_ticks"])).is_equal(0)
	assert_int(GateMetricsUtil.integer(record["eligible_samples"])).is_equal(105)
	assert_int(GateMetricsUtil.integer(record["depth_histogram"]["2_to_3cm"])).is_equal(101)
	assert_int(GateMetricsUtil.integer(record["depth_histogram"]["3_to_4cm"])).is_equal(4)
	var histogram: Dictionary = record["depth_histogram"]
	assert_bool(histogram.has("le_1um")).is_false()


func test_judge_uses_same_run_p99_not_outlier_maximum() -> void:
	var host: Dictionary = _valid_reading()
	var client: Dictionary = _valid_reading()
	client["slip"]["p99_m"] = 0.15
	client["slip"]["max_m"] = 100.0
	var result: Dictionary = GateMetricsUtil.judge(host, client)
	assert_str(str(result["status"])).is_equal("passed")
	client["slip"]["p99_m"] = 0.151
	assert_str(str(GateMetricsUtil.judge(host, client)["status"])).is_equal("failed")
	client["slip"]["p99_m"] = 0.1
	client["penetration"]["max_run_ticks"] = 4
	assert_str(str(GateMetricsUtil.judge(host, client)["status"])).is_equal("failed")


func test_short_or_idle_iterations_are_invalid_and_headless_is_unverified() -> void:
	var host: Dictionary = _valid_reading()
	var client: Dictionary = _valid_reading()
	client["duration_s"] = 299.0
	assert_str(str(GateMetricsUtil.judge(host, client)["status"])).is_equal("invalid")
	client["duration_s"] = 300.0
	client["ticks"] = 17999
	assert_str(str(GateMetricsUtil.judge(host, client)["status"])).is_equal("invalid")
	client["ticks"] = 18000
	client["activity"]["complete_cycles"] = 9
	assert_str(str(GateMetricsUtil.judge(host, client)["status"])).is_equal("invalid")
	client["activity"]["complete_cycles"] = 10
	client["fps"]["windowed"] = false
	var result: Dictionary = GateMetricsUtil.judge(host, client)
	assert_str(str(result["status"])).is_equal("unverified")
	assert_bool(GateMetricsUtil.boolean(result["logic_passed"])).is_true()
	assert_bool(GateMetricsUtil.boolean(result["render_verified"])).is_false()
	client["run_id"] = "another_run"
	assert_str(str(GateMetricsUtil.judge(host, client)["status"])).is_equal("invalid")
	client["run_id"] = "same_test_run"
	client["crew_remote_error"] = {"applicable": true, "status": "unmatched", "matched": 0}
	assert_str(str(GateMetricsUtil.judge(host, client)["status"])).is_equal("invalid")
	client["crew_remote_error"] = {"applicable": true, "status": "measured", "matched": 1}
	client["cargo_remote_error"] = {"applicable": false, "status": "not_observed"}
	assert_str(str(GateMetricsUtil.judge(host, client)["status"])).is_equal("invalid")
	client.erase("cargo_remote_error")
	assert_str(str(GateMetricsUtil.judge(host, client)["status"])).is_equal("invalid")


func test_low_support_does_not_replace_the_filtered_slip_judgment() -> void:
	var host: Dictionary = _valid_reading()
	var client: Dictionary = _valid_reading()
	client["off_bus_support_ticks"] = 9000
	client["bus_support"] = {"percent": 50.0, "last_tick_supported": false, "max_off_run_ticks": 45}
	assert_str(str(GateMetricsUtil.judge(host, client)["status"])).is_equal("passed")
	client["slip"]["p99_m"] = 100.0
	var result: Dictionary = GateMetricsUtil.judge(host, client)
	assert_str(str(result["status"])).is_equal("failed")
	assert_bool(GateMetricsUtil.boolean(result.get("slip_judged", false))).is_true()
	assert_array(result["failures"]).contains_exactly(["client slip p99 exceeds 1.5 times same-run host"])


func test_capped_or_vsynced_fps_is_unverified_instead_of_failure() -> void:
	var host: Dictionary = _valid_reading()
	var client: Dictionary = _valid_reading()
	client["fps"]["p1"] = 30.0
	for config: Dictionary in [{"vsync_mode": 1, "max_fps": 0}, {"vsync_mode": 0, "max_fps": 120}]:
		client["render_configuration"] = config
		var result: Dictionary = GateMetricsUtil.judge(host, client)
		assert_str(str(result["status"])).is_equal("unverified")
		assert_array(result["failures"]).is_empty()
	client["render_configuration"] = {"vsync_mode": 0, "max_fps": 0}
	assert_str(str(GateMetricsUtil.judge(host, client)["status"])).is_equal("failed")


func test_trace_interpolates_position_and_quaternion_at_observation_utc() -> void:
	var source: Array[Dictionary] = [_pose("bus", "bus", 0.0, 0.0, 1, 1, 1000000),
		_pose("bus", "bus", 1.0, 90.0, 1, 1, 1100000)]
	var local: Array[Dictionary] = [_pose("bus", "bus", 0.7, 55.0, 1, 2, 1050000)]
	var result: Dictionary = GateTraceUtil.compare_traces(local, source)
	var error: Dictionary = result["bus_remote_error"]
	assert_int(GateMetricsUtil.integer(error["matched"])).is_equal(1)
	assert_int(GateMetricsUtil.integer(error["unmatched"])).is_equal(0)
	assert_float(GateMetricsUtil.number(error["p95_m"])).is_equal_approx(0.2, 0.000001)
	assert_float(GateMetricsUtil.number(error["max_deg"])).is_equal_approx(10.0, 0.0001)


func test_trace_does_not_interpolate_handover_or_fake_zero_without_matches() -> void:
	var source: Array[Dictionary] = [_pose("cargo/Box", "cargo", 0.0, 0.0, 1, 1, 1000000),
		_pose("cargo/Box", "cargo", 1.0, 0.0, 2, 2, 1100000)]
	var local: Array[Dictionary] = [_pose("cargo/Box", "cargo", 0.5, 0.0, 1, 2, 1050000),
		_pose("bus", "bus", 0.0, 0.0, 1, 1, 1050000)]
	var result: Dictionary = GateTraceUtil.compare_traces(local, source)
	var cargo: Dictionary = result["cargo_remote_error"]
	assert_int(GateMetricsUtil.integer(cargo["matched"])).is_equal(0)
	assert_int(GateMetricsUtil.integer(cargo["unmatched"])).is_equal(1)
	assert_bool(cargo["p95_m"] == null).is_true()
	var bus: Dictionary = result["bus_remote_error"]
	assert_bool(GateMetricsUtil.boolean(bus["applicable"])).is_false()
	assert_str(str(bus["status"])).is_equal("not_applicable")
	var absent: Dictionary = result["crew_remote_error"]
	assert_str(str(absent["status"])).is_equal("not_observed")
	source = [
		_pose("cargo/Box", "cargo", 0.0, 0.0, 2, 2, 1000000),
		_pose("cargo/Box", "cargo", 0.5, 0.0, 1, 2, 1100000),
		_pose("cargo/Box", "cargo", 1.0, 0.0, 2, 2, 1200000)]
	local = [_pose("cargo/Box", "cargo", 0.75, 0.0, 2, 1, 1150000)]
	result = GateTraceUtil.compare_traces(local, source)
	cargo = result["cargo_remote_error"]
	assert_int(GateMetricsUtil.integer(cargo["matched"])).is_equal(0)
	assert_int(GateMetricsUtil.integer(cargo["unmatched"])).is_equal(1)


func test_observer_filters_remote_penetration_and_preserves_simulation_counters() -> void:
	var bus: RigidBody3D = _bus()
	var packed: PackedScene = load("res://src/crew/crew_member.tscn") as PackedScene
	var crew: CrewMember = auto_free(packed.instantiate())
	crew.position = Vector3(0.0, -0.59, 0.0)
	add_child(crew)
	crew.set_physics_process(false)
	var remote: CrewMember = auto_free(packed.instantiate())
	remote.set_multiplayer_authority(23)
	remote.position = Vector3(0.0, -0.67, 2.0)
	add_child(remote)
	remote.set_physics_process(false)
	var cargo_scene: PackedScene = load("res://src/cargo/package.tscn") as PackedScene
	var cargo: Package = auto_free(cargo_scene.instantiate())
	cargo.name = "GateMetricPackage"
	cargo.freeze = true
	cargo.position = Vector3(1000.0, 0.0, 0.0)
	add_child(cargo)
	var activity: ActivitySource = auto_free(ActivitySource.new())
	add_child(activity)
	var observer: GateMetrics = auto_free(GateMetrics.new())
	add_child(observer)
	observer.set_process(false)
	observer.set_physics_process(false)
	observer.begin(bus, crew, activity)
	observer._process(0.0)
	assert_int(observer._frames.size()).is_equal(0)
	var bus_before: Transform3D = bus.global_transform
	observer._physics_process(1.0 / 60.0)
	crew.position.z += 0.02
	remote.physics_simulation_ticks += 1
	cargo.integration_callback_ticks += 7
	observer._physics_process(1.0 / 60.0)
	var result: Dictionary = observer.finish()
	assert_int(observer.tick_count).is_equal(2)
	assert_int(observer.process_physics_priority).is_equal(1000)
	assert_int(observer.process_priority).is_equal(1000)
	# v5: "slip" is the FILTERED series (supported and no cargo contact in the
	# previous three ticks). This fixture's crew has no bus support, so the
	# filtered series must be EMPTY and the displacement lives in slip_raw.
	assert_float(GateMetricsUtil.number(result["slip_raw"]["p99_m"])).is_equal_approx(0.02, 0.000001)
	assert_int(GateMetricsUtil.integer(result["slip"]["samples"])).is_equal(0)
	assert_float(GateMetricsUtil.number(result["penetration"]["max_depth_m"])).is_less(0.05)
	assert_bool(result.has("penetration_diagnostic")).is_true()
	if result.has("penetration_diagnostic"):
		assert_float(GateMetricsUtil.number(result["penetration_diagnostic"]["crew/23"]["max_depth_m"])).is_greater(0.05)
	assert_int(GateMetricsUtil.integer(result["remote_crew_simulation_ticks"])).is_equal(1)
	assert_int(GateMetricsUtil.integer(result["unauthorized_cargo_simulation_ticks"])).is_equal(0)
	var entities: Dictionary = result["simulation_entities"]
	var cargo_counters: Dictionary = entities["cargo/GateMetricPackage"]
	assert_int(GateMetricsUtil.integer(cargo_counters["integration_callback_ticks"])).is_equal(7)
	assert_int(GateMetricsUtil.integer(cargo_counters["physics_simulation_ticks"])).is_equal(0)
	assert_bool(bus.global_transform == bus_before).is_true()
	assert_bool(crew.position == Vector3(0.0, -0.59, 0.02)).is_true()
	assert_array(observer.get_trace()).is_not_empty()
	observer.begin(bus, crew, activity)
	for tick: int in range(60):
		observer._physics_process(1.0 / 60.0)
	var bus_samples: int = 0
	for sample: Dictionary in observer.get_trace():
		if sample["kind"] == "bus":
			bus_samples += 1
	assert_int(bus_samples).is_equal(10)
	observer.finish()
	observer.begin(bus, crew, activity)
	cargo.position = Vector3(0.0, -0.67, 2.0)
	cargo.freeze = false
	observer._physics_process(1.0 / 60.0)
	cargo.freeze = true
	observer._physics_process(1.0 / 60.0)
	cargo.freeze = false
	cargo.set_multiplayer_authority(23)
	observer._physics_process(1.0 / 60.0)
	var physical: Dictionary = observer.finish()["penetration"]["entities"]["cargo/GateMetricPackage"]
	assert_float(GateMetricsUtil.number(physical["max_depth_m"])).is_greater(0.05)
	assert_int(GateMetricsUtil.integer(physical["excluded_ticks"])).is_equal(2)
	assert_int(GateMetricsUtil.integer(physical["max_run_ticks"])).is_equal(1)


func _bus() -> RigidBody3D:
	var packed: PackedScene = load("res://src/vehicle/bus.tscn") as PackedScene
	var bus: RigidBody3D = auto_free(packed.instantiate())
	bus.freeze = true
	add_child(bus)
	return bus


func _valid_reading() -> Dictionary:
	var activity: Dictionary = {}
	for key: String in GateMetricsUtil.ACTIVITY_KEYS:
		activity[key] = 10
	return {"run_id": "same_test_run", "metrics_version": 5, "duration_s": 300.0, "ticks": 18000,
		"travel_samples": 18000, "cargo_contact_samples": 18000, "travel_observation_complete": true,
		"push_classification_complete": true, "hull_exit_ticks": 0,
		"pushes": {"count": 0, "max_duration_ticks": 0, "max_local_displacement_m": 0.0, "open_count": 0},
		"slip_raw": {"samples": 17999, "p99_m": 0.1, "max_m": 0.2},
		"off_bus_support_ticks": 0, "render_configuration": {"vsync_mode": 0, "max_fps": 0},
		"sampling_phase": GateMetricsUtil.SAMPLING_PHASE, "sampling_process_physics_priority": 1000,
		"sampling_process_priority": 1000, "activity": activity, "instrumentation_missing": [],
		"slip": {"p99_m": 0.1, "max_m": 0.2, "samples": 17999},
		"cameras": {"min": 1, "max": 1}, "unauthorized_cargo_simulation_ticks": 0,
		"remote_crew_simulation_ticks": 0, "penetration": {"max_depth_m": 0.05, "max_run_ticks": 3},
		"bus_remote_error": {"applicable": false, "status": "not_applicable", "local_samples": 1},
		"crew_remote_error": {"applicable": true, "status": "measured", "matched": 1},
		"cargo_remote_error": {"applicable": true, "status": "measured", "matched": 1},
		"fps": {"windowed": true, "frames": 18000, "p1": 60.0, "percent_below_60": 0.0}}


func _pose(entity: String, kind: String, x: float, degrees: float, authority: int,
		observer: int, utc_us: int) -> Dictionary:
	return GateTraceUtil.pose_sample(entity, kind, Transform3D(Basis(Vector3.UP, deg_to_rad(degrees)),
		Vector3(x, 0.0, 0.0)), authority, observer, utc_us)
## A box leaving the hand reads FREE for one tick while its `disabled` write is
## still deferred (package.gd:128 sets FREE, :135 defers the shape). Flagging
## that as missing instrumentation invalidated gate iteration 5, whose every
## criterion had passed. A body with no ACTIVE shape cannot penetrate anything.
func test_a_package_without_an_active_shape_is_excluded_not_missing_instrumentation() -> void:
	var bus: RigidBody3D = auto_free(RigidBody3D.new())
	bus.freeze = true
	add_child(bus)
	var crew: CrewMember = auto_free((load("res://src/crew/crew_member.tscn") as PackedScene).instantiate())
	crew.position = Vector3(0.0, -0.59, 0.0)
	add_child(crew)
	crew.set_physics_process(false)
	var cargo: Package = auto_free((load("res://src/cargo/package.tscn") as PackedScene).instantiate())
	cargo.name = "ShapelessPackage"
	cargo.freeze = true
	add_child(cargo)
	# FREE (so the restraint check does not exclude it) with every shape off,
	# which is exactly the one-tick window after a release.
	cargo.restraint = Package.Restraint.FREE
	for child: Node in cargo.get_children():
		if child is CollisionShape3D:
			var shape: CollisionShape3D = child
			shape.disabled = true
	var activity: ActivitySource = auto_free(ActivitySource.new())
	add_child(activity)
	var observer: GateMetrics = auto_free(GateMetrics.new())
	add_child(observer)
	observer.set_process(false)
	observer.set_physics_process(false)
	observer.begin(bus, crew, activity)
	observer._physics_process(1.0 / 60.0)
	var result: Dictionary = observer.finish()
	var missing: Array = result["instrumentation_missing"]
	for reason: Variant in missing:
		assert_str(str(reason)).not_contains("ShapelessPackage")
	var diagnostic: Dictionary = result["penetration_diagnostic"]
	assert_bool(diagnostic.has("cargo/ShapelessPackage")).is_true()
	if diagnostic.has("cargo/ShapelessPackage"):
		var row: Dictionary = diagnostic["cargo/ShapelessPackage"]
		assert_int(GateMetricsUtil.integer(row["excluded_ticks"])).is_equal(1)
		assert_float(GateMetricsUtil.number(row["max_depth_m"])).is_equal(0.0)

