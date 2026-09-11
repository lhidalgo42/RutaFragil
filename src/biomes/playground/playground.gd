class_name Playground
extends Node3D

## Greybox all-in-one test scene (D50, plan M0-T0.3 step 7): flat ground, a
## ramp the circuit crosses, a bump field and a water zone the lap drives
## through. With demo_mode the DemoDriver takes the bus around the circuit
## with no human input (D51); F5 and the headless run_demo tool both use it.

## True hands the bus to the DemoDriver; false leaves it parked.
@export var demo_mode: bool = true
@export var demo_driver: DemoDriver


func _ready() -> void:
	if demo_driver == null:
		push_error("Playground: demo_driver is not assigned")
		return
	demo_driver.enabled = demo_mode
