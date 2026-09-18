extends SceneTree

## Cronómetro y contador por constructor: cuánto tarda cada pieza de un bioma en armarse
## y qué quedó dentro — instancias por lote, triángulos por cinta, matas de pasto. Es la
## forma de verificar un cambio de ASPECTO sin abrir una ventana: el renderizador headless
## no dibuja, pero las mallas y los MultiMesh sí se pueden contar.
##
## timeout 600 "$GODOT_BIN" --headless --path . -s res://src/tooling/build_timing.gd ++ data=res://data/b0_requinoa.json

var _data_path: String = "res://data/b0_requinoa.json"
var _done: bool = false


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		var parts: PackedStringArray = arg.split("=", true, 1)
		if parts.size() == 2 and parts[0] == "data":
			_data_path = parts[1]


func _process(_delta: float) -> bool:
	if _done:
		return false
	_done = true
	var t0: int = Time.get_ticks_msec()
	var data: OsmMapData = OsmMapData.load_from(_data_path)
	print("TIME load=%d ms" % (Time.get_ticks_msec() - t0))
	if data == null:
		quit(1)
		return true
	t0 = Time.get_ticks_msec()
	var mask: RoadMask = RoadMask.new()
	mask.build(data)
	print("TIME mask=%d ms celdas=%d" % [Time.get_ticks_msec() - t0, mask.paved_cells()])
	for entry: Array in [["OsmRoad", OsmRoad], ["OsmGravel", OsmGravel], ["OsmBuildings", OsmBuildings], ["OsmFurniture", OsmFurniture], ["OsmTown", OsmTown], ["OsmForest", OsmForest]]:
		var script_class: Variant = entry[1]
		var node: Node3D = script_class.new()
		node.set("data_path", _data_path)
		node.set("progressive", false)   # el bosque: todo de una vez, para medirlo entero
		t0 = Time.get_ticks_msec()
		root.add_child(node)
		var ms: int = Time.get_ticks_msec() - t0
		print("TIME %s=%d ms" % [entry[0], ms])
		_report(node)
		node.queue_free()
	quit(0)
	return true


## Lo que dejó un constructor, por hijo directo: ahí viven los lotes y las cintas.
func _report(node: Node) -> void:
	for child: Node in node.get_children():
		if child is GrassStrip:
			var grass: GrassStrip = child
			print("    %-24s matas=%d" % [child.name, grass.multimesh.instance_count if grass.multimesh != null else 0])
		elif child is MultiMeshInstance3D:
			var mm: MultiMeshInstance3D = child
			print("    %-24s instancias=%d" % [child.name, mm.multimesh.instance_count if mm.multimesh != null else 0])
		elif child is MeshInstance3D:
			var mi: MeshInstance3D = child
			var mesh: ArrayMesh = mi.mesh as ArrayMesh
			var verts: int = mesh.surface_get_array_len(0) if mesh != null and mesh.get_surface_count() > 0 else 0
			print("    %-24s triángulos=%d" % [child.name, verts / 3])
		elif child is StaticBody3D:
			print("    %-24s colisiones=%d" % [child.name, child.get_child_count()])
