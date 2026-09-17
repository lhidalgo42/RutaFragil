extends "res://src/tooling/run_write_order_probe.gd"

## Runs the original rig unchanged and observes both clocks in the SAME run.
## The legacy measurement stays at its original point; the observer reads the
## same tick after every node. Only final reporting waits for the second sample.
##   godot --headless --fixed-fps 60 --path . -s res://src/tooling/run_write_order_audit.gd ++ mode=run path=step order=frame
## Use the original mode=rec recording first; compare order=frame and order=before.

class EndOfNodesObserver:
	extends Node
	var audit: SceneTree = null

	func _physics_process(_delta: float) -> void:
		audit.call("_observe_completed_nodes")


var _report_pending: bool = false
var _common_previous_local: Vector3 = Vector3.ZERO
var _common_previous_bus: Vector3 = Vector3.ZERO
var _common_slips: Array[float] = []
var _common_ratios: Array[float] = []
var _common_zero: int = 0
var _paired_rows: Array[String] = []
var _legacy_row: String = ""


func _boot() -> void:
	super._boot()
	var observer: EndOfNodesObserver = EndOfNodesObserver.new()
	observer.audit = self
	observer.process_physics_priority = 1000
	root.add_child(observer)


func _measure() -> void:
	var first: int = SETTLE_TICKS + ORIGIN_TICKS
	if _n > first and _n <= first + _measure_ticks:
		_legacy_row = _pose_row(_bus_prev)
	super._measure()


func _report() -> void:
	_report_pending = true


func _observe_completed_nodes() -> void:
	if _mode != "run" or _bus == null or _crew == null:
		return
	var first: int = SETTLE_TICKS + ORIGIN_TICKS
	var local: Vector3 = _bus.global_transform.affine_inverse() * _crew.global_position
	if _n == first:
		_common_previous_local = local
		_common_previous_bus = _bus.global_position
	if _n > first and _n <= first + _measure_ticks:
		_common_slips.append(local.distance_to(_common_previous_local))
		_common_previous_local = local
		var bus_speed: float = _bus.global_position.distance_to(_common_previous_bus) * float(Engine.physics_ticks_per_second)
		var platform: float = _crew.get_platform_velocity().length()
		if platform <= 0.001:
			_common_zero += 1
		if bus_speed > 1.0:
			_common_ratios.append(platform / bus_speed)
		_paired_rows.append("%d,%s,%s" % [_n, _legacy_row, _pose_row(_common_previous_bus)])
		_common_previous_bus = _bus.global_position
	if _report_pending:
		_finish_audit()


func _pose_row(previous_bus: Vector3) -> String:
	var bus_at: Vector3 = _bus.global_position
	var crew_at: Vector3 = _crew.global_position
	var local: Vector3 = _bus.global_transform.affine_inverse() * crew_at
	return "%.9f,%.9f,%.9f,%.9f,%.9f,%.9f,%.9f,%.9f,%.9f,%.9f,%.9f" % [
		bus_at.x, bus_at.y, bus_at.z, crew_at.x, crew_at.y, crew_at.z,
		local.x, local.y, local.z, _crew.get_platform_velocity().length(),
		bus_at.distance_to(previous_bus) * float(Engine.physics_ticks_per_second)]


func _audit_reading(slips: Array, ratios: Array, zero_ticks: int) -> Dictionary:
	var ratio_sum: float = 0.0
	for ratio: float in ratios:
		ratio_sum += ratio
	return {"samples": slips.size(), "p95_m": _percentile(slips, 0.95),
		"p99_m": _percentile(slips, 0.99), "p999_m": _percentile(slips, 0.999),
		"max_m": _percentile(slips, 1.0), "ratio_samples": ratios.size(),
		"mean_ratio": ratio_sum / maxf(1.0, float(ratios.size())), "zero_platform_ticks": zero_ticks}


func _finish_audit() -> void:
	_report_pending = false
	var result: Dictionary = {"path": _path, "order": _order,
		"legacy": _audit_reading(_slips, _ratios, _zero_platform),
		"after_nodes": _audit_reading(_common_slips, _common_ratios, _common_zero)}
	var output: String = "user://write_order_audit_%s_%s" % [_path, _order]
	var summary: FileAccess = FileAccess.open(output + ".json", FileAccess.WRITE)
	if summary == null:
		printerr("ORDER_AUDIT cannot write summary: ", FileAccess.get_open_error())
		quit(1)
		return
	summary.store_string(JSON.stringify(result, "\t"))
	summary.close()
	var csv: FileAccess = FileAccess.open(output + ".csv", FileAccess.WRITE)
	if csv == null:
		printerr("ORDER_AUDIT cannot write CSV: ", FileAccess.get_open_error())
		quit(1)
		return
	var fields: String = "bus_x,bus_y,bus_z,crew_x,crew_y,crew_z,local_x,local_y,local_z,platform_mps,bus_mps"
	csv.store_line("tick,legacy_" + fields.replace(",", ",legacy_") + ",common_" + fields.replace(",", ",common_"))
	for row: String in _paired_rows:
		csv.store_line(row)
	csv.close()
	print("ORDER_AUDIT ", JSON.stringify(result))
	super._report()
