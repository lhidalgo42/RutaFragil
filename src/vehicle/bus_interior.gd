class_name BusInterior
extends Node3D

## Bus interior greybox (D66, D67): own scene instanced as a direct child of
## the Bus RigidBody3D. The physics shapes are authored under the Shapes node
## for organization, but a CollisionShape3D only registers on a body as its
## DIRECT child (measured 2026-09-12: nested shapes never collide), so _ready
## re-parents them onto the RigidBody3D above us. Same rid as the chassis:
## the suspension rays exclude the interior for free and nothing pushes the
## chassis around. Meshes, positions and restraints stay under this node.
## No gameplay here: no walking, boarding or seats (that is T2.2/T2.3).
##
## THE OPEN REAR IS THE CARGO DOOR (D99, owner 2026-09-17). WallRearLeft and
## WallRearRight are 0.55 m wide at x = +/-0.975, leaving a 1.4 m by 1.9 m gap
## in the middle; a 0.4 m package passes through it easily. That is deliberate,
## NOT a greybox omission like the windshield of D89, so do not "fix" it with a
## sill, a pane or a ramp. Free cargo sliding out of the back while the bus
## accelerates is what the straps exist for: in the owner's 300 s session all
## four boxes left through it at floor level, the first after 5.4 s untouched.
## D103 supersedes D99: side and rear gaps now have animated, closable blockers
## owned by BusDoors. The open rear remains the cargo door.


## The ONE definition of "inside the hull" (interior bounds D67/D72):
## Seat's restore-point validation and Package's damper gate both call this;
## two copies of the limits would drift apart. Bus-local coordinates.
static func is_inside_local(local: Vector3) -> bool:
	return absf(local.x) <= 1.15 and local.z >= -3.8 and local.z <= 3.8 and local.y >= -0.65 and local.y <= 1.30


func _ready() -> void:
	_reparent_shapes.call_deferred()


func _reparent_shapes() -> void:
	var parent: Node = get_parent()
	if parent is not RigidBody3D:
		push_error("BusInterior must be a direct child of the Bus RigidBody3D")
		return
	var body: RigidBody3D = parent
	var shapes: Node = get_node_or_null("Shapes")
	if shapes == null:
		push_error("BusInterior: missing Shapes node")
		return
	# Deferred because add_child on an ancestor during the _ready cascade
	# fails with "Parent node is busy setting up children" and the shapes
	# would leak as stray orphans (measured 2026-09-12). Identity transforms
	# all the way up, so the local positions carry over unchanged.
	for shape: Node in shapes.get_children():
		if shape is CollisionShape3D:
			shapes.remove_child(shape)
			body.add_child(shape)
