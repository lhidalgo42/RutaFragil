class_name NetAuthority
extends RefCounted


static func local_crew(tree: SceneTree) -> CrewMember:
	for node: Node in tree.get_nodes_in_group("crew"):
		if node is CrewMember and not node.is_queued_for_deletion():
			var member: CrewMember = node
			if is_local(member):
				return member
	return null


static func is_local(member: CrewMember) -> bool:
	if not is_instance_valid(member) or not member.is_inside_tree():
		return false
	# NetworkBackend.leave clears the peer; querying its unique ID would error.
	if not member.multiplayer.has_multiplayer_peer():
		return member.get_multiplayer_authority() == 1
	return member.is_multiplayer_authority()


static func crew_for_peer(tree: SceneTree, peer_id: int) -> CrewMember:
	for node: Node in tree.get_nodes_in_group("crew"):
		if node is CrewMember and not node.is_queued_for_deletion():
			var member: CrewMember = node
			if member.get_multiplayer_authority() == peer_id:
				return member
	return null


static func scoped_eye(member: CrewMember) -> Camera3D:
	if not is_instance_valid(member) or not member.is_inside_tree():
		return null
	for node: Node in member.get_tree().get_nodes_in_group("eye_camera"):
		if node is Camera3D and member.is_ancestor_of(node):
			return node
	return null
