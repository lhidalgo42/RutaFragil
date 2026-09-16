class_name OsmCrosswalks
extends RefCounted

## Las cebras y las líneas de detención de las bocacalles reales (D67). Salió de OsmRoad
## para no pasar el tope de 400 líneas de R8: solo pinta malla, así que le basta el
## batcher y los datos. No se dibujan en la estación, en el pasaje, junto al paso bajo
## nivel ni en los tramos sin pavimento.

const OFFSET_M: float = 12.0


static func build(batcher: MeshBatcher, data: OsmMapData) -> void:
	for gap: Dictionary in data.curb_gaps:
		var gap_name: String = str(gap.get("name", ""))
		if gap_name == "estacion" or gap_name == "pasaje":
			continue
		var s_j: float = (float(gap.get("s0", 0.0)) + float(gap.get("s1", 0.0))) * 0.5 + OFFSET_M
		if s_j < 20.0 or s_j > data.length - 20.0 or absf(s_j - float(data.underpass.get("s", -1000.0))) < 30.0 or data.section_at(s_j) == "gravel":
			continue
		var frame: Transform3D = data.sample(s_j)
		var left: Vector3 = data.left_of(frame)
		var fwd: Vector3 = -frame.basis.z
		var avenue: bool = data.section_at(s_j) == "avenue"
		var inner: float = data.median_width * 0.5 + 0.75 if avenue else 0.25
		var bars: int = 10 if avenue else 6
		for side: float in [-1.0, 1.0]:
			for k: int in bars:
				var lat: float = side * (inner + float(k) * 1.0)
				batcher.box("paint_white", MeshBatcher.along(frame.basis, frame.origin + left * lat, Vector3(0.5, 0.02, 4.0), 0.026))
			# stop line 3 m before the crossing, in the direction of travel of that carriageway (south = eastbound)
			var stop_pos: Vector3 = frame.origin + left * (side * data.lane_at(s_j)) + fwd * (-3.0 if side < 0.0 else 3.0)
			var stop_w: float = data.carriageway_width - 0.6 if avenue else data.curb_at(s_j) - 1.0
			batcher.box("paint_white", MeshBatcher.along(frame.basis, stop_pos, Vector3(stop_w, 0.02, 0.4), 0.026))
