extends GdUnitTestSuite

## CrewHands + the E-duration wiring end to end (M2-T2.3, agent B): the pure
## target choice, the pure throw composition, grab/drop/strap/unstrap through
## the real action state (Input.action_press/release drive it headless — the
## reviewer's measurement), and the round-4 catcher: a HELD package in the
## bus at 40 km/h must not change the bus's omega nor height. Bodies are
## positioned BEFORE add_child; everything spawned is auto_free'd.

const CREW_SCENE: String = "res://src/crew/crew_member.tscn"
const PACKAGE_SCENE: String = "res://src/cargo/package.tscn"

## The package grabbed by `_grabbed_setup` (gdUnit4 helpers return one value).
var _last_package: Package = null


func after_test() -> void:
	for action: String in ["walk_forward", "walk_back", "walk_left", "walk_right", "walk_sprint", "walk_jump", "interact", "throw", "drop"]:
		Input.action_release(action)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func test_closest_to_ray_prefers_ray_then_reach() -> void:
	var off_ray: Package = _make_package(Vector3(1.0, 0.0, -1.0))
	var on_ray: Package = _make_package(Vector3(0.0, 0.0, -2.0))
	# off_ray is NEARER to the hand; on_ray wins because it sits on the ray.
	var picked: Package = CrewHands.closest_to_ray(
		[off_ray, on_ray], Vector3.ZERO, Vector3.ZERO, Vector3(0.0, 0.0, -1.0), 3.0)
	assert_object(picked).is_same(on_ray)
	# A box beyond reach is never picked, however aligned with the ray.
	var far_on_ray: Package = _make_package(Vector3(0.0, 0.0, -4.0))
	picked = CrewHands.closest_to_ray(
		[far_on_ray, off_ray], Vector3.ZERO, Vector3.ZERO, Vector3(0.0, 0.0, -1.0), 2.5)
	assert_object(picked).is_same(off_ray)


func test_throw_velocity_sign_and_magnitude() -> void:
	var level: Vector3 = CrewHands.throw_velocity(Basis(), 6.0, Vector3.ZERO)
	assert_vector(level).is_equal_approx(Vector3(0.0, 0.0, -6.0), Vector3(0.0001, 0.0001, 0.0001))
	assert_float(level.length()).is_equal_approx(6.0, 0.0001)
	var yawed: Vector3 = CrewHands.throw_velocity(Basis(Vector3(0.0, 1.0, 0.0), PI * 0.5), 6.0, Vector3.ZERO)
	assert_vector(yawed).is_equal_approx(Vector3(-6.0, 0.0, 0.0), Vector3(0.0001, 0.0001, 0.0001))
	var aboard: Vector3 = CrewHands.throw_velocity(Basis(), 6.0, Vector3(10.0, 0.0, 0.0))
	assert_vector(aboard).is_equal_approx(Vector3(10.0, 0.0, -6.0), Vector3(0.0001, 0.0001, 0.0001))
	assert_float(aboard.length()).is_equal_approx(sqrt(136.0), 0.0001)


func test_tap_grabs_the_ray_box_which_follows_the_hand_and_seat_is_rejected() -> void:
	_make_ground()
	var crew: CrewMember = await _spawn_settled_crew(Vector3(0.0, 1.0, 0.0))
	if crew == null:
		return
	await _spawn_input(true)
	var off_ray: Package = _make_package(Vector3(0.9, 0.2, -1.0))
	var on_ray: Package = _make_package(Vector3(0.0, 0.2, -2.0))
	var hands: CrewHands = _hands()
	await _tap_interact()
	assert_object(hands.held).is_same(on_ray)
	assert_int(on_ray.restraint).is_equal(Package.Restraint.HELD)
	assert_int(off_ray.restraint).is_equal(Package.Restraint.FREE)
	await _wait_ticks(3)
	var hand: Marker3D = _hand_anchor(crew)
	assert_vector(on_ray.global_position).is_equal_approx(hand.global_position, Vector3(0.001, 0.001, 0.001))
	# Owner's priority: a tap with a package in hand REJECTS the seat.
	var marker: Marker3D = auto_free(Marker3D.new())
	marker.position = crew.global_position + Vector3(1.0, 0.0, 0.0)
	add_child(marker)
	var seat: Seat = auto_free(Seat.new())
	seat.seat_marker = marker
	add_child(seat)
	await _tap_interact()
	assert_bool(crew.seated).is_false()
	assert_object(seat.occupied_by).is_null()
	assert_object(hands.held).is_same(on_ray)


func test_hold_straps_with_progress_and_tap_unstraps() -> void:
	var crew: CrewMember = await _grabbed_setup()
	if crew == null:
		return
	_make_bus()
	var hands: CrewHands = _hands()
	var anchor: RestraintAnchor = _make_anchor(Vector3(0.0, 1.0, -1.5))
	var fractions: Array[float] = []
	hands.strap_progress.connect(func(fraction: float) -> void: fractions.append(fraction))
	Input.action_press("interact")
	await _wait_ticks(30)
	assert_bool(hands.is_strapping()).is_true()
	assert_bool(fractions.is_empty()).override_failure_message("strap_progress never emitted during the hold").is_false()
	assert_int(hands.held.restraint).is_equal(Package.Restraint.HELD)
	await _wait_ticks(80)
	Input.action_release("interact")
	await _wait_ticks(2)
	# strap_hold_seconds = 1.5 s = 90 ticks at 60 Hz; 110 held ticks strap.
	var package: Package = _last_package
	assert_int(package.restraint).is_equal(Package.Restraint.STRAPPED)
	assert_object(anchor.occupant).is_same(package)
	assert_object(hands.held).is_null()
	assert_float(fractions[fractions.size() - 1]).is_equal_approx(1.0, 0.001)
	# Empty hand now: a tap on the strapped package brings it back (D84).
	await _tap_interact()
	assert_object(hands.held).is_same(package)
	assert_int(package.restraint).is_equal(Package.Restraint.HELD)
	assert_bool(anchor.is_free()).is_true()


func test_release_before_the_hold_cancels_the_strap() -> void:
	var crew: CrewMember = await _grabbed_setup()
	if crew == null:
		return
	_make_bus()
	var hands: CrewHands = _hands()
	var anchor: RestraintAnchor = _make_anchor(Vector3(0.0, 1.0, -1.5))
	Input.action_press("interact")
	await _wait_ticks(10)
	assert_bool(hands.is_strapping()).is_true()
	Input.action_release("interact")
	await _wait_ticks(3)
	assert_bool(hands.is_strapping()).is_false()
	var package: Package = _last_package
	assert_object(hands.held).is_same(package)
	assert_int(package.restraint).is_equal(Package.Restraint.HELD)
	assert_bool(anchor.is_free()).is_true()


func test_click_with_free_pointer_recaptures_and_never_throws() -> void:
	var crew: CrewMember = await _grabbed_setup()
	if crew == null:
		return
	var hands: CrewHands = _hands()
	var package: Package = _last_package
	var input_node: Node = get_tree().get_first_node_in_group("crew_input")
	if input_node is not CrewInput:
		assert_bool(false).override_failure_message("no node in group 'crew_input'").is_true()
		return
	var input: CrewInput = input_node
	_send_escape_press()
	await get_tree().process_frame
	await _wait_ticks(2)
	assert_bool(input.is_pointer_captured()).is_false()
	# The dangerous order: the throw press lands while free, then the click
	# recaptures — the recapture must swallow the in-flight press (D83).
	Input.action_press("throw")
	_send_left_click_press()
	await get_tree().process_frame
	await _wait_ticks(2)
	Input.action_release("throw")
	assert_bool(input.is_pointer_captured()).is_true()
	assert_object(hands.held).is_same(package)
	assert_int(package.restraint).is_equal(Package.Restraint.HELD)
	# Captured now: a fresh throw press does throw, camera-forward at 6 m/s.
	# The release needs its own tick first: release+press inside the same tick
	# is invisible to the edge detector (the input test's measured rule).
	Input.action_release("throw")
	await get_tree().physics_frame
	Input.action_press("throw")
	await _wait_ticks(2)
	Input.action_release("throw")
	assert_object(hands.held).is_null()
	assert_int(package.restraint).is_equal(Package.Restraint.FREE)
	assert_float(package.linear_velocity.z).is_less(-3.0)


func test_drop_click_lands_at_the_hand_or_clear_floor_beside_the_feet() -> void:
	var crew: CrewMember = await _grabbed_setup()
	if crew == null:
		return
	var hands: CrewHands = _hands()
	var package: Package = _last_package
	var hand: Marker3D = _hand_anchor(crew)
	# No wall: the box fits at the hand point and is released right there.
	Input.action_press("drop")
	await _wait_ticks(2)
	Input.action_release("drop")
	assert_object(hands.held).is_null()
	assert_int(package.restraint).is_equal(Package.Restraint.FREE)
	assert_float(package.global_position.distance_to(hand.global_position)).is_less(0.3)
	# Re-grab, then a wall flush against the hand: the drop falls back to the
	# feet on the floor (D83).
	await _tap_interact()
	assert_object(hands.held).override_failure_message("the re-grab never took the dropped box").is_same(package)
	var wall: StaticBody3D = auto_free(StaticBody3D.new())
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(2.0, 2.0, 0.4)
	shape.shape = box
	wall.add_child(shape)
	wall.position = Vector3(0.0, 1.45, -0.9)
	add_child(wall)
	await get_tree().physics_frame
	Input.action_press("drop")
	await _wait_ticks(2)
	Input.action_release("drop")
	assert_object(hands.held).is_null()
	assert_int(package.restraint).is_equal(Package.Restraint.FREE)
	assert_float(package.global_position.y).is_less(0.6)
	var flat: Vector2 = Vector2(package.global_position.x, package.global_position.z)
	var crew_flat: Vector2 = Vector2(crew.global_position.x, crew.global_position.z)
	assert_float(flat.distance_to(crew_flat)).is_greater(0.5)


func test_held_package_inside_the_bus_at_speed_does_not_kick_it() -> void:
	var runner: GdUnitSceneRunner = scene_runner("res://scenes/playground.tscn")
	runner.scene()
	var bus_node: Node = get_tree().get_first_node_in_group("bus")
	if bus_node is not Bus:
		assert_bool(false).override_failure_message("no bus in group 'bus'").is_true()
		return
	var bus: Bus = bus_node
	# Face AWAY from the ramp before the first tick: the thresholds below are
	# absolute and need 120 flat ticks at 40 km/h (the authored spawn faces
	# the ramp and reaches 40 already climbing — the seat test's r4 note).
	bus.rotation.y = PI
	await _wait_ticks(120)
	var crew_node: Node = get_tree().get_first_node_in_group("crew")
	if crew_node is not CrewMember:
		assert_bool(false).override_failure_message("no crew in group 'crew'").is_true()
		return
	var crew: CrewMember = crew_node
	var hands: CrewHands = _hands()
	if hands == null:
		return
	# Board and grab PARKED (the seat tests' corridor pattern), so the
	# 120-tick measurement starts the exact tick the bus reaches 40 km/h.
	crew.global_position = bus.global_transform * Vector3(0.0, -0.55, 0.0)
	crew.aboard = true
	await _wait_ticks(45)
	assert_bool(crew.is_on_floor()).override_failure_message("the crew is not on the corridor floor").is_true()
	var package: Package = _make_package(bus.global_transform * Vector3(0.0, -0.4, 1.2))
	await _wait_ticks(15)
	# Aim the look AT the box so the ray choice cannot drift to another box.
	var eye_node: Node = crew.get_node_or_null("EyeCamera")
	if eye_node is not Camera3D:
		assert_bool(false).override_failure_message("no EyeCamera on the crew").is_true()
		return
	var eye: Camera3D = eye_node
	eye.rotation.x = -0.9
	await get_tree().physics_frame
	assert_bool(hands.try_grab()).override_failure_message("try_grab found no package aboard").is_true()
	assert_object(hands.held).is_same(package)
	# Round-4 configuration: look down, the held box against her torso — with
	# collision ON (the bug) this depenetrated the hull every tick.
	eye.rotation.x = -0.8
	var bus_input: Node = get_tree().get_first_node_in_group("bus_input")
	if bus_input != null:
		bus_input.set("enabled", false)
	bus.set_drive(1.0, 0.0, 0.0)
	var reached: bool = false
	for tick: int in range(900):
		await get_tree().physics_frame
		if bus.speed_mps() * 3.6 >= 40.0:
			reached = true
			break
	assert_bool(reached).override_failure_message("the bus never reached 40 km/h").is_true()
	bus.set_drive(0.0, 0.0, 0.0)
	var max_omega: float = 0.0
	var min_y: float = bus.global_position.y
	var max_y: float = min_y
	for tick: int in range(120):
		await get_tree().physics_frame
		max_omega = maxf(max_omega, bus.angular_velocity.length())
		min_y = minf(min_y, bus.global_position.y)
		max_y = maxf(max_y, bus.global_position.y)
	print("HELDRIDE max_omega=%.4f y_range=%.4f speed_kmh=%.1f" % [max_omega, max_y - min_y, bus.speed_mps() * 3.6])
	assert_float(max_omega).override_failure_message("the held package kicked the bus: max angular velocity").is_less(0.05)
	assert_float(max_y - min_y).override_failure_message("the held package lifted/sank the bus: y range").is_less(0.05)
	assert_object(hands.held).is_same(package)
	assert_int(package.restraint).is_equal(Package.Restraint.HELD)


## Ground + settled crew + enabled input + a package grabbed through an E
## tap: the shared prelude of the hands tests.
func _grabbed_setup() -> CrewMember:
	_make_ground()
	var crew: CrewMember = await _spawn_settled_crew(Vector3(0.0, 1.0, 0.0))
	if crew == null:
		return null
	await _spawn_input(true)
	_last_package = _make_package(Vector3(0.0, 0.2, -1.2))
	await _tap_interact()
	var hands: CrewHands = _hands()
	assert_object(hands.held).override_failure_message("the E tap never grabbed the package").is_same(_last_package)
	return crew


func _tap_interact() -> void:
	# A real tap: up one tick, then down one (the edge detector never sees a
	# press released inside the same tick).
	Input.action_release("interact")
	await get_tree().physics_frame
	Input.action_press("interact")
	await get_tree().physics_frame
	Input.action_release("interact")
	await get_tree().physics_frame


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


## The real D81 scene (0.4 m, layer 2, can_sleep=false for the damper).
func _make_package(pos: Vector3) -> Package:
	var packed: Resource = load(PACKAGE_SCENE)
	if packed is PackedScene:
		var scene: PackedScene = packed
		var package: Package = auto_free(scene.instantiate())
		package.position = pos
		add_child(package)
		return package
	assert_bool(false).override_failure_message("package.tscn did not load").is_true()
	return null


## Package.strap() reparents onto the group-"bus" node and refuses without
## one: a bare frozen Bus is enough (no shapes, no wheels, never moves).
func _make_bus() -> Bus:
	var bus: Bus = auto_free(Bus.new())
	bus.add_to_group("bus")
	bus.freeze = true
	add_child(bus)
	return bus


func _make_anchor(pos: Vector3) -> RestraintAnchor:
	var anchor: RestraintAnchor = auto_free(RestraintAnchor.new())
	# Scene-born anchors get the group from bus_interior.tscn.
	anchor.add_to_group("restraint_anchor")
	anchor.position = pos
	add_child(anchor)
	return anchor


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
	# _find_crew is deferred: give it its frames. Player mode runs captured:
	# the click tests need the real capture path.
	await _wait_ticks(2)
	input.set_mouse_captured(true)
	return input


func _hands() -> CrewHands:
	var node: Node = get_tree().get_first_node_in_group("crew_hands")
	if node is CrewHands:
		return node
	assert_bool(false).override_failure_message("no node in group 'crew_hands'").is_true()
	return null


func _hand_anchor(crew: CrewMember) -> Marker3D:
	var node: Node = crew.get_node_or_null("EyeCamera/HandAnchor")
	if node is Marker3D:
		return node
	assert_bool(false).override_failure_message("no HandAnchor under the eye camera").is_true()
	return null


func _send_escape_press() -> void:
	var key: InputEventKey = InputEventKey.new()
	key.keycode = KEY_ESCAPE
	key.pressed = true
	Input.parse_input_event(key)


func _send_left_click_press() -> void:
	var click: InputEventMouseButton = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	Input.parse_input_event(click)


func _wait_ticks(count: int) -> void:
	for i: int in range(count):
		await get_tree().physics_frame
