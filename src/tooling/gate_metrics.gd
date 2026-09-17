class_name GateMetrics
extends Node

## A read-only observer: no drive, transform, authority or collision writes.
## Every pose, contact and counter is sampled after all node physics callbacks.
signal sampled(tick: int)


var tick_count: int = 0
var bus_receiver: NetBusSync = null
var _active: bool = false
var _bus: RigidBody3D = null
var _local_crew: CrewMember = null
var _cargo_sync: Node = null
var _peer_id: int = 1
var _elapsed_s: float = 0.0
var _start_utc_us: int = 0
var _last_frame_us: int = 0
var _trace_elapsed: float = 0.0
var _frames: Array[float] = []
var _trace: Array[Dictionary] = []
var _tick_csv: PackedStringArray = []
var _origin: Vector3 = Vector3.ZERO
var _drift: Vector3 = Vector3.ZERO
var _drift_max: Vector3 = Vector3.ZERO
var _have_origin: bool = false
var _off_support: int = 0
var _cameras_min: int = 2147483647
var _cameras_max: int = 0
var _missing: Array[String] = []
var _penetration: Dictionary = {}
var _penetration_diagnostic: Dictionary = {}
var _simulation: Dictionary = {}
var _counter_previous: Dictionary = {}
var _activity_start: Dictionary = {}
var _unauthorized_cargo: int = 0
var _remote_crew_simulation: int = 0
var _hull: GateHullProbe = GateHullProbe.new()
var _result: Dictionary = {}
var _support_probe: GateSupportProbe = GateSupportProbe.new()
var _travel: GateTravelMetrics = GateTravelMetrics.new()


func _ready() -> void:
	process_priority = 1000
	process_physics_priority = 1000


func begin(bus: RigidBody3D, local_crew: CrewMember, cargo_sync: Node) -> void:
	_bus = bus
	_local_crew = local_crew
	_cargo_sync = cargo_sync
	_peer_id = multiplayer.get_unique_id()
	tick_count = 0
	_elapsed_s = 0.0
	_start_utc_us = GateMetricsUtil.integer(Time.get_unix_time_from_system() * 1000000.0)
	_last_frame_us = 0
	_trace_elapsed = 0.0
	_frames.clear()
	_trace.clear()
	_tick_csv = ["tick,utc_us,local_x,local_y,local_z,slip_m,bus_support,bus_x,bus_y,bus_z,snapshots_received,source_s,playback_s,bus_write_m,inside_hull,cargo_contact,cargo_contact_previous_three,slip_eligible,push_active,cargo_history_complete"]
	_missing.clear()
	_penetration.clear()
	_penetration_diagnostic.clear()
	_simulation.clear()
	_counter_previous.clear()
	_result.clear()
	_support_probe.reset()
	_travel.reset()
	_have_origin = false
	_drift = Vector3.ZERO
	_drift_max = Vector3.ZERO
	_off_support = 0
	_cameras_min = 2147483647
	_cameras_max = 0
	_unauthorized_cargo = 0
	_remote_crew_simulation = 0
	if not is_instance_valid(bus) or not is_instance_valid(local_crew):
		_missing.append("bus or local crew absent at begin")
		return
	_hull.configure(bus)
	for piece: String in _hull.missing:
		_missing.append("hull piece " + piece)
	_activity_start = _activity()
	_read_counters(true)
	_active = true


func _process(_delta: float) -> void:
	if not _active:
		return
	var now: int = Time.get_ticks_usec()
	if _last_frame_us == 0:
		_last_frame_us = now
		return
	_frames.append(GateMetricsUtil.number(now - _last_frame_us) / 1000000.0)
	_last_frame_us = now


func _physics_process(delta: float) -> void:
	if not _active:
		return
	tick_count += 1
	_elapsed_s += delta
	if is_instance_valid(_bus) and is_instance_valid(_local_crew):
		_read_local()
		_read_hull()
	else:
		_missing_once("bus or local crew disappeared")
	_read_counters(false)
	var cameras: int = _active_cameras()
	_cameras_min = mini(_cameras_min, cameras)
	_cameras_max = maxi(_cameras_max, cameras)
	_trace_elapsed += delta
	if tick_count == 1 or _trace_elapsed + 0.000001 >= 0.1:
		_append_trace()
		_trace_elapsed = maxf(0.0, _trace_elapsed - 0.1)
	sampled.emit(tick_count)


func finish() -> Dictionary:
	if not _result.is_empty():
		return _result.duplicate(true)
	_active = false
	if tick_count > 0:
		_append_trace()
	var depth: float = 0.0
	var run: int = 0
	for entity: String in _penetration:
		var record: Dictionary = _penetration[entity]
		depth = maxf(depth, GateMetricsUtil.number(record["max_depth_m"]))
		run = maxi(run, GateMetricsUtil.integer(record["max_run_ticks"]))
	var activity: Dictionary = _activity()
	for key: String in activity:
		activity[key] = GateMetricsUtil.integer(activity[key]) - GateMetricsUtil.integer(_activity_start.get(key, 0))
	_result = {"peer_id": _peer_id, "ticks": tick_count, "duration_s": _elapsed_s,
		"start_utc_us": _start_utc_us, "finish_utc_us": GateMetricsUtil.integer(Time.get_unix_time_from_system() * 1000000.0),
		"sampling_phase": GateMetricsUtil.SAMPLING_PHASE, "sampling_process_priority": process_priority,
		"sampling_process_physics_priority": process_physics_priority,
		"off_bus_support_ticks": _off_support,
		"cargo_contact_samples": _support_probe.cargo_contact_samples,
		"push_classification_complete": _support_probe.push_classification_complete,
		"pushes": _support_probe.push_summary(),
		"bus_support": {"supported_ticks": tick_count - _off_support, "total_ticks": tick_count,
			"percent": 100.0 * float(tick_count - _off_support) / maxf(1.0, float(tick_count)),
			"last_tick_supported": _support_probe.last_supported, "max_off_run_ticks": _support_probe.max_off_run},
		"support_loss_count": _support_probe.events.size(),
		"drift_final_m": GateMetricsUtil.vector_array(_drift), "drift_max_abs_m": GateMetricsUtil.vector_array(_drift_max),
		"penetration": {"max_depth_m": depth, "max_run_ticks": run, "entities": _penetration.duplicate(true),
			"method": "finite authored hull boxes; capsule distance / oriented box SAT",
			"excluded": "remote crew; seated crew; frozen, replica, HELD or STRAPPED cargo",
			"run_threshold_m": GateMetricsUtil.PENETRATION_REST_M, "noise_epsilon_m": GateMetricsUtil.NOISE_EPSILON_M},
		"penetration_diagnostic": _penetration_diagnostic.duplicate(true),
		"fps": GateMetricsUtil.fps_summary(_frames, DisplayServer.get_name() != "headless"),
		"display_server": DisplayServer.get_name(),
		"cameras": {"min": _cameras_min if tick_count > 0 else 0, "max": _cameras_max},
		"unauthorized_cargo_simulation_ticks": _unauthorized_cargo,
		"remote_crew_simulation_ticks": _remote_crew_simulation,
		"simulation_entities": _simulation.duplicate(true), "activity": activity,
		"simulation_counter_semantics": "integration_callback_ticks includes frozen callbacks; physics_simulation_ticks counts dynamic integration only",
		"instrumentation_missing": _missing.duplicate(), "trace_samples": _trace.size(),
		"trace_clock": "system UTC microseconds, same machine", "trace_hz": 10}
	_result.merge(_travel.summary())
	if bus_receiver != null:
		_result["bus_interpolation_delay_s"] = bus_receiver.interpolation_delay_s
		_result["bus_buffer_underrun_ticks"] = bus_receiver.buffer_underrun_ticks
		_result["bus_write_phase"] = "node_physics_priority_minus_100"
	_result["render_configuration"] = {"max_fps": Engine.max_fps,
		"vsync_mode": DisplayServer.window_get_vsync_mode() if DisplayServer.get_name() != "headless" else -1,
		"viewport_size": [get_viewport().get_visible_rect().size.x, get_viewport().get_visible_rect().size.y]}
	var fps: Dictionary = _result["fps"]
	var render: Dictionary = _result["render_configuration"]
	fps["render_no_verificado"] = not GateMetricsUtil.boolean(fps["windowed"]) \
		or GateMetricsUtil.integer(render["vsync_mode"]) != 0 or Engine.max_fps != 0
	return _result.duplicate(true)


func get_trace() -> Array[Dictionary]:
	return _trace.duplicate(true)


func get_tick_csv() -> String:
	return "\n".join(_tick_csv) + "\n"


func get_support_losses() -> Array[Dictionary]:
	return _support_probe.events.duplicate(true)


func _read_local() -> void:
	var local: Vector3 = _bus.global_transform.affine_inverse() * _local_crew.global_position
	if not _have_origin:
		_origin = local
		_have_origin = true
	_drift = local - _origin
	_drift_max = _drift_max.max(_drift.abs())
	var support: bool = CarryProbeMetrics.has_bus_support(_local_crew, _bus, local)
	if not support:
		_off_support += 1
	_support_probe.observe(tick_count, _local_crew, _bus, bus_receiver, support)
	_travel.observe(tick_count, local, support, _support_probe.last_cargo_contact,
		_support_probe.cargo_contact_previous_three, _support_probe.history_complete)
	var timing: Array[float] = [0.0, 0.0, 0.0, 0.0]
	if bus_receiver != null:
		timing = bus_receiver.timing_sample()
	var p: Vector3 = _bus.global_position
	_tick_csv.append("%d,%d,%.9f,%.9f,%.9f,%.9f,%d,%.9f,%.9f,%.9f,%d,%.9f,%.9f,%.9f,%d,%d,%d,%d,%d,%d" % [
		tick_count, GateMetricsUtil.integer(Time.get_unix_time_from_system() * 1000000.0),
		local.x, local.y, local.z, _travel.last_slip_m, int(support), p.x, p.y, p.z,
		GateMetricsUtil.integer(timing[0]), timing[1], timing[2], timing[3],
		int(_travel.inside_hull), int(_support_probe.last_cargo_contact),
		int(_support_probe.cargo_contact_previous_three), int(_travel.slip_eligible),
		int(_support_probe.active_push()), int(_support_probe.history_complete)])


func _read_hull() -> void:
	for group: String in ["crew", "package"]:
		for node: Node in get_tree().get_nodes_in_group(group):
			if node is not Node3D:
				continue
			var body: Node3D = node
			var excluded: bool = false
			if body is CrewMember:
				var member: CrewMember = body
				excluded = member.seated
			elif body is Package:
				var package: Package = body
				excluded = package.restraint == Package.Restraint.HELD
			var entity: String = _identity(body)
			var measured: Dictionary = {"depth_m": 0.0, "piece": ""}
			if not excluded:
				measured = _hull.measure(body, _bus.global_transform)
				if GateMetricsUtil.boolean(measured["unsupported_shape"]):
					_missing_once(entity + ": unsupported collision shape type")
				elif GateMetricsUtil.integer(measured["shapes"]) == 0:
					# A body with no ACTIVE shape cannot penetrate anything, so
					# this is an exclusion, not a missing measurement. The
					# restraint flag flips a tick before the deferred `disabled`
					# write flushes (package.gd:128 sets FREE, :135 defers the
					# shape), so a box leaving the hand reads FREE with its shape
					# still off. Flagging that invalidated iteration 5, whose
					# every criterion had passed.
					excluded = true
					measured = {"depth_m": 0.0, "piece": ""}
			_record_penetration(_penetration_diagnostic, entity, measured, excluded)
			var simulated: bool = false
			if body is CrewMember:
				var member: CrewMember = body
				simulated = member == _local_crew and member.get_multiplayer_authority() == _peer_id \
					and not member.seated and (not member.network_member or member.network_ready)
			elif body is Package:
				var package: Package = body
				simulated = package.restraint == Package.Restraint.FREE and not package.freeze \
					and not package.replica_only and package.get_multiplayer_authority() == _peer_id
			_record_penetration(_penetration, entity, measured, not simulated)


func _record_penetration(records: Dictionary, entity: String, measured: Dictionary, excluded: bool) -> void:
	var previous: Dictionary = records.get(entity, {})
	var depth: float = 0.0 if excluded else GateMetricsUtil.number(measured["depth_m"])
	var updated: Dictionary = GateMetricsUtil.penetration_step(previous, depth, not excluded)
	# Only the ticks that actually penetrate are kept, as [tick, depth] pairs.
	# The point of this array (evidence 17) is re-picking the resting threshold
	# later, and a tick at zero cannot move any threshold. Storing one entry per
	# tick per body wrote 18000 mostly-null values each: 17.6 MB across the 25
	# committed summaries, for no extra information.
	var depths: Array = previous.get("depth_samples_m", [])
	if not excluded and depth > GateMetricsUtil.NOISE_EPSILON_M:
		depths.append([tick_count, depth])
	updated["depth_samples_m"] = depths
	updated["depth_samples_note"] = "[tick, depth_m] pairs, penetrating ticks only"
	updated["excluded_ticks"] = GateMetricsUtil.integer(previous.get("excluded_ticks", 0)) + (1 if excluded else 0)
	updated["deepest_piece"] = measured["piece"] if depth > GateMetricsUtil.number(previous.get("max_depth_m", 0.0)) else previous.get("deepest_piece", "")
	records[entity] = updated


func _read_counters(baseline: bool) -> void:
	for group: String in ["crew", "package"]:
		for node: Node in get_tree().get_nodes_in_group(group):
			var entity: String = _identity(node)
			var counters: Array[String] = ["physics_simulation_ticks"]
			if group == "package":
				counters.append("unauthorized_simulation_ticks")
				counters.append("integration_callback_ticks")
			var totals: Dictionary = _simulation.get(entity, {})
			for counter: String in counters:
				var key: String = str(node.get_instance_id()) + ":" + counter
				if not _counter_previous.has(key) and not _has_property(node, counter):
					_missing_once(entity + ": " + counter)
					continue
				var current: int = GateMetricsUtil.integer(node.get(counter))
				var delta: int = 0 if baseline else maxi(0, current - GateMetricsUtil.integer(_counter_previous.get(key, 0)))
				_counter_previous[key] = current
				totals[counter] = GateMetricsUtil.integer(totals.get(counter, 0)) + delta
				if group == "crew" and node.get_multiplayer_authority() != _peer_id:
					_remote_crew_simulation += delta
				elif group == "package" and counter == "unauthorized_simulation_ticks":
					_unauthorized_cargo += delta
			_simulation[entity] = totals


func _append_trace() -> void:
	var now: int = GateMetricsUtil.integer(Time.get_unix_time_from_system() * 1000000.0)
	if is_instance_valid(_bus):
		_trace.append(GateTraceUtil.pose_sample("bus", "bus", _bus.global_transform, _bus.get_multiplayer_authority(), _peer_id, now))
	for group: String in ["crew", "package"]:
		for node: Node in get_tree().get_nodes_in_group(group):
			if node is Node3D:
				var spatial: Node3D = node
				_trace.append(GateTraceUtil.pose_sample(_identity(node), "crew" if group == "crew" else "cargo",
					spatial.global_transform, node.get_multiplayer_authority(), _peer_id, now))


func _activity() -> Dictionary:
	if not is_instance_valid(_cargo_sync) or not _cargo_sync.has_method("activity_for_peer"):
		_missing_once("cargo activity_for_peer")
		return {}
	var raw: Variant = _cargo_sync.call("activity_for_peer", _peer_id)
	if raw is not Dictionary:
		_missing_once("cargo activity dictionary")
		return {}
	var source: Dictionary = raw
	var counters: Dictionary = source.duplicate()
	for key: String in GateMetricsUtil.ACTIVITY_KEYS:
		if not counters.has(key):
			_missing_once("cargo activity " + key)
	return counters


func _active_cameras() -> int:
	var seen: Dictionary = {}
	for group: String in ["eye_camera", "cabin_camera", "chase_camera"]:
		for node: Node in get_tree().get_nodes_in_group(group):
			if node is Camera3D:
				var camera: Camera3D = node
				if camera.current:
					seen[node.get_instance_id()] = true
	return seen.size()


func _identity(node: Node) -> String:
	if node is CrewMember:
		return "crew/" + str(node.get_multiplayer_authority())
	return "cargo/" + str(node.name)


func _missing_once(reason: String) -> void:
	if reason not in _missing:
		_missing.append(reason)


func _has_property(node: Node, property_name: String) -> bool:
	for property: Dictionary in node.get_property_list():
		if str(property["name"]) == property_name:
			return true
	return false
