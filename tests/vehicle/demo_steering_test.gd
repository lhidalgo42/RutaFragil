extends GdUnitTestSuite

## DemoSteering is pure math (D49): no SceneTree needed. Sign convention:
## steer > 0 means the target sits to the LEFT of forward; the bus faces -Z,
## so left is -X.

const FORWARD: Vector3 = Vector3(0.0, 0.0, -1.0)


func test_steer_straight_ahead_is_zero() -> void:
	assert_float(DemoSteering.steer_for(FORWARD, Vector3(0.0, 0.0, -10.0))).is_equal_approx(0.0, 0.0001)


func test_steer_left_is_positive_under_one() -> void:
	# 30 degrees to the left of forward.
	var steer: float = DemoSteering.steer_for(FORWARD, Vector3(-0.5, 0.0, -0.866))
	assert_float(steer).is_greater(0.0)
	assert_float(steer).is_less(1.0)
	assert_float(steer).is_equal_approx(30.0 / 45.0, 0.02)


func test_steer_right_is_negative() -> void:
	var steer: float = DemoSteering.steer_for(FORWARD, Vector3(0.5, 0.0, -0.866))
	assert_float(steer).is_less(0.0)
	assert_float(steer).is_equal_approx(-30.0 / 45.0, 0.02)


func test_steer_90_left_saturates() -> void:
	assert_float(DemoSteering.steer_for(FORWARD, Vector3(-1.0, 0.0, 0.0))).is_equal(1.0)


func test_steer_90_right_saturates() -> void:
	assert_float(DemoSteering.steer_for(FORWARD, Vector3(1.0, 0.0, 0.0))).is_equal(-1.0)


func test_target_behind_saturates_throttles_low_and_brakes() -> void:
	var steer: float = DemoSteering.steer_for(FORWARD, Vector3(0.0, 0.0, 10.0))
	assert_float(absf(steer)).is_equal(1.0)
	var abs_angle: float = absf(DemoSteering.signed_angle_for(FORWARD, Vector3(0.0, 0.0, 10.0)))
	assert_float(abs_angle).is_equal_approx(PI, 0.0001)
	assert_float(DemoSteering.throttle_for(abs_angle)).is_equal_approx(0.3, 0.0001)
	assert_float(DemoSteering.brake_for(abs_angle, 8.0)).is_equal(1.0)


func test_throttle_fades_from_full_to_minimum() -> void:
	assert_float(DemoSteering.throttle_for(0.0)).is_equal(1.0)
	assert_float(DemoSteering.throttle_for(PI / 4.0)).is_equal_approx(0.65, 0.0001)
	assert_float(DemoSteering.throttle_for(PI / 2.0)).is_equal_approx(0.3, 0.0001)
	assert_float(DemoSteering.throttle_for(PI)).is_equal_approx(0.3, 0.0001)


func test_brake_only_when_turn_is_sharp_and_moving() -> void:
	assert_float(DemoSteering.brake_for(0.0, 8.0)).is_equal(0.0)
	# 45 degrees still turns under throttle fade alone; 90 degrees brakes.
	assert_float(DemoSteering.brake_for(PI / 4.0, 8.0)).is_equal(0.0)
	assert_float(DemoSteering.brake_for(PI / 2.0, 8.0)).is_equal(1.0)
	assert_float(DemoSteering.brake_for(PI, 0.0)).is_equal(0.0)
	assert_float(DemoSteering.brake_for(PI, 8.0)).is_equal(1.0)


func test_has_reached_inside_outside_border_and_ignores_height() -> void:
	var target: Vector3 = Vector3(0.0, 0.0, 0.0)
	assert_bool(DemoSteering.has_reached(Vector3(3.0, 0.0, 0.0), target, 4.0)).is_true()
	assert_bool(DemoSteering.has_reached(Vector3(5.0, 0.0, 0.0), target, 4.0)).is_false()
	# Border counts: exactly on the radius.
	assert_bool(DemoSteering.has_reached(Vector3(4.0, 0.0, 0.0), target, 4.0)).is_true()
	# Height never counts.
	assert_bool(DemoSteering.has_reached(Vector3(3.0, 50.0, 0.0), target, 4.0)).is_true()


func test_next_index_wraps() -> void:
	assert_int(DemoSteering.next_index(0, 3)).is_equal(1)
	assert_int(DemoSteering.next_index(2, 3)).is_equal(0)
	assert_int(DemoSteering.next_index(0, 1)).is_equal(0)
	assert_int(DemoSteering.next_index(0, 0)).is_equal(0)
