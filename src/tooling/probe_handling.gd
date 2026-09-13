extends SceneTree

## Temporary measurement rig for M2-T2.1 step 4 (deleted after capture; the
## table lives in docs/evidencia/M2-T2.1/03_handling_regression.txt).

var ticks: int = 0

func _initialize() -> void:
	physics_frame.connect(func() -> void: ticks += 1)
	process_frame.connect(_start, CONNECT_ONE_SHOT)

func _start() -> void:
	_make_ground()
	await _measure_straight()
	await _measure_turn()
	await _measure_brake()
	quit(0)

func _make_ground() -> void:
	var ground: StaticBody3D = StaticBody3D.new()
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(4000, 1, 4000)
	shape.shape = box
	ground.add_child(shape)
	root.add_child(ground)
	ground.global_position = Vector3(0, -0.5, 0)

func _spawn_bus() -> RigidBody3D:
	var packed: Resource = load("res://src/vehicle/bus.tscn")
	var scene: PackedScene = packed
	var bus: RigidBody3D = scene.instantiate()
	root.add_child(bus)
	bus.global_position = Vector3(0, 1.6, 0)
	return bus

func _wait(n: int) -> void:
	var start: int = ticks
	while ticks - start < n:
		await physics_frame

func _measure_straight() -> void:
	var bus: RigidBody3D = _spawn_bus()
	await _wait(90)
	print("MEASURE rest_height_m=%.3f" % bus.global_position.y)
	bus.call("set_drive", 1.0, 0.0, 0.0)
	var t60: float = -1.0
	var max_speed: float = 0.0
	var start_tick: int = ticks
	while ticks - start_tick < 1200:
		await physics_frame
		var v: float = bus.linear_velocity.length()
		max_speed = maxf(max_speed, v)
		if t60 < 0.0 and v * 3.6 >= 60.0:
			t60 = float(ticks - start_tick) / 60.0
	print("MEASURE time_0_60_s=%.2f" % t60)
	print("MEASURE max_speed_kmh=%.1f" % (max_speed * 3.6))
	bus.queue_free()
	await _wait(10)

func _measure_turn() -> void:
	var bus: RigidBody3D = _spawn_bus()
	await _wait(90)
	bus.call("set_drive", 1.0, 0.0, 0.0)
	var start_tick: int = ticks
	while ticks - start_tick < 900:
		await physics_frame
		if bus.linear_velocity.length() * 3.6 >= 30.0:
			break
	bus.call("set_drive", 0.2, 1.0, 0.0)
	await _wait(120)
	var rates: Array[float] = []
	var speed_samples: Array[float] = []
	var last_yaw: float = bus.global_basis.get_euler().y
	for i: int in range(240):
		await physics_frame
		var yaw: float = bus.global_basis.get_euler().y
		rates.append(absf(wrapf(yaw - last_yaw, -PI, PI)) * 60.0)
		last_yaw = yaw
		speed_samples.append(bus.linear_velocity.length())
	var rate: float = rates.reduce(func(a: float, b: float) -> float: return a + b, 0.0) / rates.size()
	var speed: float = speed_samples.reduce(func(a: float, b: float) -> float: return a + b, 0.0) / speed_samples.size()
	var radius: float = -1.0
	if rate > 0.001:
		radius = speed / rate
	print("MEASURE turn_radius_m=%.1f (mean_speed_kmh=%.1f)" % [radius, speed * 3.6])
	bus.queue_free()
	await _wait(10)

func _measure_brake() -> void:
	var bus: RigidBody3D = _spawn_bus()
	await _wait(90)
	bus.call("set_drive", 1.0, 0.0, 0.0)
	var start_tick: int = ticks
	while ticks - start_tick < 900:
		await physics_frame
		if bus.linear_velocity.length() * 3.6 >= 50.0:
			break
	var brake_start: Vector3 = bus.global_position
	bus.call("set_drive", 0.0, 0.0, 1.0)
	var stop_tick: int = ticks
	while bus.linear_velocity.length() > 0.3 and ticks - stop_tick < 600:
		await physics_frame
	print("MEASURE brake_50kmh_distance_m=%.1f stop_time_s=%.2f" % [bus.global_position.distance_to(brake_start), float(ticks - stop_tick) / 60.0])
	bus.queue_free()
	await _wait(10)
