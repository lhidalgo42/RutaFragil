class_name WaterZone
extends Area3D

## Greybox water (D50): detects the bus and nothing more. Flotation and
## sinking are T7.2; until then depth_m is only informative.

signal bus_entered(body: Node3D)
signal bus_exited(body: Node3D)

## Informative until T7.2.
@export var depth_m: float = 0.3


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("bus"):
		bus_entered.emit(body)


func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("bus"):
		bus_exited.emit(body)
