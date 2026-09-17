extends Node

## A preflight never consumes D96. A fourth valid failed gate is refused.
const LEDGER_PATH: String = "res://docs/evidencia/M2-GATE/04_iteration_ledger.json"
var config: GateConfig = null
var _pids: Dictionary[String, int] = {}
var _ledger: Array = []
var _source_commit: String = ""
var _source_clean: bool = false


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var revision: Array = []
	var status: Array = []
	OS.execute("git", ["-C", ProjectSettings.globalize_path("res://"), "rev-parse", "HEAD"], revision)
	var status_code: int = OS.execute("git", ["-C", ProjectSettings.globalize_path("res://"), "status", "--porcelain",
		"--", ".", ":!docs"], status)
	_source_commit = "".join(revision).strip_edges()
	_source_clean = status_code == 0 and "".join(status).strip_edges().is_empty()
	if FileAccess.file_exists(LEDGER_PATH):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(LEDGER_PATH))
		if parsed is Array:
			_ledger = parsed
	var failures: int = 0
	for entry: Dictionary in _ledger:
		if entry.get("valid", false) and entry.get("status", "") == "failed":
			failures += 1
	if failures >= 3 and config.counts_for_d96():
		printerr("GATE D96: three failed iterations; stop and plan option B")
		get_tree().quit(3)
		return
	if failures == 2 and config.counts_for_d96():
		var previous: Variant = JSON.parse_string(FileAccess.get_file_as_string(config.precondition)) \
			if FileAccess.file_exists(config.precondition) else null
		if not previous is Dictionary or not _source_clean \
				or not GateReadiness.allows_gate(previous, _source_commit, config.signature()):
			printerr("GATE D95 v5: third attempt requires a passing 300 s experiment on this clean commit and configuration")
			get_tree().quit(3)
			return
	if FileAccess.file_exists(config.output.path_join("summary.json")):
		printerr("GATE refuses to overwrite existing evidence: ", config.output)
		get_tree().quit(1)
		return
	DirAccess.make_dir_recursive_absolute(config.output)
	if config.counts_for_d96():
		config.iteration = _ledger.size() + 1
	var exe: String = OS.get_executable_path()
	_pids["host"] = OS.create_process(exe, config.child_args("host"))
	await get_tree().create_timer(0.5).timeout
	_pids["client"] = OS.create_process(exe, config.child_args("client"))
	print("GATE launcher output=%s seconds=%.1f deadline=%.1f pids=%s" % [config.output, config.seconds, config.budget_s() + 10.0, _pids])
	var deadline: int = Time.get_ticks_msec() + int((config.budget_s() + 10.0) * 1000.0)
	while Time.get_ticks_msec() < deadline and not _alive().is_empty():
		await get_tree().create_timer(0.25).timeout
	var killed: Array[String] = _alive()
	for role: String in killed:
		OS.kill(_pids[role])
	_aggregate(killed)


func _alive() -> Array[String]:
	var alive: Array[String] = []
	for role: String in _pids:
		if _pids[role] > 0 and OS.is_process_running(_pids[role]):
			alive.append(role)
	return alive


func _aggregate(killed: Array[String]) -> void:
	var exit_codes: Dictionary = {}
	for role: String in _pids:
		exit_codes[role] = OS.get_process_exit_code(_pids[role])
	var host_raw: Variant = config.read_json("host.json")
	var client_raw: Variant = config.read_json("client.json")
	if not (host_raw is Dictionary and client_raw is Dictionary) or not killed.is_empty():
		_invalid({"reason": "missing child result or deadline", "killed": killed, "exit_codes": exit_codes})
		get_tree().quit(2)
		return
	var host: Dictionary = host_raw
	var client: Dictionary = client_raw
	var host_exit: int = host.get("exit", 1)
	var client_exit: int = client.get("exit", 1)
	if host_exit != 0 or client_exit != 0 or exit_codes.values().any(func(value: int) -> bool: return value != 0):
		_invalid({"reason": "child setup failed", "host": host, "client": client, "exit_codes": exit_codes})
		get_tree().quit(2)
		return
	var host_trace: Array[Dictionary] = []
	var client_trace: Array[Dictionary] = []
	var host_trace_raw: Variant = config.read_json("host_trace.json")
	var client_trace_raw: Variant = config.read_json("client_trace.json")
	if host_trace_raw is Array:
		var host_samples: Array = host_trace_raw
		host_trace.assign(host_samples)
	if client_trace_raw is Array:
		var client_samples: Array = client_trace_raw
		client_trace.assign(client_samples)
	host.merge(GateTraceUtil.compare_traces(host_trace, client_trace), true)
	client.merge(GateTraceUtil.compare_traces(client_trace, host_trace), true)
	var verdict: Dictionary = GateMetricsUtil.judge(host, client)
	if config.experiment:
		verdict = {"status": "completed", "valid": false, "d96_consumed": false,
			"invalid_reasons": [], "failures": [], "human_gate_approval": "not_a_gate"}
	elif config.human != "none":
		# D97: the owner is playing. The verdict is theirs, not this script's,
		# so the metrics are recorded and nothing is passed or failed here.
		verdict = {"status": "played", "valid": false, "d96_consumed": false,
			"invalid_reasons": [], "failures": [], "human_gate_approval": "pending_owner",
			"automatic_reference": GateMetricsUtil.judge(host, client)}
	var logs: Dictionary = {"host": _log_counts("host"), "client": _log_counts("client")}
	for role: String in logs:
		var counts: Dictionary = logs[role]
		if counts.get("missing", false) or GateMetricsUtil.integer(counts.get("errors", 0)) > 0:
			verdict["valid"] = false
			verdict["logic_passed"] = false
			verdict["status"] = "invalid"
			var invalid: Array = verdict["invalid_reasons"]
			invalid.append(role + ": missing log or engine errors")
	verdict["iteration"] = config.iteration
	verdict["kind"] = config.kind()
	verdict["source_commit"] = _source_commit
	verdict["source_clean"] = _source_clean
	verdict["configuration"] = config.signature()
	verdict["gate_precondition"] = GateReadiness.evaluate(host, client)
	verdict["output"] = config.output
	verdict["exit_codes"] = exit_codes
	verdict["host"] = host
	verdict["client"] = client
	verdict["logs"] = logs
	config.write_json("host.json", host)
	config.write_json("client.json", client)
	config.write_json("summary.json", verdict)
	_record_iteration(verdict)
	print("GATE result=%s valid=%s iteration=%d" % [verdict.get("status"), verdict.get("valid"), config.iteration])
	var code: int = 0 if verdict.get("status") == "passed" else 1
	if not verdict.get("valid", false):
		code = 2
	if config.experiment and verdict.get("status") == "completed":
		code = 0
	if config.human != "none" and verdict.get("status") == "played":
		code = 0
	get_tree().quit(code)


func _invalid(details: Dictionary) -> void:
	details.merge({"status": "invalid", "valid": false, "iteration": config.iteration,
		"kind": config.kind(), "output": config.output})
	config.write_json("summary.json", details)
	_record_iteration(details)


func _record_iteration(verdict: Dictionary) -> void:
	if config.counts_for_d96():
		_ledger.append({"iteration": config.iteration, "valid": verdict.get("valid", false),
			"status": verdict.get("status", "invalid"), "output": config.output})
		var ledger_file: FileAccess = FileAccess.open(LEDGER_PATH, FileAccess.WRITE)
		if ledger_file != null:
			ledger_file.store_string(JSON.stringify(_ledger, "\t"))
			ledger_file.close()


func _log_counts(role: String) -> Dictionary:
	var path: String = config.output.path_join(role + ".log")
	if not FileAccess.file_exists(path):
		return {"missing": true}
	var log_text: String = FileAccess.get_file_as_string(path)
	return {"errors": log_text.count("ERROR:"), "warnings": log_text.count("WARNING:")}
