class_name GateReadiness
extends RefCounted

## D95 v5 checks containment and recovery, not the percentage of floor support.
## Penetration coverage remains a separate limitation of the full gate verdict.
static func evaluate(host: Dictionary, client: Dictionary) -> Dictionary:
	var reasons: Array[String] = []
	for role: String in ["host", "client"]:
		var reading: Dictionary = host if role == "host" else client
		var ticks: int = GateMetricsUtil.integer(reading.get("ticks", 0))
		if not GateMetricsUtil.travel_complete(reading):
			reasons.append(role + ": incomplete v5 travel observation")
		if ticks != 18000 or absf(GateMetricsUtil.number(reading.get("duration_s", 0.0)) - 300.0) > 0.001:
			reasons.append(role + ": requires exactly 300 seconds / 18000 ticks")
		if GateMetricsUtil.integer(reading.get("hull_exit_ticks"), -1) != 0:
			reasons.append(role + ": local crew left the bus hull")
		var pushes: Dictionary = reading.get("pushes", {})
		if GateMetricsUtil.integer(pushes.get("max_duration_ticks"), 2147483647) > 45:
			reasons.append(role + ": cargo push exceeds 45 ticks")
		var activity: Dictionary = reading.get("activity", {})
		if GateMetricsUtil.integer(activity.get("complete_cycles"), -1) < 10:
			reasons.append(role + ": fewer than ten complete cargo cycles")
	return {"ready": reasons.is_empty(), "reasons": reasons}


static func allows_gate(previous: Dictionary, source_commit: String, configuration: Dictionary) -> bool:
	# JSON reloads integer values as floats; compare both signatures in that form.
	var recorded_config: Dictionary = JSON.parse_string(JSON.stringify(previous.get("configuration", {})))
	var current_config: Dictionary = JSON.parse_string(JSON.stringify(configuration))
	if source_commit.is_empty() or previous.get("source_commit", "") != source_commit \
			or recorded_config != current_config or not GateMetricsUtil.boolean(previous.get("source_clean", false)):
		return false
	if previous.get("kind", "") != "experiment" or previous.get("status", "") != "completed":
		return false
	var host: Dictionary = previous.get("host", {})
	var client: Dictionary = previous.get("client", {})
	return GateMetricsUtil.boolean(evaluate(host, client)["ready"])
