class_name CrewMember
extends CharacterBody3D

## The crew member (D73, D74, D75): a 1.75 m capsule with a first-person
## camera at eye height. Movement logic is callable WITHOUT input (tests drive
## it directly; headless delivers no InputEvent, plan §3). The numbers come
## from GameConfig.tuning (R2: player_walk_speed_mps, player_sprint_speed_mps,
## player_jump_height_m), never from this script.
## Platform inheritance is the ENGINE's (D74, measured in paso 1): standing on
## the moving bus, move_and_slide carries the body and get_platform_velocity()
## reports the bus. No manual carry. RULE: position every body BEFORE
## add_child (the physics server sees one tick at the origin otherwise, and
## the depenetration can launch the bus — measured by the reviewer).
## seated (D76): the seat hides and freezes the body; CrewInput then drives
## the bus through BusInput.

signal boarded
signal exited

## True while the crew member is inside the bus (set by the transit zone).
var aboard: bool = false
var seated: bool = false

const GRAVITY: float = 9.8
const EYE_HEIGHT_M: float = 1.65


static func jump_velocity_for(jump_height_m: float) -> float:
	if jump_height_m <= 0.0:
		return 0.0
	return sqrt(2.0 * GRAVITY * jump_height_m)


static func horizontal_speed(walk_mps: float, sprint_mps: float, sprint: bool) -> float:
	return sprint_mps if sprint else walk_mps


static func wish_direction(walk_input: Vector2, basis: Basis) -> Vector3:
	var dir: Vector3 = basis * Vector3(walk_input.x, 0.0, walk_input.y)
	dir.y = 0.0
	if dir.length() > 1.0:
		return dir.normalized()
	return dir


func _ready() -> void:
	add_to_group("crew")


func _physics_process(delta: float) -> void:
	if seated:
		velocity = Vector3.ZERO
		return
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	elif velocity.y > -0.5:
		# Keep a small downward press on the floor instead of zeroing it:
		# zeroed, the body separated over the bumps and drifted ~0.3 m per lap
		# (measured 2026-09-13); pressed, the engine's platform carry holds it.
		velocity.y = -0.5
	move_and_slide()


## The movement entry point for CrewInput and the tests (never reads Input).
func drive_move(walk_input: Vector2, sprint: bool, jump: bool, camera_basis: Basis) -> void:
	if seated:
		return
	var tuning: TuningTable = GameConfig.tuning
	if tuning == null:
		push_error("CrewMember: GameConfig.tuning is null; not moving")
		return
	var speed: float = horizontal_speed(tuning.player_walk_speed_mps, tuning.player_sprint_speed_mps, sprint)
	var wish: Vector3 = wish_direction(walk_input, camera_basis)
	velocity.x = wish.x * speed
	velocity.z = wish.z * speed
	if jump and is_on_floor():
		velocity.y = jump_velocity_for(tuning.player_jump_height_m)


func eye_position() -> Vector3:
	return global_position + Vector3(0.0, EYE_HEIGHT_M, 0.0)


func set_seated(on: bool) -> void:
	seated = on
	if seated:
		velocity = Vector3.ZERO
