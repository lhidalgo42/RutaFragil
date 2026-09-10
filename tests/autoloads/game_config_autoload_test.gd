extends GdUnitTestSuite

## GameConfig autoload contract (D43/D46): it must exist in the test runner,
## expose non-null data/tuning, and reload() must emit `reloaded`.
## No concrete data values are asserted here: the real user://mods of the
## developer machine may legitimately override them.


func _autoload() -> Node:
	return get_tree().root.get_node_or_null("GameConfig")


func _write_json(path: String, text: String) -> void:
	assert_int(JsonFile.write_text(path, text)).is_equal(OK)


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


func test_reload_push_warning_on_rejected_mod() -> void:
	# MR3: a rejected mod must surface as a push_warning with the REJECTED
	# text, so a modder sees it in the console. Own instance, never added to
	# the tree: _ready() must not run the real res://data load, reload() is
	# driven by hand with the injected directories.
	var base_dir: String = create_temp_dir("autoload_reject_base")
	var mods_dir: String = create_temp_dir("autoload_reject_mods")
	_write_json(base_dir + "/game_config.json", "{\"game_config\": {\"max_players\": 6}}")
	_write_json(base_dir + "/tuning.json", "{\"tuning\": {\"starting_money\": 500}}")
	_write_json(mods_dir + "/bad.json", "{\"tuning\": {\"starting_money\": \"mucho\"}}")
	var node: Node = auto_free(load("res://src/autoloads/game_config.gd").new())
	await assert_error(func() -> void: node.call("reload", base_dir, mods_dir)).is_push_warning(
		"REJECTED mod:bad.json: key 'starting_money': expected an int, got String"
	)


func test_reload_push_error_on_empty_dirs() -> void:
	# MR3: with no data at all the report fails (M4) and the autoload raises
	# it as a push_error carrying the report summary.
	var base_dir: String = create_temp_dir("autoload_empty_base")
	var mods_dir: String = create_temp_dir("autoload_empty_mods")
	var node: Node = auto_free(load("res://src/autoloads/game_config.gd").new())
	await assert_error(func() -> void: node.call("reload", base_dir, mods_dir)).is_push_error(
		(
			"data load: 0 applied, 0 warning(s), 2 error(s)"
			+ "\n  [error] doc:game_config: no .tres or base .json layer applied"
			+ "\n  [error] doc:tuning: no .tres or base .json layer applied"
		)
	)
