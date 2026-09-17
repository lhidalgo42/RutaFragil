class_name GateConfig
extends RefCounted

## Gate deadlines follow the requested duration, independently of the legacy route.
var role: String = "launcher"
var seconds: float = 300.0
var port: int = 47810
var human: String = "none"
var windowed: String = "both"
var output: String = ""
var iteration: int = 1
var vsync: bool = false
var experiment: bool = false
var cargo_spawn: bool = true
var walk_only: bool = false
var precondition: String = ""


func parse(args: PackedStringArray) -> void:
	for arg: String in args:
		var parts: PackedStringArray = arg.split("=", true, 1)
		if parts.size() != 2:
			continue
		match parts[0]:
			"role": role = parts[1]
			"seconds": seconds = maxf(1.0, parts[1].to_float())
			"port": port = parts[1].to_int()
			"human": human = parts[1]
			"windowed": windowed = parts[1]
			"vsync": vsync = parts[1] != "off"
			"experiment": experiment = parts[1] == "1"
			"cargo": cargo_spawn = parts[1] != "off"
			"walk_only": walk_only = parts[1] == "1"
			"output": output = parts[1]
			"precondition": precondition = parts[1]
			"iteration": iteration = maxi(1, parts[1].to_int())
	if output.is_empty():
		output = "user://gate/run_%d" % Time.get_unix_time_from_system()
	output = ProjectSettings.globalize_path(output)
	if human != "none":
		windowed = human


## D97's human gate is a play session, not a D96 attempt: it must not demand a
## precondition, must not be numbered as an iteration and must not be judged
## automatically. Only a scripted 300 s run counts against the three.
func counts_for_d96() -> bool:
	return seconds >= 300.0 and not experiment and human == "none"


## What this run is for, in the evidence: a D96 iteration, the owner's human
## gate, a reduction experiment, or a short preflight.
func kind() -> String:
	if experiment:
		return "experiment"
	if human != "none":
		return "human"
	return "gate" if seconds >= 300.0 else "preflight"


func budget_s() -> float:
	return seconds + 90.0


func signature() -> Dictionary:
	return {"seconds": seconds, "human": human, "windowed": windowed, "vsync": vsync,
		"cargo": cargo_spawn, "walk_only": walk_only, "physics_hz": Engine.physics_ticks_per_second,
		"engine": Engine.get_version_info()["string"],
		"effective_game_config": ResourceJsonCodec.to_dictionary(GameConfig.data),
		"effective_tuning": ResourceJsonCodec.to_dictionary(GameConfig.tuning)}


func visible(child_role: String) -> bool:
	return windowed == "both" or windowed == child_role


func child_args(child_role: String) -> PackedStringArray:
	var args: PackedStringArray = ["--path", ProjectSettings.globalize_path("res://"),
		"--log-file", output.path_join(child_role + ".log"),
		"-s", "res://src/tooling/run_net_scenario.gd", "++", "mode=gate",
		"role=" + child_role, "seconds=%s" % seconds, "port=%d" % port,
		"human=" + human, "windowed=" + windowed, "output=" + output,
		"iteration=%d" % iteration, "vsync=" + ("on" if vsync else "off"),
		"experiment=" + ("1" if experiment else "0"), "cargo=" + ("on" if cargo_spawn else "off"),
		"walk_only=" + ("1" if walk_only else "0")]
	if not visible(child_role):
		args.insert(0, "--headless")
	return args


func write_json(file_name: String, value: Variant) -> bool:
	var file: FileAccess = FileAccess.open(output.path_join(file_name), FileAccess.WRITE)
	if file == null:
		printerr("GATE cannot write ", file_name, ": ", FileAccess.get_open_error())
		return false
	file.store_string(JSON.stringify(value, "\t"))
	file.close()
	return true


func read_json(file_name: String) -> Variant:
	var path: String = output.path_join(file_name)
	if not FileAccess.file_exists(path):
		return null
	var parser: JSON = JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path)) != OK:
		return null
	return parser.data
