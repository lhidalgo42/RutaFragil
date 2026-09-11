class_name NetScenarioUtil
extends RefCounted

## Static helpers for the run_net_scenario tool (D54): JSON IO with silent
## parse errors (JSON.parse_string prints an ERROR on failure), Variant-safe
## narrowing for numbers coming out of parsed JSON, and the runtime factories
## for the spawner/synchronizer shared by the host and client roles.

const RESULTS_DIR: String = "user://netscenario"
const LOGS_DIR: String = "user://netlogs"
const NET_MARKER_SCRIPT: GDScript = preload("res://src/net/net_marker.gd")


static func vec3_to_array(value: Variant) -> Array:
	if value is Vector3:
		var vector: Vector3 = value
		return [vector.x, vector.y, vector.z]
	return [0.0, 0.0, 0.0]


static func array_to_vec3(value: Variant) -> Vector3:
	if value is Array:
		var items: Array = value
		if items.size() == 3:
			var coords: Array[float] = []
			for item_v: Variant in items:
				var number: float = 0.0
				if item_v is float:
					number = item_v
				elif item_v is int:
					var item_int: int = item_v
					number = float(item_int)
				coords.append(number)
			return Vector3(coords[0], coords[1], coords[2])
	return Vector3.ZERO


static func yaw_deg(node: Node) -> float:
	var basis_v: Variant = node.get("global_basis")
	if basis_v is Basis:
		var basis: Basis = basis_v
		return rad_to_deg(basis.get_euler().y)
	return 0.0


static func angle_diff_deg(a: float, b: float) -> float:
	return absf(fmod(a - b + 540.0, 360.0) - 180.0)


static func dict_int(data: Dictionary, key: String, fallback: int) -> int:
	var value_v: Variant = data.get(key)
	if value_v is float:
		var as_float: float = value_v
		return roundi(as_float)
	if value_v is int:
		var as_int: int = value_v
		return as_int
	return fallback


static func dict_float(data: Dictionary, key: String, fallback: float) -> float:
	var value_v: Variant = data.get(key)
	if value_v is float:
		var as_float: float = value_v
		return as_float
	if value_v is int:
		var as_int: int = value_v
		return float(as_int)
	return fallback


static func dict_bool(data: Dictionary, key: String) -> bool:
	var value_v: Variant = data.get(key)
	if value_v is bool:
		var as_bool: bool = value_v
		return as_bool
	return false


static func write_text(file_name: String, text: String) -> void:
	DirAccess.make_dir_recursive_absolute(RESULTS_DIR)
	var file: FileAccess = FileAccess.open(RESULTS_DIR + "/" + file_name, FileAccess.WRITE)
	if file == null:
		printerr("NET cannot write ", file_name)
		return
	file.store_string(text)
	file.close()


static func write_json(name: String, data: Dictionary) -> void:
	write_text(name + ".json", JSON.stringify(data, "\t"))


static func read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parser: JSON = JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path)) != OK:
		return {}
	var data_v: Variant = parser.data
	if data_v is Dictionary:
		var data: Dictionary = data_v
		return data
	return {}


static func clean_dir(path: String) -> void:
	var dir: DirAccess = DirAccess.open(path)
	if dir == null:
		return
	for file_name: String in dir.get_files():
		dir.remove(file_name)


static func make_spawner(scene: Node) -> MultiplayerSpawner:
	var container: Node3D = Node3D.new()
	container.name = "NetMarkers"
	scene.add_child(container)
	var spawner: MultiplayerSpawner = MultiplayerSpawner.new()
	spawner.name = "NetSpawner"
	scene.add_child(spawner)
	spawner.spawn_path = spawner.get_path_to(container)
	# The documented auto-replication path (class reference 4.7): scenes added
	# via add_spawnable_scene are replicated when the AUTHORITY adds them as
	# children of spawn_path with a readable name. A custom spawn_function was
	# tried first and dropped silently by the engine on every probe.
	spawner.add_spawnable_scene("res://src/net/net_marker.tscn")
	return spawner


## Authority-side spawn of one marker per peer. The readable name is REQUIRED:
## the spawner refuses to auto-spawn children whose instantiate() default name
## is a reserved "@Node3D@N" ("Unable to auto-spawn node with reserved name").
static func spawn_marker(container: Node, marker_scene: PackedScene, owner_peer_id: int) -> void:
	var marker: Node = marker_scene.instantiate()
	marker.set("owner_peer_id", owner_peer_id)
	marker.name = "NetMarker_%d" % owner_peer_id
	container.add_child(marker, true)


static func make_sync(scene: Node) -> void:
	var bus: Node = scene.get_node("PlaceholderBus")
	var sync: MultiplayerSynchronizer = MultiplayerSynchronizer.new()
	sync.name = "NetSync"
	bus.add_child(sync)
	sync.root_path = NodePath("..")
	var config: SceneReplicationConfig = SceneReplicationConfig.new()
	config.add_property(".:global_transform")
	sync.replication_config = config
	sync.replication_interval = 1.0 / 30.0
