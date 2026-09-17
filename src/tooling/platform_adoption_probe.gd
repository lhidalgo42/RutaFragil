extends Node

## Round-five reduction: real bus recorded once, frozen replay with a lateral
## cargo collider. No networking, no rewinds, no resets during measurement.
const Driver: GDScript = preload("res://src/tooling/platform_probe_driver.gd")
const ProbeCrew: GDScript = preload("res://src/tooling/platform_probe_crew.gd")
const Sampler: GDScript = preload("res://src/tooling/carry_probe_sampler.gd")
var _args: Dictionary = {}
var _scene: Playground
var _bus: Bus
var _crew: CrewMember
var _driver: Node
var _sampler: Node
var _package: Package
var _out: String = "user://platform_probe"


func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		var parts: PackedStringArray = arg.split("=", true, 1)
		if parts.size() == 2:
			_args[parts[0]] = parts[1]
	_out = str(_args.get("output", _out))
	_start.call_deferred()


func _start() -> void:
	DirAccess.make_dir_recursive_absolute(_out)
	var recording: bool = str(_args.get("mode", "run")) == "rec"
	var packed: PackedScene = load("res://scenes/playground.tscn")
	_scene = packed.instantiate()
	_scene.demo_mode = true
	_scene.cargo_spawn = false
	_bus = _scene.get_node("Bus") as Bus
	_bus.transform = Transform3D(Basis(Vector3.UP, PI), Vector3(30.0, 0.6, -210.0))
	_bus.freeze = true
	_bus.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	_crew = _scene.get_node("CrewMember") as CrewMember
	if _crew == null:
		for node: Node in _scene.find_children("*", "CharacterBody3D", true, false):
			if node is CrewMember:
				_crew = node
	if str(_args.get("crew_model", "fixture")) != "production":
		_crew.set_script(ProbeCrew)
	_crew.transform = _bus.transform * Transform3D(Basis.IDENTITY, Vector3(0.0, -0.55, 2.5))
	_crew.aboard = true
	var floor_shape: CollisionShape3D = _scene.get_node("Ground/CollisionShape3D") as CollisionShape3D
	var box: BoxShape3D = floor_shape.shape.duplicate() as BoxShape3D
	box.size = Vector3(400.0, 1.0, 800.0)
	floor_shape.shape = box
	get_tree().root.add_child(_scene)
	_scene.demo_driver.enabled = false
	_driver = Driver.new()
	_driver.set("bus", _bus)
	_driver.set("crew", _crew)
	_driver.set("record_mode", recording)
	_scene.add_child(_driver)
	_sampler = Sampler.new()
	_scene.add_child(_sampler)
	if recording:
		await _record()
	else:
		await _run()
	get_tree().quit(0)


func _record() -> void:
	_crew.set_physics_process(false)
	_crew.set_collision_disabled(true)
	_bus.freeze = false
	_bus.set_drive(0.0, 0.0, 1.0)
	for tick: int in range(120):
		await _sampler.completed_tick
	_driver.set("active", true)
	var rows: Array[Dictionary] = []
	var bump_speeds: Array[float] = []
	for tick: int in range(1500):
		await _sampler.completed_tick
		rows.append({"at": _flat(_bus.global_transform), "speed_kmh": _bus.speed_mps() * 3.6,
			"linear": GateMetricsUtil.vector_array(_bus.linear_velocity),
			"angular": GateMetricsUtil.vector_array(_bus.angular_velocity)})
		if _bus.global_position.z >= 2.0 and _bus.global_position.z <= 46.0:
			bump_speeds.append(_bus.speed_mps() * 3.6)
		if _bus.global_position.z > 70.0:
			break
	_write("recording.json", rows)
	var report: Dictionary = {"samples": rows.size(), "bump_ticks": bump_speeds.size(),
		"bump_min_kmh": CarryProbeMetrics.percentile(bump_speeds, 0.0),
		"bump_max_kmh": CarryProbeMetrics.percentile(bump_speeds, 1.0),
		"fixture_ground_m": [400, 1, 800], "physics_hz": Engine.physics_ticks_per_second}
	_write("recording_summary.json", report)
	print("PLATFORM_RECORD ", JSON.stringify(report))


func _run() -> void:
	var input: String = str(_args.get("recording", _out.path_join("recording.json")))
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(input))
	if not parsed is Array:
		printerr("PLATFORM no recording")
		get_tree().quit(1)
		return
	var raw: Array = parsed
	var poses: Array[Transform3D] = []
	for row: Dictionary in raw:
		poses.append(_unflat(row["at"]))
	_driver.set("recording", poses)
	_bus.global_transform = poses[0]
	_crew.global_position = _bus.global_transform * Vector3(0.0, -0.55, float(_args.get("crew_z", "2.5")))
	_crew.velocity = Vector3.ZERO
	var candidate: String = str(_args.get("candidate", "engine"))
	var walking: bool = str(_args.get("walking", "0")) == "1"
	_crew.set("explicit_carry", candidate == "explicit")
	_crew.set("down_press", float(_args.get("press", "-0.5")))
	if candidate == "explicit":
		_crew.platform_floor_layers = 0
		_crew.platform_wall_layers = 0
		_crew.platform_on_leave = CharacterBody3D.PLATFORM_ON_LEAVE_DO_NOTHING
	elif candidate == "masked":
		_crew.platform_floor_layers = 1
		_crew.platform_wall_layers = 1
	_driver.set("walking", walking)
	_driver.set("speed_ratio", float(_args.get("ratio", "0.665")))
	_driver.set("deficit_start", int(_args.get("deficit_start", "350")))
	if str(_args.get("cargo", "on")) != "off":
		var packed: PackedScene = load("res://src/cargo/package.tscn")
		_package = packed.instantiate()
		_package.configure_replication(_bus, true)
		var at: Vector3 = Vector3(float(_args.get("box_x", "0.49")), -0.4, float(_args.get("box_z", "2.5")))
		_driver.set("box_local", at)
		_package.transform = _bus.global_transform * Transform3D(Basis.IDENTITY, at)
		_scene.add_child(_package)
		_driver.set("package", _package)
	for tick: int in range(90):
		await _sampler.completed_tick
	_driver.set("active", true)
	var slips: Array[float] = []
	var probe: GateSupportProbe = GateSupportProbe.new()
	var supported: int = 0
	var airborne: int = 0
	var dual_contacts: int = 0
	var previous: Vector3 = _bus.to_local(_crew.global_position)
	var csv: PackedStringArray = ["tick,support,on_floor,local_x,local_y,local_z,slip_m,bus_write_m,package_write_m,platform_speed,dual_contact"]
	for tick: int in range(poses.size()):
		await _sampler.completed_tick
		var local: Vector3 = _bus.to_local(_crew.global_position)
		var support: bool = CarryProbeMetrics.has_bus_support(_crew, _bus, local)
		var slip: float = local.distance_to(previous)
		previous = local
		slips.append(slip)
		supported += 1 if support else 0
		airborne += 0 if _crew.is_on_floor() else 1
		var floor_contact: bool = false
		var box_contact: bool = false
		for index: int in range(_crew.get_slide_collision_count()):
			var collision: KinematicCollision3D = _crew.get_slide_collision(index)
			for contact: int in range(collision.get_collision_count()):
				floor_contact = floor_contact or collision.get_collider(contact) == _bus
				box_contact = box_contact or collision.get_collider(contact) == _package
		var dual: bool = floor_contact and box_contact
		dual_contacts += 1 if dual else 0
		probe.observe(tick + 1, _crew, _bus, null, support)
		var bus_delta: Vector3 = _driver.get("bus_delta")
		var package_delta: Vector3 = _driver.get("package_delta")
		csv.append("%d,%d,%d,%.9f,%.9f,%.9f,%.9f,%.9f,%.9f,%.9f,%d" % [
			tick + 1, int(support), int(_crew.is_on_floor()), local.x, local.y, local.z, slip,
			bus_delta.length(), package_delta.length(), _crew.get_platform_velocity().length(), int(dual)])
	var label: String = str(_args.get("label", candidate))
	var result: Dictionary = {"candidate": candidate, "walking": walking, "arguments": _args,
		"ticks": poses.size(), "support_percent": 100.0 * float(supported) / poses.size(),
		"supported_ticks": supported, "airborne_ticks": airborne, "losses": probe.events.size(),
		"last_supported": probe.last_supported, "max_off_run_ticks": probe.max_off_run,
		"dual_contact_ticks": dual_contacts, "slip": GateMetricsUtil.slip_summary(slips),
		"sampling": "independent post-node observer, both priorities 1000"}
	_write(label + ".json", result)
	_write(label + "_losses.json", probe.events)
	var file: FileAccess = FileAccess.open(_out.path_join(label + "_ticks.csv"), FileAccess.WRITE)
	file.store_string("\n".join(csv) + "\n")
	file.close()
	print("PLATFORM_RESULT ", JSON.stringify(result))


func _write(name: String, value: Variant) -> void:
	var file: FileAccess = FileAccess.open(_out.path_join(name), FileAccess.WRITE)
	file.store_string(JSON.stringify(value, "\t"))
	file.close()


func _flat(at: Transform3D) -> Array[float]:
	return [at.basis.x.x, at.basis.x.y, at.basis.x.z, at.basis.y.x, at.basis.y.y, at.basis.y.z,
		at.basis.z.x, at.basis.z.y, at.basis.z.z, at.origin.x, at.origin.y, at.origin.z]


func _unflat(values: Array) -> Transform3D:
	var numbers: Array[float] = []
	for value: Variant in values:
		numbers.append(GateMetricsUtil.number(value))
	return Transform3D(Basis(Vector3(numbers[0], numbers[1], numbers[2]), Vector3(numbers[3], numbers[4], numbers[5]),
		Vector3(numbers[6], numbers[7], numbers[8])), Vector3(numbers[9], numbers[10], numbers[11]))
