class_name Playground
extends Node3D

## Greybox all-in-one test scene (D50, plan M0-T0.3 step 7): flat ground, a
## ramp the circuit crosses, a bump field and a water zone the lap drives
## through. With demo_mode the DemoDriver takes the bus around the circuit
## with no human input (D51); F5 and the headless run_demo tool both use it.
##
## network_role (D55): "single" is the everyday scene (F5, run_demo, unit
## tests — nothing changes). "host" behaves like "single" and additionally
## owns the replicated bus. "client" disables the demo and freezes the bus so
## local physics never fights the host's MultiplayerSynchronizer.

## True hands the bus to the DemoDriver; false leaves it parked.
@export var demo_mode: bool = true
@export var demo_driver: DemoDriver
@export var network_role: String = "single"


func _ready() -> void:
	if network_role == "client":
		demo_mode = false
		_freeze_bus_for_client()
	if demo_driver == null:
		push_error("Playground: demo_driver is not assigned")
		return
	demo_driver.enabled = demo_mode


func _freeze_bus_for_client() -> void:
	var bus_node: Node = get_node_or_null("PlaceholderBus")
	if bus_node is RigidBody3D:
		var rigid: RigidBody3D = bus_node
		rigid.freeze = true
