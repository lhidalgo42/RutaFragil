extends Resource

## Test fixture for resource_json_codec_test.gd: the shipped schemas
## (GameConfigData, TuningTable) have no bool/string fields, so this resource
## exercises the bool and string validation paths of ResourceJsonCodec.
## No class_name on purpose: it is preloaded by path from the test.

@export var flag_enabled: bool = false
@export var label_text: String = ""


# No parameters: duplicate() and ResourceLoader require a default constructor.
func _init() -> void:
	pass
