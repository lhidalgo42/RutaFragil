extends GdUnitTestSuite

## GameDataLoader contract (D45): layers .tres -> base .json -> mods/*.json,
## deep merge per document, alphabetical mod order, whole-mod rejection on
## any error. Directories are injected from create_temp_dir, never the real
## user://mods. A document with no applied layer is a load error (M4), so
## fixtures that assert is_ok() write a base layer for both documents.


func _write_json(path: String, text: String) -> void:
	assert_int(JsonFile.write_text(path, text)).is_equal(OK)


## game_config layer shared by the fixtures; each test writes its own
## tuning.json/.tres with the values it cares about.
func _write_base_game_config(base_dir: String) -> void:
	_write_json(base_dir + "/game_config.json", "{\"game_config\": {\"max_players\": 6}}")


func _write_tuning_tres(base_dir: String, starting_money: int) -> void:
	var table: TuningTable = TuningTable.new()
	table.starting_money = starting_money
	assert_int(ResourceSaver.save(table, base_dir + "/tuning.tres")).is_equal(OK)


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
	_write_base_game_config(base_dir)
	var tuning_path: String = base_dir + "/tuning.json"
	_write_json(tuning_path, "{\"tuning\": {\"starting_money\": 500}}")
	var loader: GameDataLoader = GameDataLoader.new(base_dir, mods_dir)
	var first_report: DataLoadReport = loader.load_all()
	assert_bool(first_report.is_ok()).is_true()
	assert_int(loader.tuning.starting_money).is_equal(500)
	_write_json(tuning_path, "{\"tuning\": {\"starting_money\": 777}}")
	var second_report: DataLoadReport = loader.load_all()
	assert_bool(second_report.is_ok()).is_true()
	assert_int(loader.tuning.starting_money).is_equal(777)


func test_mod_overrides_base() -> void:
	# Acceptance criterion 2: a JSON in mods wins over the base layer.
	var base_dir: String = create_temp_dir("loader_mod_base_base")
	var mods_dir: String = create_temp_dir("loader_mod_base_mods")
	_write_base_game_config(base_dir)
	_write_json(base_dir + "/tuning.json", "{\"tuning\": {\"starting_money\": 500}}")
	_write_json(mods_dir + "/my_mod.json", "{\"tuning\": {\"starting_money\": 999}}")
	var loader: GameDataLoader = GameDataLoader.new(base_dir, mods_dir)
	var report: DataLoadReport = loader.load_all()
	assert_bool(report.is_ok()).is_true()
	assert_int(loader.tuning.starting_money).is_equal(999)


func test_two_mods_apply_in_alphabetical_order() -> void:
	var base_dir: String = create_temp_dir("loader_mod_order_base")
	var mods_dir: String = create_temp_dir("loader_mod_order_mods")
	_write_base_game_config(base_dir)
	_write_json(
		base_dir + "/tuning.json",
		"{\"tuning\": {\"starting_money\": 500, \"rent_quota\": 900}}"
	)
	# zz.json is written FIRST on purpose: only the loader's sort, never the
	# filesystem write order, may decide the mod order (mt1).
	_write_json(mods_dir + "/zz.json", "{\"tuning\": {\"starting_money\": 700}}")
	_write_json(mods_dir + "/aa.json", "{\"tuning\": {\"rent_quota\": 950}}")
	var loader: GameDataLoader = GameDataLoader.new(base_dir, mods_dir)
	var report: DataLoadReport = loader.load_all()
	assert_bool(report.is_ok()).is_true()
	# Each mod contributes the key the other does not touch.
	assert_int(loader.tuning.starting_money).is_equal(700)
	assert_int(loader.tuning.rent_quota).is_equal(950)
	# Base layers first, then the mods in alphabetical order.
	var applied: PackedStringArray = report.applied_files
	assert_int(applied.size()).is_equal(4)
	assert_str(applied[0]).is_equal(base_dir + "/game_config.json")
	assert_str(applied[1]).is_equal(base_dir + "/tuning.json")
	assert_str(applied[2]).is_equal(mods_dir + "/aa.json")
	assert_str(applied[3]).is_equal(mods_dir + "/zz.json")


func test_partial_mod_preserves_untouched_siblings() -> void:
	var base_dir: String = create_temp_dir("loader_mod_partial_base")
	var mods_dir: String = create_temp_dir("loader_mod_partial_mods")
	_write_base_game_config(base_dir)
	_write_json(
		base_dir + "/tuning.json",
		"{\"tuning\": {\"starting_money\": 500, \"base_pay\": {\"normal\": 60, \"fragile\": 120}}}"
	)
	_write_json(mods_dir + "/fragile_only.json", "{\"tuning\": {\"base_pay\": {\"fragile\": 999}}}")
	var loader: GameDataLoader = GameDataLoader.new(base_dir, mods_dir)
	var report: DataLoadReport = loader.load_all()
	assert_bool(report.is_ok()).is_true()
	assert_int(loader.tuning.base_pay["fragile"]).is_equal(999)
	assert_int(loader.tuning.base_pay["normal"]).is_equal(60)
	# Untouched top-level sibling of the section survives the merge too (mt3).
	assert_int(loader.tuning.starting_money).is_equal(500)


func test_mod_with_error_is_rejected_entirely() -> void:
	var base_dir: String = create_temp_dir("loader_mod_bad_base")
	var mods_dir: String = create_temp_dir("loader_mod_bad_mods")
	_write_base_game_config(base_dir)
	_write_json(base_dir + "/tuning.json", "{\"tuning\": {\"starting_money\": 500}}")
	_write_json(mods_dir + "/bad.json", "{\"tuning\": {\"starting_money\": \"mucho\"}}")
	var loader: GameDataLoader = GameDataLoader.new(base_dir, mods_dir)
	var report: DataLoadReport = loader.load_all()
	# A rejected mod is a warning, never a load failure (D45).
	assert_bool(report.is_ok()).is_true()
	assert_int(loader.tuning.starting_money).is_equal(500)
	assert_bool(_has_warning_containing(report, "REJECTED")).is_true()
	var applied: PackedStringArray = report.applied_files
	assert_int(applied.size()).is_equal(2)
	assert_str(applied[0]).is_equal(base_dir + "/game_config.json")
	assert_str(applied[1]).is_equal(base_dir + "/tuning.json")


func test_mod_with_failing_section_is_rejected_entirely() -> void:
	# M2: two sections in one file, one with a type error. A per-key or
	# per-section rejection would let the valid keys through; the contract is
	# that the whole file applies or nothing does (D45).
	var base_dir: String = create_temp_dir("loader_mod_sections_base")
	var mods_dir: String = create_temp_dir("loader_mod_sections_mods")
	_write_base_game_config(base_dir)
	_write_json(
		base_dir + "/tuning.json",
		"{\"tuning\": {\"starting_money\": 500, \"rent_quota\": 900}}"
	)
	_write_json(
		mods_dir + "/mixed.json",
		(
			"{\"tuning\": {\"starting_money\": \"mucho\", \"rent_quota\": 1},"
			+ " \"game_config\": {\"max_players\": 2}}"
		)
	)
	var loader: GameDataLoader = GameDataLoader.new(base_dir, mods_dir)
	var report: DataLoadReport = loader.load_all()
	assert_bool(report.is_ok()).is_true()
	# The bad key, its valid sister key AND the valid second section are all
	# dropped with the file.
	assert_int(loader.tuning.starting_money).is_equal(500)
	assert_int(loader.tuning.rent_quota).is_equal(900)
	assert_int(loader.game_config.max_players).is_equal(6)
	assert_bool(_has_warning_containing(report, "REJECTED")).is_true()
	var applied: PackedStringArray = report.applied_files
	assert_int(applied.size()).is_equal(2)
	assert_str(applied[0]).is_equal(base_dir + "/game_config.json")
	assert_str(applied[1]).is_equal(base_dir + "/tuning.json")


func test_tres_layer_only_loads_values() -> void:
	# M1(a): a document served only by its .tres layer must load (the shipped
	# artifact, D44); without this the first layer of D45 is never exercised.
	var base_dir: String = create_temp_dir("loader_tres_only_base")
	var mods_dir: String = create_temp_dir("loader_tres_only_mods")
	_write_base_game_config(base_dir)
	_write_tuning_tres(base_dir, 321)
	var loader: GameDataLoader = GameDataLoader.new(base_dir, mods_dir)
	var report: DataLoadReport = loader.load_all()
	assert_bool(report.is_ok()).is_true()
	assert_int(loader.tuning.starting_money).is_equal(321)
	var applied: PackedStringArray = report.applied_files
	assert_int(applied.size()).is_equal(2)
	assert_str(applied[1]).is_equal(base_dir + "/tuning.tres")


func test_base_json_wins_over_tres_layer() -> void:
	# M1(b): the JSON mirror is the upper layer and wins (D45, hot-edit path).
	var base_dir: String = create_temp_dir("loader_tres_then_json_base")
	var mods_dir: String = create_temp_dir("loader_tres_then_json_mods")
	_write_base_game_config(base_dir)
	_write_tuning_tres(base_dir, 321)
	_write_json(base_dir + "/tuning.json", "{\"tuning\": {\"starting_money\": 500}}")
	var loader: GameDataLoader = GameDataLoader.new(base_dir, mods_dir)
	var report: DataLoadReport = loader.load_all()
	assert_bool(report.is_ok()).is_true()
	assert_int(loader.tuning.starting_money).is_equal(500)
	assert_int(report.applied_files.size()).is_equal(3)


func test_invalid_base_json_marks_report_not_ok() -> void:
	# M1(c): broken base JSON omits the layer and fails the report, but the
	# game keeps the .tres values (D45).
	var base_dir: String = create_temp_dir("loader_bad_base_base")
	var mods_dir: String = create_temp_dir("loader_bad_base_mods")
	_write_tuning_tres(base_dir, 321)
	_write_json(base_dir + "/tuning.json", "{\"tuning\": ")
	var loader: GameDataLoader = GameDataLoader.new(base_dir, mods_dir)
	var report: DataLoadReport = loader.load_all()
	assert_bool(report.is_ok()).is_false()
	assert_int(loader.tuning.starting_money).is_equal(321)
	var applied: PackedStringArray = report.applied_files
	assert_int(applied.size()).is_equal(1)
	assert_str(applied[0]).is_equal(base_dir + "/tuning.tres")


func test_tres_layer_reload_rereads_the_file() -> void:
	# M1(d): the same loader instance must see a rewritten .tres on the next
	# load_all(); anything else means the resource cache, not
	# CACHE_MODE_IGNORE, is deciding (D45).
	var base_dir: String = create_temp_dir("loader_tres_reload_base")
	var mods_dir: String = create_temp_dir("loader_tres_reload_mods")
	_write_base_game_config(base_dir)
	_write_tuning_tres(base_dir, 321)
	var loader: GameDataLoader = GameDataLoader.new(base_dir, mods_dir)
	var first_report: DataLoadReport = loader.load_all()
	assert_bool(first_report.is_ok()).is_true()
	assert_int(loader.tuning.starting_money).is_equal(321)
	_write_tuning_tres(base_dir, 654)
	var second_report: DataLoadReport = loader.load_all()
	assert_bool(second_report.is_ok()).is_true()
	assert_int(loader.tuning.starting_money).is_equal(654)


func test_real_res_data_loads_without_errors() -> void:
	# The shipped data must always load clean: real res://data with an empty
	# injected mods dir (the real user://mods is never touched).
	var mods_dir: String = create_temp_dir("loader_real_data_mods")
	var loader: GameDataLoader = GameDataLoader.new("res://data", mods_dir)
	var report: DataLoadReport = loader.load_all()
	assert_bool(report.is_ok()).is_true()
	assert_int(report.errors.size()).is_equal(0)
	# mt2: both documents arrive through both layers (.tres + .json each), and
	# no warning goes unnoticed.
	assert_int(report.applied_files.size()).is_equal(4)
	assert_bool(report.warnings.is_empty()).is_true()
	assert_int(loader.game_config.max_players).is_greater_equal(1)
	assert_int(loader.tuning.starting_money).is_greater_equal(1)
