extends GdUnitTestSuite

## JsonMerge.deep_merge contract (D45): dictionaries merge key by key,
## everything else (arrays included) is replaced, and inputs are never
## mutated. Literals are floats because JSON parses every number into float
## (plan §3), which is how the loader always sees them.


func test_scalar_override_replaces_value() -> void:
	var base: Dictionary = {"speed": 1.0}
	var over: Dictionary = {"speed": 2.0}
	var merged: Dictionary = JsonMerge.deep_merge(base, over)
	assert_dict(merged).is_equal({"speed": 2.0})


func test_nested_dictionaries_keep_sibling_keys() -> void:
	var base: Dictionary = {"economy": {"money": 500.0, "rent": 900.0}}
	var over: Dictionary = {"economy": {"money": 501.0}}
	var merged: Dictionary = JsonMerge.deep_merge(base, over)
	assert_dict(merged).is_equal({"economy": {"money": 501.0, "rent": 900.0}})


func test_key_only_in_base_is_kept() -> void:
	var base: Dictionary = {"money": 500.0, "rent": 900.0}
	var over: Dictionary = {}
	var merged: Dictionary = JsonMerge.deep_merge(base, over)
	assert_dict(merged).is_equal({"money": 500.0, "rent": 900.0})


func test_key_only_in_override_is_added() -> void:
	var base: Dictionary = {"money": 500.0}
	var over: Dictionary = {"rent": 900.0}
	var merged: Dictionary = JsonMerge.deep_merge(base, over)
	assert_dict(merged).is_equal({"money": 500.0, "rent": 900.0})


func test_arrays_are_replaced_not_concatenated() -> void:
	var base: Dictionary = {"route": [1.0, 2.0, 3.0]}
	var over: Dictionary = {"route": [9.0]}
	var merged: Dictionary = JsonMerge.deep_merge(base, over)
	assert_dict(merged).is_equal({"route": [9.0]})


func test_scalar_over_dictionary_replaces_it() -> void:
	var base: Dictionary = {"field": {"nested": 1.0}}
	var over: Dictionary = {"field": 5.0}
	var merged: Dictionary = JsonMerge.deep_merge(base, over)
	assert_dict(merged).is_equal({"field": 5.0})


func test_inputs_are_never_mutated() -> void:
	var base: Dictionary = {"nested": {"a": 1.0}, "route": [1.0, 2.0]}
	var over: Dictionary = {"nested": {"b": 2.0}, "route": [9.0]}
	var base_before: Dictionary = base.duplicate(true)
	var over_before: Dictionary = over.duplicate(true)
	var merged: Dictionary = JsonMerge.deep_merge(base, over)
	# The merge must not write back into either caller dictionary.
	assert_dict(base).is_equal(base_before)
	assert_dict(over).is_equal(over_before)
	# And the result still holds the union of both sides.
	assert_dict(merged).is_equal({"nested": {"a": 1.0, "b": 2.0}, "route": [9.0]})
