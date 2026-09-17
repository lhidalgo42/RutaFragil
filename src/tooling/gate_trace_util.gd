class_name GateTraceUtil
extends RefCounted



static func pose_sample(entity: String, kind: String, at: Transform3D, authority: int,
		observer: int, utc_us: int) -> Dictionary:
	var orientation: Quaternion = at.basis.orthonormalized().get_rotation_quaternion().normalized()
	return {"entity": entity, "kind": kind, "authority": authority, "observer": observer,
		"t_utc_us": utc_us, "position": GateMetricsUtil.vector_array(at.origin),
		"quaternion": [orientation.x, orientation.y, orientation.z, orientation.w]}


## Authority samples bracket the observed UTC instant. Never bridge a handover
## or extrapolate an absent endpoint; report unmatched observations instead.
static func compare_traces(observed: Array[Dictionary], source: Array[Dictionary]) -> Dictionary:
	var tracks: Dictionary = {}
	for sample: Dictionary in source:
		# Non-authoritative samples preserve the boundaries between ownership periods.
		var entity: String = str(sample["entity"])
		if not tracks.has(entity):
			tracks[entity] = []
		var samples: Array = tracks[entity]
		samples.append(sample)
	for entity: String in tracks:
		var samples: Array = tracks[entity]
		samples.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return GateMetricsUtil.integer(a["t_utc_us"]) < GateMetricsUtil.integer(b["t_utc_us"]))
	var buckets: Dictionary = {}
	for kind: String in ["bus", "crew", "cargo"]:
		buckets[kind] = {"distances": [], "angles": [], "unmatched": 0, "local_samples": 0}
	for sample: Dictionary in observed:
		var kind: String = str(sample["kind"])
		if not buckets.has(kind):
			continue
		var bucket: Dictionary = buckets[kind]
		if GateMetricsUtil.integer(sample["observer"]) == GateMetricsUtil.integer(sample["authority"]):
			bucket["local_samples"] = GateMetricsUtil.integer(bucket["local_samples"]) + 1
			continue
		var samples: Array = tracks.get(str(sample["entity"]), [])
		var expected: Dictionary = _interpolate(samples, GateMetricsUtil.integer(sample["t_utc_us"]), GateMetricsUtil.integer(sample["authority"]))
		if expected.is_empty():
			bucket["unmatched"] = GateMetricsUtil.integer(bucket["unmatched"]) + 1
			continue
		var distances: Array = bucket["distances"]
		var angles: Array = bucket["angles"]
		var expected_position: Vector3 = expected["position"]
		var expected_orientation: Quaternion = expected["quaternion"]
		distances.append(_position(sample).distance_to(expected_position))
		angles.append(rad_to_deg(_orientation(sample).angle_to(expected_orientation)))
	var result: Dictionary = {}
	for kind: String in buckets:
		var bucket: Dictionary = buckets[kind]
		var distances: Array[float] = []
		var angles: Array[float] = []
		var raw_distances: Array = bucket["distances"]
		var raw_angles: Array = bucket["angles"]
		distances.assign(raw_distances)
		angles.assign(raw_angles)
		var applicable: bool = not distances.is_empty() or GateMetricsUtil.integer(bucket["unmatched"]) > 0
		var status: String = "measured" if not distances.is_empty() else "unmatched"
		if not applicable:
			status = "not_applicable" if GateMetricsUtil.integer(bucket["local_samples"]) > 0 else "not_observed"
		result[kind + "_remote_error"] = {"applicable": applicable,
			"status": status,
			"matched": distances.size(), "unmatched": GateMetricsUtil.integer(bucket["unmatched"]),
			"local_samples": GateMetricsUtil.integer(bucket["local_samples"]),
			"p95_m": GateMetricsUtil.percentile(distances, 0.95) if not distances.is_empty() else null,
			"max_m": GateMetricsUtil.percentile(distances, 1.0) if not distances.is_empty() else null,
			"p95_deg": GateMetricsUtil.percentile(angles, 0.95) if not angles.is_empty() else null,
			"max_deg": GateMetricsUtil.percentile(angles, 1.0) if not angles.is_empty() else null}
	return result


static func _interpolate(samples: Array, utc_us: int, authority: int) -> Dictionary:
	if samples.is_empty():
		return {}
	var low: int = 0
	var high: int = samples.size()
	while low < high:
		var middle: int = (low + high) / 2
		var sample: Dictionary = samples[middle]
		if GateMetricsUtil.integer(sample["t_utc_us"]) < utc_us:
			low = middle + 1
		else:
			high = middle
	if low >= samples.size():
		return {}
	var after: Dictionary = samples[low]
	if GateMetricsUtil.integer(after["authority"]) != authority or GateMetricsUtil.integer(after["observer"]) != authority:
		return {}
	if GateMetricsUtil.integer(after["t_utc_us"]) == utc_us:
		return {"position": _position(after), "quaternion": _orientation(after)}
	if low == 0:
		return {}
	var before: Dictionary = samples[low - 1]
	if GateMetricsUtil.integer(before["authority"]) != authority or GateMetricsUtil.integer(before["observer"]) != authority:
		return {}
	var span: int = GateMetricsUtil.integer(after["t_utc_us"]) - GateMetricsUtil.integer(before["t_utc_us"])
	if span <= 0:
		return {}
	var weight: float = GateMetricsUtil.number(utc_us - GateMetricsUtil.integer(before["t_utc_us"])) / GateMetricsUtil.number(span)
	return {"position": _position(before).lerp(_position(after), weight),
		"quaternion": _orientation(before).slerp(_orientation(after), weight).normalized()}


static func _position(sample: Dictionary) -> Vector3:
	var position: Array = sample["position"]
	return Vector3(GateMetricsUtil.number(position[0]), GateMetricsUtil.number(position[1]), GateMetricsUtil.number(position[2]))


static func _orientation(sample: Dictionary) -> Quaternion:
	var rotation: Array = sample["quaternion"]
	return Quaternion(GateMetricsUtil.number(rotation[0]), GateMetricsUtil.number(rotation[1]), GateMetricsUtil.number(rotation[2]), GateMetricsUtil.number(rotation[3])).normalized()
