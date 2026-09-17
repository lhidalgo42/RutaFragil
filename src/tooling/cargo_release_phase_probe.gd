extends Node

## Isolate host release phase without contacts, damping, gravity or network.
class PhaseProbe extends Node3D:
	signal finished(result: Dictionary)
	const SPEED: float = 18.5
	const FREE_LOCAL: Vector3 = Vector3(0.8, 2.0, 0.1664648)
	var phase: String = "physics"
	var bus: Bus
	var package: Package
	var ticks: int = 0
	var released: bool = false
	var release_frame: int = -1
	var samples: int = 0
	var rows: Array[Dictionary] = []

	func _ready() -> void:
		bus = Bus.new()
		bus.name = "Bus"
		bus.rotation.y = PI
		_prepare_body(bus)
		var collision: CollisionShape3D = CollisionShape3D.new()
		collision.shape = BoxShape3D.new()
		bus.add_child(collision)
		add_child(bus)
		bus.set_physics_process(false)
		bus.linear_velocity = Vector3(0, 0, SPEED)
		var packed: PackedScene = load("res://src/cargo/package.tscn")
		package = packed.instantiate()
		package.name = "PhasePackage"
		package.configure_replication(bus, false)
		_prepare_body(package)
		package.freeze = true
		add_child(package)
		package.apply_replicated_state(Package.Restraint.HELD,
			Transform3D(Basis.IDENTITY, Vector3(0.8, 2, -1)), Vector3.ZERO, &"", 1)
		get_tree().physics_frame.connect(_after_sync)

	func _prepare_body(body: RigidBody3D) -> void:
		body.gravity_scale = 0
		body.linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
		body.linear_damp = 0
		body.angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
		body.angular_damp = 0
		body.can_sleep = false
		body.collision_layer = 0
		body.collision_mask = 0

	func _physics_process(_delta: float) -> void:
		ticks += 1
		if phase == "physics" and ticks == 12:
			_release()

	func _process(_delta: float) -> void:
		if phase == "process" and ticks >= 12 and not released:
			_release()

	func _release() -> void:
		released = true
		release_frame = Engine.get_physics_frames()
		rows.append(_sample("before_release"))
		package.apply_replicated_state(Package.Restraint.FREE,
			Transform3D(Basis.IDENTITY, FREE_LOCAL), Vector3.ZERO, &"", 0)
		rows.append(_sample("after_release"))

	func _after_sync() -> void:
		if not released or Engine.get_physics_frames() <= release_frame:
			return
		samples += 1
		rows.append(_sample("after_sync_%d" % samples))
		if samples == 4:
			get_tree().physics_frame.disconnect(_after_sync)
			set_process(false)
			set_physics_process(false)
			finished.emit({"phase": phase, "expected_tick_m": SPEED / 60.0, "rows": rows,
				"final_local_delta": _vector(bus.global_transform.affine_inverse() * package.global_position - FREE_LOCAL)})

	func _sample(stage: String) -> Dictionary:
		var physical_bus: Transform3D = _physical(bus)
		var physical_package: Transform3D = _physical(package)
		return {"stage": stage, "physics_frame": Engine.get_physics_frames(),
			"physics_phase": Engine.is_in_physics_frame(),
			"bus_node": _vector(bus.global_position), "bus_server": _vector(physical_bus.origin),
			"bus_gap": _vector(physical_bus.origin - bus.global_position),
			"package_node": _vector(package.global_position), "package_server": _vector(physical_package.origin),
			"local_node": _vector(bus.to_local(package.global_position)),
			"local_server": _vector(physical_bus.affine_inverse() * physical_package.origin),
			"velocity": _vector(package.linear_velocity)}

	func _physical(body: RigidBody3D) -> Transform3D:
		var value: Variant = PhysicsServer3D.body_get_state(body.get_rid(), PhysicsServer3D.BODY_STATE_TRANSFORM)
		if value is Transform3D:
			return value
		return Transform3D.IDENTITY

	func _vector(value: Vector3) -> Array[float]:
		return [value.x, value.y, value.z]


var _results: Array[Dictionary] = []


func _ready() -> void:
	for phase: String in ["physics", "process"]:
		var probe: PhaseProbe = PhaseProbe.new()
		probe.name = "Probe_" + phase
		probe.phase = phase
		probe.finished.connect(_finished.bind(probe))
		add_child(probe)


func _finished(result: Dictionary, probe: Node) -> void:
	_results.append(result)
	probe.queue_free()
	if _results.size() == 2:
		var file: FileAccess = FileAccess.open("res://docs/evidencia/M2-GATE/16_bank/release_phase.json", FileAccess.WRITE)
		file.store_string(JSON.stringify(_results, "\t"))
		file.close()
		print("RELEASE_PHASE ", JSON.stringify(_results))
		get_tree().quit.call_deferred(0)
