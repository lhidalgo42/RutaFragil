extends SceneTree

## Load gameplay types only after autoloads exist.
func _initialize() -> void:
	process_frame.connect(_boot, CONNECT_ONE_SHOT)


func _boot() -> void:
	var path: String = "res://src/tooling/platform_adoption_probe.gd"
	if "study=release" in OS.get_cmdline_user_args():
		path = "res://src/tooling/cargo_release_phase_probe.gd"
	var script: GDScript = load(path)
	var probe: Node = script.new()
	root.add_child(probe)
