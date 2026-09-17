extends SceneTree


func _initialize() -> void:
	process_frame.connect(_boot, CONNECT_ONE_SHOT)


func _boot() -> void:
	var script: GDScript = load("res://src/tooling/air_carry_probe.gd")
	var probe: Node = script.new()
	root.add_child(probe)
