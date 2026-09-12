class_name NetScenarioUtil
extends RefCounted

## Static helpers for the run_net_scenario tool (D54): JSON IO with silent
## parse errors (JSON.parse_string prints an ERROR on failure), Variant-safe
## narrowing for numbers coming out of parsed JSON, and the runtime factories
## for the spawner/synchronizer shared by the host and client roles.

const RESULTS_DIR: String = "user://netscenario"
const LOGS_DIR: String = "user://netlogs"
const NET_MARKER_SCRIPT: GDScript = preload("res://src/net/net_marker.gd")

const MAX_DEVIATION_M: float = 0.5
const MAX_DEVIATION_DEG: float = 5.0



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


## Seconds allowed to reach `waypoints` waypoints: ~15 s per waypoint with a
## 30 s floor (r1.2; the short route of 2 keeps the old 30 s behavior).
static func route_budget_s(waypoints: int) -> float:
	return maxf(30.0, waypoints * 15.0)


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


## The bus is found by group, never by node name (D59).
static func find_bus(scene: Node) -> Node:
	return scene.get_tree().get_first_node_in_group("bus")


static func make_sync(scene: Node) -> void:
	var bus: Node = find_bus(scene)
	var sync: MultiplayerSynchronizer = MultiplayerSynchronizer.new()
	sync.name = "NetSync"
	bus.add_child(sync)
	sync.root_path = NodePath("..")
	var config: SceneReplicationConfig = SceneReplicationConfig.new()
	config.add_property(".:global_transform")
	sync.replication_config = config
	sync.replication_interval = 1.0 / 30.0

static func aggregate(pids: Dictionary, clients: int, killed: Array[String]) -> Array[String]:
	var failures: Array[String] = []
	var host_data: Dictionary = read_json(
		NetScenarioUtil.RESULTS_DIR + "/host.json")
	if not killed.is_empty():
		failures.append("children_exited (killed: %s)" % ", ".join(killed))
	var host_ok: bool = not host_data.is_empty() \
		and dict_int(host_data, "exit", 1) == 0
	if not host_ok:
		failures.append("host_exit (host.json missing or exit != 0)")
	var peers_v: Variant = host_data.get("peers", [])
	var peers_count: int = 0
	if peers_v is Array:
		var peers_array: Array = peers_v
		peers_count = peers_array.size()
	if host_ok and peers_count != clients:
		failures.append("clients_connect (host saw %d of %d)" % [peers_count, clients])
	var max_pos_dev: float = 0.0
	var max_yaw_dev: float = 0.0
	var markers_each: Array[String] = []
	var clients_connected: int = 0
	var host_pos: Vector3 = array_to_vec3(host_data.get("bus_pos"))
	var host_yaw: float = dict_float(host_data, "bus_yaw_deg", 0.0)
	for index: int in range(clients):
		var client_data: Dictionary = read_json(
			NetScenarioUtil.RESULTS_DIR + "/client_%d.json" % index)
		if client_data.is_empty() or not dict_bool(client_data, "connected"):
			failures.append("clients_connect (client_%d not connected)" % index)
			continue
		clients_connected += 1
		var markers: int = dict_int(client_data, "markers_received", 0)
		markers_each.append("%d" % markers)
		if markers != clients + 1:
			failures.append("markers (client_%d got %d of %d)" % [index, markers, clients + 1])
		# Deviation is computed only against a REAL host snapshot (r1.3): with
		# the host down there is nothing meaningful to compare to (a zero
		# vector would print tens of meaningless meters).
		if host_ok:
			var client_pos: Vector3 = array_to_vec3(client_data.get("bus_pos"))
			var pos_dev: float = client_pos.distance_to(host_pos)
			var yaw_dev: float = angle_diff_deg(
				dict_float(client_data, "bus_yaw_deg", 0.0), host_yaw)
			max_pos_dev = maxf(max_pos_dev, pos_dev)
			max_yaw_dev = maxf(max_yaw_dev, yaw_dev)
			if pos_dev > MAX_DEVIATION_M or yaw_dev > MAX_DEVIATION_DEG:
				failures.append(
					"convergence (client_%d: %.3f m, %.2f deg)" % [index, pos_dev, yaw_dev])
	var port_used: int = dict_int(host_data, "port", -1)
	print("NET summary port=%d pids=%s" % [port_used, str(pids.values())])
	print("NET summary clients_connected=%d/%d markers_per_client=[%s]" % [
		clients_connected, clients, ", ".join(markers_each)])
	if host_ok:
		print("NET summary max_pos_dev=%.3f m max_yaw_dev=%.2f deg" % [max_pos_dev, max_yaw_dev])
	else:
		print("NET summary deviation omitted: no valid host snapshot (r1.3)")
	return failures
