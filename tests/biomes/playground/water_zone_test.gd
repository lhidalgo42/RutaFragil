extends GdUnitTestSuite

## WaterZone (D50): only bodies in the "bus" group raise bus_entered; the raw
## body_entered signal proves the area detected the contact either way.


func test_bus_body_triggers_bus_entered() -> void:
	var zone: WaterZone = _make_zone()
	var emitter: Object = monitor_signals(zone)
	_drop_body(true)
	await assert_signal(emitter).wait_until(5000).is_emitted("bus_entered", any())


func test_plain_body_does_not_trigger_bus_entered() -> void:
	var zone: WaterZone = _make_zone()
	var emitter: Object = monitor_signals(zone)
	_drop_body(false)
	await assert_signal(emitter).wait_until(5000).is_emitted("body_entered", any())
	await assert_signal(emitter).wait_until(500).is_not_emitted("bus_entered", any())


func _make_zone() -> WaterZone:
	var zone: WaterZone = auto_free(WaterZone.new())
	var shape_node: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(10.0, 4.0, 10.0)
	shape_node.shape = box
	zone.add_child(shape_node)
	add_child(zone)
	zone.global_position = Vector3(0.0, 2.0, 0.0)
	return zone


func _drop_body(in_bus_group: bool) -> void:
	var body: RigidBody3D = auto_free(RigidBody3D.new())
	var shape_node: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(1.0, 1.0, 1.0)
	shape_node.shape = box
	body.add_child(shape_node)
	if in_bus_group:
		body.add_to_group("bus")
	add_child(body)
	body.global_position = Vector3(0.0, 6.0, 0.0)
