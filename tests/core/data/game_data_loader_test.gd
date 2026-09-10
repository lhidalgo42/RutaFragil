extends GdUnitTestSuite

## GameDataLoader contract (D45): layers .tres -> base .json -> mods/*.json,
## deep merge per document, byte (ASCII) mod order, whole-mod rejection on
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


func test_two_mods_apply_in_byte_order() -> void:
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
	# Base layers first, then the mods in byte (ASCII) order.
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


func test_invalid_base_json_error_points_at_the_truncated_file() -> void:
	# M1(c): a broken base JSON omits the layer and fails the report, but the
	# game keeps the .tres values (D45). The game_config base layer is present
	# on purpose: with it, the single reported error must come from the
	# truncated tuning.json itself and not from a document with no layer (M4).
	var base_dir: String = create_temp_dir("loader_bad_base_base")
	var mods_dir: String = create_temp_dir("loader_bad_base_mods")
	_write_base_game_config(base_dir)
	_write_tuning_tres(base_dir, 321)
	_write_json(base_dir + "/tuning.json", "{\"tuning\": ")
	var loader: GameDataLoader = GameDataLoader.new(base_dir, mods_dir)
	var report: DataLoadReport = loader.load_all()
	assert_bool(report.is_ok()).is_false()
	assert_int(loader.tuning.starting_money).is_equal(321)
	assert_int(report.errors.size()).is_equal(1)
	assert_str(report.errors[0]).starts_with("base:" + base_dir + "/tuning.json")
	var applied: PackedStringArray = report.applied_files
	assert_int(applied.size()).is_equal(2)
	assert_str(applied[0]).is_equal(base_dir + "/game_config.json")
	assert_str(applied[1]).is_equal(base_dir + "/tuning.tres")


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


func test_empty_dirs_fail_with_one_error_per_document() -> void:
	# M4 (MR1): with no data at all, every document reports its own load
	# error; without data the game would otherwise run on zeroes in silence.
	var base_dir: String = create_temp_dir("loader_empty_base")
	var mods_dir: String = create_temp_dir("loader_empty_mods")
	var loader: GameDataLoader = GameDataLoader.new(base_dir, mods_dir)
	var report: DataLoadReport = loader.load_all()
	assert_bool(report.is_ok()).is_false()
	assert_int(report.errors.size()).is_equal(2)
	# DOCS iterates game_config first, then tuning.
	assert_str(report.errors[0]).is_equal(
		"doc:game_config: no .tres or base .json layer applied"
	)
	assert_str(report.errors[1]).is_equal("doc:tuning: no .tres or base .json layer applied")
	assert_int(report.applied_files.size()).is_equal(0)


func test_mc1a_empty_object_base_json_is_an_error() -> void:
	# mc1: a base JSON of "{}" parses fine but carries no document section, so
	# it is a load error naming the file, and the document still counts as
	# having no applied layer (M4).
	var base_dir: String = create_temp_dir("loader_mc1a_base")
	var mods_dir: String = create_temp_dir("loader_mc1a_mods")
	_write_json(base_dir + "/game_config.json", "{}")
	_write_json(base_dir + "/tuning.json", "{\"tuning\": {\"starting_money\": 500}}")
	var loader: GameDataLoader = GameDataLoader.new(base_dir, mods_dir)
	var report: DataLoadReport = loader.load_all()
	assert_bool(report.is_ok()).is_false()
	assert_int(report.errors.size()).is_equal(2)
	assert_str(report.errors[0]).is_equal(
		"base:" + base_dir + "/game_config.json: missing object section 'game_config'"
	)
	assert_str(report.errors[1]).is_equal(
		"doc:game_config: no .tres or base .json layer applied"
	)
	assert_int(loader.tuning.starting_money).is_equal(500)


func test_mc1b_empty_object_mod_applies_with_a_warning() -> void:
	# mc1: a mod of "{}" is well-formed and empty, not a rejection: it lands
	# in applied_files with a "no sections" warning and changes nothing.
	var base_dir: String = create_temp_dir("loader_mc1b_base")
	var mods_dir: String = create_temp_dir("loader_mc1b_mods")
	_write_base_game_config(base_dir)
	_write_json(base_dir + "/tuning.json", "{\"tuning\": {\"starting_money\": 500}}")
	_write_json(mods_dir + "/empty.json", "{}")
	var loader: GameDataLoader = GameDataLoader.new(base_dir, mods_dir)
	var report: DataLoadReport = loader.load_all()
	assert_bool(report.is_ok()).is_true()
	assert_int(loader.tuning.starting_money).is_equal(500)
	assert_int(report.warnings.size()).is_equal(1)
	assert_str(report.warnings[0]).is_equal("mod:empty.json: no sections; nothing to apply")
	var applied: PackedStringArray = report.applied_files
	assert_int(applied.size()).is_equal(3)
	assert_str(applied[2]).is_equal(mods_dir + "/empty.json")


func test_mod_with_only_unknown_sections_applies_with_warning() -> void:
	# A mod whose sections are all unknown is not a rejection (D45): each one
	# becomes a warning and the file still lands in applied_files.
	var base_dir: String = create_temp_dir("loader_unknown_mod_base")
	var mods_dir: String = create_temp_dir("loader_unknown_mod_mods")
	_write_base_game_config(base_dir)
	_write_json(base_dir + "/tuning.json", "{\"tuning\": {\"starting_money\": 500}}")
	_write_json(mods_dir + "/mystery.json", "{\"workshop\": {\"bench\": 1}}")
	var loader: GameDataLoader = GameDataLoader.new(base_dir, mods_dir)
	var report: DataLoadReport = loader.load_all()
	assert_bool(report.is_ok()).is_true()
	assert_int(loader.tuning.starting_money).is_equal(500)
	assert_int(report.warnings.size()).is_equal(1)
	assert_str(report.warnings[0]).is_equal(
		"mod:mystery.json: unknown section 'workshop' ignored"
	)
	var applied: PackedStringArray = report.applied_files
	assert_int(applied.size()).is_equal(3)
	assert_str(applied[2]).is_equal(mods_dir + "/mystery.json")


func test_mc3_tres_of_wrong_class_is_an_error() -> void:
	# mc3: a .tres holding another document class must not merge foreign keys
	# into the document; the layer is rejected as an error and the base JSON
	# still applies.
	var base_dir: String = create_temp_dir("loader_mc3_base")
	var mods_dir: String = create_temp_dir("loader_mc3_mods")
	_write_base_game_config(base_dir)
	_write_json(base_dir + "/tuning.json", "{\"tuning\": {\"starting_money\": 500}}")
	assert_int(
		ResourceSaver.save(GameConfigData.new(), base_dir + "/tuning.tres")
	).is_equal(OK)
	var loader: GameDataLoader = GameDataLoader.new(base_dir, mods_dir)
	var report: DataLoadReport = loader.load_all()
	assert_bool(report.is_ok()).is_false()
	assert_int(report.errors.size()).is_equal(1)
	assert_str(report.errors[0]).is_equal(
		(
			"tres:" + base_dir + "/tuning.tres:"
			+ " resource is not a res://src/core/data/tuning_table.gd"
		)
	)
	assert_int(loader.tuning.starting_money).is_equal(500)


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
