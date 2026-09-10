class_name GameConfigData
extends Resource

## Global game configuration schema (D43). Values live only in the data files
## (res://data/game_config.tres + .json mirror), never in code (R2/D44):
## every field keeps a neutral default so GameConfigData.new() is all zeroes.

@export var schema_version: int = 0
@export var max_players: int = 0
@export var max_players_hard_limit: int = 0


# No parameters: duplicate() and ResourceLoader require a default constructor.
func _init() -> void:
	pass
