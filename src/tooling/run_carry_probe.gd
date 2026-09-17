extends SceneTree

## Carry probe (M2-GATE, D92 — COMMITTED tooling, like run_demo.gd): how well
## does a crew member ride the bus when the bus's transform arrives at 30 Hz?
## Deterministic: one process, --fixed-fps 60. The demo's trajectory is
## RECORDED per crew regime (real bus) and REPLAYED onto the frozen bus with
## that regime's own trajectory and the three
## client mechanisms — (a) STATIC hold (today), (b) KINEMATIC hold, (c)
## KINEMATIC + 60 Hz interpolation between the last two 30 Hz snapshots with
## one snapshot of latency. The baseline row is the real bus itself (same
## window, fresh scene for each baseline and replay).
## Regimes: standing and walking the aisle (bounded, bus-frame drive_move).
## Both write phases are measurable; neither is required to improve carry.
## All rows use a separate read-only node after physics callbacks, with
## process_physics_priority=1000 and process_priority=1000 (round 3b).
## Metrics per tick in the bus frame: drift, PER-TICK slip (the jitter the
## gate forbids), ticks without bus support, hull violations with depth and run
## length. Raw per-tick CSVs + summary JSON land in user://carryprobe/.
##   godot --headless --fixed-fps 60 --path . -s res://src/tooling/run_carry_probe.gd [++ window_s=60] [++ save_raw=1]
##   ... ++ mode=speed for the straight-line speed runs.
##   ... ++ write=physics_process compares the alternative write phase.

const ReplayDriver: GDScript = preload("res://src/tooling/carry_probe_replay.gd")
const ProbeMetrics: GDScript = preload("res://src/tooling/carry_probe_metrics.gd")
const ProbeSampler: GDScript = preload("res://src/tooling/carry_probe_sampler.gd")
const SCENE_PATH: String = "res://scenes/playground.tscn"
const AISLE_POINT: Vector3 = Vector3(0.0, -0.6, 0.5)
const WALK_BOUND_Z: float = 2.5
const HULL_X: float = 1.15
const HULL_Z: float = 3.8
const HULL_FLOOR_Y: float = -0.60
const HULL_Y_MIN: float = -0.65
const HULL_Y_MAX: float = 1.30
# The bump field, from playground.tscn: BumpField at x=30, tables x∈[24,36],
# z from ~2 (first ramp base) to ~46 (second descent end).
const BUMP_MIN: Vector2 = Vector2(24.0, 2.0)
const BUMP_MAX: Vector2 = Vector2(36.0, 46.0)
const SETTLE_TICKS: int = 10

var _mode: String = "table"
var _window_ticks: int = 3600
var _save_raw: bool = false
var _write_phase: String = "physics_frame"
var _out_dir: String = "user://carryprobe"

var _scene: Node = null
var _bus: RigidBody3D = null
var _crew: CharacterBody3D = null
var _driver: Node = null
var _replay: ReplayDriver = null
var _sampler: ProbeSampler = null

var _recording: Array[Transform3D] = []
var _speeds: Array[float] = []

var _local_origin: Vector3 = Vector3.ZERO
var _local_prev: Vector3 = Vector3.ZERO
var _origin_set: bool = false
var _drifts: Array[float] = []
var _slips: Array[float] = []
var _off_bus_support: int = 0
var _below_ticks: int = 0
var _outside_ticks: int = 0
var _below_depth_max: float = 0.0
var _below_run: int = 0
var _below_run_max: int = 0
var _walk_dir: float = 1.0
var _raw_rows: Array[String] = []


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		var parts: PackedStringArray = arg.split("=", true, 1)
		if parts.size() != 2:
			continue
		match parts[0]:
			"mode":
				_mode = parts[1]
			"window_s":
				_window_ticks = int(maxf(5.0, parts[1].to_float()) * 60.0)
			"save_raw":
				_save_raw = parts[1] == "1"
			"write":
				_write_phase = parts[1]
	process_frame.connect(_start, CONNECT_ONE_SHOT)


func _start() -> void:
	if _write_phase not in ["physics_frame", "physics_process"]:
		printerr("CARRY unknown write phase: ", _write_phase)
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(_out_dir)
	match _mode:
		"table":
			await _run_table()
		"speed":
			await _run_speed()
		_:
			printerr("CARRY unknown mode: ", _mode)
			quit(1)


func _load_scene() -> void:
	if _scene != null:
		_scene.queue_free()
		await process_frame
	var packed: Resource = load(SCENE_PATH)
	if not (packed is PackedScene):
		printerr("CARRY could not load the playground")
		quit(1)
		return
	var packed_scene: PackedScene = packed
	var scene: Node = packed_scene.instantiate()
	scene.set("demo_mode", true)
	scene.set("cargo_spawn", false)
	root.add_child(scene)
	_scene = scene
	var bus_node: Node = get_first_node_in_group("bus")
	var crew_node: Node = get_first_node_in_group("crew")
	if bus_node is RigidBody3D:
		_bus = bus_node
	if crew_node is CharacterBody3D:
		_crew = crew_node
	_driver = scene.get_node_or_null("DemoDriver")
	_replay = null
	_sampler = ProbeSampler.new()
	_scene.add_child(_sampler)
	# The crew boards a parked bus before the demo builds speed.
	_crew.global_position = _bus.global_transform * AISLE_POINT
	_crew.velocity = Vector3.ZERO
	_crew.set("aboard", true)


func _settle() -> void:
	for i: int in range(SETTLE_TICKS):
		await physics_frame


# The separate sampler reads after writers and move_and_slide in every row.
func _measure_window(walking: bool, record: bool) -> void:
	_origin_set = false
	_drifts = []
	_slips = []
	_off_bus_support = 0
	_below_ticks = 0
	_outside_ticks = 0
	_below_depth_max = 0.0
	_below_run = 0
	_below_run_max = 0
	_raw_rows = []
	_walk_dir = 1.0
	for step: int in range(_window_ticks + 1):
		await _sampler.completed_tick
		if step > 0:
			if record:
				_recording.append(_bus.global_transform)
				var speed_v: Variant = _bus.call("speed_mps")
				if speed_v is float:
					var speed: float = speed_v
					_speeds.append(speed)
			_measure_tick()
		if walking and step < _window_ticks:
			_walk_tick()


func _measure_tick() -> void:
	var local: Vector3 = _bus.global_transform.affine_inverse() * _crew.global_position
	if not _origin_set:
		_local_origin = local
		_local_prev = local
		_origin_set = true
	var drift: float = local.distance_to(_local_origin)
	var slip: float = local.distance_to(_local_prev)
	_local_prev = local
	_drifts.append(drift)
	_slips.append(slip)
	var on_bus: bool = ProbeMetrics.has_bus_support(_crew, _bus, local)
	if not on_bus:
		_off_bus_support += 1
	var depth: float = HULL_FLOOR_Y - local.y
	if local.y < HULL_Y_MIN:
		_below_ticks += 1
		_below_run += 1
		_below_run_max = maxi(_below_run_max, _below_run)
		_below_depth_max = maxf(_below_depth_max, depth)
	else:
		_below_run = 0
	if absf(local.x) > HULL_X or absf(local.z) > HULL_Z or local.y > HULL_Y_MAX:
		_outside_ticks += 1
	if _save_raw:
		_raw_rows.append("%d,%.4f,%.4f,%.4f,%.4f,%.4f,%d,%.4f" % [
			_drifts.size(), local.x, local.y, local.z, drift, slip,
			1 if on_bus else 0, maxf(0.0, depth)])


func _walk_tick() -> void:
	var local: Vector3 = _bus.global_transform.affine_inverse() * _crew.global_position
	if local.z > WALK_BOUND_Z:
		_walk_dir = -1.0
	elif local.z < -WALK_BOUND_Z:
		_walk_dir = 1.0
	_crew.drive_move(Vector2(0.0, _walk_dir), false, false, _bus.global_transform.basis)


func _percentile(values: Array[float], fraction: float) -> float:
	return ProbeMetrics.percentile(values, fraction)


func _reading() -> Dictionary:
	return {
		"drift_max_m": _percentile(_drifts, 1.0),
		"drift_p95_m": _percentile(_drifts, 0.95),
		"slip_max_m": _percentile(_slips, 1.0),
		"slip_p95_m": _percentile(_slips, 0.95),
		"slip_p99_m": _percentile(_slips, 0.99),
		"slip_p999_m": _percentile(_slips, 0.999),
		"off_bus_support_ticks": _off_bus_support,
		"below_floor_ticks": _below_ticks,
		"below_depth_max_m": _below_depth_max,
		"below_run_max_ticks": _below_run_max,
		"outside_hull_ticks": _outside_ticks,
	}


func _report_pass(config: String, regime: String) -> void:
	print("CARRY pass=%s_%s window=%ds drift_max=%.3f drift_p95=%.3f slip_max=%.4f slip_p95=%.4f slip_p99=%.4f slip_p999=%.4f off_bus_support=%d/%d below=%d(depth=%.2f,run=%d) outside=%d" % [
		config, regime, _window_ticks / 60, _percentile(_drifts, 1.0), _percentile(_drifts, 0.95),
		_percentile(_slips, 1.0), _percentile(_slips, 0.95), _percentile(_slips, 0.99),
		_percentile(_slips, 0.999), _off_bus_support, _window_ticks,
		_below_ticks, _below_depth_max, _below_run_max, _outside_ticks])
	if _save_raw:
		var file: FileAccess = FileAccess.open(
			"%s/%s_%s.csv" % [_out_dir, config, regime], FileAccess.WRITE)
		if file != null:
			file.store_line("tick,local_x,local_y,local_z,drift_m,slip_m,on_bus_support,below_depth_m")
			for row: String in _raw_rows:
				file.store_line(row)
			file.close()


func _freeze_bus(kinematic: bool) -> void:
	_bus.freeze = true
	if kinematic:
		_bus.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	if _driver != null:
		_driver.set("enabled", false)
	_bus.call("set_drive", 0.0, 0.0, 1.0)


# Baseline pass: the REAL bus with the demo at the wheel; the trajectory the
# replays consume comes from their matching regime. Fresh scene per call.
func _record_pass(walking: bool) -> Dictionary:
	await _load_scene()
	_recording = []
	_speeds = []
	await _settle()
	await _measure_window(walking, true)
	_report_pass("host_real", "walking" if walking else "standing")
	return _reading()


func _replay_pass(config: String, walking: bool) -> Dictionary:
	await _load_scene()
	_freeze_bus(config != "static")
	_bus.global_transform = _recording[0]
	_crew.global_position = _bus.global_transform * AISLE_POINT
	_crew.velocity = Vector3.ZERO
	await _settle()
	_replay = ReplayDriver.new()
	_replay.bus = _bus
	_replay.recording = _recording
	_replay.interp = config == "interp"
	_replay.write_phase = _write_phase
	_replay.process_priority = -100
	_scene.add_child(_replay)
	await _measure_window(walking, false)
	_report_pass(config, "walking" if walking else "standing")
	_replay.stop()
	_replay.queue_free()
	_replay = null
	_bus.freeze = false
	_bus.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
	return _reading()


func _run_table() -> void:
	var summary: Array[Dictionary] = []
	var base_standing: Dictionary = await _record_pass(false)
	var recording_standing: Array[Transform3D] = _recording.duplicate()
	var speeds_standing: Array[float] = _speeds.duplicate()
	# Walking can perturb the dynamic bus; each regime keeps its own recording.
	var base_walking: Dictionary = await _record_pass(true)
	var recording_walking: Array[Transform3D] = _recording.duplicate()
	var trajectory_delta: Dictionary = ProbeMetrics.trajectory_distances(recording_standing, recording_walking)
	print("CARRY trajectory_distance: ", JSON.stringify(trajectory_delta))
	base_standing["config"] = "host_real"
	base_standing["regime"] = "standing"
	base_walking["config"] = "host_real"
	base_walking["regime"] = "walking"
	summary.append(base_standing)
	summary.append(base_walking)
	for config: String in ["static", "kinematic", "interp"]:
		for walking: bool in [false, true]:
			_recording = recording_walking if walking else recording_standing
			var reading: Dictionary = await _replay_pass(config, walking)
			reading["config"] = config
			reading["regime"] = "walking" if walking else "standing"
			summary.append(reading)
	var file: FileAccess = FileAccess.open(_out_dir + "/summary.json", FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"window_s": _window_ticks / 60,
			"sampling_phase": "after_all_node_physics",
			"sampling_process_physics_priority": 1000, "sampling_process_priority": 1000,
			"write_phase": _write_phase, "trajectory_distance": trajectory_delta, "passes": summary}, "\t"))
		file.close()
	_recording = recording_standing
	_speeds = speeds_standing
	_speed_section_from_recording()
	quit(0)


func _speed_section_from_recording() -> void:
	var peak: float = 0.0
	var bump_sum: float = 0.0
	var bump_max: float = 0.0
	var bump_min: float = INF
	var bump_ticks: int = 0
	for i: int in range(_speeds.size()):
		var speed_kmh: float = _speeds[i] * 3.6
		peak = maxf(peak, speed_kmh)
		var origin: Vector3 = _recording[i].origin
		if origin.x >= BUMP_MIN.x and origin.x <= BUMP_MAX.x and origin.z >= BUMP_MIN.y and origin.z <= BUMP_MAX.y:
			bump_sum += speed_kmh
			bump_max = maxf(bump_max, speed_kmh)
			bump_min = minf(bump_min, speed_kmh)
			bump_ticks += 1
	var bump_avg: float = bump_sum / maxf(1.0, float(bump_ticks))
	print("SPEED lap_peak_kmh=%.1f bumps_avg_kmh=%.1f bumps_max_kmh=%.1f bumps_min_kmh=%.1f bumps_ticks=%d" % [
		peak, bump_avg, bump_max, bump_min if bump_ticks > 0 else 0.0, bump_ticks])


# --- speed mode ---------------------------------------------------------------
# (1) the bump-field lane from its south edge — the attack speed at the first
# bump; (2) an open lane measuring distance and time to reach 80 km/h.
func _run_speed() -> void:
	await _load_scene()
	if _driver != null:
		_driver.set("enabled", false)
	await _speed_run(Vector3(30.0, 0.6, -95.0), 2.0, "attack")
	await _speed_run(Vector3(-60.0, 0.6, -95.0), 90.0, "reach80")
	quit(0)


func _speed_run(start: Vector3, stop_z: float, label: String) -> void:
	_bus.global_position = start
	_bus.global_rotation = Vector3(0.0, PI, 0.0)
	_bus.linear_velocity = Vector3.ZERO
	_bus.angular_velocity = Vector3.ZERO
	var max_ticks: int = 30 * 60
	var entry_speed: float = 0.0
	var reach80_dist: float = -1.0
	var reach80_t: float = -1.0
	for tick: int in range(max_ticks):
		await physics_frame
		_bus.call("set_drive", 1.0, 0.0, 0.0)
		var speed_v: Variant = _bus.call("speed_mps")
		if not (speed_v is float):
			continue
		var speed: float = speed_v
		if label == "attack" and _bus.global_position.z >= stop_z:
			entry_speed = speed
			break
		if label == "reach80" and speed * 3.6 >= 80.0:
			reach80_dist = _bus.global_position.z - start.z
			reach80_t = float(tick) / 60.0
			break
		if _bus.global_position.z >= stop_z + 100.0:
			break
	if label == "attack":
		print("SPEED attack_entry_kmh=%.1f from_start_m=%.1f" % [entry_speed * 3.6, _bus.global_position.z - start.z])
	else:
		print("SPEED reach80 dist_m=%.1f t_s=%.1f (not reached if dist<0)" % [reach80_dist, reach80_t])
