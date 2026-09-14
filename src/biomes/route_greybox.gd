class_name RouteGreybox
extends Node3D

## Greybox route made of BiomeSegments, driven by the DemoDriver over a
## RouteCircuit. Same shape as Playground (demo_mode + demo_driver) so
## run_demo and the scene tests treat both alike. With spawn_bus_at_entry the
## bus is moved to the first segment's Entry marker (D65: real-avenue routes
## start wherever the data says). Grass strips get the bus to bend around.

## True hands the bus to the DemoDriver; false leaves it parked.
@export var demo_mode: bool = true
@export var demo_driver: DemoDriver
@export var spawn_bus_at_entry: bool = false


func _ready() -> void:
	if demo_driver == null:
		push_error("RouteGreybox: demo_driver is not assigned")
		return
	var bus: PlaceholderBus = demo_driver.bus
	if bus != null:
		if spawn_bus_at_entry:
			var segment: BiomeSegment = first_segment()
			if segment != null:
				bus.global_transform = segment.entry_transform()
				bus.linear_velocity = Vector3.ZERO
				bus.angular_velocity = Vector3.ZERO
		get_tree().call_group("grass", "set_follow", bus)
	demo_driver.enabled = demo_mode


func first_segment() -> BiomeSegment:
	var root: Node = get_node_or_null("Segments")
	if root == null:
		return null
	for child: Node in root.get_children():
		if child is BiomeSegment:
			var segment: BiomeSegment = child
			return segment
	return null
