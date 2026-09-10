extends SceneTree

## CLI tool (plan M0-T0.2, paso 4): res://data/<doc>.json -> <doc>.tres.
## A hand-edited JSON becomes the engine artifact without opening the editor.
## Run: godot --headless --path . -s res://src/tooling/import_data_mirror.gd
## quit() is guaranteed on every path; an error before it would hang headless.

const DATA_DIR: String = "res://data"


func _init() -> void:
	var exit_code: int = 0
	for doc_id: String in GameDataLoader.DOC_IDS:
		if not _import_document(doc_id):
			exit_code = 1
	if exit_code == 0:
		print("import_data_mirror: OK")
	quit(exit_code)


func _import_document(doc_id: String) -> bool:
	var json_path: String = "%s/%s.json" % [DATA_DIR, doc_id]
	var tres_path: String = "%s/%s.tres" % [DATA_DIR, doc_id]
	var source: String = "base:" + json_path
	var report: DataLoadReport = DataLoadReport.new()
	var res: Resource = _new_document(doc_id)
	var raw: Dictionary = JsonFile.read_object(json_path, report, source)
	if raw.is_empty():
		printerr("import_data_mirror: invalid base JSON for '%s'" % doc_id)
		printerr(report.summary())
		return false
	var section_v: Variant = raw.get(doc_id, null)
	if not (section_v is Dictionary):
		printerr("import_data_mirror: %s has no object section '%s'" % [json_path, doc_id])
		return false
	var section: Dictionary = section_v
	var valid: Dictionary = ResourceJsonCodec.validate(res, section, report, source, true)
	if not report.is_ok():
		printerr(report.summary())
		return false
	ResourceJsonCodec.apply(res, valid)
	var err: Error = ResourceSaver.save(res, tres_path)
	if err != OK:
		printerr("import_data_mirror: ResourceSaver.save failed for %s (error %d)" % [tres_path, err])
		return false
	print("import_data_mirror: saved %s" % tres_path)
	print(JSON.stringify({doc_id: ResourceJsonCodec.to_dictionary(res)}, "\t"))
	return true


func _new_document(doc_id: String) -> Resource:
	if doc_id == "game_config":
		return GameConfigData.new()
	return TuningTable.new()
