class_name PlaceholderBus
extends RigidBody3D

## Placeholder "powered disc" vehicle (D48): a rigid box pushed by a central
## force, steered by yaw torque, kept straight by scripted lateral grip.
## T1.1 replaces it with the real raycast-suspension bus (ADR-007); only the
## set_drive(throttle, steer, brake) interface survives.
## Mass, top speed and acceleration come from GameConfig.tuning (R2); every
## export below is greybox-only and disappears with T1.1.

# Greybox (T1.1 deletes): side-slip damping rate, in 1/s.
@export var lateral_grip: float = 8.0
# Greybox (T1.1 deletes): yaw torque per kg of mass at full steer, N·m/kg.
@export var steer_torque_per_kg: float = 8.0
# Greybox (T1.1 deletes): longitudinal brake damping rate at full brake, 1/s.
@export var brake_damping: float = 4.0
# Greybox (T1.1 deletes): below this upright dot the bus counts rolled.
@export var rollover_dot_threshold: float = 0.5
# Greybox (T1.1 deletes): how long the tilt must hold before rolled_over.
@export var rollover_seconds: float = 1.0
# Greybox (T1.1 deletes): speed where steering reaches full authority, m/s.
@export var steer_full_speed_mps: float = 8.0
# Greybox (T1.1 deletes): yaw damping torque per kg and rad/s. Without it the
# bang-bang steering enters a limit cycle and the bus weaves off course.
@export var yaw_damping: float = 12.0
# Greybox (T1.1 deletes): floor of the steering speed factor, so the bus can
# still rotate at crawl speed instead of locking against contact friction.
@export var steer_min_speed_factor: float = 0.35

signal rolled_over

var drive_throttle: float = 0.0
var drive_steer: float = 0.0
var drive_brake: float = 0.0

var _accel_mps2: float = 0.0
var _max_speed_mps: float = 0.0
var _rollover_time_s: float = 0.0
var _rolled_over_emitted: bool = false


func _ready() -> void:
	_apply_tuning()
	GameConfig.reloaded.connect(_on_game_config_reloaded)


func set_drive(throttle: float, steer: float, brake: float) -> void:
	drive_throttle = clampf(throttle, -1.0, 1.0)
	drive_steer = clampf(steer, -1.0, 1.0)
	drive_brake = clampf(brake, 0.0, 1.0)


func speed_mps() -> float:
	return linear_velocity.length()


func forward() -> Vector3:
	return -global_basis.z


func is_grounded() -> bool:
	return get_contact_count() > 0


static func upright_dot(basis: Basis) -> float:
	return basis.y.dot(Vector3.UP)


func _physics_process(delta: float) -> void:
	_update_rollover(delta)
	if not is_grounded():
		return
	var fwd: Vector3 = forward()
	if drive_throttle != 0.0 and speed_mps() < _max_speed_mps:
		apply_central_force(fwd * (mass * _accel_mps2 * drive_throttle))
	if drive_steer != 0.0:
		var speed_factor: float = clampf(speed_mps() / steer_full_speed_mps, steer_min_speed_factor, 1.0)
		apply_torque(Vector3.UP * (drive_steer * steer_torque_per_kg * mass * speed_factor))
	if yaw_damping > 0.0 and angular_velocity.y != 0.0:
		apply_torque(Vector3.UP * (-angular_velocity.y * yaw_damping * mass))
	if drive_brake > 0.0:
		var v_long: Vector3 = fwd * linear_velocity.dot(fwd)
		linear_velocity -= v_long * clampf(brake_damping * drive_brake * delta, 0.0, 1.0)
	var right: Vector3 = global_basis.x
	var v_lat: Vector3 = right * linear_velocity.dot(right)
	linear_velocity -= v_lat * clampf(lateral_grip * delta, 0.0, 1.0)


func _update_rollover(delta: float) -> void:
	if _rolled_over_emitted:
		return
	if upright_dot(global_basis) < rollover_dot_threshold:
		_rollover_time_s += delta
		if _rollover_time_s >= rollover_seconds:
			_rolled_over_emitted = true
			rolled_over.emit()
	else:
		_rollover_time_s = 0.0


func _apply_tuning() -> void:
	var tuning: TuningTable = GameConfig.tuning
	if tuning == null:
		# The authored 1 kg mass stays so the misconfiguration stays visible.
		push_error("PlaceholderBus: GameConfig.tuning is null; keeping authored mass and zero drive")
		_accel_mps2 = 0.0
		_max_speed_mps = 0.0
		return
	mass = float(maxi(tuning.bus_mass_kg, 1))
	if tuning.bus_accel_0_60_kmh_s > 0.0:
		_accel_mps2 = (60.0 / 3.6) / tuning.bus_accel_0_60_kmh_s
	else:
		_accel_mps2 = 0.0
	_max_speed_mps = tuning.bus_max_speed_kmh / 3.6


func _on_game_config_reloaded(_report: DataLoadReport) -> void:
	_apply_tuning()
