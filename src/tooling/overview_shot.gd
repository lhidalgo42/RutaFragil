extends SceneTree

## Windowed tool: loads a route scene, switches to its OverviewCamera and
## saves a top-down PNG after `seconds` of game time (the demo keeps driving
## meanwhile, so the bus shows where it is). Args after ++:
## scene=<res path>, seconds=<game seconds, default 12>, out=<png path>.
## Same constraints as run_demo: load on the first process_frame, inspect by
## node name, quit() on every path; run under an outer `timeout`.

const DEFAULT_SCENE: String = "res://scenes/route_mvp.tscn"

var _scene_path: String = DEFAULT_SCENE
var _seconds: float = 12.0
var _out: String = "user://overview.png"
var _ticks: int = 0
var _done: bool = false


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		var parts: PackedStringArray = arg.split("=", true, 1)
		if parts.size() != 2:
			continue
		match parts[0]:
			"scene":
				_scene_path = parts[1]
			"seconds":
				_seconds = maxf(0.0, parts[1].to_float())
			"out":
				_out = parts[1]
	process_frame.connect(_load_scene, CONNECT_ONE_SHOT)


func _load_scene() -> void:
	var packed: Resource = load(_scene_path)
	if not (packed is PackedScene):
		print("OVERVIEW load_failed")
		quit(1)
		return
	var packed_scene: PackedScene = packed
	var scene: Node = packed_scene.instantiate()
	root.add_child(scene)
	var cam: Node = scene.get_node_or_null("OverviewCamera")
	if cam == null or not cam.has_method("show_overview"):
		print("OVERVIEW no_overview_camera")
		quit(1)
		return
	cam.call("show_overview", true)
	physics_frame.connect(_on_physics_frame)


func _on_physics_frame() -> void:
	if _done:
		return
	_ticks += 1
	if _ticks / float(Engine.physics_ticks_per_second) < _seconds:
		return
	_done = true
	var image: Image = root.get_texture().get_image()
	if image == null:
		print("OVERVIEW screenshot_failed")
		quit(1)
		return
	var err: Error = image.save_png(_out)
	print("OVERVIEW saved=%s error=%d" % [_out, err])
	quit(0 if err == OK else 1)
