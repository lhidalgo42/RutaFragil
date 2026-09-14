class_name CameraArbiter
extends RefCounted

## THE single site that decides the active camera (M2-T2.2 round 3, approval
## addition 4): exactly one Camera3D is `current` at any moment, and which one
## follows the crew's state. Every camera switch in the game goes through
## apply() / toggle_bus_view() — nobody else writes camera logic.
## Cameras are found by GROUP, never by node path (D59 style):
##   "eye_camera"   — the crew member's first-person camera (on foot).
##   "cabin_camera" — the driver's first-person camera (seated, preferred).
##   "chase_camera" — third-person camera following the bus (demo, or the
##                    driver's alternate view via toggle_camera).

enum Mode { ON_FOOT, SEATED, DEMO }

## The driver's preferred bus camera while seated (true = cabin, false =
## chase); toggle_camera flips it. Tests: reset to true in before_test.
static var bus_view_cabin: bool = true


const GROUP_EYE: String = "eye_camera"
const GROUP_CABIN: String = "cabin_camera"
const GROUP_CHASE: String = "chase_camera"


## Applies the one active camera for the given state: eye on foot, cabin or
## chase while seated (bus_view_cabin), chase in the demo. A missing target
## camera is an error, not a crash: unit tests mount only the cameras they
## assert on. The other two cameras are switched off explicitly even though
## the engine would, so a camera that missed its group never stays live.
static func apply(tree: SceneTree, mode: Mode) -> void:
	var target_group: String = GROUP_EYE
	match mode:
		Mode.ON_FOOT:
			target_group = GROUP_EYE
		Mode.SEATED:
			target_group = GROUP_CABIN if bus_view_cabin else GROUP_CHASE
		Mode.DEMO:
			target_group = GROUP_CHASE
	var target_node: Node = tree.get_first_node_in_group(target_group)
	if not (target_node is Camera3D):
		push_error("CameraArbiter: no Camera3D in group '%s'" % target_group)
		return
	var target: Camera3D = target_node
	target.current = true
	for group: String in [GROUP_EYE, GROUP_CABIN, GROUP_CHASE]:
		if group == target_group:
			continue
		var node: Node = tree.get_first_node_in_group(group)
		if node is Camera3D:
			var cam: Camera3D = node
			cam.current = false


## Flips the seated-camera preference and reapplies it. Callers invoke it
## only while the crew is seated (BusInput's toggle_camera), so reapplying
## SEATED is the whole contract.
static func toggle_bus_view(tree: SceneTree) -> void:
	bus_view_cabin = not bus_view_cabin
	apply(tree, Mode.SEATED)
