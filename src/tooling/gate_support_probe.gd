class_name GateSupportProbe
extends RefCounted

## Save both sides of a support edge; reading only the airborne tick loses its floor.
var events: Array[Dictionary] = []
var _previous: Dictionary = {}
var _received: int = 0
var _history: Array[Dictionary] = []
var _positions: Dictionary = {}
var _bus_position: Vector3 = Vector3.ZERO
var _have_bus: bool = false
var _loss_index: int = -1
var off_run: int = 0
var max_off_run: int = 0
var last_supported: bool = false
var cargo_contact_samples: int = 0
var last_cargo_contact: bool = false
var cargo_contact_previous_three: bool = false
var history_complete: bool = false
var push_classification_complete: bool = true


func reset() -> void:
	events.clear()
	_previous.clear()
	_received = 0
	_history.clear()
	_positions.clear()
	_have_bus = false
	_loss_index = -1
	off_run = 0
	max_off_run = 0
	last_supported = false
	cargo_contact_samples = 0
	last_cargo_contact = false
	cargo_contact_previous_three = false
	history_complete = false
	push_classification_complete = true


func observe(tick: int, crew: CrewMember, bus: RigidBody3D, receiver: NetBusSync, supported: bool) -> void:
	var contacts: Array[Dictionary] = []
	var floors: Array[Dictionary] = []
	var cargo_contact: bool = false
	for slide: int in range(crew.get_slide_collision_count()):
		var collision: KinematicCollision3D = crew.get_slide_collision(slide)
		for index: int in range(collision.get_collision_count()):
			var collider: Object = collision.get_collider(index)
			cargo_contact = cargo_contact or collider is Package
			var contact: Dictionary = {"body": str(collider), "rid": str(collision.get_collider_rid(index)),
				"normal": GateMetricsUtil.vector_array(collision.get_normal(index)),
				"velocity": GateMetricsUtil.vector_array(collision.get_collider_velocity(index)),
				"position": GateMetricsUtil.vector_array(collision.get_position(index)),
				"depth_m": collision.get_depth(), "shape_index": collision.get_collider_shape_index(index)}
			if collider is Node:
				var node: Node = collider
				contact["body"] = str(node.get_path())
			var shape: Object = collision.get_collider_shape(index)
			contact["shape"] = str(shape)
			if shape is Node:
				var shape_node: Node = shape
				contact["shape"] = str(shape_node.get_path())
			contacts.append(contact)
			if collision.get_normal(index).dot(crew.up_direction) >= cos(crew.floor_max_angle):
				floors.append(contact)
	var nearest: Dictionary = {"body": null, "origin_distance_m": null, "package_count": 0}
	var distance: float = INF
	var packages: Array[Dictionary] = []
	var motion: Dictionary = {}
	for node: Node in crew.get_tree().get_nodes_in_group("net_cargo_sync"):
		if node is NetCargoSync:
			var sync: NetCargoSync = node
			motion = sync.motion_samples()
	for node: Node in crew.get_tree().get_nodes_in_group("package"):
		if node is Package:
			var package: Package = node
			var key: String = str(package.get_instance_id())
			var previous_position: Vector3 = _positions.get(key, package.global_position)
			var displacement: Vector3 = package.global_position - previous_position
			_positions[key] = package.global_position
			var state: PhysicsDirectBodyState3D = PhysicsServer3D.body_get_direct_state(package.get_rid())
			packages.append({"body": str(package.get_path()), "rid": str(package.get_rid()),
				"package_write_m": displacement.length(), "package_write_vector": GateMetricsUtil.vector_array(displacement),
				"position": GateMetricsUtil.vector_array(package.global_position),
				"local_position": GateMetricsUtil.vector_array(bus.to_local(package.global_position)),
				"server_velocity": GateMetricsUtil.vector_array(state.linear_velocity) if state != null else [],
				"restraint": package.restraint, "replica": package.replica_only, "freeze": package.freeze,
				"replication_write": motion.get(package.name, {})})
			nearest["package_count"] = GateMetricsUtil.integer(nearest["package_count"]) + 1
			var candidate: float = crew.global_position.distance_to(package.global_position)
			if candidate < distance:
				distance = candidate
				nearest["body"] = str(package.get_path())
				nearest["origin_distance_m"] = distance
				nearest["restraint"] = package.restraint
				nearest["authority"] = package.get_multiplayer_authority()
				nearest["freeze"] = package.freeze
				nearest["freeze_mode"] = package.freeze_mode
				nearest["position"] = GateMetricsUtil.vector_array(package.global_position)
	var snapshots: Dictionary = {"received_this_tick": 0, "source_s": 0.0, "playback_s": 0.0}
	var bus_displacement: Vector3 = bus.global_position - _bus_position if _have_bus else Vector3.ZERO
	_bus_position = bus.global_position
	_have_bus = true
	var write_m: float = bus_displacement.length()
	if receiver != null:
		var timing: Array[float] = receiver.timing_sample()
		snapshots = {"received_total": receiver.received_count,
			"received_this_tick": receiver.received_count - _received,
			"source_s": timing[1], "playback_next_s": timing[2], "playback_used_s": receiver.last_write_playback_s,
			"buffer_ahead_s": timing[1] - receiver.last_write_playback_s,
			"last_transport_s": receiver.last_transport_s, "last_arrival_utc_us": receiver.last_arrival_utc_us}
		_received = receiver.received_count
	var row: Dictionary = {"tick": tick, "physics_frame": Engine.get_physics_frames(),
		"bus_support": supported, "cargo_contact": cargo_contact,
		"on_floor": crew.is_on_floor(), "on_ceiling": crew.is_on_ceiling(), "floor_bodies": floors,
		"crew_velocity": GateMetricsUtil.vector_array(crew.velocity),
		"crew_real_velocity": GateMetricsUtil.vector_array(crew.get_real_velocity()),
		"platform_velocity": GateMetricsUtil.vector_array(crew.get_platform_velocity()),
		"local_position": GateMetricsUtil.vector_array(bus.to_local(crew.global_position)),
		"bus_position": GateMetricsUtil.vector_array(bus.global_position),
		"bus_linear_velocity": GateMetricsUtil.vector_array(NetBusSync.point_velocity(bus, bus.global_position)),
		"bus_write_m": write_m, "bus_write_vector": GateMetricsUtil.vector_array(bus_displacement),
		"platform_rid_api_available": crew.has_method("get_platform_rid"),
		"platform_contact_candidates": _platform_candidates(crew, contacts),
		"packages": packages, "snapshots": snapshots, "nearest_package": nearest, "contacts": contacts}
	push_sample(row)


func push_sample(row: Dictionary) -> void:
	last_cargo_contact = GateMetricsUtil.boolean(row.get("cargo_contact"))
	if row.get("cargo_contact") is bool:
		cargo_contact_samples += 1
	cargo_contact_previous_three = false
	history_complete = _history.size() == 3
	for previous: Dictionary in _history:
		cargo_contact_previous_three = cargo_contact_previous_three or GateMetricsUtil.boolean(previous.get("cargo_contact"))
		history_complete = history_complete and previous.get("cargo_contact") is bool
	last_supported = GateMetricsUtil.boolean(row.get("bus_support"))
	off_run = 0 if last_supported else off_run + 1
	max_off_run = maxi(max_off_run, off_run)
	if _previous.is_empty() and not last_supported:
		push_classification_complete = false
	if _loss_index >= 0:
		_update_displacement(events[_loss_index], row)
		events[_loss_index]["off_ticks"] = off_run if not last_supported else GateMetricsUtil.integer(events[_loss_index]["off_ticks"])
		if last_supported:
			events[_loss_index]["recovered"] = true
			events[_loss_index]["recovered_tick"] = row["tick"]
			_loss_index = -1
	if not _previous.is_empty() and GateMetricsUtil.boolean(_previous.get("bus_support")) \
			and not GateMetricsUtil.boolean(row.get("bus_support")):
		var classified: bool = history_complete or cargo_contact_previous_three
		push_classification_complete = push_classification_complete and classified
		var event: Dictionary = {"previous": _previous.duplicate(true), "previous_three": _history.duplicate(true),
			"lost": row.duplicate(true), "recovered": false, "recovered_tick": null, "off_ticks": 1,
			"push": cargo_contact_previous_three, "classification_complete": classified,
			"max_local_displacement_m": 0.0, "airborne_ticks": 0,
			"current_airborne_run_ticks": 0, "max_airborne_run_ticks": 0}
		_update_displacement(event, row)
		events.append(event)
		_loss_index = events.size() - 1
		print("SUPPORT_LOST ", JSON.stringify(event))
	_previous = row.duplicate(true)
	_history.append(_previous)
	if _history.size() > 3:
		_history.pop_front()


func active_push() -> bool:
	return _loss_index >= 0 and GateMetricsUtil.boolean(events[_loss_index].get("push"))


func push_summary() -> Dictionary:
	var result: Dictionary = {"count": 0, "open_count": 0, "max_duration_ticks": 0,
		"max_airborne_ticks": 0, "max_airborne_run_ticks": 0, "max_local_displacement_m": 0.0}
	for event: Dictionary in events:
		if not GateMetricsUtil.boolean(event.get("push")):
			continue
		result["count"] = GateMetricsUtil.integer(result["count"]) + 1
		result["open_count"] = GateMetricsUtil.integer(result["open_count"]) + (0 if GateMetricsUtil.boolean(event["recovered"]) else 1)
		result["max_duration_ticks"] = maxi(GateMetricsUtil.integer(result["max_duration_ticks"]), GateMetricsUtil.integer(event["off_ticks"]))
		result["max_airborne_ticks"] = maxi(GateMetricsUtil.integer(result["max_airborne_ticks"]), GateMetricsUtil.integer(event["airborne_ticks"]))
		result["max_airborne_run_ticks"] = maxi(GateMetricsUtil.integer(result["max_airborne_run_ticks"]), GateMetricsUtil.integer(event["max_airborne_run_ticks"]))
		result["max_local_displacement_m"] = maxf(GateMetricsUtil.number(result["max_local_displacement_m"]), GateMetricsUtil.number(event["max_local_displacement_m"]))
	return result


func _update_displacement(event: Dictionary, row: Dictionary) -> void:
	var previous: Dictionary = event["previous"]
	var origin: Array = previous.get("local_position", [])
	var current: Array = row.get("local_position", [])
	if origin.size() == 3 and current.size() == 3:
		var from: Vector3 = Vector3(GateMetricsUtil.number(origin[0]), GateMetricsUtil.number(origin[1]), GateMetricsUtil.number(origin[2]))
		var at: Vector3 = Vector3(GateMetricsUtil.number(current[0]), GateMetricsUtil.number(current[1]), GateMetricsUtil.number(current[2]))
		event["max_local_displacement_m"] = maxf(GateMetricsUtil.number(event["max_local_displacement_m"]), from.distance_to(at))
	var airborne: bool = not GateMetricsUtil.boolean(row.get("on_floor"))
	event["airborne_ticks"] = GateMetricsUtil.integer(event["airborne_ticks"]) + (1 if airborne else 0)
	var run: int = GateMetricsUtil.integer(event["current_airborne_run_ticks"]) + 1 if airborne else 0
	event["current_airborne_run_ticks"] = run
	event["max_airborne_run_ticks"] = maxi(GateMetricsUtil.integer(event["max_airborne_run_ticks"]), run)


func _platform_candidates(crew: CharacterBody3D, contacts: Array[Dictionary]) -> Array[Dictionary]:
	# 4.7.2 does not bind its internal platform_rid. Preserve every velocity
	# match and ambiguity instead of pretending a contact RID is that getter.
	var candidates: Array[Dictionary] = []
	for contact: Dictionary in contacts:
		var values: Array = contact["velocity"]
		var velocity: Vector3 = Vector3(GateMetricsUtil.number(values[0]),
			GateMetricsUtil.number(values[1]), GateMetricsUtil.number(values[2]))
		if velocity.distance_to(crew.get_platform_velocity()) < 0.001:
			candidates.append({"body": contact["body"], "rid": contact["rid"], "inferred_by": "velocity_match"})
	return candidates
