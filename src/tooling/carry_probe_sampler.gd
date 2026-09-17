extends Node

## Read-only sampling boundary after the writer and crew physics callbacks.
signal completed_tick


func _ready() -> void:
	process_priority = 1000
	process_physics_priority = 1000


func _physics_process(_delta: float) -> void:
	completed_tick.emit()
