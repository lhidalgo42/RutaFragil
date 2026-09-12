class_name NetMarker
extends Node3D

## Trivial replicated spawn marker (D55): the host's MultiplayerSpawner creates
## one per connected peer so clients can assert that replicated spawning works
## without needing game content that does not exist yet (packages are M3).

@export var owner_peer_id: int = 0
