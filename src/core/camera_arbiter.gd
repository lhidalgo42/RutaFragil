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


## Applies the one active camera for the given state. FASE-0 skeleton; the
## implementation lands with the arbitration agent.
static func apply(_tree: SceneTree, _mode: Mode) -> void:
	pass


## Flips the seated-camera preference and reapplies it. FASE-0 skeleton.
static func toggle_bus_view(_tree: SceneTree) -> void:
	pass
