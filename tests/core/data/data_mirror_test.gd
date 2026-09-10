extends GdUnitTestSuite

## DataMirror contract (D44): res://data/<doc>.json must be the exact mirror
## of <doc>.tres, and a regenerated mirror is byte-identical (idempotent).


func test_real_data_mirror_is_in_sync() -> void:
	# Drift guard: if someone edits one side of the pair, this fails.
	var report: DataLoadReport = DataLoadReport.new()
	var config: Resource = ResourceLoader.load(
		"res://data/game_config.tres", "", ResourceLoader.CACHE_MODE_IGNORE
	)
	assert_object(config).is_not_null()
	assert_bool(
		DataMirror.check_mirror(config, "game_config", "res://data/game_config.json", report)
	).is_true()
	var tuning: Resource = ResourceLoader.load(
		"res://data/tuning.tres", "", ResourceLoader.CACHE_MODE_IGNORE
	)
	assert_object(tuning).is_not_null()
	assert_bool(
		DataMirror.check_mirror(tuning, "tuning", "res://data/tuning.json", report)
	).is_true()
	assert_bool(report.is_ok()).is_true()


func test_write_and_check_round_trip_in_temp_dir() -> void:
	var tuning: TuningTable = TuningTable.new()
	var report: DataLoadReport = DataLoadReport.new()
	var valid: Dictionary = ResourceJsonCodec.validate(
		tuning,
		{"starting_money": 500.0, "jerrycan_pour_seconds": 7.5, "base_pay": {"normal": 60.0}},
		report,
		"test",
		true
	)
	ResourceJsonCodec.apply(tuning, valid)
	var json_path: String = create_temp_dir("mirror_round_trip") + "/tuning.json"
	assert_int(DataMirror.write_mirror(tuning, "tuning", json_path)).is_equal(OK)
	var check_report: DataLoadReport = DataLoadReport.new()
	assert_bool(DataMirror.check_mirror(tuning, "tuning", json_path, check_report)).is_true()
	assert_bool(check_report.is_ok()).is_true()
	# Regenerating over the same file is byte-identical: no phantom diffs.
	var first_text: String = FileAccess.get_file_as_string(json_path)
	assert_int(DataMirror.write_mirror(tuning, "tuning", json_path)).is_equal(OK)
	assert_str(FileAccess.get_file_as_string(json_path)).is_equal(first_text)
	# And the written mirror parses back to the same values (JSON numbers
	# come back as floats, so expectations here are float literals).
	var read_report: DataLoadReport = DataLoadReport.new()
	var raw: Dictionary = JsonFile.read_object(json_path, read_report, "test")
	assert_bool(read_report.is_ok()).is_true()
	var section_v: Variant = raw["tuning"]
	assert_bool(section_v is Dictionary).is_true()
	if section_v is Dictionary:
		var section: Dictionary = section_v
		assert_float(section["starting_money"]).is_equal_approx(500.0, 0.0001)
		assert_float(section["jerrycan_pour_seconds"]).is_equal_approx(7.5, 0.0001)
