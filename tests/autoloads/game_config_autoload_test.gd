extends GdUnitTestSuite

## GameConfig autoload contract (D43/D46): it must exist in the test runner,
## expose non-null data/tuning, and reload() must emit `reloaded`.
## No concrete data values are asserted here: the real user://mods of the
## developer machine may legitimately override them.


func _autoload() -> Node:
	return get_tree().root.get_node_or_null("GameConfig")


func test_autoload_exists_in_runner() -> void:
	# If the autoload script fails to load, the runner continues without it:
	# this test is what catches that situation.
	assert_object(_autoload()).is_not_null()


func test_data_and_tuning_are_present() -> void:
	var node: Node = _autoload()
	assert_object(node).is_not_null()
	var data_v: Variant = node.get("data")
	var tuning_v: Variant = node.get("tuning")
	assert_bool(data_v is GameConfigData).is_true()
	assert_bool(tuning_v is TuningTable).is_true()


func test_max_players_comes_from_the_data() -> void:
	# R1: GameConfig.max_players must be a live view over the loaded data.
	var node: Node = _autoload()
	assert_object(node).is_not_null()
	var max_players_v: Variant = node.get("max_players")
	assert_bool(max_players_v is int).is_true()
	if max_players_v is int:
		var max_players: int = max_players_v
		assert_int(max_players).is_greater_equal(1)


func test_reload_emits_reloaded() -> void:
	var node: Node = _autoload()
	assert_object(node).is_not_null()
	var emitter: Object = monitor_signals(node)
	emitter.call("reload")
	# The signal carries the report, so the match needs one any() argument.
	await assert_signal(emitter).is_emitted("reloaded", any())
