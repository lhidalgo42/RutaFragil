extends Node

## Two-peer gate orchestration. All mutation precedes the separate metrics observer.
var config: GateConfig = GateConfig.new()
var scene: Playground = null
var bus: Bus = null
var crew_sync: Node = null
var cargo_sync: Node = null
var bus_sync: NetBusSync = null
var metrics: Node = null
var actor: GateActor = null
var drive: GateDrive = null
var _peer: int = 0
var _bootstrapped: bool = false
var _client_done: bool = false
var _running: bool = false
var _finish_started: bool = false
var _deadline_ms: int = 0


func _ready() -> void:
	config.parse(OS.get_cmdline_user_args())
	_deadline_ms = Time.get_ticks_msec() + int(config.budget_s() * 1000.0)
	Engine.max_fps = 0
	if config.role == "launcher":
		var launcher_script: GDScript = load("res://src/tooling/gate_launcher.gd")
		var launcher: Node = launcher_script.new()
		launcher.set("config", config)
		add_child(launcher)
		return
	get_tree().root.title = "Ruta Fragil — Gate " + config.role
	if not config.vsync and DisplayServer.get_name() != "headless":
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	_start.call_deferred()


func _process(_delta: float) -> void:
	if config.role != "launcher" and Time.get_ticks_msec() > _deadline_ms:
		_fail("deadline exceeded (seconds + 90)")


func _start() -> void:
	if config.role == "host":
		await _host()
	elif config.role == "client":
		await _client()
	else:
		_fail("unknown role")


func _backend() -> Node:
	return get_tree().root.get_node("NetworkBackend")


func _until(condition: Callable, seconds: float) -> bool:
	var deadline: int = Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < deadline:
		if condition.call():
			return true
		await get_tree().physics_frame
	return condition.call()


func _host() -> void:
	if GameConfig.max_players < 2:
		_fail("gate requires capacity for host and client")
		return
	var connected: bool = false
	for offset: int in range(5):
		if _backend().call("host_game", config.port + offset) == OK:
			config.port += offset
			connected = true
			break
	if not connected:
		_fail("no available port")
		return
	config.write_json("port.json", {"port": config.port})
	_build_scene()
	if not await _until(func() -> bool: return not multiplayer.get_peers().is_empty(), 30.0):
		_fail("client did not join")
		return
	_peer = multiplayer.get_peers()[0]
	if not await _until(_client_prepared, 30.0):
		_fail("client did not prepare replication nodes")
		return
	crew_sync.set("network_enabled", true)
	cargo_sync.set("network_enabled", true)
	bus_sync.network_enabled = true
	var crew_ids: Array[int] = [1, _peer]
	crew_sync.call("spawn_crews", crew_ids)
	await get_tree().physics_frame
	_setup_cargo()
	cargo_sync.call("publish_manifest")
	if not await _until(func() -> bool: return _bootstrapped, 20.0):
		_fail("client did not receive crew and cargo")
		return
	bus.freeze = false
	bus.set_drive(0.0, 0.0, 1.0)
	await get_tree().create_timer(1.5).timeout
	var start_utc: float = Time.get_unix_time_from_system() + 1.0
	_begin.rpc(start_utc)
	_begin(start_utc)


func _client() -> void:
	if not await _until(func() -> bool: return config.read_json("port.json") is Dictionary, 25.0):
		_fail("host port missing")
		return
	var port_data: Dictionary = config.read_json("port.json")
	var joined: Array[bool] = [false]
	_backend().connect("joined", func() -> void: joined[0] = true)
	if _backend().call("join_game", "127.0.0.1", GateMetricsUtil.integer(port_data["port"])) != OK:
		_fail("join failed")
		return
	if not await _until(func() -> bool: return joined[0], 20.0):
		_fail("connection timeout")
		return
	_build_scene()
	if not await _until(func() -> bool: return crew_sync.call("is_setup_ready"), 10.0):
		_fail("crew spawner setup incomplete")
		return
	crew_sync.set("network_enabled", true)
	cargo_sync.set("network_enabled", true)
	bus_sync.network_enabled = true
	_backend().rpc_id(1, "mark_ready")
	if not await _until(func() -> bool:
		var crew_count: int = crew_sync.call("ready_count")
		var cargo_count: int = cargo_sync.call("ready_count")
		return crew_count == 2 and cargo_count == (4 if config.cargo_spawn else 0), 25.0):
		_fail("crew/cargo replication incomplete")
		return
	_ready_on_client.rpc_id(1)


func _build_scene() -> void:
	var packed: PackedScene = load("res://scenes/playground.tscn")
	scene = packed.instantiate()
	scene.network_role = config.role
	scene.cargo_spawn = config.cargo_spawn
	scene.demo_mode = config.role == "host"
	for node: Node in scene.find_children("*", "RigidBody3D", true, false):
		if node is Bus and node.is_in_group("bus"):
			bus = node
	bus.transform = Transform3D(Basis(Vector3.UP, PI), Vector3(30.0, 0.6, -95.0))
	bus.freeze = true
	# ChaseCamera already smooths its pose in _process, outside physics ticks.
	(scene.get_node("ChaseCamera") as Camera3D).physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	get_tree().root.add_child(scene)
	scene.demo_driver.enabled = false
	crew_sync = NetCrewSync.new()
	crew_sync.name = "NetCrewSync"
	crew_sync.set("bus", bus)
	crew_sync.set("network_enabled", false)
	scene.add_child(crew_sync)
	bus_sync = NetBusSync.new()
	bus_sync.name = "NetBusSync"
	bus_sync.bus = bus
	bus_sync.capture_snapshots = config.experiment
	scene.add_child(bus_sync)
	cargo_sync = NetCargoSync.new()
	cargo_sync.name = "NetCargoSync"
	cargo_sync.set("bus", bus)
	cargo_sync.set("network_enabled", false)
	scene.add_child(cargo_sync)


func _setup_cargo() -> void:
	var packages: Array[Node] = get_tree().get_nodes_in_group("package")
	packages.sort_custom(func(a: Node, b: Node) -> bool: return str(a.name) < str(b.name))
	var anchors: Array[Node] = get_tree().get_nodes_in_group("restraint_anchor")
	for index: int in range(mini(2, packages.size())):
		var anchor_name: String = "restraint_left_0" if index == 0 else "restraint_right_0"
		for anchor: Node in anchors:
			if str(anchor.name) == anchor_name:
				var package: Package = packages[index] as Package
				var at: Transform3D = bus.global_transform.affine_inverse() * (anchor as Node3D).global_transform
				package.apply_replicated_state(Package.Restraint.STRAPPED, at, Vector3.ZERO, StringName(anchor_name), 0)


@rpc("any_peer", "call_remote", "reliable")
func _ready_on_client() -> void:
	if multiplayer.is_server() and multiplayer.get_remote_sender_id() == _peer:
		_bootstrapped = true


@rpc("authority", "call_remote", "reliable")
func _begin(start_utc: float) -> void:
	var local: CrewMember = NetAuthority.local_crew(get_tree())
	if local == null:
		_fail("local crew missing")
		return
	var input: CrewInput = scene.get_node("CrewInput") as CrewInput
	input.enabled = config.human == config.role
	input.set_mouse_captured(config.human == config.role)
	CameraArbiter.apply(get_tree(), CameraArbiter.Mode.ON_FOOT if config.role == "client" else CameraArbiter.Mode.DEMO)
	await _capture("ready")
	while Time.get_unix_time_from_system() < start_utc:
		await get_tree().physics_frame
	actor = GateActor.new()
	actor.bus = bus
	actor.crew = local
	actor.cargo = cargo_sync
	actor.package_name = &"Package_2" if config.role == "host" else &"Package_3"
	actor.anchor_name = &"restraint_left_2" if config.role == "host" else &"restraint_right_4"
	actor.aisle_end = -2.0 if config.role == "host" else 2.0
	actor.enabled = config.human != config.role
	actor.walking_only = config.walk_only or not config.cargo_spawn
	add_child(actor)
	if config.role == "host":
		drive = GateDrive.new()
		drive.bus = bus
		drive.enabled = true
		add_child(drive)
	var metrics_script: GDScript = load("res://src/tooling/gate_metrics.gd")
	metrics = metrics_script.new()
	metrics.set("bus_receiver", bus_sync)
	add_child(metrics)
	metrics.call("begin", bus, local, cargo_sync)
	metrics.connect("sampled", _sampled)
	_running = true
	print("GATE begin role=%s peer=%d seconds=%.1f sample=after_all_node_physics priority=1000" % [config.role, multiplayer.get_unique_id(), config.seconds])


func _sampled(tick: int) -> void:
	if tick == 300:
		_capture("running")
	if tick >= ceili(config.seconds * Engine.physics_ticks_per_second) and not _finish_started:
		_finish_started = true
		_finish()


func _client_prepared() -> bool:
	var ready: Array[int] = _backend().get("ready_peers")
	return ready.has(_peer)


func _finish() -> void:
	_running = false
	actor.enabled = false
	if drive != null:
		drive.enabled = false
		bus.set_drive(0.0, 0.0, 1.0)
	var result: Dictionary = metrics.call("finish")
	result["role"] = config.role
	result["run_id"] = config.output
	result["iteration"] = config.iteration
	result["human"] = config.human == config.role
	result["requested_seconds"] = config.seconds
	result["experiment"] = config.experiment
	result["cargo_spawn"] = config.cargo_spawn
	result["cargo_count"] = cargo_sync.call("ready_count")
	result["actor_mode"] = "walk_only" if actor.walking_only else "cargo_cycles"
	result["exit"] = 0
	if drive != null:
		result["drive"] = drive.report()
	config.write_json(config.role + ".json", result)
	config.write_json(config.role + "_trace.json", metrics.call("get_trace"))
	config.write_json(config.role + "_support_losses.json", metrics.call("get_support_losses"))
	if config.experiment:
		config.write_json(config.role + "_bus_snapshots.json", bus_sync.snapshot_trace)
	var csv: FileAccess = FileAccess.open(config.output.path_join(config.role + "_ticks.csv"), FileAccess.WRITE)
	if csv != null:
		csv.store_string(metrics.call("get_tick_csv"))
		csv.close()
	print("GATE complete role=%s ticks=%s activity=%s" % [config.role, result.get("ticks", 0), result.get("activity", {})])
	if config.role == "client":
		_done_on_client.rpc_id(1)
	else:
		if not await _until(func() -> bool: return _client_done, 30.0):
			_fail("client did not finish")
			return
		_shutdown.rpc()
		_disable_network()
		await get_tree().create_timer(0.5).timeout
		get_tree().quit(0)


@rpc("any_peer", "call_remote", "reliable")
func _done_on_client() -> void:
	if multiplayer.is_server() and multiplayer.get_remote_sender_id() == _peer:
		_client_done = true


@rpc("authority", "call_remote", "reliable")
func _shutdown() -> void:
	_disable_network()
	get_tree().quit(0)


func _disable_network() -> void:
	crew_sync.set("network_enabled", false)
	cargo_sync.set("network_enabled", false)
	bus_sync.network_enabled = false


func _capture(label: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	var err: Error = image.save_png(config.output.path_join(config.role + "_" + label + ".png"))
	if err != OK:
		printerr("GATE screenshot failed: ", err)


func _fail(reason: String) -> void:
	set_process(false)
	printerr("GATE fatal role=%s: %s" % [config.role, reason])
	config.write_json(config.role + ".json", {"role": config.role, "exit": 1, "error": reason})
	get_tree().quit(1)
