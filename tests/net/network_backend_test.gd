extends GdUnitTestSuite

## NetworkBackend unit tests (D53, plan M0-T0.4 step 1): hosting lifecycle on
## real ports and the connection-failure path without a server. Each test uses
## its own high port and leaves in after_test so ports never leak across tests.
## The autoload has no class_name (same pattern as GameConfig, D43), so it is
## reached by name and driven with call()/connect() on Node.

const TEST_PORT_A: int = 49211
const TEST_PORT_B: int = 49212

var _backend: Node


func before_test() -> void:
	_backend = get_tree().root.get_node("NetworkBackend")
	_backend.call("leave")


func after_test() -> void:
	_backend.call("leave")


func _is_host() -> bool:
	var value_v: Variant = _backend.call("is_host")
	if value_v is bool:
		var value: bool = value_v
		return value
	return false


func _peer_count() -> int:
	var value_v: Variant = _backend.call("peer_ids")
	if value_v is PackedInt32Array:
		var value: PackedInt32Array = value_v
		return value.size()
	return -1


func _call_ok(method: String, args: Array) -> bool:
	var value_v: Variant = _backend.callv(method, args)
	if value_v is int:
		var value: int = value_v
		return value == OK
	return false


func test_initial_state_is_idle() -> void:
	assert_bool(_is_host()).is_false()
	assert_int(_peer_count()).is_equal(0)


func test_host_game_makes_us_host_and_emits_hosted() -> void:
	var hosted_ports: Array[int] = []
	_backend.connect("hosted", func(port: int) -> void: hosted_ports.append(port))
	assert_bool(_call_ok("host_game", [TEST_PORT_A])).is_true()
	assert_bool(_is_host()).is_true()
	assert_int(hosted_ports.size()).is_equal(1)
	assert_int(hosted_ports[0]).is_equal(TEST_PORT_A)


func test_leave_returns_to_idle_and_frees_the_port() -> void:
	assert_bool(_call_ok("host_game", [TEST_PORT_A])).is_true()
	_backend.call("leave")
	assert_bool(_is_host()).is_false()
	assert_bool(_call_ok("host_game", [TEST_PORT_A])).is_true()


func test_join_without_server_fails_without_hanging() -> void:
	var failures: Array[String] = []
	_backend.connect("connection_failed", func(reason: String) -> void: failures.append(reason))
	assert_bool(_call_ok("join_game", ["127.0.0.1", TEST_PORT_B])).is_true()
	await await_signal_on(_backend, "connection_failed", [], 15000)
	assert_int(failures.size()).is_equal(1)
