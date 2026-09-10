extends GdUnitTestSuite

## GameDataLoader contract (D45): layers .tres -> base .json -> mods/*.json,
## deep merge per document, alphabetical mod order, whole-mod rejection on
## any error. Directories are injected from create_temp_dir, never the real
## user://mods.


func _write_json(path: String, text: String) -> void:
	assert_int(JsonFile.write_text(path, text)).is_equal(OK)


func _has_warning_containing(report: DataLoadReport, fragment: String) -> bool:
	for warning: String in report.warnings:
		if warning.contains(fragment):
			return true
	return false


func test_base_only_loads_values() -> void:
	var base_dir: String = create_temp_dir("loader_base_only_base")
	var mods_dir: String = create_temp_dir("loader_base_only_mods")
	_write_json(base_dir + "/game_config.json", "{\"game_config\": {\"max_players\": 6}}")
	_write_json(base_dir + "/tuning.json", "{\"tuning\": {\"starting_money\": 500}}")
	var loader: GameDataLoader = GameDataLoader.new(base_dir, mods_dir)
	var report: DataLoadReport = loader.load_all()
	assert_bool(report.is_ok()).is_true()
	assert_int(loader.game_config.max_players).is_equal(6)
	assert_int(loader.tuning.starting_money).is_equal(500)
	assert_int(report.applied_files.size()).is_equal(2)


func test_reload_picks_up_json_rewrite_in_same_process() -> void:
	# Acceptance criterion 1: editing the JSON and reloading changes the game
	# without reopening anything; same process, fresh read from disk.
	var base_dir: String = create_temp_dir("loader_hot_edit_base")
	var mods_dir: String = create_temp_dir("loader_hot_edit_mods")
	var tuning_path: String = base_dir + "/tuning.json"
	_write_json(tuning_path, "{\"tuning\": {\"starting_money\": 500}}")
	var loader: GameDataLoader = GameDataLoader.new(base_dir, mods_dir)
	loader.load_all()
	assert_int(loader.tuning.starting_money).is_equal(500)
	_write_json(tuning_path, "{\"tuning\": {\"starting_money\": 777}}")
	loader.load_all()
	assert_int(loader.tuning.starting_money).is_equal(777)


func test_mod_overrides_base() -> void:
	# Acceptance criterion 2: a JSON in mods wins over the base layer.
	var base_dir: String = create_temp_dir("loader_mod_base_base")
	var mods_dir: String = create_temp_dir("loader_mod_base_mods")
	_write_json(base_dir + "/tuning.json", "{\"tuning\": {\"starting_money\": 500}}")
	_write_json(mods_dir + "/my_mod.json", "{\"tuning\": {\"starting_money\": 999}}")
	var loader: GameDataLoader = GameDataLoader.new(base_dir, mods_dir)
	var report: DataLoadReport = loader.load_all()
	assert_bool(report.is_ok()).is_true()
	assert_int(loader.tuning.starting_money).is_equal(999)


func test_two_mods_apply_in_alphabetical_order() -> void:
	var base_dir: String = create_temp_dir("loader_mod_order_base")
	var mods_dir: String = create_temp_dir("loader_mod_order_mods")
	_write_json(base_dir + "/tuning.json", "{\"tuning\": {\"starting_money\": 500}}")
	_write_json(mods_dir + "/aa.json", "{\"tuning\": {\"starting_money\": 600}}")
	_write_json(mods_dir + "/zz.json", "{\"tuning\": {\"starting_money\": 700}}")
	var loader: GameDataLoader = GameDataLoader.new(base_dir, mods_dir)
	var report: DataLoadReport = loader.load_all()
	assert_bool(report.is_ok()).is_true()
	# Later alphabetically wins: zz.json overrides aa.json.
	assert_int(loader.tuning.starting_money).is_equal(700)


func test_partial_mod_preserves_untouched_siblings() -> void:
	var base_dir: String = create_temp_dir("loader_mod_partial_base")
	var mods_dir: String = create_temp_dir("loader_mod_partial_mods")
	_write_json(
		base_dir + "/tuning.json",
		"{\"tuning\": {\"base_pay\": {\"normal\": 60, \"fragile\": 120}}}"
	)
	_write_json(mods_dir + "/fragile_only.json", "{\"tuning\": {\"base_pay\": {\"fragile\": 999}}}")
	var loader: GameDataLoader = GameDataLoader.new(base_dir, mods_dir)
	var report: DataLoadReport = loader.load_all()
	assert_bool(report.is_ok()).is_true()
	assert_int(loader.tuning.base_pay["fragile"]).is_equal(999)
	assert_int(loader.tuning.base_pay["normal"]).is_equal(60)


func test_mod_with_error_is_rejected_entirely() -> void:
	var base_dir: String = create_temp_dir("loader_mod_bad_base")
	var mods_dir: String = create_temp_dir("loader_mod_bad_mods")
	_write_json(base_dir + "/tuning.json", "{\"tuning\": {\"starting_money\": 500}}")
	var bad_mod_path: String = mods_dir + "/bad.json"
	_write_json(bad_mod_path, "{\"tuning\": {\"starting_money\": \"mucho\"}}")
	var loader: GameDataLoader = GameDataLoader.new(base_dir, mods_dir)
	var report: DataLoadReport = loader.load_all()
	# A rejected mod is a warning, never a load failure (D45).
	assert_bool(report.is_ok()).is_true()
	assert_int(loader.tuning.starting_money).is_equal(500)
	assert_bool(_has_warning_containing(report, "REJECTED")).is_true()
	var applied: PackedStringArray = report.applied_files
	assert_int(applied.size()).is_equal(1)
	assert_str(applied[0]).is_equal(base_dir + "/tuning.json")


func test_invalid_base_json_marks_report_not_ok() -> void:
	var base_dir: String = create_temp_dir("loader_bad_base_base")
	var mods_dir: String = create_temp_dir("loader_bad_base_mods")
	_write_json(base_dir + "/tuning.json", "{\"tuning\": ")
	var loader: GameDataLoader = GameDataLoader.new(base_dir, mods_dir)
	var report: DataLoadReport = loader.load_all()
	# Broken base layer: omitted, report not ok, and with no .tres around the
	# resource keeps its neutral defaults (D44/D45).
	assert_bool(report.is_ok()).is_false()
	assert_int(loader.tuning.starting_money).is_equal(0)


func test_real_res_data_loads_without_errors() -> void:
	# The shipped data must always load clean: real res://data with an empty
	# injected mods dir (the real user://mods is never touched).
	var mods_dir: String = create_temp_dir("loader_real_data_mods")
	var loader: GameDataLoader = GameDataLoader.new("res://data", mods_dir)
	var report: DataLoadReport = loader.load_all()
	assert_bool(report.is_ok()).is_true()
	assert_int(report.errors.size()).is_equal(0)
	assert_int(loader.game_config.max_players).is_greater_equal(1)
	assert_int(loader.tuning.starting_money).is_greater_equal(1)
