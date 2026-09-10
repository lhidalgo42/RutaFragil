class_name JsonMerge

## Deep dictionary merge for the data layers (D45). Dictionary.merge() is
## shallow, so nested overrides need this: dictionaries merge key by key,
## everything else (including arrays) is replaced.

static func deep_merge(base: Dictionary, over: Dictionary) -> Dictionary:
	var merged: Dictionary = base.duplicate(true)
	for key: Variant in over:
		var over_value: Variant = over[key]
		var base_value: Variant = merged.get(key, null)
		if over_value is Dictionary and base_value is Dictionary:
			var over_dict: Dictionary = over_value
			var base_dict: Dictionary = base_value
			merged[key] = deep_merge(base_dict, over_dict)
		elif over_value is Dictionary:
			# Copied so the result never aliases the caller's dictionaries.
			var over_dict: Dictionary = over_value
			merged[key] = over_dict.duplicate(true)
		elif over_value is Array:
			var over_array: Array = over_value
			merged[key] = over_array.duplicate(true)
		else:
			merged[key] = over_value
	return merged
