extends SceneTree

## Inventory tool for the owner: loads a scene and prints every piece it is made of,
## module by module — each builder node, each MultiMesh batch with its instance count
## and mesh kind, and each collision body with its shape count. Args after ++:
## scene=<res path>.

var _scene_path: String = "res://scenes/b0_requinoa.tscn"
var _frames: int = 0


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		var parts: PackedStringArray = arg.split("=", true, 1)
		if parts.size() == 2 and parts[0] == "scene":
			_scene_path = parts[1]
	process_frame.connect(_load, CONNECT_ONE_SHOT)


func _load() -> void:
	var packed: Resource = load(_scene_path)
	if not (packed is PackedScene):
		print("INV load_failed")
		quit(1)
		return
	var ps: PackedScene = packed
	root.add_child(ps.instantiate())
	process_frame.connect(_tick)


func _tick() -> void:
	_frames += 1
	if _frames < 4:
		return
	process_frame.disconnect(_tick)
	_walk(root.get_child(root.get_child_count() - 1), "")
	quit(0)


func _walk(node: Node, path: String) -> void:
	var here: String = path + "/" + node.name
	if node is MultiMeshInstance3D:
		var mmi: MultiMeshInstance3D = node
		var mesh_kind: String = "?"
		var colour: String = ""
		if mmi.multimesh != null and mmi.multimesh.mesh != null:
			mesh_kind = mmi.multimesh.mesh.get_class()
			var mat: Material = mmi.multimesh.mesh.surface_get_material(0)
			if mat is StandardMaterial3D:
				var std: StandardMaterial3D = mat
				colour = "#%02x%02x%02x" % [int(std.albedo_color.r * 255), int(std.albedo_color.g * 255), int(std.albedo_color.b * 255)]
		print("INV MALLA|%s|%d|%s|%s" % [here, mmi.multimesh.instance_count if mmi.multimesh != null else 0, mesh_kind, colour])
	elif node is StaticBody3D or node is Area3D:
		var shapes: int = 0
		for child: Node in node.get_children():
			if child is CollisionShape3D:
				shapes += 1
		print("INV COLISION|%s|%d|%s" % [here, shapes, node.get_class()])
	elif node is MeshInstance3D:
		var mi: MeshInstance3D = node
		print("INV PIEZA|%s|1|%s" % [here, mi.mesh.get_class() if mi.mesh != null else "?"])
	elif node.get_child_count() == 0 and not (node is CollisionShape3D):
		print("INV NODO|%s|0|%s" % [here, node.get_class()])
	for child: Node in node.get_children():
		_walk(child, here)
