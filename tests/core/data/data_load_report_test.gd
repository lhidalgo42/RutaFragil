extends GdUnitTestSuite

## DataLoadReport contract (M3, R13): is_ok() reflects errors only, entries
## keep the "<source>: <message>" format, and summary() renders the header
## plus one tagged line per entry. summary() is what the CLI tools print and
## what the evidence files capture, so its exact shape is pinned here.


func test_fresh_report_is_ok_and_empty() -> void:
	var report: DataLoadReport = DataLoadReport.new()
	assert_bool(report.is_ok()).is_true()
	assert_int(report.errors.size()).is_equal(0)
	assert_int(report.warnings.size()).is_equal(0)
	assert_int(report.applied_files.size()).is_equal(0)


func test_errors_make_is_ok_false() -> void:
	var report: DataLoadReport = DataLoadReport.new()
	report.add_error("base:tuning.json", "broken")
	assert_bool(report.is_ok()).is_false()


func test_warnings_alone_keep_is_ok_true() -> void:
	# A rejected mod becomes a warning and must never fail a load (D45).
	var report: DataLoadReport = DataLoadReport.new()
	report.add_warning("mod:zz.json", "unknown key ignored")
	assert_bool(report.is_ok()).is_true()


func test_add_error_and_warning_format_source_then_message() -> void:
	var report: DataLoadReport = DataLoadReport.new()
	report.add_error("base:tuning.json", "missing object section 'tuning'")
	report.add_warning("mod:zz.json", "unknown section 'cheats' ignored")
	assert_str(report.errors[0]).is_equal("base:tuning.json: missing object section 'tuning'")
	assert_str(report.warnings[0]).is_equal("mod:zz.json: unknown section 'cheats' ignored")


func test_summary_has_header_and_one_tagged_line_per_entry() -> void:
	var report: DataLoadReport = DataLoadReport.new()
	report.applied_files.append("res://data/tuning.tres")
	report.applied_files.append("user://mods/zz.json")
	report.add_warning("mod:zz.json", "unknown key 'cheat' ignored")
	report.add_error("doc:game_config", "no .tres or base .json layer applied")
	var expected: String = (
		"data load: 2 applied, 1 warning(s), 1 error(s)"
		+ "\n  [applied] res://data/tuning.tres"
		+ "\n  [applied] user://mods/zz.json"
		+ "\n  [warning] mod:zz.json: unknown key 'cheat' ignored"
		+ "\n  [error] doc:game_config: no .tres or base .json layer applied"
	)
	assert_str(report.summary()).is_equal(expected)


func test_summary_of_empty_report_is_only_the_header() -> void:
	var report: DataLoadReport = DataLoadReport.new()
	assert_str(report.summary()).is_equal("data load: 0 applied, 0 warning(s), 0 error(s)")
