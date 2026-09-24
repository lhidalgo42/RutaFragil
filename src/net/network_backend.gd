extends Node

## Transport-agnostic network entry point (D53, ADR-001): the game talks to
## this autoload, never to `multiplayer` directly. ENet lives behind _impl;
## GodotSteam replaces it in M4 without touching callers. No game logic here.

signal hosted(port: int)
signal joined
signal peer_joined(id: int)
signal peer_left(id: int)
signal connection_failed(reason: String)
signal server_lost
signal peer_ready(id: int)
signal peer_done(id: int)
signal snapshot_requested

const MAX_CLIENTS: int = 8

var _impl: ENetMultiplayerPeer = null


func host_game(port: int) -> Error:
	leave()
	var peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	var err: Error = peer.create_server(port, MAX_CLIENTS)
	if err != OK:
		return err
	_impl = peer
	multiplayer.multiplayer_peer = peer
	_connect_tree_signals()
	hosted.emit(port)
	return OK


func join_game(address: String, port: int) -> Error:
	leave()
	var peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	var err: Error = peer.create_client(address, port)
	if err != OK:
		return err
	# Bound the failure wait: ENet's stock timeout reports a dead server only
	# after ~32 s (measured on loopback, 2026-09-11); ~5-8 s is friendlier on
	# a LAN and keeps the harness fast. Detection stays engine-side.
	var server_peer: ENetPacketPeer = peer.get_peer(1)
	if server_peer != null:
		server_peer.set_timeout(32, 3000, 5000)
	_impl = peer
	multiplayer.multiplayer_peer = peer
	_connect_tree_signals()
	return OK


func leave() -> void:
	if _impl != null:
		_impl.close()
		_impl = null
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer = null
	ready_peers.clear()
	done_peers.clear()
	_disconnect_tree_signals()


func is_host() -> bool:
	return _impl != null and multiplayer.is_server()


func peer_ids() -> PackedInt32Array:
	if not multiplayer.has_multiplayer_peer():
		return PackedInt32Array()
	return multiplayer.get_peers()


func _connect_tree_signals() -> void:
	if not multiplayer.peer_connected.is_connected(_on_peer_connected):
		multiplayer.peer_connected.connect(_on_peer_connected)
	if not multiplayer.peer_disconnected.is_connected(_on_peer_disconnected):
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	if not multiplayer.connected_to_server.is_connected(_on_connected_to_server):
		multiplayer.connected_to_server.connect(_on_connected_to_server)
	if not multiplayer.connection_failed.is_connected(_on_connection_failed):
		multiplayer.connection_failed.connect(_on_connection_failed)
	if not multiplayer.server_disconnected.is_connected(_on_server_disconnected):
		multiplayer.server_disconnected.connect(_on_server_disconnected)


func _disconnect_tree_signals() -> void:
	if multiplayer.peer_connected.is_connected(_on_peer_connected):
		multiplayer.peer_connected.disconnect(_on_peer_connected)
	if multiplayer.peer_disconnected.is_connected(_on_peer_disconnected):
		multiplayer.peer_disconnected.disconnect(_on_peer_disconnected)
	if multiplayer.connected_to_server.is_connected(_on_connected_to_server):
		multiplayer.connected_to_server.disconnect(_on_connected_to_server)
	if multiplayer.connection_failed.is_connected(_on_connection_failed):
		multiplayer.connection_failed.disconnect(_on_connection_failed)
	if multiplayer.server_disconnected.is_connected(_on_server_disconnected):
		multiplayer.server_disconnected.disconnect(_on_server_disconnected)


func _on_peer_connected(id: int) -> void:
	peer_joined.emit(id)


func _on_peer_disconnected(id: int) -> void:
	ready_peers.erase(id)
	done_peers.erase(id)
	peer_left.emit(id)


func _on_connected_to_server() -> void:
	joined.emit()


func _on_connection_failed() -> void:
	connection_failed.emit("connection to the server failed or timed out")


func _on_server_disconnected() -> void:
	server_lost.emit()


## Readiness handshake for multiplayer setup: a client that finished building
## its replicated nodes calls rpc("mark_ready") and the host counts one
## peer_ready per peer before spawning/synchronizing anything. Without it,
## spawns fired right after peer_connected are dropped on peers whose scene is
## not built yet (measured 2026-09-11: markers_received=0, no error either side).
var ready_peers: Array[int] = []


@rpc("any_peer", "call_remote", "reliable")
func mark_ready() -> void:
	var sender: int = multiplayer.get_remote_sender_id()
	if sender != 0 and not ready_peers.has(sender):
		ready_peers.append(sender)
		peer_ready.emit(sender)


## Symmetric completion handshake: replicated spawns are REMOVED by the engine
## when the authority disconnects (measured 2026-09-11: markers vanished the
## moment the host quit, while synchronized transforms survived), so the host
## must stay connected until every client has taken its snapshot.
var done_peers: Array[int] = []


@rpc("any_peer", "call_remote", "reliable")
func mark_done() -> void:
	var sender: int = multiplayer.get_remote_sender_id()
	if sender != 0 and not done_peers.has(sender):
		done_peers.append(sender)
		peer_done.emit(sender)


## Snapshot coordination (r1.2): the host tells every peer WHEN to take its
## state snapshot, after braking and settling, instead of clients guessing a
## fixed wall-clock time (which broke the full-lap route: 16 waypoints need
## ~37 s and the client's fixed 30 s fired first).
@rpc("authority", "call_remote", "reliable")
func snapshot_now() -> void:
	snapshot_requested.emit()
