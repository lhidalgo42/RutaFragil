extends GdUnitTestSuite

## ResourceJsonCodec contract (D44/D45): the schema is exactly the @export
## fields, validation happens before any set(), and only values that survive
## validation are applied. Fixture resource: tests/core/data/fixtures.

const CODEC_FIXTURE: GDScript = preload("res://tests/core/data/fixtures/codec_fixture.gd")


func test_schema_contains_only_exported_fields() -> void:
	var schema: Dictionary = ResourceJsonCodec.schema_of(TuningTable.new())
	assert_bool(schema.has("starting_money")).is_true()
	assert_bool(schema.has("base_pay")).is_true()
	assert_bool(schema.has("resource_name")).is_false()
	assert_bool(schema.has("resource_path")).is_false()
	assert_bool(schema.has("script")).is_false()
	var info: Dictionary = schema["base_pay"]
	assert_int(info["type"]).is_equal(TYPE_DICTIONARY)
	assert_int(info["key_type"]).is_equal(TYPE_STRING)
	assert_int(info["value_type"]).is_equal(TYPE_INT)
	var config_schema: Dictionary = ResourceJsonCodec.schema_of(GameConfigData.new())
	assert_int(config_schema.size()).is_equal(3)


func test_neutral_defaults_are_zero_and_empty() -> void:
	# R2/D44: values live in the data files, never in the schema defaults.
	var tuning: TuningTable = TuningTable.new()
	assert_int(tuning.starting_money).is_equal(0)
	assert_float(tuning.rent_increase_per_cycle).is_equal_approx(0.0, 0.0001)
	assert_dict(tuning.base_pay).is_empty()
	assert_dict(tuning.shop_prices).is_empty()
	var config: GameConfigData = GameConfigData.new()
	assert_int(config.schema_version).is_equal(0)
	assert_int(config.max_players).is_equal(0)
	assert_int(config.max_players_hard_limit).is_equal(0)


func test_int_field_accepts_integral_float() -> void:
	var tuning: TuningTable = TuningTable.new()
	var report: DataLoadReport = DataLoadReport.new()
	var valid: Dictionary = ResourceJsonCodec.validate(
		tuning, {"starting_money": 500.0}, report, "test", true
	)
	assert_bool(report.is_ok()).is_true()
	assert_dict(valid).is_equal({"starting_money": 500})
	ResourceJsonCodec.apply(tuning, valid)
	assert_int(tuning.starting_money).is_equal(500)


func test_int_field_rejects_fractional_float_and_keeps_previous_value() -> void:
	var tuning: TuningTable = TuningTable.new()
	tuning.starting_money = 42
	var report: DataLoadReport = DataLoadReport.new()
	var valid: Dictionary = ResourceJsonCodec.validate(
		tuning, {"starting_money": 6.5}, report, "test", true
	)
	assert_bool(report.is_ok()).is_false()
	assert_dict(valid).is_empty()
	ResourceJsonCodec.apply(tuning, valid)
	assert_int(tuning.starting_money).is_equal(42)


func test_int_field_rejects_string() -> void:
	var tuning: TuningTable = TuningTable.new()
	tuning.starting_money = 42
	var report: DataLoadReport = DataLoadReport.new()
	var valid: Dictionary = ResourceJsonCodec.validate(
		tuning, {"starting_money": "12"}, report, "test", true
	)
	assert_bool(report.is_ok()).is_false()
	assert_dict(valid).is_empty()
	assert_str(report.errors[0]).contains("expected an int")
	ResourceJsonCodec.apply(tuning, valid)
	assert_int(tuning.starting_money).is_equal(42)


func test_bool_field_accepts_bool_and_rejects_number_and_string() -> void:
	var fixture: Resource = CODEC_FIXTURE.new()
	var ok_report: DataLoadReport = DataLoadReport.new()
	var valid: Dictionary = ResourceJsonCodec.validate(
		fixture, {"flag_enabled": true}, ok_report, "test", true
	)
	assert_bool(ok_report.is_ok()).is_true()
	ResourceJsonCodec.apply(fixture, valid)
	assert_bool(fixture.get("flag_enabled")).is_true()
	var float_report: DataLoadReport = DataLoadReport.new()
	var valid_float: Dictionary = ResourceJsonCodec.validate(
		fixture, {"flag_enabled": 1.0}, float_report, "test", true
	)
	assert_bool(float_report.is_ok()).is_false()
	assert_dict(valid_float).is_empty()
	var string_report: DataLoadReport = DataLoadReport.new()
	var valid_string: Dictionary = ResourceJsonCodec.validate(
		fixture, {"flag_enabled": "true"}, string_report, "test", true
	)
	assert_bool(string_report.is_ok()).is_false()
	assert_dict(valid_string).is_empty()
	assert_str(string_report.errors[0]).contains("expected a bool")


func test_unknown_key_is_a_warning_in_mod_mode() -> void:
	var tuning: TuningTable = TuningTable.new()
	var report: DataLoadReport = DataLoadReport.new()
	var valid: Dictionary = ResourceJsonCodec.validate(
		tuning, {"starting_money": 7.0, "not_a_field": 1.0}, report, "mod:test", false
	)
	# Lenient mode: only the unknown key is dropped, the rest still applies.
	assert_bool(report.is_ok()).is_true()
	assert_int(report.warnings.size()).is_equal(1)
	assert_str(report.warnings[0]).contains("unknown key 'not_a_field'")
	assert_dict(valid).is_equal({"starting_money": 7})


func test_unknown_key_is_an_error_in_base_mode() -> void:
	var tuning: TuningTable = TuningTable.new()
	var report: DataLoadReport = DataLoadReport.new()
	var valid: Dictionary = ResourceJsonCodec.validate(
		tuning, {"starting_money": 7.0, "not_a_field": 1.0}, report, "base:test", true
	)
	# Strict mode: any error voids the whole section, valid keys included.
	assert_bool(report.is_ok()).is_false()
	assert_dict(valid).is_empty()
	assert_str(report.errors[0]).contains("unknown key 'not_a_field'")


func test_typed_dictionary_is_validated_and_applied_with_assign() -> void:
	var tuning: TuningTable = TuningTable.new()
	var report: DataLoadReport = DataLoadReport.new()
	var valid: Dictionary = ResourceJsonCodec.validate(
		tuning, {"base_pay": {"fragile": 9.0, "normal": 60.0}}, report, "test", true
	)
	assert_bool(report.is_ok()).is_true()
	# JSON floats arrive integral, so values coerce to real ints before apply.
	var pay: Dictionary = valid["base_pay"]
	assert_int(pay["fragile"]).is_equal(9)
	ResourceJsonCodec.apply(tuning, valid)
	assert_int(tuning.base_pay["fragile"]).is_equal(9)
	assert_int(tuning.base_pay["normal"]).is_equal(60)
	var bad_report: DataLoadReport = DataLoadReport.new()
	var valid_bad: Dictionary = ResourceJsonCodec.validate(
		tuning, {"base_pay": {"fragile": "mucho"}}, bad_report, "test", true
	)
	assert_bool(bad_report.is_ok()).is_false()
	assert_dict(valid_bad).is_empty()


func test_to_dictionary_round_trip_through_apply() -> void:
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
	var snapshot: Dictionary = ResourceJsonCodec.to_dictionary(tuning)
	assert_int(snapshot["starting_money"]).is_equal(500)
	assert_float(snapshot["jerrycan_pour_seconds"]).is_equal_approx(7.5, 0.0001)
	var copy: TuningTable = TuningTable.new()
	ResourceJsonCodec.apply(copy, snapshot)
	var snapshot_copy: Dictionary = ResourceJsonCodec.to_dictionary(copy)
	assert_dict(snapshot_copy).is_equal(snapshot)


func test_lenient_mode_with_type_error_voids_the_whole_file() -> void:
	# M2: unknown keys are the only case whose severity depends on the layer;
	# a type error invalidates every key of the file even in lenient (mod)
	# mode, valid sister keys included.
	var tuning: TuningTable = TuningTable.new()
	var report: DataLoadReport = DataLoadReport.new()
	var valid: Dictionary = ResourceJsonCodec.validate(
		tuning, {"starting_money": "mucho", "rent_quota": 1.0}, report, "mod:test", false
	)
	assert_bool(report.is_ok()).is_false()
	assert_dict(valid).is_empty()
	assert_str(report.errors[0]).contains("starting_money")


func test_string_field_accepts_a_string() -> void:
	var fixture: Resource = CODEC_FIXTURE.new()
	var report: DataLoadReport = DataLoadReport.new()
	var valid: Dictionary = ResourceJsonCodec.validate(
		fixture, {"label_text": "ruta norte"}, report, "test", true
	)
	assert_bool(report.is_ok()).is_true()
	assert_dict(valid).is_equal({"label_text": "ruta norte"})
	ResourceJsonCodec.apply(fixture, valid)
	var label_v: Variant = fixture.get("label_text")
	assert_bool(label_v is String).is_true()
	if label_v is String:
		var label: String = label_v
		assert_str(label).is_equal("ruta norte")


func test_string_field_rejects_non_string_and_keeps_previous_value() -> void:
	var fixture: Resource = CODEC_FIXTURE.new()
	fixture.set("label_text", "original")
	var report: DataLoadReport = DataLoadReport.new()
	var valid: Dictionary = ResourceJsonCodec.validate(
		fixture, {"label_text": 4.0}, report, "test", true
	)
	assert_bool(report.is_ok()).is_false()
	assert_dict(valid).is_empty()
	assert_str(report.errors[0]).contains("expected a string")
	ResourceJsonCodec.apply(fixture, valid)
	var label_v: Variant = fixture.get("label_text")
	assert_bool(label_v is String).is_true()
	if label_v is String:
		var label: String = label_v
		assert_str(label).is_equal("original")
