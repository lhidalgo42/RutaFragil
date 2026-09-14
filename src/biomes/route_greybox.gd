class_name RouteGreybox
extends Node3D

## Greybox route made of BiomeSegments, driven by the DemoDriver over a
## RouteCircuit. Same shape as Playground (demo_mode + demo_driver) so
## run_demo and the scene tests treat both alike.

## True hands the bus to the DemoDriver; false leaves it parked.
@export var demo_mode: bool = true
@export var demo_driver: DemoDriver


func _ready() -> void:
	if demo_driver == null:
		push_error("RouteGreybox: demo_driver is not assigned")
		return
	demo_driver.enabled = demo_mode
