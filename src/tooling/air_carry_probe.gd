extends "res://src/tooling/platform_adoption_probe.gd"

## Exercise the actual CrewMember, with the same recorded trajectory on both sides.
func _ready() -> void:
	super._ready()
	_args["crew_model"] = "production"


func _run() -> void:
	var recording: String = str(_args.get("recording", "res://docs/evidencia/M2-GATE/16_bank/recording.json"))
	var raw: Array = JSON.parse_string(FileAccess.get_file_as_string(recording))
	var poses: Array[Transform3D] = []
	for row: Dictionary in raw:
		poses.append(_unflat(row["at"]))
	var case_name: String = str(_args.get("case", "jump_standing"))
	var jumping: bool = case_name.begins_with("jump_")
	var walking: bool = case_name.ends_with("walking")
	var jump_at: int = -1
	if jumping:
		for index: int in range(raw.size()):
			var row: Dictionary = raw[index]
			if (case_name == "jump_bumps" and poses[index].origin.z >= 3.0) \
					or (case_name != "jump_bumps" and GateMetricsUtil.number(row["speed_kmh"]) >= 80.0):
				jump_at = index
				break
	_driver.set("recording", poses)
	_driver.set("walking", walking)
	_driver.set("fixture_carry", false)
	_driver.set("jump_index", jump_at)
	_driver.set("keep_air_walk", jumping)
	_bus.global_transform = poses[0]
	_crew.global_position = _bus.global_transform * Vector3(0.0, -0.55, 2.5)
	_crew.velocity = Vector3.ZERO
	if case_name == "slow_encounter":
		var packed: PackedScene = load("res://src/cargo/package.tscn")
		_package = packed.instantiate()
		_package.configure_replication(_bus, true)
		var at: Vector3 = Vector3(0.3, -0.4, 1.5)
		_package.transform = _bus.global_transform * Transform3D(Basis.IDENTITY, at)
		_scene.add_child(_package)
		_driver.set("package", _package)
		_driver.set("box_local", at)
		_driver.set("speed_ratio", 0.665)
	for tick: int in range(90):
		await _sampler.completed_tick
	_driver.set("active", true)
	var exits: int = 0
	var airborne: int = 0
	var supported: int = 0
	var flights: Array[Dictionary] = []
	var flight: Dictionary = {}
	var expected: Vector3 = Vector3.ZERO
	var takeoff_step: Vector3 = Vector3.ZERO
	var previous_step: Vector3 = Vector3.ZERO
	var previous: Vector3 = _bus.to_local(_crew.global_position)
	var probe: GateSupportProbe = GateSupportProbe.new()
	var csv: PackedStringArray = ["tick,local_x,local_y,local_z,on_floor,bus_support,inside_hull,velocity_x,velocity_y,velocity_z,platform_speed,jump_command,walk_dx,walk_dy,walk_dz"]
	for tick: int in range(poses.size()):
		await _sampler.completed_tick
		var local: Vector3 = _bus.to_local(_crew.global_position)
		var support: bool = CarryProbeMetrics.has_bus_support(_crew, _bus, local)
		var inside: bool = BusInterior.is_inside_local(local)
		var on_floor: bool = _crew.is_on_floor()
		var step: Vector3 = _driver.get("commanded_step")
		if not on_floor and flight.is_empty():
			flight = {"start_tick": tick + 1, "start": previous, "air_ticks": 0,
				"recovered": false, "landing_tick": null, "landing_raw_m": null, "landing_error_m": null}
			expected = Vector3.ZERO
			takeoff_step = previous_step
		if not flight.is_empty():
			if not on_floor:
				expected += takeoff_step
			flight["air_ticks"] = GateMetricsUtil.integer(flight["air_ticks"]) + (0 if on_floor else 1)
			if on_floor:
				var start: Vector3 = flight["start"]
				flight["start"] = GateMetricsUtil.vector_array(start)
				flight["expected_walk"] = GateMetricsUtil.vector_array(expected)
				flight["recovered"] = true
				flight["landed_on_bus"] = support
				flight["landing_tick"] = tick + 1
				flight["landing_raw_m"] = local.distance_to(start)
				flight["landing_error_m"] = (local - start - expected).length()
				flights.append(flight)
				flight = {}
		probe.observe(tick + 1, _crew, _bus, null, support)
		exits += 0 if inside else 1
		airborne += 0 if on_floor else 1
		supported += 1 if support else 0
		csv.append("%d,%.9f,%.9f,%.9f,%d,%d,%d,%.9f,%.9f,%.9f,%.9f,%d,%.9f,%.9f,%.9f" % [
			tick + 1, local.x, local.y, local.z, int(on_floor), int(support), int(inside),
			_crew.velocity.x, _crew.velocity.y, _crew.velocity.z, _crew.get_platform_velocity().length(),
			int(tick == jump_at), step.x, step.y, step.z])
		previous = local
		previous_step = step
	if not flight.is_empty():
		var start: Vector3 = flight["start"]
		flight["start"] = GateMetricsUtil.vector_array(start)
		flights.append(flight)
	var label: String = str(_args.get("label", case_name))
	var result: Dictionary = {"case": case_name, "ticks": poses.size(), "hull_exit_ticks": exits,
		"airborne_ticks": airborne, "bus_support_percent": 100.0 * float(supported) / poses.size(),
		"jump_command_tick": jump_at + 1 if jumping else null, "flights": flights,
		"support_losses": probe.events.size(), "max_off_run_ticks": probe.max_off_run,
		"last_supported": probe.last_supported, "platform_on_leave": _crew.platform_on_leave,
		"sampling": "independent post-node observer, both priorities 1000", "recording": recording}
	result["residual_definition"] = "landing - (last supported local position + last supported local walking velocity * airborne ticks / 60)"
	if jumping:
		var jump_row: Dictionary = raw[jump_at]
		result["jump_bus_speed_kmh"] = jump_row["speed_kmh"]
	_write(label + ".json", result)
	_write(label + "_losses.json", probe.events)
	var file: FileAccess = FileAccess.open(_out.path_join(label + "_ticks.csv"), FileAccess.WRITE)
	file.store_string("\n".join(csv) + "\n")
	file.close()
	print("AIR_RESULT ", JSON.stringify(result))
