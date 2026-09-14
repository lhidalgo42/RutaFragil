class_name MouseLook
extends RefCounted

## Pure mouse-look math (§9.2), testable without a window or input events
## (the events coalesce and their values are environment-dependent — the
## wiring test only asserts that yaw CHANGED; exactness lives here).
##
## Callers MUST pass InputEventMouseMotion.screen_relative, NEVER .relative:
## with window/stretch/mode="canvas_items" the engine multiplies .relative by
## the stretch factor (measured by the reviewer: a (10, -4) physical move
## arrives as (180, -72)), so .relative changes the sensitivity when the
## window is resized. screen_relative reaches the node intact.
## Signs (pinned by the pure tests): mouse right (delta.x > 0) turns right
## (yaw decreases); mouse up (delta.y < 0) looks up (pitch increases).


## One mouse step -> new Vector2(yaw, pitch) in radians, clamped.
## yaw_limit_rad <= 0.0 means unbounded yaw (on foot); pitch is always
## clamped to +-pitch_limit_rad. Sensitivity is radians per pixel
## (TuningTable.player_mouse_sensitivity). FASE-0 skeleton.
static func next_yaw_pitch(_current_yaw: float, _current_pitch: float, _delta_px: Vector2, _sens_rad_per_px: float, _yaw_limit_rad: float, _pitch_limit_rad: float) -> Vector2:
	return Vector2.ZERO
