class_name JsonFile

## JSON file IO for the data layers. Always JSON.new().parse(), never
## JSON.parse_string(): the instance API reports line/message without
## printing an engine ERROR (plan §3).

static func read_object(path: String, report: DataLoadReport, source: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		report.add_error(source, "file not found: %s" % path)
		return {}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		report.add_error(source, "cannot open %s (error %d)" % [path, FileAccess.get_open_error()])
		return {}
	var text: String = file.get_as_text()
	file.close()
	var json: JSON = JSON.new()
	var err: Error = json.parse(text)
	if err != OK:
		report.add_error(source, "%s:%d: %s" % [path, json.get_error_line(), json.get_error_message()])
		return {}
	var data: Variant = json.data
	if not (data is Dictionary):
		report.add_error(
			source, "%s: root must be a JSON object, got %s" % [path, type_string(typeof(data))]
		)
		return {}
	var object: Dictionary = data
	return object


## Names (not paths) of the *.json files in dir, sorted for a deterministic
## load order. A missing directory is an empty list, not an engine ERROR.
static func list_json_files(dir: String) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	if not DirAccess.dir_exists_absolute(dir):
		return result
	for file_name: String in DirAccess.get_files_at(dir):
		if file_name.to_lower().ends_with(".json"):
			result.append(file_name)
	result.sort()
	return result


static func write_text(path: String, text: String) -> Error:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(text)
	file.close()
	return OK
