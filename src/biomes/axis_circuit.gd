class_name AxisCircuit
extends Circuit

## Circuit whose Marker3D waypoints come from OsmMapData.waypoints (D65),
## created at runtime so the scene file stays under 60 nodes (R8). The lap
## order, loops and detours were computed and angle-checked by
## tools/osm_to_b0.py.

@export var data_path: String = "res://data/b0_departamental.json"


func _ready() -> void:
	var data: OsmMapData = OsmMapData.load_from(data_path)
	if data != null:
		build(data)


func build(data: OsmMapData) -> void:
	for child: Node in get_children():
		remove_child(child)
		child.free()
	for i: int in data.waypoints.size():
		var marker: Marker3D = Marker3D.new()
		marker.name = "WP%d" % i
		add_child(marker)
		marker.global_position = data.waypoints[i]
