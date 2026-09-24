class_name BusExteriorVisual
extends Node3D

## Visual-only wheels and doors: reads the Bus suspension, NetBusSync snapshots
## and BusDoors progress; never applies force, writes physics or owns door state.
## Expected node shape per wheel: WheelFL/SteerPivot/SpinPivot/(visual GLB).
## Door pivots come from the GLB: Model/SideDoorPivot, Model/RearDoor{Left,Right}Pivot.

const WHEEL_NAMES: Array[String] = ["WheelFL", "WheelFR", "WheelRL", "WheelRR"]
const SIDE_POP_M: float = 0.035
const SIDE_SLIDE_M: float = 0.95
const REAR_OPEN_DEG: float = 132.0
## Share of the side travel spent popping outward before the slide starts.
const SIDE_POP_SHARE: float = 0.2

@export var exterior_material: Material
@export var wheel_material: Material

var _bus: Bus = null
var _spin: Dictionary = {}
var _side_pivot: Node3D = null
var _rear_left_pivot: Node3D = null
var _rear_right_pivot: Node3D = null
var _side_closed: Vector3 = Vector3.ZERO


func _ready() -> void:
	process_physics_priority = 100
	var parent: Node = get_parent()
	if parent is Bus:
		_bus = parent
	for wheel_name: String in WHEEL_NAMES:
		_spin[wheel_name] = 0.0
	_apply_materials()
	_side_pivot = get_node_or_null("Model/SideDoorPivot") as Node3D
	_rear_left_pivot = get_node_or_null("Model/RearDoorLeftPivot") as Node3D
	_rear_right_pivot = get_node_or_null("Model/RearDoorRightPivot") as Node3D
	if _side_pivot != null:
		_side_closed = _side_pivot.position
	update_doors()


## Side leaf offset from its closed pivot for progress t (0 closed, 1 open):
## pops outward (+x) first, then slides rearward (+z).
static func side_pose(t: float) -> Vector3:
	var clamped: float = clampf(t, 0.0, 1.0)
	var pop: float = clampf(clamped / SIDE_POP_SHARE, 0.0, 1.0)
	var slide: float = clampf((clamped - SIDE_POP_SHARE) / (1.0 - SIDE_POP_SHARE), 0.0, 1.0)
	return Vector3(SIDE_POP_M * pop, 0.0, SIDE_SLIDE_M * slide)


## Rear leaf yaw in degrees for progress t; side -1 = left leaf, +1 = right leaf.
static func rear_yaw(t: float, side: int) -> float:
	return signf(float(side)) * REAR_OPEN_DEG * clampf(t, 0.0, 1.0)


func update_doors() -> void:
	var side_t: float = _door_progress(&"side")
	var rear_t: float = _door_progress(&"rear")
	if _side_pivot != null:
		_side_pivot.position = _side_closed + side_pose(side_t)
	if _rear_left_pivot != null:
		_rear_left_pivot.rotation.y = deg_to_rad(rear_yaw(rear_t, -1))
	if _rear_right_pivot != null:
		_rear_right_pivot.rotation.y = deg_to_rad(rear_yaw(rear_t, 1))


func _door_progress(door_id: StringName) -> float:
	var doors: Node = _bus.get_node_or_null("BusDoors") if _bus != null else null
	if doors == null or not doors.has_method("progress"):
		return 1.0
	return float(doors.call("progress", door_id))


func _apply_materials() -> void:
	var model: Node = get_node_or_null("Model")
	if model != null and VisualMaterialApplier.apply(model, exterior_material) == 0:
		push_error("BusExteriorVisual: exterior model has no MeshInstance3D")
	for wheel_name: String in WHEEL_NAMES:
		var wheel: Node = get_node_or_null(wheel_name)
		if wheel != null:
			VisualMaterialApplier.apply(wheel, wheel_material)
	if VisualMaterialApplier.carries_collision(self):
		push_error("BusExteriorVisual: visual GLBs must not carry collision")


static func spin_step(longitudinal_speed_mps: float, radius_m: float, delta: float) -> float:
	if radius_m <= 0.0 or delta <= 0.0:
		return 0.0
	return -longitudinal_speed_mps / radius_m * delta


static func wheel_steer_deg(marker_local: Vector3, front_steer_deg: float) -> float:
	return front_steer_deg if marker_local.z < 0.0 else 0.0


func _physics_process(delta: float) -> void:
	update_visuals(delta)


func update_visuals(delta: float) -> void:
	if _bus == null:
		return
	update_doors()
	var sync: NetBusSync = _sync_for(_bus)
	var steer_input: float = sync.replicated_steer_input() \
		if sync != null and sync.received_count > 0 else _bus.drive_steer
	var linear: Vector3 = sync.replicated_linear_velocity() \
		if sync != null and sync.received_count > 0 else _bus.linear_velocity
	var speed: float = absf(linear.dot(_bus.forward()))
	var front_steer: float = _bus.visual_steer_angle_deg(speed, steer_input)
	var radius: float = _bus.wheel_radius_m()
	for wheel_name: String in WHEEL_NAMES:
		var marker_node: Node = _bus.get_node_or_null(wheel_name)
		var wheel_node: Node = get_node_or_null(wheel_name)
		if not (marker_node is Marker3D) or not (wheel_node is Node3D):
			continue
		var marker: Marker3D = marker_node
		var wheel: Node3D = wheel_node
		wheel.position = _bus.visual_wheel_center(wheel_name)
		var steer_node: Node = wheel.get_node_or_null("SteerPivot")
		if steer_node is Node3D:
			var steer_pivot: Node3D = steer_node
			steer_pivot.rotation.y = deg_to_rad(wheel_steer_deg(marker.position, front_steer))
			var spin_node: Node = steer_pivot.get_node_or_null("SpinPivot")
			if spin_node is Node3D:
				var spin_pivot: Node3D = spin_node
				var wheel_world: Vector3 = _bus.global_transform * wheel.position
				var signed_speed: float = NetBusSync.point_velocity(_bus, wheel_world).dot(_bus.forward())
				if sync != null and sync.received_count > 0:
					signed_speed = linear.dot(_bus.forward())
				var angle: float = float(_spin[wheel_name]) + spin_step(signed_speed, radius, delta)
				angle = wrapf(angle, -PI, PI)
				_spin[wheel_name] = angle
				spin_pivot.rotation.x = angle


static func _sync_for(bus: Bus) -> NetBusSync:
	if not bus.is_inside_tree():
		return null
	for node: Node in bus.get_tree().get_nodes_in_group("net_bus_sync"):
		if node is NetBusSync:
			var sync: NetBusSync = node
			if sync.bus == bus:
				return sync
	return null
