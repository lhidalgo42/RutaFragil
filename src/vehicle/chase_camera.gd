class_name ChaseCamera
extends Camera3D

## Exterior follow camera (ADR-004): sits behind the target's forward axis
## flattened onto XZ, at fixed distance and height, smoothing exponentially
## and always aiming at the target.

@export var target: Node3D
@export var distance_m: float = 14.0
@export var height_m: float = 5.0
@export var smoothing: float = 4.0


func _process(delta: float) -> void:
	if target == null:
		return
	var forward: Vector3 = -target.global_basis.z
	var flat: Vector3 = Vector3(forward.x, 0.0, forward.z)
	if flat.length_squared() < 0.0001:
		flat = Vector3(0.0, 0.0, -1.0)
	flat = flat.normalized()
	var desired: Vector3 = target.global_position - flat * distance_m + Vector3.UP * height_m
	var weight: float = clampf(1.0 - exp(-smoothing * delta), 0.0, 1.0)
	global_position = global_position.lerp(desired, weight)
	look_at(target.global_position, Vector3.UP)
