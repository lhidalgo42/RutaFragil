extends GdUnitTestSuite

## Static net (M2-T2.2 ronda 2): every action name read through
## Input.is_action_* / get_action_strength / get_axis / get_vector in
## src/**.gd must exist in the project's input map. Round 1 shipped six walk
## actions that the code read and project.godot never registered; this test
## fails in that situation, without a window and without input.
##
## KNOWN LIMITATION (accepted, not fixed): the extraction is a regex over
## string literals inside src/. An action name built from a variable, or one
## referenced only from a .tscn, escapes it. The end-to-end sibling
## (tests/crew/crew_input_test.gd) covers the effect of pressing; this one
## only covers "registered vs read".

const PATTERN: String = "Input\\.(?:is_action_pressed|is_action_just_pressed|is_action_just_released|is_action_released|get_action_strength|get_axis|get_vector)\\s*\\(\\s*\"([^\"]+)\""


func test_every_action_read_in_src_is_registered() -> void:
	var files: Array[String] = []
	_collect_gd("res://src", files)
	assert_array(files).override_failure_message("no .gd files found under res://src").is_not_empty()
	var regex: RegEx = RegEx.new()
	assert_int(regex.compile(PATTERN)).is_equal(OK)
	var used: Dictionary[String, bool] = {}
	for path: String in files:
		var text: String = FileAccess.get_file_as_string(path)
		for found: RegExMatch in regex.search_all(text):
			used[found.get_string(1)] = true
	assert_bool(used.has("walk_forward")).override_failure_message("sanity: walk_forward read in src/ should be found").is_true()
	var missing: Array[String] = []
	for action: String in used.keys():
		if not InputMap.has_action(action):
			missing.append(action)
	assert_array(missing).override_failure_message("actions read in src/ but missing from the input map: %s" % [str(missing)]).is_empty()


func _collect_gd(dir_path: String, out: Array[String]) -> void:
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var name: String = dir.get_next()
	while name != "":
		if dir.current_is_dir():
			_collect_gd(dir_path.path_join(name), out)
		elif name.ends_with(".gd"):
			out.append(dir_path.path_join(name))
		name = dir.get_next()
	dir.list_dir_end()
