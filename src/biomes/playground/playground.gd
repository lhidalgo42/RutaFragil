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
## demo_mode=true hands the bus to the DemoDriver (run_demo forces this).
## demo_mode=false (the authored default since M1-T1.1) hands it to the
## owner through BusInput: F5 is the driving gate.
@export var demo_mode: bool = false
@export var demo_driver: DemoDriver
@export var bus_input: BusInput
@export var network_role: String = "single"
## Spawn the four greybox packages at load (T2.3). Skipped in demo_mode so
## run_demo's regression numbers stay intact; tests that spawn their own
## cargo can also set this false after load (the spawn is deferred).
@export var cargo_spawn: bool = true


func _ready() -> void:
	if network_role == "client":
		demo_mode = false
		_freeze_bus_for_client()
	if demo_driver == null:
		push_error("Playground: demo_driver is not assigned")
		return
	demo_driver.enabled = demo_mode
	if bus_input == null:
		push_error("Playground: bus_input is not assigned")
		return
	# Since M2-T2.2 the owner's F5 is ON FOOT: walk to the door, board, sit at
	# the wheel (E), drive. The Seat (D76) enables bus_input when seated.
	bus_input.enabled = false
	var crew_input: Node = get_node_or_null("CrewInput")
	if crew_input != null:
		crew_input.set("enabled", not demo_mode and network_role != "client")
	# The arbiter owns the one active camera (M2-T2.2 r3): the demo and the
	# network client watch the bus; the owner walks in on her own eyes.
	var player_mode: bool = not demo_mode and network_role != "client"
	if player_mode:
		CameraArbiter.apply(get_tree(), CameraArbiter.Mode.ON_FOOT)
	else:
		CameraArbiter.apply(get_tree(), CameraArbiter.Mode.DEMO)
	_set_mouse_captured(crew_input, player_mode)
	if cargo_spawn and not demo_mode:
		_spawn_cargo.call_deferred()


func _process(_delta: float) -> void:
	# F1 hands the bus to the DemoDriver and back at runtime (T1.1 r1.2, D71):
	# F5 stays the owner's seat and the demo needs no console. Headless
	# delivers no InputEvent, so this is inert in tests and tools.
	if Input.is_action_just_pressed("toggle_demo"):
		set_demo_mode(not demo_mode)


## The demo toggle as a callable (the test drives it without input).
## Input ownership follows the CREW state, not the demo flag — the F1
## wrinkle (T2.2 r3): leaving the demo set bus_input.enabled = true even
## with the crew on foot, and W throttled the parked bus while walking.
func set_demo_mode(on: bool) -> void:
	demo_mode = on
	if demo_driver != null:
		demo_driver.enabled = demo_mode
	if bus_input != null:
		bus_input.enabled = _crew_seated() and not demo_mode
	# The camera follows the mode change, and the cursor with it: the demo
	# is watched with a free mouse, playing captures it again.
	if demo_mode:
		CameraArbiter.apply(get_tree(), CameraArbiter.Mode.DEMO)
		_set_mouse_captured(get_node_or_null("CrewInput"), false)
	else:
		CameraArbiter.apply(get_tree(), _crew_camera_mode())
		_set_mouse_captured(get_node_or_null("CrewInput"), true)


## Whether the crew member is seated at the wheel right now.
func _crew_seated() -> bool:
	var crew_node: Node = get_tree().get_first_node_in_group("crew")
	if crew_node is CrewMember:
		var member: CrewMember = crew_node
		return member.seated
	return false


## The camera the crew returns to when the demo hands control back: the
## seat's bus view if she is seated, her own eyes otherwise.
func _crew_camera_mode() -> CameraArbiter.Mode:
	var crew_node: Node = get_tree().get_first_node_in_group("crew")
	if crew_node is CrewMember:
		var member: CrewMember = crew_node
		if member.seated:
			return CameraArbiter.Mode.SEATED
	return CameraArbiter.Mode.ON_FOOT


## CrewInput owns the capture flag (the mouse wiring is another agent's);
## the playground only says when capture is wanted.
func _set_mouse_captured(crew_input: Node, captured: bool) -> void:
	if crew_input is CrewInput:
		var input: CrewInput = crew_input
		input.set_mouse_captured(captured)


## The four greybox packages of T2.3: two resting on the rack tops, two on
## the aisle floor, positioned BEFORE add_child (the measured rule). The
## scene stays at 60 authored nodes (R8): the Cargo node and its packages
## are runtime instances, not authored ones.
func _spawn_cargo() -> void:
	# Re-checked at fire time: deferred, so demo_mode set right after load
	# (demo, run_demo) and tests setting cargo_spawn=false both skip it.
	if not cargo_spawn or demo_mode:
		return
	var packed: Resource = load("res://src/cargo/package.tscn")
	if not (packed is PackedScene):
		push_error("Playground: package.tscn did not load")
		return
	var scene: PackedScene = packed
	var bus_node: Node = get_tree().get_first_node_in_group("bus")
	if not (bus_node is RigidBody3D):
		push_error("Playground: no bus for cargo spawn")
		return
	var bus: RigidBody3D = bus_node
	var cargo_node: Node3D = Node3D.new()
	cargo_node.name = "Cargo"
	add_child(cargo_node)
	var local_points: Array[Vector3] = [
		Vector3(-0.875, 1.0, -1.5),
		Vector3(0.875, 1.0, 1.5),
		Vector3(-0.4, -0.4, 0.5),
		Vector3(0.4, -0.4, 2.5),
	]
	for point: Vector3 in local_points:
		var package: RigidBody3D = scene.instantiate()
		package.position = bus.global_transform * point
		cargo_node.add_child(package)


func _freeze_bus_for_client() -> void:
	# By group, never by node name (D59).
	var bus_node: Node = get_tree().get_first_node_in_group("bus")
	if bus_node is RigidBody3D:
		var rigid: RigidBody3D = bus_node
		rigid.freeze = true
