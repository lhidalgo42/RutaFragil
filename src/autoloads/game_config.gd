extends Node

## Autoload (D43): single access point for the validated game data.
## reload() re-reads the layer stack (res://data -> user://mods) through
## GameDataLoader, so a data edit never requires reopening the project.
## The directories are defaulted arguments so tests can inject temp dirs;
## the game always runs on the defaults.
## Every load surfaces each report warning with push_warning (modders must see
## their rejections, M4) and a failing report with push_error.

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


func reload(base_dir: String = "res://data", mods_dir: String = "user://mods") -> DataLoadReport:
	var loader: GameDataLoader = GameDataLoader.new(base_dir, mods_dir)
	last_report = loader.load_all()
	data = loader.game_config
	tuning = loader.tuning
	for warning: String in last_report.warnings:
		push_warning(warning)
	if not last_report.is_ok():
		push_error(last_report.summary())
	reloaded.emit(last_report)
	return last_report


func _get_max_players() -> int:
	if data == null:
		push_error("GameConfig.max_players read before data loaded")
		return 0
	return data.max_players
