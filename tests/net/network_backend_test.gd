extends GdUnitTestSuite

## NetworkBackend unit tests (D53, plan M0-T0.4 step 1): hosting lifecycle on
## real ports and the connection-failure path without a server.
## The autoload has no class_name (same pattern as GameConfig, D43), so it is
## reached by name and driven with call()/connect() on Node.
##
## Ports are NEVER hardcoded: Windows Hyper-V/WinNAT reserves dynamic UDP
## ranges that are re-rolled on every reboot (measured by the reviewer:
## 49152-49251 excluded on 2026-09-11, and two fixed test ports inside it
## failed at night after passing that afternoon). Each test probes a list of
## candidates below that band (the 47810 neighbourhood, proven) and uses the
## first one create_server accepts; if none works the test fails saying there
## is no free port, not with a misleading assert diff.

const PORT_CANDIDATES: Array[int] = [47810, 47811, 47850, 47900, 47950, 48010, 48050, 48100]

var _backend: Node


func before_test() -> void:
	_backend = get_tree().root.get_node("NetworkBackend")
	_backend.call("leave")


func after_test() -> void:
	_backend.call("leave")


## Finds a UDP port that accepts create_server among the candidates, or -1.
## The probe server is closed immediately; the port is only borrowed.
func _find_free_port() -> int:
	var probe: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	for candidate: int in PORT_CANDIDATES:
		if probe.create_server(candidate, 1) == OK:
			probe.close()
			return candidate
	return -1


func _require_free_port() -> int:
	var port: int = _find_free_port()
	assert_int(port).override_failure_message(
		"no free UDP port among the %d candidates (Windows reserved-port ranges shift on reboot)" % PORT_CANDIDATES.size()
	).is_not_equal(-1)
	return port


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
	var port: int = _require_free_port()
	if port == -1:
		return
	var hosted_ports: Array[int] = []
	_backend.connect("hosted", func(hosted_port: int) -> void: hosted_ports.append(hosted_port))
	assert_bool(_call_ok("host_game", [port])).is_true()
	assert_bool(_is_host()).is_true()
	assert_int(hosted_ports.size()).is_equal(1)
	assert_int(hosted_ports[0]).is_equal(port)


func test_leave_returns_to_idle_and_frees_the_port() -> void:
	var port: int = _require_free_port()
	if port == -1:
		return
	assert_bool(_call_ok("host_game", [port])).is_true()
	_backend.call("leave")
	assert_bool(_is_host()).is_false()
	assert_bool(_call_ok("host_game", [port])).is_true()


func test_join_without_server_fails_without_hanging() -> void:
	var port: int = _require_free_port()
	if port == -1:
		return
	var failures: Array[String] = []
	_backend.connect("connection_failed", func(reason: String) -> void: failures.append(reason))
	assert_bool(_call_ok("join_game", ["127.0.0.1", port])).is_true()
	await await_signal_on(_backend, "connection_failed", [], 15000)
	assert_int(failures.size()).is_equal(1)
