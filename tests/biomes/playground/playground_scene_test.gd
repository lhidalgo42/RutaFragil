extends GdUnitTestSuite

## Playground scene (D50/D51): structure checks plus a short demo drive on the
## real scene — three waypoints reached on a clock budget and no rolled_over.
## set_time_factor(4.0) multiplies the physics rate without changing the step
## (plan §3); every wait is signal-based with an explicit timeout, never a
## process-frame count.

var _rolled_over_count: int = 0


func test_scene_structure() -> void:
	var runner: GdUnitSceneRunner = scene_runner("res://scenes/playground.tscn")
	var scene: Node = runner.scene()
	assert_bool(scene is Playground).is_true()
	var circuit_node: Node = scene.get_node_or_null("Circuit")
	assert_bool(circuit_node is Circuit).is_true()
	if circuit_node is Circuit:
		var circuit: Circuit = circuit_node
		assert_int(circuit.waypoint_count()).is_greater_equal(8)
	var water_node: Node = scene.get_node_or_null("WaterZone")
	assert_bool(water_node is WaterZone).is_true()
	var driver_node: Node = scene.get_node_or_null("DemoDriver")
	assert_bool(driver_node is DemoDriver).is_true()
	if driver_node is DemoDriver:
		var driver: DemoDriver = driver_node
		# The authored default is demo_mode=false (M1-T1.1: F5 is the owner's
		# driving seat); the demo test below enables it explicitly.
		assert_bool(driver.enabled).is_false()
		assert_object(driver.circuit).is_not_null()
	# The bus is found by group, never by node name (D59).
	var bus_node: Node = scene.get_tree().get_first_node_in_group("bus")
	assert_bool(bus_node is Bus).is_true()
	if bus_node != null:
		assert_bool(bus_node.is_in_group("bus")).is_true()
	if bus_node is Bus:
		var bus: Bus = bus_node
		# Anti-corruption pin (2026-09-14): an out-of-band editor re-save once
		# moved the authored bus spawn to y=14 (it fell 13 m every start and no
		# test noticed — the demo lands and drives anyway). Assert the spawn is
		# on the ground, so a re-save like that fails HERE, not in gameplay.
		assert_float(bus.global_position.y).is_less(3.0)
	# The driver's seat must keep its marker: the same re-save dropped
	# seat_marker, and occupy() silently stopped teleporting to the wheel.
	var seat_node: Node = scene.get_tree().get_first_node_in_group("seat")
	assert_bool(seat_node is Seat).is_true()
	if seat_node is Seat:
		var seat: Seat = seat_node
		assert_object(seat.seat_marker).is_not_null()
	# D80 pins: the driver sits on the LEFT (Chile drives on the right), the
	# door stays on the right. An accidental editor drag must not move them
	# back in silence.
	var driver_marker_node: Node = scene.get_node_or_null("Bus/BusInterior/Positions/driver")
	assert_bool(driver_marker_node is Marker3D).is_true()
	if driver_marker_node is Marker3D:
		var driver_marker: Marker3D = driver_marker_node
		assert_float(driver_marker.position.x).is_less(0.0)
	var cabin_node: Node = scene.get_node_or_null("Bus/CabinCamera")
	assert_bool(cabin_node is Camera3D).is_true()
	if cabin_node is Camera3D:
		var cabin_cam: Camera3D = cabin_node
		assert_float(cabin_cam.position.x).is_less(0.0)
	var camera_node: Node = scene.get_node_or_null("ChaseCamera")
	assert_bool(camera_node is ChaseCamera).is_true()
	if camera_node is ChaseCamera:
		var camera: ChaseCamera = camera_node
		assert_object(camera.target).is_not_null()
	# Since round 3 (CameraArbiter): in the authored player mode the ONE
	# active camera is the crew's first-person eye camera; the chase camera
	# wakes for the demo and as the driver's alternate view.
	var eye_node: Node = scene.get_tree().get_first_node_in_group("eye_camera")
	assert_bool(eye_node is Camera3D).is_true()
	if eye_node is Camera3D:
		var eye: Camera3D = eye_node
		assert_bool(eye.current).is_true()


func test_demo_reaches_three_waypoints_without_rolling_over() -> void:
	var runner: GdUnitSceneRunner = scene_runner("res://scenes/playground.tscn")
	runner.set_time_factor(4.0)
	var scene: Node = runner.scene()
	# demo_mode is enabled explicitly: the authored default is false (M1-T1.1).
	# The DemoDriver and BusInput never drive at once (BusInput would write
	# set_drive(0,0,0) over the driver's commands every tick).
	scene.set("demo_mode", true)
	scene.get_node("DemoDriver").set("enabled", true)
	scene.get_node("BusInput").set("enabled", false)
	var bus_node: Node = scene.get_tree().get_first_node_in_group("bus")
	var driver_node: Node = scene.get_node_or_null("DemoDriver")
	assert_bool(bus_node is Bus).is_true()
	assert_bool(driver_node is DemoDriver).is_true()
	if not (bus_node is Bus) or not (driver_node is DemoDriver):
		return
	var bus: Bus = bus_node
	var driver: DemoDriver = driver_node
	_rolled_over_count = 0
	bus.rolled_over.connect(_on_rolled_over)
	await await_signal_on(driver, "waypoint_reached", [0], 15000)
	await await_signal_on(driver, "waypoint_reached", [1], 15000)
	await await_signal_on(driver, "waypoint_reached", [2], 15000)
	assert_int(driver.current_index).is_equal(3)
	assert_int(_rolled_over_count).is_equal(0)


func test_leaving_the_demo_follows_the_crew_state() -> void:
	var runner: GdUnitSceneRunner = scene_runner("res://scenes/playground.tscn")
	var scene: Node = runner.scene()
	assert_bool(scene is Playground).is_true()
	if not (scene is Playground):
		return
	var playground: Playground = scene
	var bus_input_node: Node = scene.get_node_or_null("BusInput")
	assert_bool(bus_input_node is BusInput).is_true()
	if not (bus_input_node is BusInput):
		return
	var bus_input: BusInput = bus_input_node
	# On foot: leaving the demo must NOT enable the driving input (the F1
	# wrinkle: it did, and W throttled the parked bus while walking).
	playground.set_demo_mode(true)
	assert_bool(bus_input.enabled).is_false()
	playground.set_demo_mode(false)
	assert_bool(bus_input.enabled).override_failure_message("leaving the demo enabled BusInput with the crew on foot").is_false()
	# Seated, leaving the demo restores the wheel.
	var bus_node: Node = scene.get_tree().get_first_node_in_group("bus")
	var crew_node: Node = scene.get_tree().get_first_node_in_group("crew")
	var seat_node: Node = scene.get_tree().get_first_node_in_group("seat")
	if not (bus_node is Bus) or not (crew_node is CrewMember) or not (seat_node is Seat):
		assert_bool(false).override_failure_message("cast missing").is_true()
		return
	var bus: Bus = bus_node
	var crew: CrewMember = crew_node
	var seat: Seat = seat_node
	crew.global_position = bus.global_transform * Vector3(0.0, -0.55, 0.0)
	crew.aboard = true
	for i: int in range(30):
		await scene.get_tree().physics_frame
	assert_bool(seat.occupy(crew)).is_true()
	assert_bool(bus_input.enabled).is_true()
	playground.set_demo_mode(true)
	assert_bool(bus_input.enabled).is_false()
	playground.set_demo_mode(false)
	assert_bool(bus_input.enabled).override_failure_message("leaving the demo did not restore the wheel while seated").is_true()
	seat.vacate()
	assert_bool(bus_input.enabled).is_false()


func _on_rolled_over() -> void:
	_rolled_over_count += 1
