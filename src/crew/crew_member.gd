class_name CrewMember
extends CharacterBody3D

## The crew member (D73, D74, D75): a 1.75 m capsule with a first-person
## camera at eye height. Movement logic is callable WITHOUT input (tests drive
## it directly; headless delivers no InputEvent, plan §3). The numbers come
## from GameConfig.tuning (R2: player_walk_speed_mps, player_sprint_speed_mps,
## player_jump_height_m), never from this script.
## Platform inheritance is the ENGINE's (D74, measured in paso 1): standing on
## the moving bus, move_and_slide carries the body and get_platform_velocity()
## reports the bus. In air, retain the last grounded carry (D98). Position every body BEFORE
## add_child (the physics server sees one tick at the origin otherwise, and
## the depenetration can launch the bus — measured by the reviewer).
## seated (D76): the seat hides and freezes the body; CrewInput then drives
## the bus through BusInput.

signal boarded
signal exited

## True while the crew member is inside the bus (set by the transit zone).
var aboard: bool = false
var seated: bool = false
var network_member: bool = false
var network_ready: bool = true
var physics_simulation_ticks: int = 0

const EYE_HEIGHT_M: float = 1.65

var _gravity: float = 0.0
var _ground_carry: Vector3 = Vector3.ZERO
var _air_carry: Vector3 = Vector3.ZERO
var _jump_requested: bool = false


## Gravity comes from the project setting (r1.2 of M2-T2.2): the bus falls
## with physics/3d/default_gravity and the crew must fall with the same
## number, or one day someone touches the setting and cargo and crew disagree.
static func project_gravity() -> float:
	var raw: Variant = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
	if raw is float:
		return raw
	if raw is int:
		var narrowed: int = raw
		return float(narrowed)
	return 9.8


static func jump_velocity_for(jump_height_m: float) -> float:
	if jump_height_m <= 0.0:
		return 0.0
	return sqrt(2.0 * project_gravity() * jump_height_m)


static func horizontal_speed(walk_mps: float, sprint_mps: float, sprint: bool) -> float:
	return sprint_mps if sprint else walk_mps


static func wish_direction(walk_input: Vector2, basis: Basis) -> Vector3:
	var dir: Vector3 = basis * Vector3(walk_input.x, 0.0, walk_input.y)
	dir.y = 0.0
	if dir.length() > 1.0:
		return dir.normalized()
	return dir


func _enter_tree() -> void:
	if String(name).begins_with("Crew_"):
		var peer_id: int = String(name).trim_prefix("Crew_").to_int()
		if peer_id > 0:
			network_member = true
			network_ready = false
			set_multiplayer_authority(peer_id)
			# Replicated PackedScenes arrive before their reliable initial pose.
			set_collision_disabled(true)


func _ready() -> void:
	add_to_group("crew")
	_gravity = project_gravity()
	# Transfer grounded inertia once ourselves, including when a wall is touched.
	# The engine still supplies all displacement while supported.
	platform_on_leave = CharacterBody3D.PLATFORM_ON_LEAVE_DO_NOTHING
	# A descending ceiling must cancel ascent without retrying the upward
	# remainder until max_slides consumes the horizontal movement (4.7.2).
	slide_on_ceiling = false
	# The scene file stays untouched: the eye camera joins its group from
	# code so the CameraArbiter can find it (D59 style, never by node path).
	var eye_node: Node = get_node_or_null("EyeCamera")
	if eye_node is Camera3D:
		var eye: Camera3D = eye_node
		eye.add_to_group("eye_camera")


func _physics_process(delta: float) -> void:
	if network_member and (not network_ready or not NetAuthority.is_local(self)):
		return
	if seated:
		velocity = Vector3.ZERO
		return
	var was_grounded: bool = is_on_floor()
	if was_grounded and _jump_requested:
		velocity.y = jump_velocity_for(GameConfig.tuning.player_jump_height_m)
	elif not was_grounded:
		velocity.y -= _gravity * delta
	elif velocity.y > -0.5:
		# Keep a small downward press on the floor instead of zeroing it:
		# zeroed, the body separated over the bumps and drifted ~0.3 m per lap
		# (measured 2026-09-13); pressed, the engine's platform carry holds it.
		velocity.y = -0.5
	_jump_requested = false
	physics_simulation_ticks += 1
	move_and_slide()
	if is_on_floor():
		_ground_carry = get_platform_velocity()
		_air_carry = Vector3.ZERO
	elif was_grounded:
		# This tick already received platform displacement inside move_and_slide.
		# Preserve its velocity for following ticks, without moving twice now.
		_air_carry = _ground_carry
		velocity += _air_carry


## The movement entry point for CrewInput and the tests (never reads Input).
func drive_move(walk_input: Vector2, sprint: bool, jump: bool, camera_basis: Basis) -> void:
	if network_member and (not network_ready or not NetAuthority.is_local(self)):
		return
	if seated:
		return
	var tuning: TuningTable = GameConfig.tuning
	if tuning == null:
		push_error("CrewMember: GameConfig.tuning is null; not moving")
		return
	var speed: float = horizontal_speed(tuning.player_walk_speed_mps, tuning.player_sprint_speed_mps, sprint)
	var wish: Vector3 = wish_direction(walk_input, camera_basis)
	var carry: Vector3 = Vector3.ZERO if is_on_floor() else _air_carry
	velocity.x = wish.x * speed + carry.x
	velocity.z = wish.z * speed + carry.z
	if jump and is_on_floor():
		_jump_requested = true


func eye_position() -> Vector3:
	return global_position + Vector3(0.0, EYE_HEIGHT_M, 0.0)


## The seat turns the capsule's collision off while seated (M2-T2.2 round 4):
## seated at the wheel marker the capsule pokes through the roof, and an
## active kinematic shape inside the hull depenetrates the bus every tick
## (the owner's gate: the bus rocked and swerved when driving seated).
func set_collision_disabled(on: bool) -> void:
	# By TYPE, not by node name (r4.2): renaming the shape when the art lands
	# must not silently re-enable seated collision.
	for child: Node in get_children():
		if child is CollisionShape3D:
			var shape: CollisionShape3D = child
			shape.disabled = on


func set_seated(on: bool) -> void:
	seated = on
	if seated:
		velocity = Vector3.ZERO
		_ground_carry = Vector3.ZERO
		_air_carry = Vector3.ZERO
		_jump_requested = false
