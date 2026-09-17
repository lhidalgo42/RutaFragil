class_name NetCrewPose
extends RefCounted

var previous: Transform3D = Transform3D.IDENTITY
var latest: Transform3D = Transform3D.IDENTITY
var previous_pitch: float = 0.0
var latest_pitch: float = 0.0
var elapsed: float = 0.0
var received: bool = false


func accept(at: Transform3D, pitch: float) -> void:
	previous = latest if received else at
	previous_pitch = latest_pitch if received else pitch
	latest = at
	latest_pitch = pitch
	elapsed = 0.0
	received = true


func apply(member: CrewMember, delta: float, snapshot_hz: float) -> void:
	var weight: float = clampf(elapsed * snapshot_hz, 0.0, 1.0)
	member.global_transform = previous.interpolate_with(latest, weight)
	var eye: Camera3D = NetAuthority.scoped_eye(member)
	if eye != null:
		eye.rotation.x = lerpf(previous_pitch, latest_pitch, weight)
	elapsed += delta
