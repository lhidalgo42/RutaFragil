class_name TuningTable
extends Resource

## Tuning parameters schema (maestro §8.1, names per D47). Values live only in
## the data files (res://data/tuning.tres + .json mirror), never in code
## (R2/D44): every field keeps a neutral default so TuningTable.new() is all
## zeroes and empty dictionaries.

@export_group("economy")
@export var starting_money: int = 0
@export var base_pay: Dictionary[String, int] = {}
@export var rent_quota: int = 0
@export var rent_every_contracts: int = 0
@export var rent_increase_per_cycle: float = 0.0
@export var defeat_keep_fraction: float = 0.0

@export_group("fuel")
@export var fuel_tank_liters: int = 0
@export var fuel_consumption_l_per_km: float = 0.0
@export var fuel_slope_multiplier: float = 0.0
@export var fuel_mud_multiplier: float = 0.0
@export var fuel_price_per_liter: int = 0
@export var jerrycan_liters: int = 0
@export var jerrycan_pour_seconds: float = 0.0
@export var jerrycan_fill_seconds: float = 0.0
@export var jerrycan_fill_seconds_two_players: float = 0.0
@export var fuel_zones_per_route_min: int = 0
@export var fuel_zones_per_route_max: int = 0
@export var barrel_liters_min: int = 0
@export var barrel_liters_max: int = 0
@export var empty_jerrycans_per_route_min: int = 0
@export var empty_jerrycans_per_route_max: int = 0

@export_group("services")
@export var repair_cost_per_integrity_point: int = 0
@export var maintenance_cost: int = 0
@export var shop_prices: Dictionary[String, int] = {}

@export_group("contract")
@export var contract_packages_min: int = 0
@export var contract_packages_max: int = 0
@export var contract_destinations_min: int = 0
@export var contract_destinations_max: int = 0
@export var route_km_min: int = 0
@export var route_km_max: int = 0
@export var target_minutes_min: int = 0
@export var target_minutes_max: int = 0

@export_group("player")
@export var player_walk_speed_mps: float = 0.0
@export var player_sprint_speed_mps: float = 0.0
@export var player_jump_height_m: float = 0.0
@export var interaction_reach_m: float = 0.0
## Mouse look sensitivity, radians per pixel of InputEventMouseMotion
## .screen_relative (round 3). PLAYER PREFERENCE, not game balance: fine here
## today, but a settings menu must move it out of mod reach (BACKLOG note).
@export var player_mouse_sensitivity: float = 0.0

@export_group("cargo")
@export var package_mass_kg: float = 0.0
@export var package_throw_speed_mps: float = 0.0
@export var package_hold_distance_m: float = 0.0
@export var strap_hold_seconds: float = 0.0
## Vertical relative-velocity damper for FREE cargo inside the hull (D85,
## measured: k=160 contains the bump embedding and leaves zero wall/floor
## violations on the lap; applied ONLY along the bus's up axis so braking and
## sliding sideways stay the game — §5.3 needs the 2-3 m/s impacts).
@export var package_relative_damping_ns_per_m: float = 0.0

@export_group("bus")
@export var bus_mass_kg: int = 0
@export var bus_integrity_max: int = 0
@export var bus_integrity_max_loss_per_contract: int = 0
@export var bus_max_speed_kmh: float = 0.0
@export var bus_traction_force_n: float = 0.0
@export var bus_wheelbase_m: float = 0.0
@export var bus_track_width_m: float = 0.0
@export var bus_wheel_radius_m: float = 0.0
@export var bus_suspension_rest_m: float = 0.0
@export var bus_suspension_stiffness_n_per_m: float = 0.0
@export var bus_suspension_damping_ns_per_m: float = 0.0
@export var bus_grip_lateral: float = 0.0
@export var bus_grip_lateral_handbrake: float = 0.0
@export var bus_brake_force_n: float = 0.0
@export var bus_steer_max_deg: float = 0.0
@export var bus_steer_speed_falloff: float = 0.0
@export var bus_center_of_mass_y_m: float = 0.0


# No parameters: duplicate() and ResourceLoader require a default constructor.
func _init() -> void:
	pass
