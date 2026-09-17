class_name GateDrive
extends Node

## Measurement route: a straight attack through x=30; return turns stay off the lane.
var bus: Bus = null
var enabled: bool = false
var waypoint: int = 0
var laps: int = 0
var bump_speeds: Array[float] = []
var entry_speeds: Array[float] = []
var _inside_bumps: bool = false
var _route: Array[Vector3] = [
	Vector3(30, 0, 70), Vector3(10, 0, 85), Vector3(-45, 0, 85),
	Vector3(-65, 0, 60), Vector3(-65, 0, -65), Vector3(-45, 0, -85),
	Vector3(10, 0, -85), Vector3(30, 0, -65)]


func _physics_process(_delta: float) -> void:
	if not enabled or bus == null:
		return
	var target: Vector3 = _route[waypoint]
	if DemoSteering.has_reached(bus.global_position, target, 5.0):
		waypoint = (waypoint + 1) % _route.size()
		if waypoint == 0:
			laps += 1
		target = _route[waypoint]
	var direction: Vector3 = target - bus.global_position
	var angle: float = absf(DemoSteering.signed_angle_for(bus.forward(), direction))
	bus.set_drive(DemoSteering.throttle_for(angle),
		DemoSteering.steer_for(bus.forward(), direction),
		DemoSteering.brake_for(angle, bus.speed_mps()))
	var p: Vector3 = bus.global_position
	var inside: bool = p.x >= 24.0 and p.x <= 36.0 and p.z >= 2.0 and p.z <= 46.0
	if inside:
		bump_speeds.append(bus.speed_mps() * 3.6)
		if not _inside_bumps:
			entry_speeds.append(bus.speed_mps() * 3.6)
	_inside_bumps = inside


func report() -> Dictionary:
	var sum: float = 0.0
	var peak: float = 0.0
	var minimum: float = INF
	for speed: float in bump_speeds:
		sum += speed
		peak = maxf(peak, speed)
		minimum = minf(minimum, speed)
	return {"route": "straight_x30_with_outer_return", "laps": laps,
		"bump_ticks": bump_speeds.size(), "entry_speeds_kmh": entry_speeds,
		"bumps_mean_kmh": sum / maxf(1.0, bump_speeds.size()),
		"bumps_max_kmh": peak, "bumps_min_kmh": minimum if not bump_speeds.is_empty() else 0.0}
