extends SceneTree

## CLI tool (plan M0-T0.2, paso 4): res://data/<doc>.tres -> <doc>.json mirror.
## Regeneration is byte-stable (sorted keys, tab indent), so idempotency is
## verified with git status, not here.
## Run: godot --headless --path . -s res://src/tooling/write_data_mirror.gd
## quit() is guaranteed on every path; an error before it would hang headless.

const DATA_DIR: String = "res://data"


func _init() -> void:
	var exit_code: int = 0
	for doc_id: String in GameDataLoader.DOC_IDS:
		if not _write_document(doc_id):
			exit_code = 1
	if exit_code == 0:
		print("write_data_mirror: OK")
	quit(exit_code)


func _write_document(doc_id: String) -> bool:
	var tres_path: String = "%s/%s.tres" % [DATA_DIR, doc_id]
	var json_path: String = "%s/%s.json" % [DATA_DIR, doc_id]
	if not ResourceLoader.exists(tres_path):
		printerr("write_data_mirror: missing %s" % tres_path)
		return false
	# CACHE_MODE_IGNORE: a rerun in the same session must not serve stale data.
	var res: Resource = ResourceLoader.load(tres_path, "", ResourceLoader.CACHE_MODE_IGNORE)
	if res == null:
		printerr("write_data_mirror: failed to load %s" % tres_path)
		return false
	var err: Error = DataMirror.write_mirror(res, doc_id, json_path)
	if err != OK:
		printerr("write_data_mirror: failed to write %s (error %d)" % [json_path, err])
		return false
	print("write_data_mirror: wrote %s" % json_path)
	return true
