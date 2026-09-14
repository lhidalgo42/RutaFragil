class_name GravelZone
extends Area3D

## Ripio (D68): an Area3D covering an unpaved stretch. It only reports the bus
## entering and leaving; the wheeled bus of T1.1 uses it to lose grip and
## rattle. Same shape as WaterZone: bus_entered/bus_exited for bodies in the
## "bus" group, plus the surface name for the footstep/tyre systems.

signal bus_entered(body: Node3D)
signal bus_exited(body: Node3D)

## Informative until T1.1: grip multiplier the wheeled bus should apply here.
@export var grip_multiplier: float = 0.55
@export var surface: String = "gravel"


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("bus"):
		bus_entered.emit(body)


func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("bus"):
		bus_exited.emit(body)
