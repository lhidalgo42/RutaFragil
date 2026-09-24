extends SceneTree

## M-ART-VAN wheel evidence: scene real, bus congelado, estado visual inyectado
## sin simular ni escribir fuerzas. Captura steer izquierda/derecha y reversa.

var _world: Node3D = null
var _camera: Camera3D = null
var _bus: Node3D = null
var _visual: Node3D = null
var _phase: int = 0
var _frames: int = 0


func _process(_delta: float) -> bool:
	if _world == null:
		if not _setup(): quit(1); return true
		return false
	_frames += 1
	if _frames < 20: return false
	var names: Array[String] = ["steer_left", "steer_right", "reverse"]
	var steer: Array[float] = [0.8, -0.8, 0.0]
	var speed: Array[float] = [10.0, 10.0, -10.0]
	if _phase >= names.size(): quit(0); return true
	_bus.set("drive_steer", steer[_phase])
	_bus.set("linear_velocity", -_bus.global_basis.z * speed[_phase])
	_visual.call("update_visuals", 0.15)
	var path: String = "res://docs/evidencia/M-ART-VAN/integracion/wheels_%s.png" % names[_phase]
	var err: Error = root.get_texture().get_image().save_png(path)
	if err != OK: push_error("wheel capture failed %d" % err); quit(1); return true
	var fl: Node3D = _visual.get_node("WheelFL/SteerPivot")
	var rl: Node3D = _visual.get_node("WheelRL/SteerPivot")
	var spin: Node3D = _visual.get_node("WheelFL/SteerPivot/SpinPivot")
	print("WHEEL_CAPTURE name=%s steer_front_deg=%.2f steer_rear_deg=%.2f spin=%.3f" % [
		names[_phase], rad_to_deg(fl.rotation.y), rad_to_deg(rl.rotation.y), spin.rotation.x])
	_phase += 1
	_frames = 0
	return false


func _setup() -> bool:
	var packed: Resource = load("res://src/vehicle/bus.tscn")
	if not (packed is PackedScene): return false
	_world = Node3D.new(); root.add_child(_world)
	var scene: PackedScene = packed
	_bus = scene.instantiate()
	if _bus is RigidBody3D:
		var body: RigidBody3D = _bus
		body.freeze = true
	_world.add_child(_bus)
	_visual = _bus.get_node_or_null("BusExteriorVisual")
	if _visual == null: return false
	var env_node: WorldEnvironment = WorldEnvironment.new()
	var environment: Environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.12,0.14,0.18)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color.WHITE
	environment.ambient_light_energy = 1.2
	env_node.environment = environment; _world.add_child(env_node)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45,-30,0); sun.light_energy = 2.0; _world.add_child(sun)
	_camera = Camera3D.new(); _camera.position = Vector3(4.5,0.0,-5.0)
	_world.add_child(_camera); _camera.look_at(Vector3(0,-0.25,-2.7),Vector3.UP); _camera.current = true
	return true
