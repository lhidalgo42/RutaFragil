extends Node

## The fixture writes at -100; a separate node samples at +1000.
var bus: Bus
var crew: CharacterBody3D
var package: Package
var recording: Array[Transform3D] = []
var speeds: Array[float] = []
var record_mode: bool = false
var walking: bool = false
var speed_ratio: float = 1.0
var deficit_start: int = 350
var box_local: Vector3 = Vector3(0.49, -0.4, 2.5)
var index: int = 0
var active: bool = false
var walk_end: float = -2.5
var bus_delta: Vector3 = Vector3.ZERO
var package_delta: Vector3 = Vector3.ZERO
var jump_index: int = -1
var jump_sent: bool = false
var commanded_step: Vector3 = Vector3.ZERO
var fixture_carry: bool = true
var keep_air_walk: bool = false
var _last_walk: Vector2 = Vector2.ZERO


func _ready() -> void:
	process_physics_priority = -100


func _physics_process(delta: float) -> void:
	if not active:
		return
	if record_mode:
		bus.set_drive(1.0, 0.0, 0.0)
		return
	if index >= recording.size():
		active = false
		return
	var before: Transform3D = bus.global_transform
	var target: Transform3D = recording[index]
	bus_delta = target.origin - before.origin
	var point: Vector3 = before.affine_inverse() * crew.global_position
	var carry: Vector3 = (target * point - before * point) / delta
	bus.global_transform = target
	if fixture_carry:
		crew.set("bus_point_velocity", carry)
	if package != null:
		var nominal: Vector3 = target * box_local - before * box_local
		if index >= deficit_start:
			box_local.z += (1.0 - speed_ratio) * nominal.dot(-target.basis.z.normalized())
		var old_package: Vector3 = package.global_position
		package.global_transform = target * Transform3D(Basis.IDENTITY, box_local)
		package_delta = package.global_position - old_package
	var local: Vector3 = bus.to_local(crew.global_position)
	var movement: Vector2 = Vector2.ZERO
	if walking:
		if absf(local.z - walk_end) < 0.18:
			walk_end = -walk_end
		movement = Vector2(-local.x, walk_end - local.z).normalized() * 0.5
	if keep_air_walk and not crew.is_on_floor():
		movement = _last_walk
	_last_walk = movement
	var jump: bool = index == jump_index
	jump_sent = jump_sent or jump
	var wish: Vector3 = CrewMember.wish_direction(movement, bus.global_basis)
	commanded_step = bus.global_basis.inverse() * wish * GameConfig.tuning.player_walk_speed_mps * delta
	crew.call("drive_move", movement, false, jump, bus.global_basis)
	index += 1
