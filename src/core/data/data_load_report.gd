class_name DataLoadReport
extends RefCounted

## Outcome of a data load: applied files, warnings and errors.
## is_ok() drives the CLI exit codes, so mods must only ever add warnings.

var errors: Array[String] = []
var warnings: Array[String] = []
var applied_files: PackedStringArray = PackedStringArray()


func add_error(source: String, msg: String) -> void:
	errors.append("%s: %s" % [source, msg])


func add_warning(source: String, msg: String) -> void:
	warnings.append("%s: %s" % [source, msg])


func is_ok() -> bool:
	return errors.is_empty()


func summary() -> String:
	var lines: PackedStringArray = PackedStringArray()
	lines.append(
		"data load: %d applied, %d warning(s), %d error(s)"
		% [applied_files.size(), warnings.size(), errors.size()]
	)
	for applied: String in applied_files:
		lines.append("  [applied] " + applied)
	for warning: String in warnings:
		lines.append("  [warning] " + warning)
	for error: String in errors:
		lines.append("  [error] " + error)
	return "\n".join(lines)
