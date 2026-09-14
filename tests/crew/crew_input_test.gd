extends GdUnitTestSuite

## CrewInput end-to-end (M2-T2.2 ronda 2): drives the ACTION STATE with
## Input.action_press/action_release — verified to work headless (the reviewer
## measured is_action_pressed / get_action_strength / is_action_just_pressed
## all responding; what headless lacks is keyboard InputEvents) — and asserts
## the EFFECT on the crew: walking displaces it, interact seats and lifts it.
## This is the test that would have caught the round-1 failure, where the
## actions were read by the code but never registered in the input map.
## Everything spawned is auto_free'd: a crew left over from a previous test
## stays in the "crew" group and the next CrewInput binds to the STALE one
## (measured 2026-09-13: input drove instance A while the test watched B).
## All bodies are positioned (local) BEFORE add_child (the reviewer's rule).

const CREW_SCENE: String = "res://src/crew/crew_member.tscn"


func after_test() -> void:
	# Never leak action state into the next test.
	for action: String in ["walk_forward", "walk_back", "walk_left", "walk_right", "walk_sprint", "walk_jump", "interact"]:
		Input.action_release(action)


func test_walk_forward_action_moves_the_crew_forward() -> void:
	_make_ground()
	var crew: CrewMember = await _spawn_settled_crew(Vector3(0.0, 1.0, 0.0))
	if crew == null:
		return
	await _spawn_input(true)
	var start: Vector3 = crew.global_position
	Input.action_press("walk_forward")
	await _wait_ticks(30)
	Input.action_release("walk_forward")
	assert_float(crew.global_position.z - start.z).is_less(-0.5)


func test_walk_left_and_right_actions_give_the_right_sign() -> void:
	_make_ground()
	var crew: CrewMember = await _spawn_settled_crew(Vector3(0.0, 1.0, 0.0))
	if crew == null:
		return
	await _spawn_input(true)
	var start: Vector3 = crew.global_position
	Input.action_press("walk_left")
	await _wait_ticks(30)
	Input.action_release("walk_left")
	assert_float(crew.global_position.x - start.x).is_less(-0.5)
	var middle: Vector3 = crew.global_position
	Input.action_press("walk_right")
	await _wait_ticks(30)
	Input.action_release("walk_right")
	assert_float(crew.global_position.x - middle.x).is_greater(0.5)


func test_interact_action_seats_and_lifts_the_crew() -> void:
	_make_ground()
	var crew: CrewMember = await _spawn_settled_crew(Vector3(0.0, 1.0, 0.0))
	if crew == null:
		return
	var seat: Seat = _make_seat(crew.global_position + Vector3(1.0, 0.0, 0.0))
	await _spawn_input(true)
	assert_bool(await _interact_until(crew, true)).override_failure_message("interact never seated the crew").is_true()
	assert_object(seat.occupied_by).is_same(crew)
	# Seated, Seat disabled this CrewInput: the same key must still lift her
	# (that is the wire round 1 left loose).
	assert_bool(await _interact_until(crew, false)).override_failure_message("interact never lifted the crew").is_true()
	assert_object(seat.occupied_by).is_null()


func test_toggle_nearest_seat_callable_without_input() -> void:
	_make_ground()
	var crew: CrewMember = await _spawn_settled_crew(Vector3(0.0, 1.0, 0.0))
	if crew == null:
		return
	_make_seat(crew.global_position + Vector3(1.0, 0.0, 0.0))
	# enabled=false on purpose: the named function must work regardless.
	var input: CrewInput = await _spawn_input(false)
	input.toggle_nearest_seat(crew)
	assert_bool(crew.seated).is_true()
	input.toggle_nearest_seat(crew)
	assert_bool(crew.seated).is_false()


func test_toggle_nearest_seat_out_of_reach_does_nothing() -> void:
	_make_ground()
	var crew: CrewMember = await _spawn_settled_crew(Vector3(0.0, 1.0, 0.0))
	if crew == null:
		return
	_make_seat(crew.global_position + Vector3(10.0, 0.0, 0.0))
	var input: CrewInput = await _spawn_input(false)
	input.toggle_nearest_seat(crew)
	assert_bool(crew.seated).is_false()


## Taps interact until the toggle lands (bounded retry). CrewInput detects
## the press edge itself (is_action_pressed + last-tick state) because
## is_action_just_pressed is flushed at the next PROCESS frame — headless
## runs process frames far faster than the 60 Hz physics ticks, so a node's
## _physics_process never saw a programmatic just-press (measured 2026-09-13:
## 40 presses, zero seen). The tap must therefore be a real one: released for
## a full tick, then held for a full tick.
func _interact_until(crew: CrewMember, want_seated: bool) -> bool:
	var tries: int = 0
	while crew.seated != want_seated and tries < 40:
		# A real tap: up at least one physics tick, then down at least one.
		# Release+press within the same tick is invisible to CrewInput's edge
		# detector (it never observes the released tick).
		Input.action_release("interact")
		await get_tree().physics_frame
		Input.action_press("interact")
		await get_tree().physics_frame
		tries += 1
	Input.action_release("interact")
	return crew.seated == want_seated


func _make_ground() -> StaticBody3D:
	var ground: StaticBody3D = auto_free(StaticBody3D.new())
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(200.0, 1.0, 200.0)
	shape.shape = box
	ground.add_child(shape)
	add_child(ground)
	ground.global_position = Vector3(0.0, -0.5, 0.0)
	return ground


func _make_seat(marker_pos: Vector3) -> Seat:
	var marker: Marker3D = auto_free(Marker3D.new())
	marker.position = marker_pos
	add_child(marker)
	var seat: Seat = auto_free(Seat.new())
	seat.seat_marker = marker
	add_child(seat)
	return seat


func _spawn_settled_crew(pos: Vector3) -> CrewMember:
	var packed: Resource = load(CREW_SCENE)
	if packed is PackedScene:
		var scene: PackedScene = packed
		var crew: CrewMember = auto_free(scene.instantiate())
		crew.position = pos
		add_child(crew)
		await _wait_ticks(90)
		assert_bool(crew.is_on_floor()).is_true()
		return crew
	assert_bool(false).override_failure_message("crew_member.tscn did not load").is_true()
	return null


func _spawn_input(on: bool) -> CrewInput:
	var input: CrewInput = auto_free(CrewInput.new())
	input.enabled = on
	add_child(input)
	# _find_crew is deferred: give it its frames.
	await _wait_ticks(2)
	return input


func _wait_ticks(count: int) -> void:
	for i: int in range(count):
		await get_tree().physics_frame
