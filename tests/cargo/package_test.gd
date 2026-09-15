extends GdUnitTestSuite

## Package (D81, ADR-003): the three restraint states, their preconditions
## and the D85 vertical damper. Physics is real where the measured rule needs
## it (packages are instanced from package.tscn and positioned BEFORE
## add_child); the damper math and the bus-point velocity are PURE statics.
## "One package in hand at a time" is CrewHands' watch, not Package's.

const PACKAGE_SCENE: String = "res://src/cargo/package.tscn"


func _spawn_package(at: Vector3) -> Package:
	var packed: Resource = load(PACKAGE_SCENE)
	assert_bool(packed is PackedScene).override_failure_message("package.tscn did not load").is_true()
	if not (packed is PackedScene):
		return null
	var scene: PackedScene = packed
	var node: Node = scene.instantiate()
	if not (node is Package):
		assert_bool(false).override_failure_message("package.tscn root must be a Package").is_true()
		return null
	var package: Package = node
	# Position BEFORE add_child — the measured rule.
	package.position = at
	add_child(package)
	return auto_free(package)


func _shape_of(package: Package) -> CollisionShape3D:
	for child: Node in package.get_children():
		if child is CollisionShape3D:
			return child
	return null


## A frozen Bus.new() with no shapes: a kinematic landmark for the group
## lookup and the inside-the-hull gate, with nothing to collide with.
func _add_bus_fixture() -> Bus:
	var bus: Bus = auto_free(Bus.new())
	add_child(bus)
	bus.add_to_group("bus")
	bus.freeze = true
	return bus


func _add_anchor(parent: Node, local: Vector3) -> RestraintAnchor:
	var anchor: RestraintAnchor = auto_free(RestraintAnchor.new())
	anchor.position = local
	parent.add_child(anchor)
	return anchor


func test_spawn_reads_mass_from_tuning() -> void:
	var package: Package = _spawn_package(Vector3(0.0, 5.0, 0.0))
	assert_float(package.mass).is_equal(GameConfig.tuning.package_mass_kg)
	assert_bool(package.restraint == Package.Restraint.FREE).is_true()
	assert_bool(package.freeze).is_false()
	assert_bool(package.continuous_cd).is_true()


func test_hold_only_from_free() -> void:
	var crew: CrewMember = auto_free(CrewMember.new())
	var package: Package = _spawn_package(Vector3(0.0, 5.0, 0.0))
	var shape: CollisionShape3D = _shape_of(package)
	assert_object(shape).is_not_null()
	assert_bool(package.hold(crew)).is_true()
	assert_bool(package.restraint == Package.Restraint.HELD).is_true()
	assert_object(package.held_by).is_same(crew)
	assert_bool(package.freeze).is_true()
	assert_bool(shape.disabled).is_true()
	# A second hold on a HELD package fails.
	assert_bool(package.hold(crew)).is_false()


func test_release_only_from_held() -> void:
	var package: Package = _spawn_package(Vector3(0.0, 5.0, 0.0))
	var before: Vector3 = package.global_position
	# release() on a FREE package is a no-op (and reports the bug).
	package.release(Transform3D(Basis.IDENTITY, Vector3(9.0, 9.0, 9.0)), Vector3.ONE)
	assert_bool(package.restraint == Package.Restraint.FREE).is_true()
	assert_vector(package.global_position).is_equal_approx(before, Vector3(0.001, 0.001, 0.001))


func test_release_runs_the_full_pair_in_order() -> void:
	var crew: CrewMember = auto_free(CrewMember.new())
	var package: Package = _spawn_package(Vector3(0.0, 5.0, 0.0))
	var shape: CollisionShape3D = _shape_of(package)
	assert_bool(package.hold(crew)).is_true()
	var at: Transform3D = Transform3D(Basis.IDENTITY, Vector3(2.0, 1.0, -3.0))
	var velocity: Vector3 = Vector3(1.0, 2.0, 3.0)
	package.release(at, velocity)
	# Place -> unfreeze -> velocity, all synchronous...
	assert_bool(package.restraint == Package.Restraint.FREE).is_true()
	assert_object(package.held_by).is_null()
	assert_bool(package.freeze).is_false()
	assert_vector(package.global_position).is_equal_approx(at.origin, Vector3(0.001, 0.001, 0.001))
	assert_vector(package.linear_velocity).is_equal_approx(velocity, Vector3(0.001, 0.001, 0.001))
	assert_vector(package.angular_velocity).is_equal_approx(Vector3.ZERO, Vector3(0.001, 0.001, 0.001))
	# ...collision comes back DEFERRED: no solver tick sees the box badly.
	assert_bool(shape.disabled).is_true()
	await get_tree().physics_frame
	assert_bool(shape.disabled).is_false()


func test_strap_requires_held_and_a_free_anchor() -> void:
	var bus: Bus = _add_bus_fixture()
	var anchor: RestraintAnchor = _add_anchor(bus, Vector3(0.5, 0.45, -0.6))
	var crew: CrewMember = auto_free(CrewMember.new())
	var package: Package = _spawn_package(Vector3(3.0, 1.0, 0.0))
	# Straight from FREE: rejected (never grabbed off the world into an anchor).
	assert_bool(package.strap(anchor)).is_false()
	assert_bool(package.hold(crew)).is_true()
	assert_bool(package.strap(anchor)).is_true()
	assert_bool(package.restraint == Package.Restraint.STRAPPED).is_true()
	# Reparented to the BUS at the anchor's bus-local pose, frozen, collision ON.
	assert_bool(package.get_parent() == bus).is_true()
	assert_vector(package.position).is_equal_approx(anchor.position, Vector3(0.001, 0.001, 0.001))
	assert_bool(package.freeze).is_true()
	assert_bool(_shape_of(package).disabled).is_false()
	assert_object(package.held_by).is_null()
	assert_bool(anchor.is_free()).is_false()
	assert_object(anchor.occupant).is_same(package)
	# One package per anchor: the second held package is rejected.
	var second: Package = _spawn_package(Vector3(4.0, 1.0, 0.0))
	assert_bool(second.hold(crew)).is_true()
	assert_bool(second.strap(anchor)).is_false()
	assert_bool(second.restraint == Package.Restraint.HELD).is_true()
	# And a STRAPPED package is never grabbed off the anchor.
	assert_bool(package.hold(crew)).is_false()


func test_unstrap_returns_to_held_and_frees_the_anchor() -> void:
	var bus: Bus = _add_bus_fixture()
	var anchor: RestraintAnchor = _add_anchor(bus, Vector3(0.5, 0.45, -0.6))
	var crew: CrewMember = auto_free(CrewMember.new())
	var package: Package = _spawn_package(Vector3(3.0, 1.0, 0.0))
	assert_bool(package.hold(crew)).is_true()
	assert_bool(package.strap(anchor)).is_true()
	package.unstrap()
	assert_bool(package.restraint == Package.Restraint.HELD).is_true()
	assert_object(package.strapped_to).is_null()
	assert_bool(anchor.is_free()).is_true()
	assert_object(anchor.occupant).is_null()
	# HELD means frozen kinematic with collision OFF, back in the world frame
	# (the bus's parent) so CrewHands drives the transform next tick.
	assert_bool(package.freeze).is_true()
	assert_bool(_shape_of(package).disabled).is_true()
	assert_bool(package.get_parent() == bus.get_parent()).is_true()
	# unstrap() on a HELD package is a no-op (and reports the bug).
	package.unstrap()
	assert_bool(package.restraint == Package.Restraint.HELD).is_true()


func test_restraint_changed_covers_every_transition() -> void:
	var bus: Bus = _add_bus_fixture()
	var anchor: RestraintAnchor = _add_anchor(bus, Vector3(0.5, 0.45, -0.6))
	var crew: CrewMember = auto_free(CrewMember.new())
	var package: Package = _spawn_package(Vector3(3.0, 1.0, 0.0))
	var log: Array = []
	package.restraint_changed.connect(func(from: Package.Restraint, to: Package.Restraint) -> void: log.append([int(from), int(to)]))
	assert_bool(package.hold(crew)).is_true()
	package.release(Transform3D(Basis.IDENTITY, Vector3(2.0, 1.0, -3.0)), Vector3.ZERO)
	assert_bool(package.hold(crew)).is_true()
	assert_bool(package.strap(anchor)).is_true()
	package.unstrap()
	# FREE=0 HELD=1 STRAPPED=2.
	assert_array(log).is_equal([[0, 1], [1, 0], [0, 1], [1, 2], [2, 1]])


func test_rigid_point_velocity_is_v_plus_w_cross_r() -> void:
	var got: Vector3 = Package.rigid_point_velocity(Vector3(1.0, 0.0, 0.0), Vector3(0.0, 2.0, 0.0), Vector3(0.0, 0.0, 3.0))
	# (1,0,0) + (0,2,0)x(0,0,3) = (1,0,0) + (6,0,0).
	assert_vector(got).is_equal_approx(Vector3(7.0, 0.0, 0.0), Vector3(0.001, 0.001, 0.001))


func test_vertical_damping_force_is_pure_vertical() -> void:
	# Horizontal relative motion is NOT damped: that sliding is the game.
	var horizontal: Vector3 = Package.vertical_damping_force(Vector3(3.0, 0.0, 0.0), Vector3.ZERO, Vector3.UP, 160.0)
	assert_vector(horizontal).is_equal_approx(Vector3.ZERO, Vector3(0.001, 0.001, 0.001))
	# Rising relative to the bus is opposed downward; sinking is FREE (the
	# r1.1 fix: the damper only pushes against upward relative motion).
	var rising: Vector3 = Package.vertical_damping_force(Vector3(0.0, 2.0, 0.0), Vector3.ZERO, Vector3.UP, 160.0)
	assert_vector(rising).is_equal_approx(Vector3(0.0, -320.0, 0.0), Vector3(0.001, 0.001, 0.001))
	var sinking: Vector3 = Package.vertical_damping_force(Vector3.ZERO, Vector3(0.0, 1.0, 0.0), Vector3.UP, 160.0)
	assert_vector(sinking).is_equal_approx(Vector3.ZERO, Vector3(0.001, 0.001, 0.001))


func test_a_free_box_falls_like_a_box() -> void:
	# r1.1 (review 01): the vertical damper opposed ALL vertical relative
	# motion, so a free 8 kg box reached terminal velocity m*g/k = 0.49 m/s —
	# the rack-top boxes were measured sinking at 0.48-0.49 m/s (and a hand
	# drop from 0.73 m took 1.5 s; free fall: 0.39 s). The damper exists to
	# stop bumps throwing cargo at the roof — that is UPWARD relative motion
	# only; the fall must stay free. This test measures the CONSEQUENCE: a
	# FREE box (spawned, no release grace) dropped 1.0 m over the hull floor
	# makes contact in < 36 ticks (0.6 s; free fall from 1 m: 0.45 s) and
	# never bounces above 0.1 m after. (The release() path keeps its 30-tick
	# grace by design — a hand drop is not damped mid-air anyway — so the
	# defect is demonstrated on the FREE state, the rack-top scenario the
	# reviewer measured.)
	var bus: Bus = _add_bus_fixture()
	var floor_body: StaticBody3D = auto_free(StaticBody3D.new())
	var floor_shape: CollisionShape3D = CollisionShape3D.new()
	var floor_box: BoxShape3D = BoxShape3D.new()
	floor_box.size = Vector3(4.0, 0.2, 4.0)
	floor_shape.shape = floor_box
	floor_body.add_child(floor_shape)
	add_child(floor_body)
	floor_body.global_position = Vector3(0.0, -0.7, 0.0)
	# Spawned FREE 1.0 m over the floor top (-0.6 + 0.2 + 1.0 = 0.6).
	var package: Package = _spawn_package(Vector3(0.0, 0.6, 0.0))
	var contact_tick: int = -1
	var max_y_after: float = -99.0
	for i: int in range(150):
		await get_tree().physics_frame
		if contact_tick < 0 and package.get_contact_count() > 0:
			contact_tick = i
		if contact_tick >= 0:
			max_y_after = maxf(max_y_after, package.global_position.y)
	print("DROP contact_tick=%d (<36 required) max_y_after=%.3f (floor rest -0.414, bounce < 0.1)" % [contact_tick, max_y_after])
	assert_int(contact_tick).override_failure_message("the box never touched the floor in 150 ticks").is_less(36)
	assert_float(max_y_after).override_failure_message("the box bounced above 0.1 m after landing").is_less(-0.314)


func test_damper_brakes_vertical_motion_inside_the_hull() -> void:
	var bus: Bus = _add_bus_fixture()
	var package: Package = _spawn_package(Vector3.ZERO)
	# Spawned FREE (never released): no grace, the damper is live on tick one.
	package.linear_velocity = Vector3(0.0, 3.0, 0.0)
	for i: int in range(30):
		await get_tree().physics_frame
	# 30 ticks = 0.5 s. The rise is eaten in ~3 ticks (v_y <= 0.2), and after
	# that the fall is FREE (r1.1): gravity alone reads 3 - 9.8*0.5 = -1.9
	# m/s — not the old damper/gravity equilibrium of -0.49 m/s.
	assert_float(package.linear_velocity.y).override_failure_message("the rise was not eaten").is_less(0.2)
	assert_float(package.linear_velocity.y).override_failure_message("the fall is not free (old 0.49 m/s equilibrium still there)").is_less(-1.5)
	assert_bool(bus.freeze).is_true()


func test_no_bus_means_no_damper() -> void:
	var package: Package = _spawn_package(Vector3(0.0, 5.0, 0.0))
	package.linear_velocity = Vector3(0.0, 3.0, 0.0)
	for i: int in range(30):
		await get_tree().physics_frame
	# No node in group "bus": pure gravity, 3 - 9.8*0.5 = -1.9 m/s.
	assert_float(package.linear_velocity.y).is_less(-1.5)
	assert_float(package.linear_velocity.y).is_greater(-2.3)
