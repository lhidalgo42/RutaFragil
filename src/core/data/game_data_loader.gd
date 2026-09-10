class_name GameDataLoader
extends RefCounted

## Loads the game data documents in layers (D45):
##   <doc>.tres -> <base_dir>/<doc>.json -> <mods_dir>/*.json (alphabetical).
## Each layer is validated on its own, then deep-merged (nested dictionaries
## key by key, arrays replaced) and applied once per document at the end.
## Directories are injected so tests can point at create_temp_dir() instead of
## the real res://data and user://mods.

const DOC_IDS: Dictionary[String, String] = {"game_config": "game_config", "tuning": "tuning"}

var game_config: GameConfigData = null
var tuning: TuningTable = null

var _base_dir: String = ""
var _mods_dir: String = ""


func _init(base_dir: String, mods_dir: String) -> void:
	_base_dir = base_dir
	_mods_dir = mods_dir


func load_all() -> DataLoadReport:
	var report: DataLoadReport = DataLoadReport.new()
	# Fresh resources on every call: a reload must not accumulate old values.
	game_config = GameConfigData.new()
	tuning = TuningTable.new()
	# doc_id -> accumulated, already-validated layer values.
	var merged: Dictionary = {}
	for doc_id: String in DOC_IDS:
		merged[doc_id] = {}
	for doc_id: String in DOC_IDS:
		var applied_before: int = report.applied_files.size()
		_load_tres_layer(doc_id, report, merged)
		_load_base_json_layer(doc_id, report, merged)
		if report.applied_files.size() == applied_before:
			# Not fatal, but loud: with no data the game runs on zeroes (D44).
			report.add_warning("doc:" + doc_id, "no .tres or base .json found; neutral defaults in use")
	_load_mod_layers(report, merged)
	for doc_id: String in DOC_IDS:
		var values: Dictionary = merged[doc_id]
		ResourceJsonCodec.apply(_resource_for(doc_id), values)
	return report


func _resource_for(doc_id: String) -> Resource:
	if doc_id == "game_config":
		return game_config
	return tuning


func _load_tres_layer(doc_id: String, report: DataLoadReport, merged: Dictionary) -> void:
	var path: String = "%s/%s.tres" % [_base_dir, DOC_IDS[doc_id]]
	if not ResourceLoader.exists(path):
		return
	# CACHE_MODE_IGNORE: the loader must re-read the file on every reload.
	var loaded: Resource = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	if loaded == null:
		report.add_error("tres:" + path, "resource failed to load")
		return
	var accumulated: Dictionary = merged[doc_id]
	merged[doc_id] = JsonMerge.deep_merge(accumulated, ResourceJsonCodec.to_dictionary(loaded))
	report.applied_files.append(path)


func _load_base_json_layer(doc_id: String, report: DataLoadReport, merged: Dictionary) -> void:
	var path: String = "%s/%s.json" % [_base_dir, DOC_IDS[doc_id]]
	if not FileAccess.file_exists(path):
		return
	var source: String = "base:" + path
	var res: Resource = _resource_for(doc_id)
	var errors_before: int = report.errors.size()
	var raw: Dictionary = JsonFile.read_object(path, report, source)
	if raw.is_empty():
		return  # read_object already recorded why
	var section_v: Variant = raw.get(doc_id, null)
	if not (section_v is Dictionary):
		report.add_error(source, "missing object section '%s'" % doc_id)
		return
	var section: Dictionary = section_v
	var valid: Dictionary = ResourceJsonCodec.validate(res, section, report, source, true)
	if report.errors.size() != errors_before:
		# Invalid base JSON: the layer is omitted and the game keeps the .tres
		# values; is_ok() is false so tools exit non-zero (D45).
		return
	var accumulated: Dictionary = merged[doc_id]
	merged[doc_id] = JsonMerge.deep_merge(accumulated, valid)
	report.applied_files.append(path)


func _load_mod_layers(report: DataLoadReport, merged: Dictionary) -> void:
	for file_name: String in JsonFile.list_json_files(_mods_dir):
		_load_mod_file("%s/%s" % [_mods_dir, file_name], file_name, report, merged)


func _load_mod_file(
	path: String, file_name: String, report: DataLoadReport, merged: Dictionary
) -> void:
	var source: String = "mod:" + file_name
	# The scratch report isolates the file: a mod applies whole or not at all
	# (D45), and a rejected mod only ever becomes warnings in the main report,
	# so invalid mods never break the run.
	var scratch: DataLoadReport = DataLoadReport.new()
	var raw: Dictionary = JsonFile.read_object(path, scratch, source)
	if raw.is_empty():
		_forward_rejected_mod(scratch, report)
		return
	var staged: Dictionary = {}
	var rejected: bool = false
	for key_v: Variant in raw:
		if not (key_v is String):
			scratch.add_error(source, "non-string section key")
			rejected = true
			continue
		var doc_id: String = key_v
		if not DOC_IDS.has(doc_id):
			scratch.add_warning(source, "unknown section '%s' ignored" % doc_id)
			continue
		var section_v: Variant = raw[key_v]
		if not (section_v is Dictionary):
			scratch.add_error(source, "section '%s' must be an object" % doc_id)
			rejected = true
			continue
		var section: Dictionary = section_v
		var errors_before: int = scratch.errors.size()
		var valid: Dictionary = ResourceJsonCodec.validate(_resource_for(doc_id), section, scratch, source, false)
		if scratch.errors.size() != errors_before:
			rejected = true
			continue
		staged[doc_id] = valid
	if rejected:
		_forward_rejected_mod(scratch, report)
		return
	for doc_id: String in staged:
		var accumulated: Dictionary = merged[doc_id]
		var valid_data: Dictionary = staged[doc_id]
		merged[doc_id] = JsonMerge.deep_merge(accumulated, valid_data)
	report.warnings.append_array(scratch.warnings)
	report.applied_files.append(path)


func _forward_rejected_mod(scratch: DataLoadReport, report: DataLoadReport) -> void:
	for error: String in scratch.errors:
		report.warnings.append("REJECTED " + error)
	for warning: String in scratch.warnings:
		report.warnings.append("REJECTED " + warning)
