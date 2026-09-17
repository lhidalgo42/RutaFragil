class_name GateTravelMetrics
extends RefCounted

## The raw displacement remains available when contacts exclude a jitter sample.
var sample_count: int = 0
var hull_exit_ticks: int = 0
var observation_complete: bool = true
var inside_hull: bool = false
var slip_eligible: bool = false
var last_slip_m: float = 0.0
var _previous: Vector3 = Vector3.ZERO
var _raw: Array[float] = []
var _filtered: Array[float] = []


func reset() -> void:
	sample_count = 0
	hull_exit_ticks = 0
	observation_complete = true
	inside_hull = false
	slip_eligible = false
	last_slip_m = 0.0
	_previous = Vector3.ZERO
	_raw.clear()
	_filtered.clear()


## The push tick itself is the MOST contaminated sample, not the least: the
## box is pushing her on that very tick. Excluding only the previous three
## left it eligible, and 137 of the 152 samples above the 1.5x limit in the
## 300 s run were exactly that tick (measured 2026-09-17). Both flags exclude.
func observe(tick: int, local: Vector3, supported: bool,
		cargo_contact_now: bool, recent_cargo: bool, history_complete: bool) -> void:
	if tick != sample_count + 1:
		observation_complete = false
	inside_hull = BusInterior.is_inside_local(local)
	hull_exit_ticks += 0 if inside_hull else 1
	last_slip_m = local.distance_to(_previous) if sample_count > 0 else 0.0
	slip_eligible = sample_count > 0 and supported and history_complete \
		and not cargo_contact_now and not recent_cargo
	if sample_count > 0:
		_raw.append(last_slip_m)
		if slip_eligible:
			_filtered.append(last_slip_m)
	_previous = local
	sample_count += 1


func summary() -> Dictionary:
	return {"metrics_version": 5, "travel_samples": sample_count,
		"travel_observation_complete": observation_complete, "hull_exit_ticks": hull_exit_ticks,
		"slip": GateMetricsUtil.slip_summary(_filtered), "slip_raw": GateMetricsUtil.slip_summary(_raw),
		"slip_filter": "supported_and_no_cargo_contact_this_tick_or_previous_three"}
