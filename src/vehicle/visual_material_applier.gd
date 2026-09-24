class_name VisualMaterialApplier
extends RefCounted

## Applies one authored Godot material to every MeshInstance3D below a GLB root.
## GLBs carry UVs and a placeholder material but no image; external .tres
## materials keep each texture in assets/textures/ as §10.1.5 requires.

static func apply(root: Node, material: Material) -> int:
	if root == null or material == null:
		return 0
	var changed: int = 0
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is MeshInstance3D:
			var mesh_node: MeshInstance3D = node
			mesh_node.material_override = material
			changed += 1
		for child: Node in node.get_children():
			stack.append(child)
	return changed


static func carries_collision(root: Node) -> bool:
	if root == null:
		return false
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node != root and (node is CollisionObject3D or node is CollisionShape3D):
			return true
		for child: Node in node.get_children():
			stack.append(child)
	return false
