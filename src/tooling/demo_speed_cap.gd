class_name DemoSpeedCap
extends Node

## Demo aid for the town route (D69): holds the placeholder bus at town speed.
## Lives in tooling, not in the vehicle: it only clamps the speed of the box the
## DemoDriver pushes around, so the lap shows the route instead of a 90 km/h
## slide through Requínoa's bends. Leo's bus keeps its own tuning untouched.

@export var bus: RigidBody3D
@export var limit_kmh: float = 50.0


func _physics_process(_delta: float) -> void:
	if bus == null:
		return
	var limit: float = limit_kmh / 3.6
	var v: Vector3 = bus.linear_velocity
	var flat: Vector3 = Vector3(v.x, 0.0, v.z)
	if flat.length() > limit:
		flat = flat.normalized() * limit
		bus.linear_velocity = Vector3(flat.x, v.y, flat.z)
