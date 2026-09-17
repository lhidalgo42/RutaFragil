extends CrewMember

## Experimental movement only; the production CrewMember is unchanged.
var explicit_carry: bool = false
var down_press: float = -0.5
var bus_point_velocity: Vector3 = Vector3.ZERO


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= project_gravity() * delta
	elif velocity.y > down_press:
		velocity.y = down_press
	var carry: Vector3 = bus_point_velocity if explicit_carry else Vector3.ZERO
	velocity += carry
	move_and_slide()
	velocity -= carry
