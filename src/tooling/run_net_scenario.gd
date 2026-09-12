extends SceneTree

## Multi-instance network scenario harness (D54, D55, D56, D58, plan M0-T0.4).
## Three roles chosen with ++ role=launcher|host|client:
##   launcher: spawns 1 host + N clients over ENet on 127.0.0.1, waits, kills
##     survivors, and aggregates the per-process result JSONs into the D55
##     asserts. Exit 0 only if every child self-exited 0 and every assert passed.
##   host: hosts on port (+4 fallbacks), waits for N peers (mark_ready),
##     spawns one NetMarker per peer, drives the circuit to the `waypoints`
##     INDEX (0-based), brakes, settles 1.5 s, fires snapshot_now, writes
##     host.json, and stays connected until every client is done (mark_done).
##   client: joins, loads the scene with network_role="client" (frozen bus),
##     and snapshots markers + bus transform into client_N.json when the
##     host's snapshot_now RPC arrives (r1.2: no fixed clock wait).
## Runtime-created MultiplayerSpawner/MultiplayerSynchronizer on BOTH ends with
## identical node paths (accepted deviation: nothing network-specific is
## written into playground.tscn). quit() on every path; run under `timeout`.
## Helpers live in NetScenarioUtil (R8: this file stays under 400 lines).

const SCENE_PATH: String = "res://scenes/playground.tscn"
const BASE_PORT: int = 47810
const PORT_TRIES: int = 5

var _role: String = "launcher"
var _port: int = BASE_PORT
var _clients: int = 3
var _seconds: float = 30.0
var _waypoints: int = 2
var _index: int = 0
var _break: String = ""
var _ticks: int = 0


func _initialize() -> void:
	_parse_args()
	physics_frame.connect(_on_tick)
	process_frame.connect(_start, CONNECT_ONE_SHOT)


func _parse_args() -> void:
	for arg: String in OS.get_cmdline_user_args():
		var parts: PackedStringArray = arg.split("=", true, 1)
		if parts.size() != 2:
			continue
		match parts[0]:
			"role":
				_role = parts[1]
			"port":
				_port = int(parts[1])
			"clients":
				_clients = int(parts[1])
			"seconds":
				_seconds = maxf(1.0, parts[1].to_float())
			"waypoints":
				_waypoints = int(parts[1])
			"index":
				_index = int(parts[1])
			"break":
				_break = parts[1]


func _on_tick() -> void:
	_ticks += 1


func _start() -> void:
	match _role:
		"launcher":
			_run_launcher()
		"host":
			_run_host()
		"client":
			_run_client()
		_:
			_die("unknown role '%s'" % _role)


func _die(msg: String) -> void:
	printerr("NET fatal: ", msg)
	quit(1)


func _backend() -> Node:
	var node: Node = root.get_node_or_null("NetworkBackend")
	if node == null:
		_die("NetworkBackend autoload is missing")
	return node


func _wait_seconds(seconds: float) -> void:
	var ticks_needed: int = int(seconds * Engine.physics_ticks_per_second)
	var start: int = _ticks
	while _ticks - start < ticks_needed:
		await physics_frame


func _wait_until(condition: Callable, timeout_s: float) -> bool:
	var ticks_needed: int = int(timeout_s * Engine.physics_ticks_per_second)
	var start: int = _ticks
	while _ticks - start < ticks_needed:
		if condition.call():
			return true
		await physics_frame
	return condition.call()


func _instantiate_scene(role: String) -> Node:
	var packed: Resource = load(SCENE_PATH)
	if not (packed is PackedScene):
		_die("could not load " + SCENE_PATH)
		return null
	var packed_scene: PackedScene = packed
	var scene: Node = packed_scene.instantiate()
	scene.set("network_role", role)
	root.add_child(scene)
	return scene


# ------------------------------------------------------------------- host ----

func _run_host() -> void:
	var backend: Node = _backend()
	var port: int = -1
	for offset: int in range(PORT_TRIES):
		var err_v: Variant = backend.call("host_game", _port + offset)
		if err_v is int:
			var err: int = err_v
			if err == OK:
				port = _port + offset
				break
	if port < 0:
		NetScenarioUtil.write_json("host", {"role": "host", "error": "no free port", "exit": 1})
		quit(1)
		return
	NetScenarioUtil.write_text("port.txt", str(port))
	print("NET host port=%d" % port)
	var joined_ids: Array[int] = []
	backend.connect("peer_joined", func(id: int) -> void: joined_ids.append(id))
	var all_joined: bool = await _wait_until(
		func() -> bool: return joined_ids.size() >= _clients, 30.0)
	if not all_joined:
		NetScenarioUtil.write_json("host", {"role": "host", "error": "peers did not join", "exit": 1})
		quit(1)
		return
	print("NET host peers=%d" % joined_ids.size())
	# Poll the backend's ready_peers array, not the signal: a fast client can
	# fire mark_ready before this listener connects, and a signal-based
	# counter would miss it (observed with break=sync, 2026-09-11).
	var all_ready: bool = await _wait_until(
		func() -> bool:
			var ready_v: Variant = backend.get("ready_peers")
			if ready_v is Array:
				var ready: Array = ready_v
				return ready.size() >= _clients
			return false, 30.0)
	if not all_ready:
		NetScenarioUtil.write_json("host", {"role": "host", "error": "peers not ready", "exit": 1})
		quit(1)
		return
	print("NET host all clients ready")
	var scene: Node = _instantiate_scene("host")
	NetScenarioUtil.make_spawner(scene)
	var marker_ids: Array[int] = [1]
	for peer_id: int in joined_ids:
		marker_ids.append(peer_id)
	var marker_scene_v: Resource = load("res://src/net/net_marker.tscn")
	if not (marker_scene_v is PackedScene):
		NetScenarioUtil.write_json("host", {"role": "host", "error": "marker scene", "exit": 1})
		quit(1)
		return
	var marker_scene: PackedScene = marker_scene_v
	var container: Node = scene.get_node("NetMarkers")
	for owner_id: int in marker_ids:
		NetScenarioUtil.spawn_marker(container, marker_scene, owner_id)
	print("NET host markers_spawned=%d" % marker_ids.size())
	NetScenarioUtil.make_sync(scene)
	var driver: Node = scene.get_node("DemoDriver")
	var bus: Node = scene.get_node("PlaceholderBus")
	# `waypoints` is the INDEX to stop at (0-based; r1.2 off-by-one fix).
	var circuit: Node = scene.get_node("Circuit")
	var count_v: Variant = circuit.call("waypoint_count")
	var waypoint_count: int = 0
	if count_v is int:
		waypoint_count = count_v
	if _waypoints < 0 or _waypoints >= waypoint_count:
		NetScenarioUtil.write_json("host", {
			"role": "host",
			"error": "waypoints index %d out of range (0..%d)" % [_waypoints, waypoint_count - 1],
			"exit": 1,
		})
		quit(1)
		return
	var reached: Array = [false]
	driver.connect("waypoint_reached", func(index: int) -> void:
		if index == _waypoints:
			reached[0] = true)
	# The waypoint budget derives from the route asked, not from `seconds` (r1.2).
	var got_there: bool = await _wait_until(
		func() -> bool: return reached[0], NetScenarioUtil.route_budget_s(_waypoints))
	if not got_there:
		NetScenarioUtil.write_json("host", {"role": "host", "error": "waypoint timeout", "exit": 1})
		quit(1)
		return
	driver.set("enabled", false)
	bus.call("set_drive", 0.0, 0.0, 1.0)
	print("NET host braking at waypoint %d" % _waypoints)
	await _wait_seconds(1.5)
	# Clients snapshot on THIS signal, after braking and settling (r1.2), not
	# after a fixed wall-clock wait of their own.
	backend.rpc("snapshot_now")
	NetScenarioUtil.write_json("host", {
		"role": "host",
		"port": port,
		"peers": Array(joined_ids),
		"markers_spawned": marker_ids.size(),
		"waypoint": _waypoints,
		"bus_pos": NetScenarioUtil.vec3_to_array(bus.get("global_position")),
		"bus_yaw_deg": NetScenarioUtil.yaw_deg(bus),
		"error": "",
		"exit": 0,
	})
	# Replicated spawns are deleted engine-side when the authority disconnects;
	# hold the connection open until every client has snapshotted (peer_done).
	var all_done: bool = await _wait_until(
		func() -> bool:
			var done_v: Variant = backend.get("done_peers")
			if done_v is Array:
				var done: Array = done_v
				return done.size() >= _clients
			return false, _seconds + 30.0)
	if not all_done:
		print("NET host quit with clients still running")
	print("NET host done")
	quit(0)


# ----------------------------------------------------------------- client ----

func _run_client() -> void:
	var backend: Node = _backend()
	var port_file: bool = await _wait_until(
		func() -> bool: return FileAccess.file_exists(
			NetScenarioUtil.RESULTS_DIR + "/port.txt"), 20.0)
	if not port_file:
		NetScenarioUtil.write_json("client_%d" % _index,
			{"role": "client", "error": "no port.txt", "exit": 1})
		quit(1)
		return
	var port: int = int(FileAccess.get_file_as_string(NetScenarioUtil.RESULTS_DIR + "/port.txt"))
	var err_v: Variant = backend.call("join_game", "127.0.0.1", port)
	if err_v is int:
		var err: int = err_v
		if err != OK:
			NetScenarioUtil.write_json("client_%d" % _index,
				{"role": "client", "error": "join_game failed", "exit": 1})
			quit(1)
			return
	var connected: Array = [false]
	backend.connect("joined", func() -> void: connected[0] = true)
	var is_connected: bool = await _wait_until(func() -> bool: return connected[0], 15.0)
	if not is_connected:
		NetScenarioUtil.write_json("client_%d" % _index,
			{"role": "client", "error": "connection timeout", "exit": 1})
		quit(1)
		return
	print("NET client_%d connected port=%d" % [_index, port])
	var scene: Node = _instantiate_scene("client")
	NetScenarioUtil.make_spawner(scene)
	if _break != "sync":
		NetScenarioUtil.make_sync(scene)
	backend.rpc("mark_ready")
	var snapshot_got: Array = [false]
	backend.connect("snapshot_requested", func() -> void: snapshot_got[0] = true)
	# Bail fast if the host dies before firing snapshot_now (e.g. an invalid
	# waypoints index): without this, clients would wait out the whole budget.
	var host_lost: Array = [false]
	backend.connect("server_lost", func() -> void: host_lost[0] = true)
	var snapshot_ok: bool = await _wait_until(
		func() -> bool: return snapshot_got[0] or host_lost[0],
		NetScenarioUtil.route_budget_s(_waypoints) + 15.0)
	if not snapshot_got[0]:
		NetScenarioUtil.write_json("client_%d" % _index,
			{"role": "client", "connected": true, "error": "host lost before snapshot", "exit": 1})
		quit(1)
		return
	var container: Node = scene.get_node("NetMarkers")
	var bus: Node = scene.get_node("PlaceholderBus")
	var peers_v: Variant = backend.call("peer_ids")
	var peers_left: int = 0
	if peers_v is PackedInt32Array:
		var peers_array: PackedInt32Array = peers_v
		peers_left = peers_array.size()
	NetScenarioUtil.write_json("client_%d" % _index, {
		"role": "client",
		"connected": true,
		"markers_received": container.get_child_count(),
		"peers_left": peers_left,
		"server_lost": peers_left == 0,
		"bus_pos": NetScenarioUtil.vec3_to_array(bus.get("global_position")),
		"bus_yaw_deg": NetScenarioUtil.yaw_deg(bus),
		"error": "",
		"exit": 0,
	})
	backend.rpc("mark_done")
	await _wait_seconds(0.5)
	print("NET client_%d done" % _index)
	quit(0)


# --------------------------------------------------------------- launcher ----

func _spawn_child(exe: String, project_dir: String, child_role: String, index: int) -> int:
	var log_name: String = child_role
	if index >= 0:
		log_name += "_%d" % index
	var args: PackedStringArray = [
		"--headless", "--path", project_dir,
		"--log-file", NetScenarioUtil.LOGS_DIR + "/" + log_name + ".log",
		"-s", "res://src/tooling/run_net_scenario.gd",
		"++", "role=" + child_role,
		"port=%d" % _port,
		"seconds=%s" % _seconds,
		"clients=%d" % _clients,
		"waypoints=%d" % _waypoints,
	]
	if index >= 0:
		args.append("index=%d" % index)
	if _break != "":
		args.append("break=" + _break)
	var pid: int = OS.create_process(exe, args)
	if pid < 0:
		printerr("NET launcher could not spawn ", log_name)
	return pid


func _alive_names(pids: Dictionary) -> Array[String]:
	var alive: Array[String] = []
	for child_name: String in pids.keys():
		var pid_v: Variant = pids[child_name]
		if pid_v is int:
			var pid: int = pid_v
			if OS.is_process_running(pid):
				alive.append(child_name)
	return alive


func _run_launcher() -> void:
	NetScenarioUtil.clean_dir(NetScenarioUtil.RESULTS_DIR)
	NetScenarioUtil.clean_dir(NetScenarioUtil.LOGS_DIR)
	DirAccess.make_dir_recursive_absolute(NetScenarioUtil.RESULTS_DIR)
	DirAccess.make_dir_recursive_absolute(NetScenarioUtil.LOGS_DIR)
	var exe: String = OS.get_executable_path()
	var project_dir: String = ProjectSettings.globalize_path("res://")
	var pids: Dictionary = {}
	pids["host"] = _spawn_child(exe, project_dir, "host", -1)
	await _wait_seconds(1.0)
	for index: int in range(_clients):
		pids["client_%d" % index] = _spawn_child(exe, project_dir, "client", index)
	print("NET launcher spawned host + %d clients (base port %d)" % [_clients, _port])
	var deadline: int = int((NetScenarioUtil.route_budget_s(_waypoints) + 45.0) * Engine.physics_ticks_per_second)
	var start: int = _ticks
	while _ticks - start < deadline:
		if _alive_names(pids).is_empty():
			break
		await process_frame
	var killed: Array[String] = _alive_names(pids)
	for child_name: String in killed:
		var pid_v: Variant = pids[child_name]
		if pid_v is int:
			var pid: int = pid_v
			OS.kill(pid)
	_aggregate(pids, killed)

func _aggregate(pids: Dictionary, killed: Array[String]) -> void:
	var failures: Array[String] = NetScenarioUtil.aggregate(pids, _clients, killed)
	if failures.is_empty():
		print("NET result=pass asserts=children_exited,host_exit,clients_connect,markers,convergence")
		quit(0)
	else:
		print("NET result=fail assert=%s" % failures[0])
		for failure: String in failures:
			printerr("NET assert failed: ", failure)
		quit(1)
