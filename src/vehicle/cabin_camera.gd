class_name CabinCamera
extends Camera3D

## First-person cabin camera (D63, ADR-004): child of the bus at the driver's
## seat, looking forward. It holds no logic; BusInput toggles between this
## camera and the exterior ChaseCamera. Group "cabin_camera" so tools and the
## input node find it without depending on the node name (same rule as D59).


func _ready() -> void:
	add_to_group("cabin_camera")
