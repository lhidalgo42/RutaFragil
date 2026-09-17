class_name GateMetricsUtil
extends RefCounted

## Pure reductions keep D95 thresholds independent from capture and movement.
const SAMPLING_PHASE: String = "after_all_node_physics"
const PENETRATION_REST_M: float = 0.03
## Below this, a depth reading is solver noise, not contact.
const NOISE_EPSILON_M: float = 0.000001
const ACTIVITY_KEYS: Array[String] = ["hold_requested", "hold_granted", "hold_denied",
	"release", "strap_ok", "strap_denied", "unstrap", "authority_transfers", "complete_cycles"]


static func percentile(values: Array[float], fraction: float) -> float:
	if values.is_empty():
		return 0.0
	var ordered: Array[float] = values.duplicate()
	ordered.sort()
	return ordered[clampi(integer(fraction * number(ordered.size() - 1)), 0, ordered.size() - 1)]


static func slip_summary(values: Array[float]) -> Dictionary:
	return {"samples": values.size(), "p95_m": percentile(values, 0.95),
		"p99_m": percentile(values, 0.99), "p999_m": percentile(values, 0.999),
		"max_m": percentile(values, 1.0)}


static func fps_summary(frame_seconds: Array[float], windowed: bool) -> Dictionary:
	var rates: Array[float] = []
	var below: int = 0
	for seconds: float in frame_seconds:
		if seconds <= 0.0:
			continue
		var fps: float = 1.0 / seconds
		rates.append(fps)
		if fps < 60.0:
			below += 1
	return {"frames": rates.size(), "p1": percentile(rates, 0.01),
		"percent_below_60": 100.0 * number(below) / maxf(1.0, number(rates.size())),
		"windowed": windowed, "render_no_verificado": not windowed}


static func penetration_step(previous: Dictionary, depth: float, eligible: bool = true) -> Dictionary:
	# Resting overlap is reported in the maximum and histogram, but only
	# overlap strictly above the review-05 rest threshold extends a run.
	var run: int = integer(previous.get("current_run_ticks", 0)) + 1 if eligible and depth > PENETRATION_REST_M else 0
	var histogram: Dictionary = previous.get("depth_histogram", {})
	if eligible:
		var bin: String = "gt_5cm"
		if depth <= 0.000001:
			bin = "le_1um"
		elif depth <= 0.01:
			bin = "1um_to_1cm"
		elif depth <= 0.02:
			bin = "1_to_2cm"
		elif depth <= 0.03:
			bin = "2_to_3cm"
		elif depth <= 0.04:
			bin = "3_to_4cm"
		elif depth <= 0.05:
			bin = "4_to_5cm"
		histogram[bin] = integer(histogram.get(bin, 0)) + 1
	return {"max_depth_m": maxf(number(previous.get("max_depth_m", 0.0)), depth),
		"current_run_ticks": run,
		"max_run_ticks": maxi(integer(previous.get("max_run_ticks", 0)), run),
		"penetrating_ticks": integer(previous.get("penetrating_ticks", 0)) + (1 if run > 0 else 0),
		"run_threshold_m": PENETRATION_REST_M, "depth_histogram": histogram,
		"eligible_samples": integer(previous.get("eligible_samples", 0)) + (1 if eligible else 0),
		"samples": integer(previous.get("samples", 0)) + 1}


static func vector_array(value: Vector3) -> Array[float]:
	return [value.x, value.y, value.z]


static func judge(host: Dictionary, client: Dictionary) -> Dictionary:
	var invalid: Array[String] = []
	var failures: Array[String] = []
	var render_verified: bool = true
	var slip_judged: bool = true
	if str(host.get("run_id", "")).is_empty() or host.get("run_id") != client.get("run_id"):
		invalid.append("host and client must identify the same run")
	for index: int in range(2):
		var reading: Dictionary = host if index == 0 else client
		var role: String = "host" if index == 0 else "client"
		_validate(reading, role, invalid)
		if integer(reading.get("hull_exit_ticks", -1)) > 0:
			failures.append(role + ": local crew left the bus hull")
		var pushes: Dictionary = reading.get("pushes", {})
		if integer(pushes.get("max_duration_ticks", -1)) > 45:
			failures.append(role + ": cargo push exceeds 45 ticks")
		var filtered: Dictionary = reading.get("slip", {})
		if integer(filtered.get("samples", 0)) <= 0:
			slip_judged = false
		var cameras: Dictionary = reading.get("cameras", {})
		if integer(cameras.get("min", -1)) != 1 or integer(cameras.get("max", -1)) != 1:
			failures.append(role + ": active cameras must stay exactly one")
		if integer(reading.get("unauthorized_cargo_simulation_ticks", -1)) != 0:
			failures.append(role + ": unauthorized cargo simulation")
		if integer(reading.get("remote_crew_simulation_ticks", -1)) != 0:
			failures.append(role + ": remote crew simulation")
		var penetration: Dictionary = reading.get("penetration", {})
		if number(penetration.get("max_depth_m", INF)) > 0.05:
			failures.append(role + ": hull penetration exceeds 0.05 m")
		if integer(penetration.get("max_run_ticks", 2147483647)) > 3:
			failures.append(role + ": hull penetration exceeds 3 ticks")
		var fps: Dictionary = reading.get("fps", {})
		var render: Dictionary = reading.get("render_configuration", {})
		if not boolean(fps.get("windowed", false)) or integer(render.get("vsync_mode", -1)) != 0 \
				or integer(render.get("max_fps", -1)) != 0:
			render_verified = false
		elif integer(fps.get("frames", 0)) == 0:
			invalid.append(role + ": no rendered frame measurements")
		elif number(fps.get("p1", 0.0)) < 60.0:
			failures.append(role + ": FPS p1 below 60")
	var host_slip: Dictionary = host.get("slip", {})
	var client_slip: Dictionary = client.get("slip", {})
	var host_p99: float = number(host_slip.get("p99_m", 0.0))
	var client_p99: float = number(client_slip.get("p99_m", INF))
	if slip_judged and client_p99 > 1.5 * host_p99:
		failures.append("client slip p99 exceeds 1.5 times same-run host")
	var valid: bool = invalid.is_empty()
	var logic_passed: bool = valid and failures.is_empty()
	var status: String = "invalid"
	if valid:
		status = "failed" if not logic_passed else ("passed" if render_verified else "unverified")
	return {"valid": valid, "logic_passed": logic_passed, "render_verified": render_verified,
		"status": status, "invalid_reasons": invalid, "failures": failures,
		"slip_judged": slip_judged, "slip_p99_limit_m": 1.5 * host_p99, "slip_p99_client_m": client_p99,
		"slip_p99_ratio": client_p99 / host_p99 if slip_judged and host_p99 > 0.0 else null,
		"render_no_verificado": not render_verified,
		"human_gate_approval": "pending"}


static func _validate(reading: Dictionary, role: String, invalid: Array[String]) -> void:
	if not travel_complete(reading):
		invalid.append(role + ": incomplete v5 travel observation")
	var off_support: int = integer(reading.get("off_bus_support_ticks", -1))
	if off_support < 0 or off_support > integer(reading.get("ticks", 0)):
		invalid.append(role + ": missing or invalid bus support count")
	if number(reading.get("duration_s", 0.0)) + 0.000001 < 300.0 or integer(reading.get("ticks", 0)) < 18000:
		invalid.append(role + ": requires 300 seconds and 18000 physics ticks")
	if reading.get("sampling_phase", "") != SAMPLING_PHASE or integer(reading.get("sampling_process_physics_priority", 0)) != 1000 or integer(reading.get("sampling_process_priority", 0)) != 1000:
		invalid.append(role + ": incompatible sampling phase")
	var activity: Dictionary = reading.get("activity", {})
	for key: String in ACTIVITY_KEYS:
		if not activity.has(key):
			invalid.append(role + ": missing activity counter " + key)
	if integer(activity.get("complete_cycles", 0)) < 10:
		invalid.append(role + ": fewer than ten complete cargo cycles")
	var missing: Array = reading.get("instrumentation_missing", [])
	if not missing.is_empty():
		invalid.append(role + ": missing instrumentation " + str(missing))
	var slip: Dictionary = reading.get("slip", {})
	var filtered_samples: int = integer(slip.get("samples", 0))
	if filtered_samples <= 0 or filtered_samples > integer(reading.get("ticks", 0)) - 1:
		invalid.append(role + ": missing or invalid filtered slip samples")
	if not reading.has("penetration") or not reading.has("cameras") or not reading.has("fps"):
		invalid.append(role + ": missing observer summaries")
	for kind: String in ["bus", "crew", "cargo"]:
		var error: Dictionary = reading.get(kind + "_remote_error", {})
		if error.is_empty() or str(error.get("status", "not_observed")) == "not_observed":
			invalid.append(role + ": missing " + kind + " trace observations")
		elif boolean(error.get("applicable", false)) and integer(error.get("matched", 0)) == 0:
			invalid.append(role + ": no matched remote " + kind + " observations")


static func travel_complete(reading: Dictionary) -> bool:
	var ticks: int = integer(reading.get("ticks"), -1)
	var raw: Dictionary = reading.get("slip_raw", {})
	var pushes: Dictionary = reading.get("pushes", {})
	var exits: int = integer(reading.get("hull_exit_ticks"), -1)
	var count: int = integer(pushes.get("count"), -1)
	var open_count: int = integer(pushes.get("open_count"), -1)
	var duration: int = integer(pushes.get("max_duration_ticks"), -1)
	return integer(reading.get("metrics_version"), -1) == 5 and ticks > 0 \
		and integer(reading.get("travel_samples"), -1) == ticks \
		and integer(reading.get("cargo_contact_samples"), -1) == ticks \
		and boolean(reading.get("travel_observation_complete")) \
		and boolean(reading.get("push_classification_complete")) \
		and integer(raw.get("samples"), -1) == ticks - 1 \
		and exits >= 0 and exits <= ticks and count >= 0 and count <= ticks \
		and open_count >= 0 and open_count <= count and duration >= 0 and duration <= ticks \
		and reading.get("sampling_phase", "") == SAMPLING_PHASE \
		and integer(reading.get("sampling_process_physics_priority"), -1) == 1000 \
		and integer(reading.get("sampling_process_priority"), -1) == 1000


static func number(value: Variant, fallback: float = 0.0) -> float:
	if value is float:
		return value
	if value is int:
		var integer_value: int = value
		return float(integer_value)
	return fallback


static func integer(value: Variant, fallback: int = 0) -> int:
	if value is int:
		return value
	if value is float:
		var decimal: float = value
		return int(decimal)
	return fallback


static func boolean(value: Variant, fallback: bool = false) -> bool:
	if value is bool:
		return value
	return fallback
