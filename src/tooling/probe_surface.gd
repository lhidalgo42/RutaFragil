extends SceneTree

## Temporary diagnostic: raycasts down over a stretch of the route and prints the
## collision height and collider under the bus lane, to find lips and blockers.
## ++ scene=<res path> data=<res json> s0=<from> s1=<to> lat=<lateral>

var _scene_path: String = "res://scenes/route_requinoa.tscn"
var _data_path: String = "res://data/b0_requinoa.json"
var _s0: float = 0.0
var _s1: float = 200.0
var _lat: float = -3.4
var _frames: int = 0
var _step: float = 2.0
var _mode: String = "s"


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		var parts: PackedStringArray = arg.split("=", true, 1)
		if parts.size() != 2:
			continue
		match parts[0]:
			"scene": _scene_path = parts[1]
			"data": _data_path = parts[1]
			"s0": _s0 = parts[1].to_float()
			"s1": _s1 = parts[1].to_float()
			"lat": _lat = parts[1].to_float()
			"step": _step = maxf(0.05, parts[1].to_float())
			"mode": _mode = parts[1]
	process_frame.connect(_load, CONNECT_ONE_SHOT)


func _load() -> void:
	var packed: Resource = load(_scene_path)
	if not (packed is PackedScene):
		print("PROBE load_failed")
		quit(1)
		return
	var scene_res: PackedScene = packed
	root.add_child(scene_res.instantiate())
	physics_frame.connect(_tick)


func _tick() -> void:
	_frames += 1
	if _frames < 8:
		return
	physics_frame.disconnect(_tick)
	var data: Variant = load("res://src/biomes/osm_map_data.gd").call("load_from", _data_path)
	if data == null:
		print("PROBE no_data")
		quit(1)
		return
	var space: PhysicsDirectSpaceState3D = root.world_3d.direct_space_state
	if _mode == "ray":
		# s0,s1 = x inicial y final; lat,step = z inicial y final
		for h: float in [0.05, 0.2, 0.4, 0.7, 1.0, 1.4, 1.8, 2.2]:
			var a2: Vector3 = Vector3(_s0, h, _lat)
			var b2: Vector3 = Vector3(_s1, h, _step)
			var q2: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(a2, b2)
			var r2: Dictionary = space.intersect_ray(q2)
			if r2.is_empty():
				print("PROBE h=%.2f libre" % h)
			else:
				print("PROBE h=%.2f CHOCA %s a %.1f m en %s" % [h, str((r2.get("collider") as Node).name), a2.distance_to(r2.get("position")), str(r2.get("position"))])
		quit(0)
		return
	if _mode == "grid":
		var gz: float = -_step * 11.0
		while gz <= _step * 11.0:
			var row: String = "PROBE z%+07.1f " % (_lat + gz)
			var gx: float = -_step * 11.0
			while gx <= _step * 11.0:
				var pp: Vector3 = Vector3(_s0 + gx, 0.0, _lat + gz)
				var qq: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(pp + Vector3.UP * 30.0, pp - Vector3.UP * 30.0)
				var h2: Dictionary = space.intersect_ray(qq)
				row += ("%+6.2f" % float(h2.get("position", Vector3(0.0, -9.0, 0.0)).y)) if not h2.is_empty() else "    ??"
				gx += _step
			print(row)
			gz += _step
		quit(0)
		return
	if _mode == "cross":
		var s_c: float = _s0
		while s_c <= _s1:
			var line: String = "PROBE s=%6.1f " % s_c
			var lat: float = -14.0
			while lat <= 14.0:
				var pp: Vector3 = data.call("lateral_point", s_c, lat)
				var qq: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(pp + Vector3.UP * 30.0, pp - Vector3.UP * 30.0)
				var h2: Dictionary = space.intersect_ray(qq)
				line += "%+.0f:%s " % [lat, ("%.2f" % float(h2.get("position", Vector3.ZERO).y)) if not h2.is_empty() else "----"]
				lat += 2.0
			print(line)
			s_c += _step
		quit(0)
		return
	if _mode == "path":
		var wps: PackedVector3Array = data.get("waypoints")
		for i: int in wps.size():
			if float(i) < _s0 or float(i) > _s1:
				continue
			var a: Vector3 = wps[i]
			var b: Vector3 = wps[(i + 1) % wps.size()]
			for h: float in [0.4, 1.0, 1.9]:
				var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(a + Vector3.UP * h, b + Vector3.UP * h)
				var hh: Dictionary = space.intersect_ray(q)
				if not hh.is_empty():
					var col: Object = hh.get("collider")
					print("PROBE wp%d->%d h=%.1f CHOCA con %s a %.1f m" % [i, (i + 1) % wps.size(), h, str(col.get("name")), a.distance_to(hh.get("position"))])
			var ground: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(a + Vector3.UP * 30.0, a - Vector3.UP * 30.0)
			var gh: Dictionary = space.intersect_ray(ground)
			print("PROBE wp%d %s suelo=%.2f %s" % [i, str(a), float(gh.get("position", Vector3.ZERO).y) if not gh.is_empty() else -99.0, str(gh.get("collider").get("name")) if not gh.is_empty() else "-"])
		quit(0)
		return
	var prev: float = INF
	var s: float = _s0
	while s <= _s1:
		var p: Vector3 = data.call("lateral_point", s, _lat)
		var params: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(p + Vector3.UP * 30.0, p - Vector3.UP * 30.0)
		var hit: Dictionary = space.intersect_ray(params)
		var y: float = float(hit.get("position", Vector3(0.0, -99.0, 0.0)).y) if not hit.is_empty() else -99.0
		var who: String = "-"
		if not hit.is_empty() and hit.get("collider") != null:
			var col: Object = hit.get("collider")
			who = "%s#%d n=%.2f" % [str(col.get("name")), int(hit.get("shape", -1)), float(hit.get("normal", Vector3.UP).y)]
		var jump: String = ""
		if prev != INF and absf(y - prev) > 0.1:
			jump = "   <<< ESCALON %.2f m" % (y - prev)
		print("PROBE s=%7.1f  y=%6.2f  eje_y=%5.2f  %s%s" % [s, y, data.call("sample", s).origin.y, who, jump])
		prev = y
		s += _step
	quit(0)
