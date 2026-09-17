class_name RoadRibbon
extends RefCounted

## Cintas continuas de calzada (D72). Antes cada tramo era una caja rotada suelta y en
## las curvas dos cajas vecinas dejaban una cuña abierta por el lado de afuera y se
## pisaban por el de adentro: eso son los "cortes" que se ven al conectar las curvas.
## Aquí cada punto del eje aporta UNA fila de vértices que comparten los dos tramos
## vecinos, con la junta a inglete (el vector lateral promediado y alargado 1/cos(θ/2)),
## así que el ancho se mantiene en la curva y no queda junta.
##
## Emite un MeshInstance3D por color, "Ribbon_<kind>", bajo el padre. Es solo malla:
## la colisión la siguen poniendo los constructores con cajas, que no se ven.

var _surfaces: Dictionary = {}
var _counts: Dictionary = {}


## Vectores "izquierda" de cada punto, promediados con el vecino. `closed` une el
## último punto con el primero (el circuito cerrado del pueblo).
static func lefts(points: PackedVector3Array, closed: bool = false) -> PackedVector3Array:
	var out: PackedVector3Array = PackedVector3Array()
	var n: int = points.size()
	if n < 2:
		return out
	var dirs: PackedVector3Array = PackedVector3Array()
	for i: int in n - 1:
		var d: Vector3 = _flat(points[i + 1] - points[i])
		dirs.append(d.normalized() if d.length() > 0.0001 else Vector3.FORWARD)
	if closed:
		var d_close: Vector3 = _flat(points[0] - points[n - 1])
		dirs.append(d_close.normalized() if d_close.length() > 0.0001 else dirs[dirs.size() - 1])
	for i: int in n:
		var before: Vector3 = dirs[i - 1] if i > 0 else (dirs[dirs.size() - 1] if closed else dirs[0])
		var after: Vector3 = dirs[i] if i < dirs.size() else dirs[dirs.size() - 1]
		var bisector: Vector3 = (before + after)
		if bisector.length() < 0.0001:
			bisector = after   # media vuelta: no hay inglete posible, se usa el tramo que sigue
		bisector = bisector.normalized()
		var left: Vector3 = Vector3.UP.cross(bisector)
		# 1/cos(θ/2): sin esto la cinta se angosta justo en la curva y aparece el diente.
		# Tope en 0,7 (1,43 veces el ancho): con 0,35 una esquina muy cerrada disparaba el
		# vértice a casi tres anchos y la vereda se abría en un triángulo gigante (D76).
		var cos_half: float = maxf(0.7, before.dot(bisector))
		out.append(left / cos_half)
	return out


## Banda plana entre dos costados, a la altura `y`. `lat_a` va a la derecha de `lat_b`
## (lat_a < lat_b) para que la cara mire hacia arriba.
func band(kind: String, points: PackedVector3Array, left_vectors: PackedVector3Array, lat_a: float, lat_b: float, y: float) -> void:
	var st: SurfaceTool = _surface(kind)
	var up: Vector3 = Vector3.UP * y
	var run: float = 0.0
	for i: int in points.size() - 1:
		var a0: Vector3 = points[i] + left_vectors[i] * lat_a + up
		var b0: Vector3 = points[i] + left_vectors[i] * lat_b + up
		var a1: Vector3 = points[i + 1] + left_vectors[i + 1] * lat_a + up
		var b1: Vector3 = points[i + 1] + left_vectors[i + 1] * lat_b + up
		var next_run: float = run + _flat(points[i + 1] - points[i]).length()
		_quad(kind, st, a0, a1, b1, b0, run, next_run)
		run = next_run


## Cara vertical de un costado (el canto del cordón, el borde de la vereda): sin esto
## el cordón se ve como una lámina sin espesor desde el asfalto. `facing` +1 mira hacia
## el lado izquierdo del eje, -1 hacia el derecho.
func wall(kind: String, points: PackedVector3Array, left_vectors: PackedVector3Array, lat: float, y_low: float, y_high: float, facing: float = 1.0) -> void:
	var st: SurfaceTool = _surface(kind)
	var outward: float = facing
	var run: float = 0.0
	for i: int in points.size() - 1:
		var p0: Vector3 = points[i] + left_vectors[i] * lat
		var p1: Vector3 = points[i + 1] + left_vectors[i + 1] * lat
		var next_run: float = run + _flat(p1 - p0).length()
		var lo0: Vector3 = p0 + Vector3.UP * y_low
		var lo1: Vector3 = p1 + Vector3.UP * y_low
		var hi0: Vector3 = p0 + Vector3.UP * y_high
		var hi1: Vector3 = p1 + Vector3.UP * y_high
		if outward > 0.0:
			_quad(kind, st, lo0, hi0, hi1, lo1, run, next_run)
		else:
			_quad(kind, st, lo1, hi1, hi0, lo0, run, next_run)
		run = next_run


## Vértices acumulados de un color (las pruebas leen esto: bajo el renderizador
## headless no se puede leer la malla ya emitida).
func vertex_count(kind: String) -> int:
	return int(_counts.get(kind, 0))


func flush(parent: Node, colours: Dictionary) -> void:
	for kind: String in _surfaces.keys():
		var st: SurfaceTool = _surfaces[kind]
		st.generate_normals()
		# sin tangentes el mapa de normales de la textura no tiene marco y la luz sale mal
		st.generate_tangents()
		var mesh: ArrayMesh = st.commit()
		mesh.surface_set_material(0, MeshBatcher.ribbon_material(colours.get(kind, Color.MAGENTA), kind))
		var inst: MeshInstance3D = MeshInstance3D.new()
		inst.name = "Ribbon_" + kind
		inst.mesh = mesh
		parent.add_child(inst)
	_surfaces.clear()


# ---------- interno ----------

func _surface(kind: String) -> SurfaceTool:
	if not _surfaces.has(kind):
		var st: SurfaceTool = SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		_surfaces[kind] = st
		_counts[kind] = 0
	return _surfaces[kind]


## Godot toma como cara FRONTAL la que se recorre en sentido HORARIO vista de frente (al
## revés que OpenGL). Los vértices a→b→c→d vienen en sentido antihorario vistos desde la
## cara que queremos ver, así que se emiten al revés: a,c,b y a,d,c. Con el orden natural
## las calles existían y no se dibujaban — la cara de arriba era la trasera (D75).
func _quad(kind: String, st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, u0: float, u1: float) -> void:
	_vertex(st, a, Vector2(u0, 0.0))
	_vertex(st, c, Vector2(u1, 1.0))
	_vertex(st, b, Vector2(u1, 0.0))
	_vertex(st, a, Vector2(u0, 0.0))
	_vertex(st, d, Vector2(u0, 1.0))
	_vertex(st, c, Vector2(u1, 1.0))
	_counts[kind] = int(_counts[kind]) + 6


func _vertex(st: SurfaceTool, p: Vector3, uv: Vector2) -> void:
	st.set_uv(uv)
	st.add_vertex(p)


static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)
