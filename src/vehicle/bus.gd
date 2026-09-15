class_name Bus
extends RigidBody3D

## D90 layer scheme: the suspension ray reads only this layer (world).
## Cargo (2) and crew (3) are invisible to it.
const WORLD_LAYER: int = 1


## Raycast-suspension bus (ADR-007, D59, D60): replaces the T0.3 placeholder,
## keeping its public interface (set_drive, speed_mps, forward, is_grounded,
## upright_dot, rolled_over, group "bus", freezable) so DemoDriver, run_demo
## and the net harness keep working. Four wheel anchors (Marker3D children
## named WheelFL/WheelFR/WheelRL/WheelRR, repositioned from tuning at _ready)
## cast one ray each per physics tick; spring + damper, traction, braking and
## per-wheel lateral grip are applied AT THE WHEEL POINT:
## apply_force(force, global_basis * wheel_offset) — the offset MUST be
## rotated into global orientation (plan §3 measured the flip otherwise).
## Feel numbers live in data/ via GameConfig.tuning (D61): none here.
## Handbrake (D64): while held, rear wheels drop to the handbrake grip rate
## and traction is cut. freeze=true (net clients) skips all raycasts.

signal rolled_over

const ROLLOVER_DOT_THRESHOLD: float = 0.5
const ROLLOVER_SECONDS: float = 1.0

var drive_throttle: float = 0.0
var drive_steer: float = 0.0
var drive_brake: float = 0.0
var handbrake_on: bool = false

var _wheelbase: float = 0.0
var _track: float = 0.0
var _radius: float = 0.0
var _rest: float = 0.0
var _stiffness: float = 0.0
var _damping: float = 0.0
var _grip: float = 0.0
var _grip_handbrake: float = 0.0
var _brake_force: float = 0.0
var _steer_max_deg: float = 0.0
var _steer_falloff: float = 0.0
var _traction_force_n: float = 0.0
var _max_speed_mps: float = 0.0

var _prev_distances: Dictionary = {}
var _grounded: bool = false
var _rollover_time_s: float = 0.0
var _rolled_over_emitted: bool = false


func _ready() -> void:
	_apply_tuning()
	GameConfig.reloaded.connect(_on_game_config_reloaded)


static func suspension_force(compression: float, compression_rate: float, stiffness: float, damping: float) -> float:
	return maxf(0.0, stiffness * compression + damping * compression_rate)


static func compression_rate(prev_distance: float, distance: float, delta: float) -> float:
	if delta <= 0.0:
		return 0.0
	return (prev_distance - distance) / delta


static func lateral_grip_force(lateral_speed: float, grip_rate: float, mass_share: float) -> float:
	return -lateral_speed * grip_rate * mass_share


static func steer_angle_deg_for(speed_mps: float, steer_input: float, steer_max_deg: float, max_speed_mps: float, falloff: float) -> float:
	var speed_factor: float = 1.0
	if max_speed_mps > 0.0:
		speed_factor = 1.0 - falloff * clampf(speed_mps / max_speed_mps, 0.0, 1.0)
	return steer_max_deg * clampf(steer_input, -1.0, 1.0) * speed_factor


static func traction_force_per_wheel(throttle: float, traction_force_n: float, wheel_count: int) -> float:
	if wheel_count <= 0:
		return 0.0
	return traction_force_n * clampf(throttle, -1.0, 1.0) / float(wheel_count)


func set_drive(throttle: float, steer: float, brake: float) -> void:
	drive_throttle = clampf(throttle, -1.0, 1.0)
	drive_steer = clampf(steer, -1.0, 1.0)
	drive_brake = clampf(brake, 0.0, 1.0)


func set_handbrake(on: bool) -> void:
	handbrake_on = on


func speed_mps() -> float:
	return linear_velocity.length()


func forward() -> Vector3:
	return -global_basis.z


func is_grounded() -> bool:
	return _grounded


static func upright_dot(basis: Basis) -> float:
	return basis.y.dot(Vector3.UP)


func _physics_process(delta: float) -> void:
	if freeze:
		return
	_update_rollover(delta)
	var any_contact: bool = false
	for wheel: Marker3D in _wheel_markers():
		if _simulate_wheel(wheel, delta):
			any_contact = true
	_grounded = any_contact


func _wheel_markers() -> Array[Marker3D]:
	var markers: Array[Marker3D] = []
	for child: Node in get_children():
		if child is Marker3D and child.name.begins_with("Wheel"):
			markers.append(child)
	return markers


func _is_front_wheel(wheel: Marker3D) -> bool:
	return wheel.position.z < 0.0


func _simulate_wheel(wheel: Marker3D, delta: float) -> bool:
	var origin: Vector3 = wheel.global_position
	var down: Vector3 = -global_basis.y
	var ray_length: float = _rest + _radius
	var state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		origin, origin + down * ray_length)
	query.exclude = [get_rid()]
	# D90: the ray reads ONLY the world layer. Unmasked it read cargo as
	# ground: a box in a wheel column (the FR column sits in the side-door
	# gap, where the crew steps every boarding) was seen 0.2 m below the
	# anchor -> ~54 kN of spring in one corner and the parked bus flew to
	# y=3.84 m (measured 2026-09-15; exit 100 without this line).
	query.collision_mask = WORLD_LAYER
	var hit: Dictionary = state.intersect_ray(query)
	var wheel_key: String = wheel.name
	var prev_distance: float = ray_length
	if _prev_distances.has(wheel_key):
		var prev_v: Variant = _prev_distances[wheel_key]
		if prev_v is float:
			prev_distance = prev_v
	if hit.is_empty():
		_prev_distances[wheel_key] = ray_length
		return false
	var hit_pos_v: Variant = hit["position"]
	var normal_v: Variant = hit["normal"]
	if not (hit_pos_v is Vector3) or not (normal_v is Vector3):
		return false
	var hit_pos: Vector3 = hit_pos_v
	var normal: Vector3 = normal_v
	var distance: float = origin.distance_to(hit_pos)
	var compression: float = clampf(_rest + _radius - distance, 0.0, ray_length)
	var rate: float = compression_rate(prev_distance, distance, delta)
	_prev_distances[wheel_key] = distance
	# The offset of the wheel anchor from the body origin, ROTATED into global
	# orientation (plan §3: apply_force takes a global-orientation offset).
	var offset: Vector3 = global_basis * wheel.position
	var spring: float = suspension_force(compression, rate, _stiffness, _damping)
	apply_force(normal * spring, offset)
	var point_velocity: Vector3 = linear_velocity + angular_velocity.cross(offset)
	var steer_deg: float = 0.0
	if _is_front_wheel(wheel):
		steer_deg = steer_angle_deg_for(
			speed_mps(), drive_steer, _steer_max_deg, _max_speed_mps, _steer_falloff)
	_apply_drive_forces(wheel, fwd_on(normal), offset, point_velocity, steer_deg, delta)
	return true


func fwd_on(normal: Vector3) -> Vector3:
	var fwd: Vector3 = forward()
	var on_plane: Vector3 = fwd - normal * fwd.dot(normal)
	if on_plane.length() < 0.001:
		return fwd
	return on_plane.normalized()


func _apply_drive_forces(wheel: Marker3D, fwd: Vector3, offset: Vector3, point_velocity: Vector3, steer_deg: float, delta: float) -> void:
	var mass_share: float = mass / 4.0
	# Lateral grip along the wheel axis; front wheels rotate it by the steer
	# angle, which is what turns the chassis (ADR-007 weight transfer).
	var grip_rate: float = _grip
	if handbrake_on and not _is_front_wheel(wheel):
		grip_rate = _grip_handbrake
	var right: Vector3 = global_basis.x.rotated(global_basis.y, deg_to_rad(steer_deg))
	var lateral_speed: float = point_velocity.dot(right)
	var grip_force: Vector3 = right * lateral_grip_force(lateral_speed, grip_rate, mass_share)
	# Grip may scrub energy but never ADD it: when the body axis leads the
	# velocity, a raw lateral force gets a forward component and pumps speed
	# (measured 2026-09-12: 90 km/h cap holding, then a spin-pump to 177 km/h).
	# Strip the energy-adding part; the centripetal part (perpendicular to the
	# velocity) is untouched.
	var travel_dir: float = grip_force.dot(point_velocity)
	if travel_dir > 0.0 and point_velocity.length() > 0.01:
		grip_force -= point_velocity.normalized() * travel_dir
	apply_force(grip_force, offset)
	# Traction along the chassis forward, only with the wheel touching and
	# below the speed cap; the handbrake cuts it (D64).
	if drive_throttle != 0.0 and not handbrake_on and speed_mps() < _max_speed_mps:
		var traction: float = traction_force_per_wheel(drive_throttle, _traction_force_n, 4)
		apply_force(fwd * traction, offset)
	# Braking opposes the longitudinal motion at the wheel, clamped so it can
	# never reverse the travel direction within one tick.
	if drive_brake > 0.0 and delta > 0.0:
		var long_speed: float = point_velocity.dot(fwd)
		if long_speed != 0.0:
			var needed: float = absf(mass_share * long_speed / delta)
			var brake_mag: float = minf(_brake_force / 4.0 * drive_brake, needed)
			apply_force(-fwd * signf(long_speed) * brake_mag, offset)


func _update_rollover(delta: float) -> void:
	if _rolled_over_emitted:
		return
	if upright_dot(global_basis) < ROLLOVER_DOT_THRESHOLD:
		_rollover_time_s += delta
		if _rollover_time_s >= ROLLOVER_SECONDS:
			_rolled_over_emitted = true
			rolled_over.emit()
	else:
		_rollover_time_s = 0.0


func _apply_tuning() -> void:
	var tuning: TuningTable = GameConfig.tuning
	if tuning == null:
		# The authored 1 kg mass stays so the misconfiguration stays visible.
		push_error("Bus: GameConfig.tuning is null; keeping authored mass and zero drive")
		_traction_force_n = 0.0
		_max_speed_mps = 0.0
		return
	mass = float(maxi(tuning.bus_mass_kg, 1))
	_wheelbase = tuning.bus_wheelbase_m
	_track = tuning.bus_track_width_m
	_radius = tuning.bus_wheel_radius_m
	_rest = tuning.bus_suspension_rest_m
	_stiffness = tuning.bus_suspension_stiffness_n_per_m
	_damping = tuning.bus_suspension_damping_ns_per_m
	_grip = tuning.bus_grip_lateral
	_grip_handbrake = tuning.bus_grip_lateral_handbrake
	_brake_force = tuning.bus_brake_force_n
	_steer_max_deg = tuning.bus_steer_max_deg
	_steer_falloff = tuning.bus_steer_speed_falloff
	# The traction data is a FORCE in newtons (r1.1 of T1.1: the old field
	# named an ideal 0-60 time that losses never delivered; the real measured
	# 0-60 is 6.93 s, the feel approved at the gate).
	_traction_force_n = tuning.bus_traction_force_n
	_max_speed_mps = tuning.bus_max_speed_kmh / 3.6
	center_of_mass_mode = CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3(0.0, tuning.bus_center_of_mass_y_m, 0.0)
	_position_wheels()


func _position_wheels() -> void:
	var half_base: float = _wheelbase / 2.0
	var half_track: float = _track / 2.0
	_set_wheel_position("WheelFL", Vector3(-half_track, 0.0, -half_base))
	_set_wheel_position("WheelFR", Vector3(half_track, 0.0, -half_base))
	_set_wheel_position("WheelRL", Vector3(-half_track, 0.0, half_base))
	_set_wheel_position("WheelRR", Vector3(half_track, 0.0, half_base))


func _set_wheel_position(wheel_name: String, local_pos: Vector3) -> void:
	var node: Node = get_node_or_null(wheel_name)
	if node is Marker3D:
		var wheel: Marker3D = node
		wheel.position = local_pos


func _on_game_config_reloaded(_report: DataLoadReport) -> void:
	_apply_tuning()
