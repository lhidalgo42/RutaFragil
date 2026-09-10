class_name ResourceJsonCodec

## Resource <-> JSON conversion driven by the @export schema (D44/D45).
## Everything is validated BEFORE set(), because Object.set() coerces in
## silence and never fails on unknown properties (plan §3).

const _EXPORTED_USAGE: int = PROPERTY_USAGE_STORAGE | PROPERTY_USAGE_SCRIPT_VARIABLE


## name -> {"type": Variant.Type, "key_type"/"value_type": Variant.Type for dictionaries}.
static func schema_of(res: Resource) -> Dictionary:
	var schema: Dictionary = {}
	for prop: Dictionary in res.get_property_list():
		var usage: int = prop["usage"]
		if (usage & _EXPORTED_USAGE) != _EXPORTED_USAGE:
			continue
		var prop_name: String = prop["name"]
		var type_code: int = prop["type"]
		var info: Dictionary = {"type": type_code}
		if type_code == TYPE_DICTIONARY:
			# Typedness comes from the live default value, not from parsing
			# hint_string ("String;int"): same fact, typed access.
			var current: Dictionary = res.get(prop_name)
			info["key_type"] = current.get_typed_key_builtin()
			info["value_type"] = current.get_typed_value_builtin()
		schema[prop_name] = info
	return schema


## Returns only the valid keys of raw, or {} if any error was recorded.
## Unknown keys are the one case whose severity depends on the layer (D45):
## error for base data, warning for mods. Broken values are always errors in
## the given report; the layer decides whether they surface as warnings (the
## loader forwards mod errors as warnings so a bad mod never fails the run).
static func validate(
	res: Resource, raw: Dictionary, report: DataLoadReport, source: String, unknown_is_error: bool
) -> Dictionary:
	var schema: Dictionary = schema_of(res)
	var valid: Dictionary = {}
	var failed: bool = false
	for key_v: Variant in raw:
		if not (key_v is String):
			report.add_error(source, "non-string key ignored")
			failed = true
			continue
		var key: String = key_v
		if not schema.has(key):
			if unknown_is_error:
				report.add_error(source, "unknown key '%s'" % key)
				failed = true
			else:
				report.add_warning(source, "unknown key '%s' ignored" % key)
			continue
		var info: Dictionary = schema[key]
		var result: Dictionary = _convert_value(info, raw[key_v])
		var ok: bool = result["ok"]
		if ok:
			valid[key] = result["value"]
		else:
			var message: String = result["error"]
			report.add_error(source, "key '%s': %s" % [key, message])
			failed = true
	if failed:
		return {}
	return valid


## Applies validate() output. Typed dictionaries go through .assign() (element
## conversion, engine error on mismatch); scalars through set(). After each
## write the value is read back: an out-of-schema key or a read-back
## discrepancy means validation let something through, which is a bug, so it
## is push_error'd rather than reported.
static func apply(res: Resource, valid: Dictionary) -> void:
	var schema: Dictionary = schema_of(res)
	for key: String in valid:
		if not schema.has(key):
			push_error("ResourceJsonCodec.apply: '%s' is not in the schema (validation bug)" % key)
			continue
		var info: Dictionary = schema[key]
		var type_code: int = info["type"]
		var value: Variant = valid[key]
		if type_code == TYPE_DICTIONARY:
			var current: Dictionary = res.get(key)
			var incoming: Dictionary = value
			current.assign(incoming)
			if current != incoming:
				push_error("ResourceJsonCodec.apply: '%s' changed under .assign()" % key)
		else:
			res.set(key, value)
			var readback: Variant = res.get(key)
			if readback != value:
				push_error("ResourceJsonCodec.apply: '%s' did not survive set()/get()" % key)


static func to_dictionary(res: Resource) -> Dictionary:
	var out: Dictionary = {}
	var schema: Dictionary = schema_of(res)
	for prop_name: String in schema:
		var value: Variant = res.get(prop_name)
		if value is Dictionary:
			# Duplicated so callers never alias the resource's live dictionary.
			var dict_value: Dictionary = value
			out[prop_name] = dict_value.duplicate(true)
		else:
			out[prop_name] = value
	return out


static func _convert_value(info: Dictionary, value: Variant) -> Dictionary:
	var type_code: int = info["type"]
	if type_code == TYPE_INT:
		return _convert_int(value)
	if type_code == TYPE_FLOAT:
		return _convert_float(value)
	if type_code == TYPE_STRING:
		if value is String:
			var as_string: String = value
			return _ok(as_string)
		return _fail("expected a string, got %s" % type_string(typeof(value)))
	if type_code == TYPE_BOOL:
		if value is bool:
			var as_bool: bool = value
			return _ok(as_bool)
		return _fail("expected a bool, got %s" % type_string(typeof(value)))
	if type_code == TYPE_DICTIONARY:
		return _convert_typed_dictionary(info, value)
	return _fail("unsupported schema type %s" % type_string(type_code))


## JSON numbers always arrive as float, so an int field accepts only integral
## values and coerces with roundi() (avoids 139.999 -> 139, plan §3).
static func _convert_int(value: Variant) -> Dictionary:
	if value is int:
		var as_int: int = value
		return _ok(as_int)
	if value is float:
		var as_float: float = value
		# roundi() is undefined for non-finite or out-of-int64-range floats.
		if not is_finite(as_float) or absf(as_float) > 9.0e18:
			return _fail("expected a finite int64-range number, got %s" % str(as_float))
		if as_float == floorf(as_float):
			return _ok(roundi(as_float))
		return _fail("expected an integral number, got %s" % str(as_float))
	return _fail("expected an int, got %s" % type_string(typeof(value)))


static func _convert_float(value: Variant) -> Dictionary:
	if value is float:
		var as_float: float = value
		return _ok(as_float)
	if value is int:
		var as_int: int = value
		return _ok(float(as_int))
	return _fail("expected a float, got %s" % type_string(typeof(value)))


## Validates entry by entry; apply() later assigns onto the typed property.
## Only Dictionary[String, int] exists in the schemas so far.
static func _convert_typed_dictionary(info: Dictionary, value: Variant) -> Dictionary:
	var key_type: int = info["key_type"]
	var value_type: int = info["value_type"]
	if key_type != TYPE_STRING or value_type != TYPE_INT:
		return _fail("only Dictionary[String, int] is supported")
	if not (value is Dictionary):
		return _fail("expected an object, got %s" % type_string(typeof(value)))
	var raw_dict: Dictionary = value
	var converted: Dictionary = {}
	for key_v: Variant in raw_dict:
		if not (key_v is String):
			return _fail("dictionary keys must be strings")
		var key: String = key_v
		var entry: Dictionary = _convert_int(raw_dict[key_v])
		var entry_ok: bool = entry["ok"]
		if not entry_ok:
			var entry_error: String = entry["error"]
			return _fail("key '%s': %s" % [key, entry_error])
		converted[key] = entry["value"]
	return _ok(converted)


static func _ok(value: Variant) -> Dictionary:
	return {"ok": true, "value": value, "error": ""}


static func _fail(message: String) -> Dictionary:
	return {"ok": false, "value": null, "error": message}
