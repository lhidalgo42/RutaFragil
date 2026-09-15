extends GdUnitTestSuite

## The single-player criterion of T2.2 (D77, paso 6): one minute inside the
## bus at speed over the bumps, the crew ABOARD (reparented per D75).
## Measured bounds come from the paso-1 table (drift of millimetres) with
## margin; penetration = below the floor top; ejection = outside the shell.
## Runs in the gdUnit4 runner (autoloads exist there; a bare -s script cannot
## reference the crew scripts, which reach GameConfig).

var _penetrations: int = 0
var _ejected: bool = false
var _max_drift: Vector3 = Vector3.ZERO


func test_one_minute_ride_at_speed_over_the_bumps() -> void:
	var runner: GdUnitSceneRunner = scene_runner("res://scenes/playground.tscn")
	runner.set_time_factor(4.0)
	var scene: Node = runner.scene()
	scene.set("cargo_spawn", false)
	scene.set("demo_mode", true)
	scene.get_node("DemoDriver").set("enabled", true)
	scene.get_node("BusInput").set("enabled", false)
	var bus_node: Node = scene.get_tree().get_first_node_in_group("bus")
	var crew_node: Node = scene.get_tree().get_first_node_in_group("crew")
	assert_bool(bus_node is Bus).is_true()
	assert_bool(crew_node is CrewMember).is_true()
	if not (bus_node is Bus) or not (crew_node is CrewMember):
		return
	var bus: Bus = bus_node
	var crew: CrewMember = crew_node
	# Board: inside, on the floor, positioned BEFORE anything (the reviewer's
	# rule), aboard. NO reparenting: the crew rides in the world frame and the
	# engine carries it (D74 measured; D75's reparent double-counted it —
	# drift of 3.5 m rearward in one lap vs millimetres in the world frame).
	crew.global_position = bus.global_transform * Vector3(0.0, -0.35, 0.0)
	await _wait_ticks(10)
	crew.aboard = true
	var base_local: Vector3 = Vector3.ZERO
	for tick: int in range(60 * 65):
		await get_tree().physics_frame
		_sample(bus, crew, base_local)
		if base_local == Vector3.ZERO:
			base_local = bus.global_transform.affine_inverse() * crew.global_position
	print("ride: max_drift=%s penetrations=%d ejected=%s" % [str(_max_drift), _penetrations, _ejected])
	assert_bool(_ejected).is_false()
	assert_int(_penetrations).is_equal(0)
	# The hard bounds of the criterion (D77) are "no penetration, no
	# ejection" — both hold. The drift is measured, not tightened to taste:
	# 0.30 m lateral over a minute of bumps at ~70 km/h (2026-09-13); the
	# assert leaves margin (0.5) without pretending the crew is glued.
	assert_float(_max_drift.x).is_less(0.5)
	assert_float(_max_drift.z).is_less(0.5)


func _sample(bus: Bus, crew: CrewMember, base_local: Vector3) -> void:
	var local: Vector3 = bus.global_transform.affine_inverse() * crew.global_position
	if base_local != Vector3.ZERO:
		var drift: Vector3 = local - base_local
		_max_drift.x = maxf(_max_drift.x, absf(drift.x))
		_max_drift.y = maxf(_max_drift.y, absf(drift.y))
		_max_drift.z = maxf(_max_drift.z, absf(drift.z))
	if local.y < -0.65 and crew.is_on_floor():
		_penetrations += 1
	if absf(local.x) > 1.5 or local.z > 4.2 or local.z < -4.2:
		_ejected = true


func _wait_ticks(count: int) -> void:
	for i: int in range(count):
		await get_tree().physics_frame
