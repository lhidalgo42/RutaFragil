extends GdUnitTestSuite

## DoorTransit (D75): crossing the door plane boards the crew onto the bus
## (reparented, transform kept), and crossing back exits to the world keeping
## the velocity. The position is always fixed BEFORE the reparent.


func test_crossing_the_door_plane_boards_and_exits() -> void:
	_make_ground()
	var bus: Bus = await _spawn_bus(Vector3(0.0, 1.6, 0.0))
	if bus == null:
		return
	await _wait_ticks(60)
	var crew: CrewMember = await _spawn_crew(Vector3(0.0, 1.0, 0.0))
	if crew == null:
		return
	var transit: DoorTransit = auto_free(DoorTransit.new())
	add_child(transit)
	await get_tree().physics_frame
	await get_tree().physics_frame
	# Put the crew INSIDE the doorway, inside the interior (local x < 1.05).
	crew.global_position = bus.global_transform * Vector3(0.0, 0.0, -2.75)
	await _wait_ticks(10)
	assert_bool(crew.aboard).is_true()
	# The crew rides in the world frame (D74 measured): it is NOT reparented
	# (the reparenting double-counted the platform carry; see the test of the
	# ride in crew_ride_test.gd and the note in door_transit.gd).
	assert_bool(crew.get_parent() != bus).is_true()
	# And back out through the door (local x > 1.30).
	crew.global_position = bus.global_transform * Vector3(1.5, 0.0, -2.75)
	await _wait_ticks(10)
	assert_bool(crew.aboard).is_false()


func _make_ground() -> StaticBody3D:
	var ground: StaticBody3D = auto_free(StaticBody3D.new())
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(200.0, 1.0, 200.0)
	shape.shape = box
	ground.add_child(shape)
	add_child(ground)
	ground.global_position = Vector3(0.0, -0.5, 0.0)
	return ground


func _spawn_crew(pos: Vector3) -> CrewMember:
	var packed: Resource = load("res://src/crew/crew_member.tscn")
	if packed is PackedScene:
		var scene: PackedScene = packed
		var crew: CrewMember = auto_free(scene.instantiate())
		crew.position = pos
		add_child(crew)
		return crew
	return null


func _spawn_bus(pos: Vector3) -> Bus:
	var runner: GdUnitSceneRunner = scene_runner("res://src/vehicle/bus.tscn")
	var node: Node = runner.scene()
	if node is Bus:
		var bus: Bus = node
		bus.global_position = pos
		return bus
	return null


func _wait_ticks(count: int) -> void:
	for i: int in range(count):
		await get_tree().physics_frame
