extends SceneTree

## CLI tool (plan M0-T0.2, paso 4): prints the effective game data after the
## full layer stack (res://data/*.tres -> *.json -> user://mods/*.json).
## Process-level proof of acceptance criteria 1-2: rerunning it picks up JSON
## edits without reopening the editor. Exit code: 0 if the report is OK, 1 if
## the base data is invalid (invalid mods are warnings only, exit stays 0).
## Run: godot --headless --path . -s res://src/tooling/print_game_data.gd
## quit() is guaranteed on every path; an error before it would hang headless.

const DATA_DIR: String = "res://data"
const MODS_DIR: String = "user://mods"


func _init() -> void:
	if not DirAccess.dir_exists_absolute(MODS_DIR):
		var mkdir_err: Error = DirAccess.make_dir_recursive_absolute(MODS_DIR)
		if mkdir_err != OK:
			printerr("print_game_data: cannot create %s (error %d)" % [MODS_DIR, mkdir_err])
			quit(1)
			return
	var loader: GameDataLoader = GameDataLoader.new(DATA_DIR, MODS_DIR)
	var report: DataLoadReport = loader.load_all()
	print(JSON.stringify({"game_config": ResourceJsonCodec.to_dictionary(loader.game_config)}, "\t"))
	print(JSON.stringify({"tuning": ResourceJsonCodec.to_dictionary(loader.tuning)}, "\t"))
	print(report.summary())
	if report.is_ok():
		quit(0)
	else:
		quit(1)
