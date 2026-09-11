class_name DemoSteering
extends RefCounted

## Pure steering math behind DemoDriver (D49): no physics, no nodes, every
## function static so unit tests exercise it without a SceneTree.
## Sign convention (D49): steer > 0 turns left (positive yaw, Godot right
## hand); forward for the bus is -Z, so left is -X.

## Angle from full alignment where steer saturates to ±1 (45°).
const STEER_FULL_ANGLE_RAD: float = TAU / 8.0
## A target more than 60° off the nose is a turn the bus cannot take at
## speed (yaw-damped steering only turns tightly once slow), so brake while
## there is speed to shed. Below it the throttle fade is enough.
const BRAKE_TURN_ANGLE_RAD: float = PI / 3.0
## Below this speed there is nothing worth braking for, in m/s.
const BRAKE_MIN_SPEED_MPS: float = 0.5


static func steer_for(forward: Vector3, to_target: Vector3) -> float:
	var signed_angle: float = signed_angle_for(forward, to_target)
	return clampf(signed_angle / STEER_FULL_ANGLE_RAD, -1.0, 1.0)


## Signed angle in the XZ plane from forward to to_target, in [-PI, PI];
## positive when the target sits to the left of forward (D49).
static func signed_angle_for(forward: Vector3, to_target: Vector3) -> float:
	var f: Vector3 = Vector3(forward.x, 0.0, forward.z)
	var t: Vector3 = Vector3(to_target.x, 0.0, to_target.z)
	if f.length_squared() < 0.0001 or t.length_squared() < 0.0001:
		return 0.0
	f = f.normalized()
	t = t.normalized()
	var cross_y: float = f.z * t.x - f.x * t.z
	return atan2(cross_y, clampf(f.dot(t), -1.0, 1.0))


static func throttle_for(abs_angle_rad: float) -> float:
	var a: float = clampf(abs_angle_rad, 0.0, PI / 2.0)
	return lerpf(1.0, 0.3, a / (PI / 2.0))


static func brake_for(abs_angle_rad: float, speed_mps: float) -> float:
	if abs_angle_rad > BRAKE_TURN_ANGLE_RAD and speed_mps > BRAKE_MIN_SPEED_MPS:
		return 1.0
	return 0.0


static func has_reached(pos: Vector3, target: Vector3, radius_m: float) -> bool:
	var dx: float = target.x - pos.x
	var dz: float = target.z - pos.z
	return dx * dx + dz * dz <= radius_m * radius_m


static func next_index(index: int, count: int) -> int:
	if count <= 0:
		return 0
	return (index + 1) % count
