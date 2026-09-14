extends GdUnitTestSuite

## MouseLook pure-math contract (§9.2): sign convention, pitch clamp,
## unbounded-vs-cone yaw and linear sensitivity, with exact numbers.

const EPS: float = 0.0001


func test_yaw_decreases_when_mouse_moves_right() -> void:
	var result: Vector2 = MouseLook.next_yaw_pitch(0.3, 0.2, Vector2(100.0, 0.0), 0.001, -1.0, 1.5)
	assert_float(result.x).is_equal_approx(0.2, EPS)
	assert_float(result.y).is_equal_approx(0.2, EPS)


func test_pitch_increases_when_mouse_moves_up() -> void:
	var result: Vector2 = MouseLook.next_yaw_pitch(0.3, 0.2, Vector2(0.0, -50.0), 0.002, -1.0, 1.5)
	assert_float(result.x).is_equal_approx(0.3, EPS)
	assert_float(result.y).is_equal_approx(0.3, EPS)


func test_pitch_is_clamped_at_both_ends() -> void:
	var limit: float = 1.5708
	var top: Vector2 = MouseLook.next_yaw_pitch(0.0, 1.5, Vector2(0.0, -100.0), 0.001, -1.0, limit)
	assert_float(top.y).is_equal_approx(limit, EPS)
	var bottom: Vector2 = MouseLook.next_yaw_pitch(0.0, -1.5, Vector2(0.0, 100.0), 0.001, -1.0, limit)
	assert_float(bottom.y).is_equal_approx(-limit, EPS)


func test_unbounded_yaw_accumulates_past_pi_without_normalizing() -> void:
	# 3.0 - 7.0 = -4.0, already past -PI: a normalized result would come back
	# near +2.2832, so the exact accumulated value pins "no wrap to +-PI".
	var result: Vector2 = MouseLook.next_yaw_pitch(3.0, 0.0, Vector2(7000.0, 0.0), 0.001, -1.0, 1.5)
	assert_float(result.x).is_equal_approx(-4.0, EPS)


func test_yaw_cone_clamps_to_cabin_limits() -> void:
	var yaw_limit: float = deg_to_rad(120.0)
	var pitch_limit: float = deg_to_rad(45.0)
	var right: Vector2 = MouseLook.next_yaw_pitch(0.0, 0.0, Vector2(-100000.0, -100000.0), 0.0025, yaw_limit, pitch_limit)
	assert_float(right.x).is_equal_approx(yaw_limit, EPS)
	assert_float(right.y).is_equal_approx(pitch_limit, EPS)
	var left: Vector2 = MouseLook.next_yaw_pitch(0.0, 0.0, Vector2(100000.0, 100000.0), 0.0025, yaw_limit, pitch_limit)
	assert_float(left.x).is_equal_approx(-yaw_limit, EPS)
	assert_float(left.y).is_equal_approx(-pitch_limit, EPS)


func test_sensitivity_is_linear() -> void:
	var single: Vector2 = MouseLook.next_yaw_pitch(1.0, 0.5, Vector2(40.0, -30.0), 0.001, -1.0, 1.5)
	var double_sens: Vector2 = MouseLook.next_yaw_pitch(1.0, 0.5, Vector2(40.0, -30.0), 0.002, -1.0, 1.5)
	assert_float(single.x).is_equal_approx(0.96, EPS)
	assert_float(single.y).is_equal_approx(0.53, EPS)
	assert_float(double_sens.x).is_equal_approx(0.92, EPS)
	assert_float(double_sens.y).is_equal_approx(0.56, EPS)


func test_zero_delta_keeps_yaw_and_pitch() -> void:
	var result: Vector2 = MouseLook.next_yaw_pitch(2.3, -0.7, Vector2.ZERO, 0.0025, -1.0, 1.5)
	assert_float(result.x).is_equal_approx(2.3, EPS)
	assert_float(result.y).is_equal_approx(-0.7, EPS)
