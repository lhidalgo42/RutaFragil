extends GdUnitTestSuite

## DemoDriver integration (D49): a real Bus on a code-built track
## drives itself to the first waypoint; a frozen bus or one blocked by an
## unclimbable wall triggers stuck instead. Waits are physics_frame/signal
## based with explicit timeouts (plan §3), never process-frame counts.


func test_waypoint_reached_when_driving_to_it() -> void:
	_make_track()
	var runner: GdUnitSceneRunner = scene_runner("res://src/vehicle/bus.tscn")
	runner.set_time_factor(2.0)
	var bus: Bus = _spawn_bus(runner, Vector3(0.0, 1.6, 0.0))
	if bus == null:
		return
	var positions: Array[Vector3] = [Vector3(0.0, 0.0, -15.0), Vector3(-15.0, 0.0, -15.0)]
	var circuit: Circuit = _make_circuit(positions)
	var driver: DemoDriver = _make_driver(bus, circuit)
	var settled: bool = await _wait_until_grounded(bus, 60)
	assert_bool(settled).is_true()
	if not settled:
		return
	driver.enabled = true
	await await_signal_on(driver, "waypoint_reached", [0], 15000)
	assert_int(driver.current_index).is_equal(1)
	assert_int(driver.laps).is_equal(0)


func test_stuck_emitted_when_bus_cannot_move() -> void:
	var runner: GdUnitSceneRunner = scene_runner("res://src/vehicle/bus.tscn")
	var bus: Bus = _spawn_bus(runner, Vector3(0.0, 3.0, 0.0))
	if bus == null:
		return
	bus.freeze = true
	var positions: Array[Vector3] = [Vector3(0.0, 0.0, -15.0), Vector3(-15.0, 0.0, -15.0)]
	var circuit: Circuit = _make_circuit(positions)
	var driver: DemoDriver = _make_driver(bus, circuit)
	driver.stuck_seconds = 1.0
	driver.enabled = true
	await await_signal_on(driver, "stuck", [], 4000)
	assert_int(driver.current_index).is_equal(0)


func test_stuck_emitted_against_unclimbable_wall() -> void:
	_make_track()
	var runner: GdUnitSceneRunner = scene_runner("res://src/vehicle/bus.tscn")
	var bus: Bus = _spawn_bus(runner, Vector3(0.0, 1.6, -0.4))
	if bus == null:
		return
	# Round 2 (r1.1): with the climb-hop deleted, a bus pressing a real wall it
	# cannot climb must stay blocked; this is the case the assist hid.
	_make_wall(Vector3(0.0, 2.0, -5.0), Vector3(10.0, 4.0, 1.0))
	var positions: Array[Vector3] = [Vector3(0.0, 0.0, -15.0), Vector3(-15.0, 0.0, -15.0)]
	var circuit: Circuit = _make_circuit(positions)
	var driver: DemoDriver = _make_driver(bus, circuit)
	driver.stuck_seconds = 1.0
	var settled: bool = await _wait_until_grounded(bus, 60)
	assert_bool(settled).is_true()
	if not settled:
		return
	var start_frame: int = Engine.get_physics_frames()
	driver.enabled = true
	await await_signal_on(driver, "stuck", [], 6000)
	var elapsed_s: float = (Engine.get_physics_frames() - start_frame) / float(Engine.physics_ticks_per_second)
	assert_float(elapsed_s).is_less_equal(driver.stuck_seconds + 1.0)
	assert_int(driver.current_index).is_equal(0)


func _make_wall(pos: Vector3, size: Vector3) -> void:
	var wall: StaticBody3D = auto_free(StaticBody3D.new())
	var shape_node: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = size
	shape_node.shape = box
	wall.add_child(shape_node)
	add_child(wall)
	wall.global_position = pos


func _make_track() -> void:
	var track: StaticBody3D = auto_free(StaticBody3D.new())
	var shape_node: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(100.0, 1.0, 100.0)
	shape_node.shape = box
	track.add_child(shape_node)
	add_child(track)
	track.global_position = Vector3(0.0, -0.5, 0.0)


func _spawn_bus(runner: GdUnitSceneRunner, pos: Vector3) -> Bus:
	var node: Node = runner.scene()
	assert_bool(node is Bus).is_true()
	if node is Bus:
		var bus: Bus = node
		bus.global_position = pos
		return bus
	return null


func _make_circuit(positions: Array[Vector3]) -> Circuit:
	var circuit: Circuit = auto_free(Circuit.new())
	add_child(circuit)
	for pos: Vector3 in positions:
		var marker: Marker3D = Marker3D.new()
		circuit.add_child(marker)
		marker.global_position = pos
	return circuit


func _make_driver(bus: Bus, circuit: Circuit) -> DemoDriver:
	var driver: DemoDriver = auto_free(DemoDriver.new())
	driver.bus = bus
	driver.circuit = circuit
	add_child(driver)
	return driver


func _wait_until_grounded(bus: Bus, max_ticks: int) -> bool:
	for i: int in max_ticks:
		await get_tree().physics_frame
		if bus.is_grounded() and bus.speed_mps() < 0.5:
			return true
	return false
