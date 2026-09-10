extends Node

## Autoload (D43): single access point for the validated game data.
## reload() re-reads the layer stack (res://data -> user://mods) through
## GameDataLoader, so a data edit never requires reopening the project.

var data: GameConfigData
var tuning: TuningTable
var last_report: DataLoadReport

var max_players: int:
	get = _get_max_players

signal reloaded(report: DataLoadReport)


func _ready() -> void:
	if not DirAccess.dir_exists_absolute("user://mods"):
		var mkdir_err: Error = DirAccess.make_dir_recursive_absolute("user://mods")
		if mkdir_err != OK:
			push_error("GameConfig: cannot create user://mods (error %d)" % mkdir_err)
	reload()
	if not last_report.is_ok():
		push_error(last_report.summary())


func reload() -> DataLoadReport:
	var loader: GameDataLoader = GameDataLoader.new("res://data", "user://mods")
	last_report = loader.load_all()
	data = loader.game_config
	tuning = loader.tuning
	reloaded.emit(last_report)
	return last_report


func _get_max_players() -> int:
	return data.max_players if data != null else 0
