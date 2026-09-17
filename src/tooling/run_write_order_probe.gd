extends SceneTree

## Write-order probe (M2-GATE, g2.1). Answers ONE question with numbers:
## when a frozen KINEMATIC RigidBody3D is moved by assigning global_transform,
## does the CharacterBody3D riding it receive the platform velocity — and does
## WHERE the write happens change the answer?
##
## This is the probe that produced the g2.1 table in review 02. The reviewer
## wrote it in a throwaway worktree and deleted it, which was exactly the sin
## he had charged the previous executor with in round 1 (g0.2: a measurement
## that decides an architecture must be committed). It is committed now.
##
## Modes:
##   mode=rec                          record the real bus trajectory once
##   mode=run path=step|interp order=frame|before|after|velocity [ticks=N]
##
##   path=step    the receiver holds the last 30 Hz snapshot for 2 ticks
##   path=interp  the receiver interpolates to 60 Hz between the last two
##                snapshots, one snapshot of latency
##   order=frame     the write happens in the SceneTree physics_frame callback
##   order=before    the write happens in a node's _physics_process, priority -100
##   order=after     ... priority +100
##   order=velocity  like `before`, plus setting linear_velocity by hand
##
## What it reports, per configuration: the crew's per-tick SLIP in the bus
## frame (p95/p99/p99.9/max — the jitter the gate forbids) and, decisively,
## the ratio between the platform velocity the crew ACTUALLY received and the
## bus's true velocity that tick, plus how many ticks delivered zero.
##
## Measured on 4.7.2 (rerun this if the engine is upgraded):
##   step   frame     slip max 0.1586  ratio 1.00
##   step   before    slip max 0.6009  ratio 0.00
##   step   after     slip max 0.6009  ratio 0.00
##   step   velocity  slip max 2.8039  ratio 0.00   (the "fix" is 4x worse)
##   interp any       slip max 0.079   ratio 1.00   (ordering is invisible here)
##
##   godot --headless --fixed-fps 60 --path . -s res://src/tooling/run_write_order_probe.gd -- mode=rec
##   godot --headless --fixed-fps 60 --path . -s res://src/tooling/run_write_order_probe.gd -- mode=run path=step order=frame

const SCENE_PATH: String = "res://scenes/playground.tscn"
const REC_PATH: String = "user://write_order_rec.json"
const REC_SAMPLES: int = 2400
const AISLE_LOCAL: Vector3 = Vector3(0.0, -0.55, 0.0)
const SETTLE_TICKS: int = 120
const ORIGIN_TICKS: int = 30

var _bus: RigidBody3D = null
var _crew: CharacterBody3D = null
var _writer: Node = null
var _mode: String = "rec"
var _path: String = "interp"
var _order: String = "frame"
var _measure_ticks: int = 1800
var _n: int = 0
var _rec: Array = []
var _start_local: Vector3 = Vector3.ZERO
var _prev_local: Vector3 = Vector3.ZERO
var _bus_prev: Vector3 = Vector3.ZERO
var _slips: Array = []
var _ratios: Array = []
var _zero_platform: int = 0
var _done: bool = false


## The write from inside node processing, so process_priority can put it before
## or after the crew's own _physics_process — the configuration the previous
## executor assumed was correct.
class TransformWriter:
	extends Node
	var probe: Object = null

	func _physics_process(_delta: float) -> void:
		if probe != null:
			probe.call("write_bus_transform")


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		var parts: PackedStringArray = arg.split("=", true, 1)
		if parts.size() != 2:
			continue
		match parts[0]:
			"mode":
				_mode = parts[1]
			"path":
				_path = parts[1]
			"order":
				_order = parts[1]
			"ticks":
				_measure_ticks = int(parts[1])
	process_frame.connect(_boot, CONNECT_ONE_SHOT)


func _boot() -> void:
	var packed: Resource = load(SCENE_PATH)
	if not (packed is PackedScene):
		print("ORDER: could not load " + SCENE_PATH)
		quit(1)
		return
	var scene_res: PackedScene = packed
	var scene: Node = scene_res.instantiate()
	scene.set("demo_mode", _mode == "rec")
	if _mode != "rec":
		scene.set("cargo_spawn", false)
	root.add_child(scene)
	physics_frame.connect(_tick)


func _flat(t: Transform3D) -> Array:
	var b: Basis = t.basis
	return [b.x.x, b.x.y, b.x.z, b.y.x, b.y.y, b.y.z, b.z.x, b.z.y, b.z.z,
		t.origin.x, t.origin.y, t.origin.z]


func _unflat(a: Array) -> Transform3D:
	return Transform3D(
		Basis(Vector3(a[0], a[1], a[2]), Vector3(a[3], a[4], a[5]), Vector3(a[6], a[7], a[8])),
		Vector3(a[9], a[10], a[11]))


func _percentile(values: Array, q: float) -> float:
	if values.is_empty():
		return 0.0
	var sorted: Array = values.duplicate()
	sorted.sort()
	return sorted[int(floorf(q * float(sorted.size() - 1)))]


## The snapshot the receiver holds at tick n. The host simulates at 60 Hz and
## sends every second tick, so received snapshot k is host tick 2k and the
## receiver is always one snapshot behind. Indexing by PACKET number instead
## would replay the recording at half speed and understate everything.
func _sample_at(n: int) -> Transform3D:
	var last: int = _rec.size() - 1
	var recent: int = 2 * int(floorf(float(n) / 2.0))
	if _path == "step":
		return _unflat(_rec[clampi(recent, 0, last)])
	var a: Transform3D = _unflat(_rec[clampi(recent - 2, 0, last)])
	var b: Transform3D = _unflat(_rec[clampi(recent, 0, last)])
	return a.interpolate_with(b, float(n % 2) / 2.0)


func write_bus_transform() -> void:
	if _bus == null or _n < 5:
		return
	var target: Transform3D = _sample_at(_n - 5)
	if _order == "velocity":
		var previous: Transform3D = _bus.global_transform
		_bus.global_transform = target
		_bus.linear_velocity = (target.origin - previous.origin) * float(Engine.physics_ticks_per_second)
		return
	_bus.global_transform = target


func _load_recording() -> bool:
	if not FileAccess.file_exists(REC_PATH):
		print("ORDER: no recording yet; run with mode=rec first")
		return false
	var file: FileAccess = FileAccess.open(REC_PATH, FileAccess.READ)
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if parsed is Array:
		_rec = parsed
		return _rec.size() > 0
	return false


func _tick() -> void:
	if _done:
		return
	_n += 1
	if _n == 5:
		_bus = get_first_node_in_group("bus")
		_crew = get_first_node_in_group("crew")
		if _mode != "rec":
			if not _load_recording():
				_done = true
				quit(1)
				return
			_bus.freeze = true
			_bus.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
			if _order != "frame":
				_writer = TransformWriter.new()
				_writer.set("probe", self)
				_writer.process_priority = 100 if _order == "after" else -100
				root.add_child(_writer)
	if _n < 5:
		return
	if _mode == "rec":
		_record()
		return
	# order=frame: the write lands here, in the physics_frame callback, which
	# is the only placement that delivers the platform velocity (measured).
	if _order == "frame":
		write_bus_transform()
	_measure()


func _record() -> void:
	_rec.append(_flat(_bus.global_transform))
	if _rec.size() < REC_SAMPLES:
		return
	var file: FileAccess = FileAccess.open(REC_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(_rec))
	file.close()
	print("ORDER recording saved: %d samples of the real bus (demo at full throttle)" % _rec.size())
	_done = true
	quit(0)


func _measure() -> void:
	if _n == SETTLE_TICKS:
		_crew.global_position = _bus.global_transform * AISLE_LOCAL
		_crew.set("velocity", Vector3.ZERO)
		_crew.set("aboard", true)
	if _n == SETTLE_TICKS + ORIGIN_TICKS:
		_start_local = _bus.global_transform.affine_inverse() * _crew.global_position
		_prev_local = _start_local
		_bus_prev = _bus.global_position
	var first: int = SETTLE_TICKS + ORIGIN_TICKS
	if _n > first and _n <= first + _measure_ticks:
		var local: Vector3 = _bus.global_transform.affine_inverse() * _crew.global_position
		_slips.append((local - _prev_local).length())
		_prev_local = local
		var bus_speed: float = (_bus.global_position - _bus_prev).length() * float(Engine.physics_ticks_per_second)
		_bus_prev = _bus.global_position
		var platform: float = _crew.call("get_platform_velocity").length()
		if platform <= 0.001:
			_zero_platform += 1
		if bus_speed > 1.0:
			_ratios.append(platform / bus_speed)
	if _n == first + _measure_ticks:
		_report()


func _report() -> void:
	var mean_ratio: float = 0.0
	for value: float in _ratios:
		mean_ratio += value
	mean_ratio /= maxf(1.0, float(_ratios.size()))
	print("ORDER path=%-6s order=%-8s | slip p95=%.4f p99=%.4f p99.9=%.4f max=%.4f | platform velocity received/true: mean=%.2f | zero-platform ticks %d/%d" % [
		_path, _order,
		_percentile(_slips, 0.95), _percentile(_slips, 0.99),
		_percentile(_slips, 0.999), _percentile(_slips, 1.0),
		mean_ratio, _zero_platform, _slips.size()])
	_done = true
	quit(0)
