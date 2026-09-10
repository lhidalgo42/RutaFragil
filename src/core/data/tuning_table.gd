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
@export var fuel_consumption_l_per_km: int = 0
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

@export_group("bus")
@export var bus_mass_kg: int = 0
@export var bus_integrity_max: int = 0
@export var bus_wear_per_contract_max: int = 0


# No parameters: duplicate() and ResourceLoader require a default constructor.
func _init() -> void:
	pass
