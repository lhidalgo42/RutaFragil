extends GdUnitTestSuite

## JsonFile IO contract: quiet instance parsing (no engine ERROR), errors
## recorded in the DataLoadReport with line and message, {} on failure.


func test_read_valid_file_returns_object() -> void:
	var dir: String = create_temp_dir("json_file_valid")
	var path: String = dir + "/doc.json"
	assert_int(JsonFile.write_text(path, "{\"a\": 2, \"nested\": {\"b\": 3.5}}")).is_equal(OK)
	var report: DataLoadReport = DataLoadReport.new()
	var result: Dictionary = JsonFile.read_object(path, report, "test")
	assert_bool(report.is_ok()).is_true()
	# Every JSON number arrives as float: expectations use float literals.
	assert_dict(result).is_equal({"a": 2.0, "nested": {"b": 3.5}})


func test_missing_file_records_error_and_returns_empty() -> void:
	var dir: String = create_temp_dir("json_file_missing")
	var report: DataLoadReport = DataLoadReport.new()
	var result: Dictionary = JsonFile.read_object(dir + "/nope.json", report, "test")
	assert_dict(result).is_empty()
	assert_bool(report.is_ok()).is_false()
	assert_int(report.errors.size()).is_equal(1)
	assert_str(report.errors[0]).contains("file not found")


func test_malformed_json_reports_line_and_message() -> void:
	var dir: String = create_temp_dir("json_file_malformed")
	var path: String = dir + "/broken.json"
	assert_int(JsonFile.write_text(path, "{\"a\": ]")).is_equal(OK)
	var report: DataLoadReport = DataLoadReport.new()
	var result: Dictionary = JsonFile.read_object(path, report, "test")
	assert_dict(result).is_empty()
	assert_int(report.errors.size()).is_equal(1)
	# Format is "<source>: <path>:<line>: <message>": the part after the
	# source and path must carry a line number and a non-empty message.
	var prefix: String = "test: " + path + ":"
	var error_text: String = report.errors[0]
	assert_str(error_text).starts_with(prefix)
	var remainder: String = error_text.substr(prefix.length())
	assert_str(remainder).contains(":")
	var colon_at: int = remainder.find(":")
	assert_bool(remainder.length() > colon_at + 2).is_true()


func test_root_array_is_rejected() -> void:
	var dir: String = create_temp_dir("json_file_root_array")
	var path: String = dir + "/array.json"
	assert_int(JsonFile.write_text(path, "[1, 2]")).is_equal(OK)
	var report: DataLoadReport = DataLoadReport.new()
	var result: Dictionary = JsonFile.read_object(path, report, "test")
	assert_dict(result).is_empty()
	assert_int(report.errors.size()).is_equal(1)
	assert_str(report.errors[0]).contains("root must be a JSON object")


func test_list_json_files_is_sorted_and_filtered() -> void:
	var dir: String = create_temp_dir("json_file_list")
	assert_int(JsonFile.write_text(dir + "/b.json", "{}")).is_equal(OK)
	assert_int(JsonFile.write_text(dir + "/a.json", "{}")).is_equal(OK)
	assert_int(JsonFile.write_text(dir + "/notes.txt", "{}")).is_equal(OK)
	var files: PackedStringArray = JsonFile.list_json_files(dir)
	assert_int(files.size()).is_equal(2)
	assert_str(files[0]).is_equal("a.json")
	assert_str(files[1]).is_equal("b.json")


func test_list_json_files_on_missing_dir_is_empty_without_engine_error() -> void:
	# Lambdas capture locals by value, so the result travels inside an array.
	var captured: Array = []
	var probe: Callable = func() -> void:
		captured.append(JsonFile.list_json_files("user://tmp/no/such/dir"))
	await assert_error(probe).is_success()
	assert_int(captured.size()).is_equal(1)
	var files: PackedStringArray = captured[0]
	assert_int(files.size()).is_equal(0)
