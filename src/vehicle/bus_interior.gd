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
