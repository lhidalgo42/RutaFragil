"""Bioma B2 Pantano (D71): del mapa crudo del humedal del río Cruces (tools/cruces_map.osm, ODbL)
arma la ruta A->B por la Ruta T-360 y el Camino Colegual, marca las secciones por superficie real
y por cercanía al humedal (barro), y extrae el pantano entero: espejos de agua, el río San Ramón,
el puente real, el vado real, juncales, troncos muertos, hualve (bosque pantanoso de temu y pitra),
el caserío y la entrega en un muelle de tablas.
Marco de Godot: x este, z = -norte, y arriba. Escribe data/b2_pantano.json.

Decisión de fondo, medida en el pueblo (D69): el suelo NO se agujerea. El agua es una malla
transparente DIBUJADA ENCIMA del suelo plano, así el bus nunca cruza una junta entre losas y el
pantano se ve continuo, sin cortes en las conexiones. La profundidad es visual, no geométrica.
"""
import json, math, os, heapq, collections, random
import xml.etree.ElementTree as ET

HERE = os.path.dirname(os.path.abspath(__file__))
MAP = os.path.join(HERE, 'cruces_map.osm')
LAT0, LON0 = -39.731853, -73.256453          # centroide de los humedales del santuario
VENTANA = (-4600.0, -1400.0, 400.0, 3000.0)  # x0, x1, z0, z1: el corazón del pantano
AGUA_Y = 0.04                                 # la lámina de agua, 4 cm SOBRE el suelo: bajo el suelo
                                              # quedaba escondida dentro de la caja del terreno (medido 2026-09-16)
MUD_CERCA_M = 100.0                           # tierra a menos de esto del humedal = barro (medido: 34% de la ruta)

def xy(lat, lon): return ((lon - LON0) * 111320 * math.cos(math.radians(LAT0)), (lat - LAT0) * 110574)
def g(p): return (p[0], -p[1])

root = ET.parse(MAP).getroot()
nodes = {n.get('id'): xy(float(n.get('lat')), float(n.get('lon'))) for n in root.iter('node')}
ntags = {n.get('id'): {t.get('k'): t.get('v') for t in n.findall('tag')} for n in root.iter('node') if n.find('tag') is not None}
ways = {w.get('id'): ({t.get('k'): t.get('v') for t in w.findall('tag')}, [r.get('ref') for r in w.findall('nd') if r.get('ref') in nodes]) for w in root.iter('way')}
print('mapa: nodos', len(nodes), 'ways', len(ways))

def en_ventana(p):
    q = g(p)
    return VENTANA[0] < q[0] < VENTANA[1] and VENTANA[2] < q[1] < VENTANA[3]

# ---------------- humedales: polígonos y un índice de rejilla ----------------
humedales = []
for wid, (t, refs) in ways.items():
    if t.get('natural') != 'wetland' or len(refs) < 4: continue
    poly = [g(nodes[r]) for r in refs]
    if any(VENTANA[0] - 400 < q[0] < VENTANA[1] + 400 and VENTANA[2] - 400 < q[1] < VENTANA[3] + 400 for q in poly):
        humedales.append(poly)
CEL = 100.0
rej = collections.defaultdict(list)
for poly in humedales:
    for a, b in zip(poly, poly[1:] + poly[:1]):
        for k in {(int(a[0] // CEL), int(a[1] // CEL)), (int(b[0] // CEL), int(b[1] // CEL))}: rej[k].append((a, b))
def dist_humedal(p):
    mejor = 1e9
    cx, cz = int(p[0] // CEL), int(p[1] // CEL)
    for i in (-1, 0, 1):
        for j in (-1, 0, 1):
            for a, b in rej.get((cx + i, cz + j), ()):
                dx, dz = b[0] - a[0], b[1] - a[1]; ll = dx * dx + dz * dz
                u = 0.0 if ll < 1e-9 else max(0.0, min(1.0, ((p[0] - a[0]) * dx + (p[1] - a[1]) * dz) / ll))
                mejor = min(mejor, math.hypot(p[0] - a[0] - dx * u, p[1] - a[1] - dz * u))
    return mejor
def dentro_poly(poly, x, z):
    hit = False; n = len(poly)
    for i in range(n):
        x1, z1 = poly[i]; x2, z2 = poly[(i + 1) % n]
        if (z1 > z) != (z2 > z) and x < x1 + (z - z1) / (z2 - z1 + 1e-12) * (x2 - x1): hit = not hit
    return hit
def en_humedal(x, z): return any(dentro_poly(p, x, z) for p in humedales)
print('humedales en la ventana:', len(humedales))

# ---------------- ruta: cadena A->B por la T-360 y el Camino Colegual ----------------
DRIVE = {'tertiary': 1.0, 'unclassified': 1.0, 'residential': 1.3, 'service': 1.8, 'track': 1.2, 'living_street': 1.5}
G = collections.defaultdict(list)
for wid, (t, refs) in ways.items():
    pen = DRIVE.get(t.get('highway'))
    if pen is None: continue
    for a, b in zip(refs, refs[1:]):
        pa, pb = g(nodes[a]), g(nodes[b])
        if not (en_ventana(nodes[a]) or en_ventana(nodes[b])): continue
        d = math.dist(pa, pb)
        m = ((pa[0] + pb[0]) * 0.5, (pa[1] + pb[1]) * 0.5)
        c = d * pen * (0.5 if dist_humedal(m) < 120 else 1.0)     # premia lo que va pegado al pantano
        G[a].append((b, c, wid)); G[b].append((a, c, wid))
def nodo_en(x, z): return min(G, key=lambda k: math.dist(g(nodes[k]), (x, z)))
VIAS = [(-1850, 1180), (-3402, 1893), (-4350, 2500), (-3900, 1200)]   # oriente, el puente real, el fondo del pantano y la vuelta por el norte
cadena = []; wl = []
for p1, p2 in zip(VIAS, VIAS[1:]):
    a, b = nodo_en(*p1), nodo_en(*p2)
    dist = {a: 0.0}; prev = {}; pq = [(0.0, a)]
    while pq:
        c, u = heapq.heappop(pq)
        if u == b: break
        if c > dist.get(u, 1e18): continue
        for v, cost, wid in G[u]:
            nc = c + cost
            if nc < dist.get(v, 1e18): dist[v] = nc; prev[v] = (u, wid); heapq.heappush(pq, (nc, v))
    if b not in prev and b != a: print('  sin camino entre', p1, p2); continue
    pn = [b]; u = b; wa = []
    while u != a: u, wid = prev[u][0], prev[u][1]; pn.append(u); wa.append(wid)
    pn.reverse(); wa.reverse()
    cadena += pn if not cadena else pn[1:]
    wl += wa
raw = [g(nodes[k]) for k in cadena]
largo_raw = sum(math.dist(a, b) for a, b in zip(raw, raw[1:]))
nombres = []
for wid in wl:
    n = ways[wid][0].get('name') or '(sin nombre) ' + ways[wid][0].get('highway', '')
    if not nombres or nombres[-1] != n: nombres.append(n)
print('cadena cruda: %d nodos, %.0f m' % (len(raw), largo_raw))
print('por dónde va:', ' -> '.join(nombres))
sup = collections.Counter(ways[w][0].get('surface', '(sin dato)') for w in wl)
print('superficies:', dict(sup))
barro = sum(math.dist(g(nodes[a]), g(nodes[b])) for a, b, w in zip(cadena, cadena[1:], wl)
            if ways[w][0].get('surface') in ('unpaved', 'dirt', 'ground', None) and dist_humedal(((g(nodes[a])[0] + g(nodes[b])[0]) / 2, (g(nodes[a])[1] + g(nodes[b])[1]) / 2)) < MUD_CERCA_M)
print('metros que darían BARRO (tierra a menos de %d m del humedal): %.0f' % (MUD_CERCA_M, barro))

# ---------------- suavizado: mismo método que el pueblo (D69) ----------------
def simplify(pts, tol=2.0):
    keep = [False] * len(pts); keep[0] = keep[-1] = True
    def rec(i0, i1):
        if i1 <= i0 + 1: return
        a, b = pts[i0], pts[i1]; ab = (b[0] - a[0], b[1] - a[1]); l2 = ab[0] ** 2 + ab[1] ** 2
        worst, wi = -1.0, -1
        for i in range(i0 + 1, i1):
            q = pts[i]
            if l2 < 1e-9: d = math.dist(q, a)
            else:
                u = max(0.0, min(1.0, ((q[0] - a[0]) * ab[0] + (q[1] - a[1]) * ab[1]) / l2))
                d = math.dist(q, (a[0] + ab[0] * u, a[1] + ab[1] * u))
            if d > worst: worst, wi = d, i
        if worst > tol: keep[wi] = True; rec(i0, wi); rec(wi, i1)
    rec(0, len(pts) - 1)
    return [q for q, k in zip(pts, keep) if k]
def prune(pts, min_leg=15.0):
    out = [pts[0]]
    for q in pts[1:-1]:
        if math.dist(q, out[-1]) >= min_leg: out.append(q)
    while len(out) > 2 and math.dist(out[-1], pts[-1]) < min_leg: out.pop()
    out.append(pts[-1]); return out
def fillet(pts, min_turn_deg=18.0):
    out = [pts[0]]
    for i in range(1, len(pts) - 1):
        a, b, c = pts[i - 1], pts[i], pts[i + 1]
        u = (b[0] - a[0], b[1] - a[1]); v = (c[0] - b[0], c[1] - b[1])
        lu, lv = math.hypot(*u), math.hypot(*v)
        if lu < 1e-6 or lv < 1e-6: continue
        u = (u[0] / lu, u[1] / lu); v = (v[0] / lv, v[1] / lv)
        theta = math.acos(max(-1.0, min(1.0, u[0] * v[0] + u[1] * v[1])))
        deg = math.degrees(theta)
        if deg < min_turn_deg: out.append(b); continue
        # radio según el ángulo, la lección del pueblo: la curva suave de un camino rural es amplia
        r_max = 48.0 if deg < 40.0 else (34.0 if deg < 60.0 else (22.0 if deg < 80.0 else 16.0))
        r = min(r_max, 0.45 * min(lu, lv) / max(1e-6, math.tan(theta / 2.0))); T = r * math.tan(theta / 2.0)
        p1 = (b[0] - u[0] * T, b[1] - u[1] * T); p2 = (b[0] + v[0] * T, b[1] + v[1] * T)
        cross = u[0] * v[1] - u[1] * v[0]; nrm = (-u[1], u[0]) if cross > 0 else (u[1], -u[0])
        o = (p1[0] + nrm[0] * r, p1[1] + nrm[1] * r)
        a1 = math.atan2(p1[1] - o[1], p1[0] - o[0]); a2 = math.atan2(p2[1] - o[1], p2[0] - o[0])
        da = (a2 - a1 + math.pi) % (2 * math.pi) - math.pi
        steps = max(2, int(abs(da) * r / 6.0))
        out += [(o[0] + r * math.cos(a1 + da * k / steps), o[1] + r * math.sin(a1 + da * k / steps)) for k in range(steps + 1)]
    out.append(pts[-1]); return out
def resample(pts, step=10.0):
    total = sum(math.dist(a, b) for a, b in zip(pts, pts[1:]))
    out = [pts[0]]; acc = 0.0; target = step
    for a, b in zip(pts, pts[1:]):
        seg = math.dist(a, b)
        while target <= acc + seg + 1e-9 and target < total:
            u = (target - acc) / max(1e-9, seg)
            out.append((a[0] + (b[0] - a[0]) * u, a[1] + (b[1] - a[1]) * u)); target += step
        acc += seg
    out.append(pts[-1]); return out

# superficie y nombre de cada tramo crudo, para asignar por proyección
raw_sec, raw_name = ['gravel'], ['?']
for wid in wl:
    tg = ways[wid][0]
    if tg.get('bridge'): s = 'bridge'
    elif tg.get('surface') == 'asphalt': s = 'street'
    else: s = 'gravel'
    raw_sec.append(s); raw_name.append(tg.get('name', '?'))
raw_segs = [(raw[i], raw[i + 1], raw_sec[i + 1], raw_name[i + 1]) for i in range(len(raw) - 1)]
def cerca_raw(q):
    best, bs, bn = 1e18, 'gravel', '?'
    for a, b, s, n in raw_segs:
        ab = (b[0] - a[0], b[1] - a[1]); l2 = ab[0] ** 2 + ab[1] ** 2
        u = 0.0 if l2 < 1e-9 else max(0.0, min(1.0, ((q[0] - a[0]) * ab[0] + (q[1] - a[1]) * ab[1]) / l2))
        d = math.dist(q, (a[0] + ab[0] * u, a[1] + ab[1] * u))
        if d < best: best, bs, bn = d, s, n
    return bs, bn

def teardrop(origin, f, n, scale=1.0):
    """Vuelta en punta: llega, se abre a la derecha, gira y sale por el otro lado."""
    return [(origin[0] + (f[0] * ds + n[0] * lt) * scale, origin[1] + (f[1] * ds + n[1] * lt) * scale)
            for ds, lt in [(26, -14), (47, -21), (64, -10), (72, 5), (64, 21), (47, 26), (29, 18), (10, 10)]]
def insert_turnarounds(pts):
    """Un camino sin salida del pantano se recorre entrando y saliendo: sin esto la cadena
    se dobla 180° sobre sí misma y el bus no puede seguirla (medido en el pueblo, D69)."""
    out, centros = [pts[0]], []
    for i in range(1, len(pts) - 1):
        a, b, c = pts[i - 1], pts[i], pts[i + 1]
        u = (b[0] - a[0], b[1] - a[1]); v = (c[0] - b[0], c[1] - b[1])
        lu, lv = math.hypot(*u), math.hypot(*v)
        if lu < 1e-6 or lv < 1e-6: continue
        if math.degrees(math.acos(max(-1.0, min(1.0, (u[0] * v[0] + u[1] * v[1]) / (lu * lv))))) > 150:
            f = (u[0] / lu, u[1] / lu); out += teardrop(b, f, (-f[1], f[0])); centros.append(b)
        else: out.append(b)
    out.append(pts[-1]); return out, centros
limpio, vueltas = insert_turnarounds(simplify(raw))
print('vueltas en punta:', len(vueltas), [tuple(round(v) for v in c) for c in vueltas])
axis = resample(fillet(prune(limpio)), 10.0)
asec, anames = zip(*[cerca_raw(q) for q in axis]); asec, anames = list(asec), list(anames)
# barro: tierra pegada al humedal
for i, q in enumerate(axis):
    if asec[i] == 'gravel' and dist_humedal(q) < MUD_CERCA_M: asec[i] = 'mud'
cum = [0.0]
for a, b in zip(axis, axis[1:]): cum.append(cum[-1] + math.dist(a, b))
L = cum[-1]
turns = [abs((math.degrees(math.atan2(c[1] - b[1], c[0] - b[0]) - math.atan2(b[1] - a[1], b[0] - a[0])) + 180) % 360 - 180)
         for a, b, c in zip(axis, axis[1:], axis[2:])]
print('eje: %d puntos, %.0f m, giro máximo %.1f°' % (len(axis), L, max(turns)))

def sample(s):
    n = len(axis) - 1; s = max(0.0, min(s, L))
    i = next((k for k in range(n) if s <= cum[k + 1] + 1e-9), n - 1)
    (x1, z1), (x2, z2) = axis[i], axis[i + 1]
    u = (s - cum[i]) / max(1e-6, cum[i + 1] - cum[i])
    tx, tz = x2 - x1, z2 - z1; nn = math.hypot(tx, tz) or 1.0
    return (x1 + (x2 - x1) * u, z1 + (z2 - z1) * u), (tx / nn, tz / nn), (tz / nn, -tx / nn)
def off(s, lat):
    (px, pz), _, (nx, nz) = sample(s); return (px + nx * lat, pz + nz * lat)
def project(x, z):
    best = (1e18, 0.0, 0.0)
    for i in range(len(axis) - 1):
        (x1, z1), (x2, z2) = axis[i], axis[i + 1]; dx, dz = x2 - x1, z2 - z1; ll = dx * dx + dz * dz
        if ll < 1e-9: continue
        sl = math.sqrt(ll); u = max(0.0, min(1.0, ((x - x1) * dx + (z - z1) * dz) / ll))
        px, pz = x1 + dx * u, z1 + dz * u; d = math.hypot(x - px, z - pz)
        if d < best[0]:
            # El costado firmado NO puede salir de la normal del tramo: si el punto más
            # cercano cae en un EXTREMO, esa componente es menor que la distancia real y un
            # edificio a 7,7 km pasaba como si estuviera a 96 m (medido en B2, 2026-09-16).
            perp = (x - px) * (dz / sl) + (z - pz) * (-dx / sl)
            best = (d, cum[i] + sl * u, math.copysign(d, perp if perp != 0.0 else 1.0))
    return best[1], best[2]
def yaw_facing(tx, tz): return math.atan2(-tx, -tz)

# ---------------- secciones, fundiendo astillas ----------------
sections = []
for i in range(len(axis) - 1):
    ty = asec[i + 1]
    if sections and sections[-1]['type'] == ty: sections[-1]['s1'] = round(cum[i + 1], 1)
    else: sections.append({'s0': round(cum[i], 1), 's1': round(cum[i + 1], 1), 'type': ty})
merged = []
for sc in sections:
    if sc['s1'] - sc['s0'] < 30.0 and sc['type'] != 'bridge' and merged: merged[-1]['s1'] = sc['s1']
    elif merged and merged[-1]['type'] == sc['type']: merged[-1]['s1'] = sc['s1']
    else: merged.append(sc)
sections = merged
def sec_at(s):
    for sc in sections:
        if sc['s0'] - 0.01 <= s <= sc['s1'] + 0.01: return sc['type']
    return 'gravel'
LANE = {'street': 3.0, 'gravel': 2.6, 'mud': 2.4, 'bridge': 2.6, 'ford': 2.6, 'causeway': 2.2}
CURB = {'street': 5.5, 'gravel': 5.0, 'mud': 4.6, 'bridge': 4.0, 'ford': 5.0, 'causeway': 3.4}
PROP = {'street': 8.0, 'gravel': 7.0, 'mud': 6.5, 'bridge': 4.2, 'ford': 7.0, 'causeway': 5.0}
print('secciones:', [(sc['type'], round(sc['s1'] - sc['s0'])) for sc in sections])
print('metros por tipo:', {k: round(sum(sc['s1'] - sc['s0'] for sc in sections if sc['type'] == k)) for k in set(sc['type'] for sc in sections)})

# ================= el pantano =================
random.seed(1960)   # el año del terremoto que hundió estas riberas

# ---- vados: donde el camino cruza un curso de agua y no hay puente ----
def seg_x(p, p2, q, q2):
    d = (p2[0] - p[0]) * (q2[1] - q[1]) - (p2[1] - p[1]) * (q2[0] - q[0])
    if abs(d) < 1e-9: return None
    t_ = ((q[0] - p[0]) * (q2[1] - q[1]) - (q[1] - p[1]) * (q2[0] - q[0])) / d
    u_ = ((q[0] - p[0]) * (p2[1] - p[1]) - (q[1] - p[1]) * (p2[0] - p[0])) / d
    return (p[0] + t_ * (p2[0] - p[0]), p[1] + t_ * (p2[1] - p[1])) if 0 <= t_ <= 1 and 0 <= u_ <= 1 else None
cursos = []
for wid, (tg, refs) in ways.items():
    if tg.get('waterway') not in ('river', 'stream', 'ditch', 'canal') or len(refs) < 2: continue
    pts = [g(nodes[r]) for r in refs]
    if any(VENTANA[0] - 300 < q[0] < VENTANA[1] + 300 and VENTANA[2] - 300 < q[1] < VENTANA[3] + 300 for q in pts):
        cursos.append({'name': tg.get('name', ''), 'kind': tg['waterway'], 'pts': pts,
                       'w': 18.0 if tg['waterway'] == 'river' else 7.0})
fords = []
for i in range(len(axis) - 1):
    for c in cursos:
        for q, q2 in zip(c['pts'], c['pts'][1:]):
            ip = seg_x(axis[i], axis[i + 1], q, q2)
            if not ip: continue
            s_f, _ = project(*ip)
            if sec_at(s_f) == 'bridge' or any(abs(f['s'] - s_f) < 40 for f in fords): continue
            fords.append({'s': round(s_f, 1), 'x': round(ip[0], 1), 'z': round(ip[1], 1),
                          'w': c['w'], 'name': c['name'] or c['kind']})
# el vado etiquetado a mano en OSM
for nid, tg in ntags.items():
    if tg.get('ford') in ('yes', 'stepping_stones') and nid in nodes:
        q = g(nodes[nid]); s_f, lat = project(*q)
        if abs(lat) < 25 and not any(abs(f['s'] - s_f) < 40 for f in fords):
            fords.append({'s': round(s_f, 1), 'x': round(q[0], 1), 'z': round(q[1], 1), 'w': 8.0, 'name': 'vado'})
fords.sort(key=lambda f: f['s'])
# Si OSM marca puente pero no mapeó el curso, el estero se deduce: un puente existe
# porque hay agua debajo. Sin esto el puente cruzaba pasto seco (foto del 16 sep 2026).
for sc in sections:
    if sc['type'] != 'bridge': continue
    s_b = (sc['s0'] + sc['s1']) * 0.5
    luz = sc['s1'] - sc['s0']
    cruza = [c for c in cursos if any(abs(project(*q)[0] - s_b) < 60 and abs(project(*q)[1]) < 40 for q in c['pts'])]
    if cruza:
        # un puente de 30 m no se construye sobre un estero de 7: el brazo es ancho
        for c in cruza:
            if c['w'] < luz - 6.0:
                print('ensanchado %s de %.0f a %.0f m: es lo que cruza el puente de %.0f m' % (c['name'] or c['kind'], c['w'], luz - 6.0, luz))
                c['w'] = luz - 6.0
        continue
    (px, pz), _, (nx, nz) = sample(s_b)
    pts = []
    for lado in (-1.0, 1.0):
        for k in range(9):
            d = lado * (12.0 + k * 17.0)
            desv = math.sin(k * 0.8 + lado) * 9.0
            (ax_, az_) = off(s_b + desv, d)
            pts.append((ax_, az_))
    pts.sort(key=lambda q: (q[0] - px) * nx + (q[1] - pz) * nz)
    cursos.append({'name': 'estero sin nombre', 'kind': 'stream', 'pts': pts, 'w': max(9.0, sc['s1'] - sc['s0'] - 6.0)})
    print('estero deducido bajo el puente en s=%.0f, %.0f m de ancho' % (s_b, max(9.0, sc['s1'] - sc['s0'] - 6.0)))
# ---- pasarela de tablas sobre el barro más largo (añadido de diseño) ----
barros = sorted([sc for sc in sections if sc['type'] == 'mud'], key=lambda sc: sc['s0'] - sc['s1'])
causeway = {}
if barros:
    sc = barros[0]; mid = (sc['s0'] + sc['s1']) * 0.5
    causeway = {'s0': round(mid - 34, 1), 's1': round(mid + 34, 1)}
# los vados y la pasarela se meten en la lista de secciones
def partir(s0, s1, tipo):
    global sections
    nuevas = []
    for sc in sections:
        if s1 <= sc['s0'] or s0 >= sc['s1']: nuevas.append(sc); continue
        if sc['s0'] < s0: nuevas.append({'s0': sc['s0'], 's1': round(s0, 1), 'type': sc['type']})
        nuevas.append({'s0': round(s0, 1), 's1': round(s1, 1), 'type': tipo})
        if sc['s1'] > s1: nuevas.append({'s0': round(s1, 1), 's1': sc['s1'], 'type': sc['type']})
    sections = [sc for sc in nuevas if sc['s1'] - sc['s0'] > 0.5]
for f in fords: partir(f['s'] - 7, f['s'] + 7, 'ford')
if causeway: partir(causeway['s0'], causeway['s1'], 'causeway')
print('vados:', [(round(f['s']), f['name']) for f in fords], '| pasarela:', causeway)

# ---- el agua: polígonos del humedal y de los cursos, todos al mismo nivel ----
def recortar(poly):
    return [[round(q[0], 1), round(q[1], 1)] for q in poly]
aguas = []
for poly in humedales:
    if len(poly) < 4: continue
    cx = sum(q[0] for q in poly) / len(poly); cz = sum(q[1] for q in poly) / len(poly)
    if not (VENTANA[0] - 300 < cx < VENTANA[1] + 300 and VENTANA[2] - 300 < cz < VENTANA[3] + 300): continue
    aguas.append({'kind': 'marsh', 'polygon': recortar(poly)})
for c in cursos:
    izq, der = [], []
    for a, b in zip(c['pts'], c['pts'][1:]):
        dx, dz = b[0] - a[0], b[1] - a[1]; n = math.hypot(dx, dz) or 1.0
        nx, nz = dz / n, -dx / n
        izq += [(a[0] + nx * c['w'] * 0.5, a[1] + nz * c['w'] * 0.5), (b[0] + nx * c['w'] * 0.5, b[1] + nz * c['w'] * 0.5)]
        der += [(a[0] - nx * c['w'] * 0.5, a[1] - nz * c['w'] * 0.5), (b[0] - nx * c['w'] * 0.5, b[1] - nz * c['w'] * 0.5)]
    aguas.append({'kind': 'channel', 'polygon': recortar(izq + der[::-1]), 'name': c['name']})
# ---- la orilla inundada del camino: OSM solo mapea los paños grandes, pero la huella
# ---- cruza pradera mojada. Se inunda la orilla de cada tramo de barro, que es justo el
# ---- que se clasificó por estar pegado al humedal. Sin esto el pantano no se ve desde el camino.
def borde_inundado(s0, s1, lado, ancho_max):
    izq, der = [], []
    s = s0
    while s <= s1:
        (px, pz), _, (nx, nz) = sample(s)
        base = PROP[sec_at(s)] + 1.0 + 5.0 * (0.5 + 0.5 * math.sin(s * 0.019 + lado))
        # el ancho respira con la distancia real al humedal: más cerca, más agua
        d = dist_humedal((px + nx * lado * base, pz + nz * lado * base))
        ancho = max(18.0, min(ancho_max, ancho_max * (1.0 - min(1.0, d / (MUD_CERCA_M * 1.6)))))
        ancho *= 0.75 + 0.5 * abs(math.sin(s * 0.011))     # la orilla no es recta
        izq.append((px + nx * lado * base, pz + nz * lado * base))
        der.append((px + nx * lado * (base + ancho), pz + nz * lado * (base + ancho)))
        s += 14.0
    if len(izq) < 3: return None
    return izq + der[::-1]
inundadas = []
for sc in sections:
    if sc['type'] not in ('mud', 'ford', 'causeway'): continue
    if sc['s1'] - sc['s0'] < 40: continue
    for lado in (1.0, -1.0):
        poly = borde_inundado(sc['s0'] - 10, sc['s1'] + 10, lado, 110.0)
        if poly: inundadas.append({'kind': 'flood', 'polygon': recortar(poly)})
aguas += inundadas
print('orillas inundadas generadas:', len(inundadas))

# ---- el agua NO pisa la huella: los paños de OSM cruzan el camino y quedaban dibujados
# ---- encima de la calzada (visto el 16 sep 2026 en la foto del vado). Se subdivide el
# ---- borde cada 4 m y todo vértice que cae dentro del corredor se empuja hasta el
# ---- deslinde de su propio lado. El único agua sobre la huella es la del vado, que la
# ---- dibuja swamp_road a propósito.
def fuera_del_corredor(poly, soltar=False):
    fino = []
    for a, b in zip(poly, poly[1:] + poly[:1]):
        fino.append(a)
        largo = math.dist(a, b)
        # solo se afina el borde que puede tocar la huella: subdividir paños de
        # kilómetros de perímetro a 4 m triplicaba el archivo por nada
        if largo > 4.0 and min(abs(project(*a)[1]), abs(project(*b)[1])) < 200.0:
            n = int(largo // 4.0)
            for k in range(1, n): fino.append((a[0] + (b[0] - a[0]) * k / n, a[1] + (b[1] - a[1]) * k / n))
    out, movidos = [], 0
    for q in fino:
        s_q, lat = project(*q)
        # bajo el puente y en el vado el agua SÍ cruza: sacarla de ahí dejaba un
        # puente sobre tierra seca (visto en la foto del puente, 16 sep 2026)
        if sec_at(s_q) in ('bridge', 'ford'): out.append(q); continue
        libre = PROP[sec_at(s_q)] + 2.0
        if abs(lat) >= libre: out.append(q); continue
        movidos += 1
        if soltar: continue      # los que no salen (vuelta en punta: el camino se abraza) se sueltan
        signo = 1.0 if lat >= 0 else -1.0
        # se pasa 2 m del deslinde: en el interior de una curva, un punto puesto justo
        # en el deslinde vuelve a medir "dentro" contra el tramo siguiente y la pasada
        # siguiente lo empujaba otra vez (no convergía)
        out.append(off(s_q, signo * (libre + 2.0)))
    return out, movidos
# Se repite: al empujar los dos extremos de una arista a lados opuestos, la arista
# sigue cruzando la calzada. La segunda pasada la subdivide y empuja el medio.
for pasada in range(3):
    total_movidos = 0
    for a in aguas:
        poly, mv = fuera_del_corredor([(q[0], q[1]) for q in a['polygon']], soltar=(pasada == 2))
        total_movidos += mv
        a['polygon'] = recortar(poly)
    print('pasada %d: %d vértices de agua %s' % (pasada + 1, total_movidos, 'soltados' if pasada == 2 else 'empujados fuera de la huella'))
    if total_movidos == 0: break
print('espejos de agua: %d paños de humedal y %d cursos' % (sum(1 for a in aguas if a['kind'] == 'marsh'), sum(1 for a in aguas if a['kind'] == 'channel')))

# ---- juncales, troncos muertos y hualve ----
juncos, troncos, hualve = [], [], []
rnd = random.Random(1960)
# primero la orilla del camino (es lo que se ve desde la huella), después los paños grandes
# El paso crece con la distancia al eje: el presupuesto se reparte por TODO el
# recorrido en vez de gastarse entero en el primer paño (medido: 3,7 km de los
# 6,1 quedaban sin un solo junco porque el tope de 16.000 se agotaba antes).
def dist_eje(poly):
    return min(abs(project(q[0], q[1])[1]) for q in poly[::max(1, len(poly) // 24)])
manchas = [a for a in aguas if a['kind'] in ('marsh', 'flood')]
for a in manchas: a['_d'] = dist_eje([(q[0], q[1]) for q in a['polygon']])
for a in sorted(manchas, key=lambda a: a['_d']):
    poly = [(q[0], q[1]) for q in a['polygon']]
    xs = [q[0] for q in poly]; zs = [q[1] for q in poly]
    paso = 2.2 if a['_d'] < 130 else (5.0 if a['_d'] < 280 else 11.0)
    del a['_d']
    x = min(xs)
    while x < max(xs) and len(juncos) < 26000:
        z = min(zs)
        while z < max(zs) and len(juncos) < 26000:
            q = (x + rnd.uniform(-1.1, 1.1), z + rnd.uniform(-1.1, 1.1))
            if dentro_poly(poly, *q) and abs(project(*q)[1]) > PROP[sec_at(project(*q)[0])] + 1.5:
                juncos.append([round(q[0], 1), round(q[1], 1)])
                if rnd.random() < 0.035 and len(troncos) < 500 and abs(project(*q)[1]) > PROP[sec_at(project(*q)[0])] + 6.0:
                    troncos.append([round(q[0], 1), round(q[1], 1), round(rnd.uniform(2.5, 7.5), 1), round(rnd.uniform(0.0, 0.25), 2)])
            z += paso
        x += paso
for wid, (tg, refs) in ways.items():
    if tg.get('natural') not in ('wood', 'scrub') and tg.get('landuse') != 'forest': continue
    if len(refs) < 4: continue
    poly = [g(nodes[r]) for r in refs]
    xs = [q[0] for q in poly]; zs = [q[1] for q in poly]
    if max(xs) < VENTANA[0] or min(xs) > VENTANA[1] or max(zs) < VENTANA[2] or min(zs) > VENTANA[3]: continue
    alto = tg.get('natural') != 'scrub'
    x = min(xs)
    while x < max(xs) and len(hualve) < 2600:
        z = min(zs)
        while z < max(zs) and len(hualve) < 2600:
            q = (x + rnd.uniform(-2.0, 2.0), z + rnd.uniform(-2.0, 2.0))
            if dentro_poly(poly, *q) and abs(project(*q)[1]) > 9.0:
                # temu y pitra: siempreverdes de 7 a 15 m, copa cerrada; el matorral queda bajo
                hualve.append([round(q[0], 1), round(q[1], 1), round(rnd.uniform(7.0, 15.0) if alto else rnd.uniform(1.8, 3.2), 1)])
            z += 6.5 if alto else 4.0
        x += 6.5 if alto else 4.0
# el hualve del borde: temu y pitra con los pies en el agua, al filo de la orilla inundada
for a in aguas:
    if a['kind'] != 'flood' or len(hualve) > 3200: continue
    poly = [(q[0], q[1]) for q in a['polygon']]
    n = len(poly) // 2
    for k in range(0, n, 3):
        q = poly[n + k // 1] if n + k < len(poly) else poly[-1]
        if abs(project(*q)[1]) < PROP[sec_at(project(*q)[0])] + 3.0: continue
        hualve.append([round(q[0] + rnd.uniform(-4, 4), 1), round(q[1] + rnd.uniform(-4, 4), 1), round(rnd.uniform(7.0, 15.0), 1)])
print('juncales %d | troncos muertos %d | hualve %d árboles' % (len(juncos), len(troncos), len(hualve)))

# ---- la pradera seca: 3,7 de los 6,1 km del camino NO van por el humedal, van por
# ---- potrero. Sin cercos ni árboles esos tramos se veían como una plancha verde vacía
# ---- (medido el 16 sep 2026 en la foto del km 1,15). Cerco de alambre a la línea de
# ---- deslinde, matorral pegado al cerco y árboles sueltos, como el potrero valdiviano.
cercos, pradera = [], []
secos = []
s_p = 0.0
while s_p < L:
    (px, pz), _, _ = sample(s_p)
    seco = dist_humedal((px, pz)) > MUD_CERCA_M * 0.9 and sec_at(s_p) not in ('ford', 'causeway', 'bridge')
    if seco and secos and s_p - secos[-1][1] < 12.0: secos[-1][1] = s_p
    elif seco: secos.append([s_p, s_p])
    s_p += 10.0
secos = [t for t in secos if t[1] - t[0] > 60.0]
for s0, s1 in secos:
    for lado in (1.0, -1.0):
        pts, s_f = [], s0
        while s_f <= s1:
            base = PROP[sec_at(s_f)] + 2.0
            q = off(s_f, lado * base)
            pts.append([round(q[0], 1), round(q[1], 1)])
            s_f += 10.0
        # un portillo cada 140 m: el cerco continuo de 2 km no existe en el campo
        corte = int(14)
        for k in range(0, len(pts), corte):
            tramo = pts[k:k + corte - 1]
            if len(tramo) > 2: cercos.append({'side': int(lado), 'pts': tramo})
    # matorral pegado al cerco y árboles sueltos más adentro
    s_f = s0
    while s_f <= s1:
        base = PROP[sec_at(s_f)]
        lado = 1.0 if rnd.random() < 0.5 else -1.0
        q = off(s_f + rnd.uniform(-4, 4), lado * (base + rnd.uniform(3.0, 11.0)))
        pradera.append([round(q[0], 1), round(q[1], 1), round(rnd.uniform(1.3, 2.9), 1)])
        if rnd.random() < 0.34:
            lado = 1.0 if rnd.random() < 0.5 else -1.0
            q = off(s_f + rnd.uniform(-8, 8), lado * (base + rnd.uniform(9.0, 26.0)))
            pradera.append([round(q[0], 1), round(q[1], 1), round(rnd.uniform(7.5, 13.5), 1)])
        s_f += 16.0
    # cortinas cortavientos: hileras de doce árboles perpendiculares, cada 240 m
    s_f = s0 + 120.0
    while s_f < s1 - 60.0:
        lado = 1.0 if int(s_f) % 2 == 0 else -1.0
        for k in range(12):
            q = off(s_f + k * 7.0, lado * (PROP[sec_at(s_f)] + 34.0 + rnd.uniform(-2, 2)))
            pradera.append([round(q[0], 1), round(q[1], 1), round(rnd.uniform(9.0, 14.0), 1)])
        s_f += 240.0
print('pradera seca: %d tramos, %.0f m | %d corridas de cerco | %d árboles y matas' %
      (len(secos), sum(t[1] - t[0] for t in secos), len(cercos), len(pradera)))

# ---- lianas sobre el camino, donde el hualve se cierra (mecánica de la biblia) ----
lianas = []
# El hualve se cierra sobre la huella: se ponen en los tramos de barro, que son los que van
# metidos en el pantano, cada 500 m y hasta cinco. La mecánica de cortarlas es de la biblia.
s_l = 200.0
while s_l < L - 200.0 and len(lianas) < 5:
    if sec_at(s_l) == 'mud' and (not lianas or s_l - lianas[-1]['s'] > 500):
        lianas.append({'s': round(s_l, 1), 'kind': 'liana'})
    s_l += 25.0
print('lianas que cierran el camino:', len(lianas))

# ---- portones reales, caserío y el muelle de la entrega ----
portones = []
for nid, tg in ntags.items():
    if tg.get('barrier') == 'gate' and nid in nodes:
        q = g(nodes[nid]); s_p, lat = project(*q)
        if abs(lat) < 30: portones.append({'x': round(q[0], 1), 'z': round(q[1], 1), 'yaw': round(yaw_facing(*sample(s_p)[1]), 4)})
def obb(poly):
    best = None
    for (x1, y1), (x2, y2) in zip(poly, poly[1:]):
        ang = math.atan2(y2 - y1, x2 - x1); c, s_ = math.cos(-ang), math.sin(-ang)
        rot = [(x * c - y * s_, x * s_ + y * c) for x, y in poly]
        w = max(q[0] for q in rot) - min(q[0] for q in rot); h = max(q[1] for q in rot) - min(q[1] for q in rot)
        if best is None or w * h < best[0]:
            cx = (max(q[0] for q in rot) + min(q[0] for q in rot)) / 2; cy = (max(q[1] for q in rot) + min(q[1] for q in rot)) / 2
            c2, s2 = math.cos(ang), math.sin(ang); best = (w * h, (cx * c2 - cy * s2, cx * s2 + cy * c2), (w, h), ang)
    return best
def clear_of_axis(cx, cz, w, d, yaw, margen=0.8):
    c_, s_ = math.cos(-yaw), math.sin(-yaw)
    for sx in (-1, 1):
        for sz in (-1, 1):
            px = cx + sx * w / 2 * c_ + sz * d / 2 * s_
            pz = cz - sx * w / 2 * s_ + sz * d / 2 * c_
            s_p, lat = project(px, pz)
            if abs(lat) < PROP[sec_at(s_p)] + margen: return False
    return True
blds = []; descartados = 0
for wid, (tg, refs) in ways.items():
    if 'building' not in tg or len(refs) < 4: continue
    poly = [nodes[r] for r in refs]
    area, centro, (w, dep), ang = obb(poly)
    if area < 10: continue
    x, z = g(centro); s_b, lat = project(x, z)
    if abs(lat) > 260: continue
    if not clear_of_axis(x, z, max(w, 3), max(dep, 3), ang): descartados += 1; continue
    if en_humedal(x, z): descartados += 1; continue          # nadie construye dentro del pantano
    lv = tg.get('building:levels')
    blds.append({'x': round(x, 1), 'z': round(z, 1), 'w': round(max(w, 3), 1), 'd': round(max(dep, 3), 1),
                 'yaw': round(ang, 4), 'levels': int(lv) if lv and lv.isdigit() else 1,
                 'type': tg['building'], 'style': 'poblacion', 's': round(s_b, 1), 'lat': round(lat, 1),
                 'delivery': False, 'damage': 1 if rnd.random() < 0.3 else 0, 'collapsed': False})
# el muelle: al final del camino sin salida, metido en el humedal (añadido de diseño)
muelle = {}
# El muelle se pone donde el camino roza el humedal de verdad: medido, el eje pasa a 1,9 m de
# un paño en s=5262. Buscarlo junto a la vuelta en punta no servía: el humedal más cercano a
# esa vuelta está a 526 m.
mejor = None
for i, q in enumerate(axis):
    if cum[i] < 300 or cum[i] > L - 200: continue
    for a in aguas:
        if a['kind'] != 'marsh': continue
        for v in a['polygon']:
            dd = math.dist(q, (v[0], v[1]))
            if dd < 60 and (mejor is None or dd < mejor[0]): mejor = (dd, cum[i], q, (v[0], v[1]))
if mejor:
    _, s_m, base, borde = mejor
    dx, dz = borde[0] - base[0], borde[1] - base[1]; n = math.hypot(dx, dz) or 1.0
    ini = (base[0] + dx / n * 7.0, base[1] + dz / n * 7.0)
    muelle = {'x': round(ini[0], 1), 'z': round(ini[1], 1), 'yaw': round(math.atan2(-dx / n, -dz / n), 4), 'length': 26.0, 's': round(s_m, 1)}
    _, lat_m = project(*ini)
    # la casa va AL LADO del muelle, no encima: con los dos en la misma normal los
    # tablones atravesaban la casa (visto en la foto del muelle, 16 sep 2026)
    cx, cz = off(s_m + 13.0, math.copysign(PROP[sec_at(s_m)] + 5.0, lat_m or 1.0))
    (_, (tx, tz), _) = sample(s_m)
    blds.append({'x': round(cx, 1), 'z': round(cz, 1), 'w': 6.0, 'd': 7.0, 'yaw': round(math.atan2(-tz, tx), 4),
                 'levels': 1, 'type': 'fill', 'style': 'poblacion', 's': round(s_m, 1), 'lat': round(lat_m, 1),
                 'delivery': True, 'damage': 0, 'collapsed': False})
print('portones %d | edificios %d (descartados %d) | muelle %s' % (len(portones), len(blds), descartados, bool(muelle)))

# ---- baches del barro ----
potholes = []
for sc in sections:
    if sc['type'] not in ('mud', 'gravel'): continue
    s_ = sc['s0'] + 10.0
    while s_ < sc['s1'] - 8.0:
        q = off(s_, rnd.uniform(-2.2, 2.2))
        potholes.append({'x': round(q[0], 1), 'z': round(q[1], 1), 'r': round(rnd.uniform(0.7, 1.5), 2)})
        s_ += rnd.uniform(18, 38)

# ---- circuito: esquinas por rumbo acumulado y par de frenado, receta del pueblo ----
def heading(s):
    (_, (tx, tz), _) = sample(max(0.0, min(L, s))); return math.atan2(tz, tx)
hits = []
s_c = 18.0
while s_c < L - 18.0:
    if abs((math.degrees(heading(s_c + 16.0) - heading(s_c - 16.0)) + 180) % 360 - 180) > 38.0: hits.append(s_c)
    s_c += 4.0
corner_s = []; run = []
for h in hits + [1e9]:
    if run and h - run[-1] > 9.0: corner_s.append(sum(run) / len(run)); run = []
    if h < 1e8: run.append(h)
fund = True
while fund and len(corner_s) > 1:
    fund = False
    for i in range(len(corner_s) - 1):
        if corner_s[i + 1] - corner_s[i] < 46.0:
            corner_s[i:i + 2] = [(corner_s[i] + corner_s[i + 1]) * 0.5]; fund = True; break
wps = []
def add(q):
    if not wps or math.dist(q, wps[-1]) >= 9.0: wps.append((round(q[0], 1), round(q[1], 1)))
def lane(s): return LANE[sec_at(s)]
s_ = 12.0; ultima = -1e9
while s_ < L - 8.0:
    cerca = [c for c in corner_s if abs(c - s_) < 22 and c > ultima + 40.0]
    if cerca:
        sc_ = cerca[0]; ultima = sc_
        add(off(sc_ - 18.0, -lane(sc_ - 18.0))); add(off(sc_ + 26.0, -lane(sc_ + 26.0)))
        s_ = sc_ + 40.0; continue
    add(off(s_, -lane(s_))); s_ += 14.0
entry = off(6.0, -lane(6.0)); (_, (etx, etz), _) = sample(6.0)
salida = off(L - 10.0, -lane(L - 10.0))
chk = wps + [wps[-1]]
tt = [abs((math.degrees(math.atan2(c[1] - b[1], c[0] - b[0]) - math.atan2(b[1] - a[1], b[0] - a[0])) + 180) % 360 - 180) for a, b, c in zip(chk, chk[1:], chk[2:])]
print('waypoints %d | esquinas %d | giro máximo %.0f° | tramo más corto %.1f m | giros > 60°: %d'
      % (len(wps), len(corner_s), max(tt), min(math.dist(a, b) for a, b in zip(wps, wps[1:])), sum(1 for x in tt if x > 60)))

# ---- bocacalles ----
chain_ways = set(wl)
junctions = []
for k in set(cadena):
    otros = {wid for _, _, wid in G[k] if wid not in chain_ways}
    if not otros: continue
    q = g(nodes[k]); s_j, lat = project(*q)
    lados = set()
    for v, _, wid in G[k]:
        if wid in otros:
            _, vlat = project(*g(nodes[v]))
            if abs(vlat) > 5: lados.add(1 if vlat > 0 else -1)
    for sd in lados: junctions.append({'side': sd, 's0': round(s_j - 7, 1), 's1': round(s_j + 7, 1), 'name': ways[sorted(otros)[0]][0].get('name', '')})
junctions.sort(key=lambda j: j['s0'])

out = {
    'source': 'OpenStreetMap contributors, ODbL 1.0 (https://www.openstreetmap.org/copyright), extracto 2026-09-16 (humedal del río Cruces, Valdivia, API 0.6)',
    'center_latlon': [LAT0, LON0], 'length': round(L, 1), 'closed_loop': False,
    'lane_offset': 3.0, 'carriageway_width': 6.0, 'median_width': 0.0, 'curb_lateral': 5.5, 'sidewalk_lateral': 7.0,
    'sections': sections, 'lane_by_type': LANE, 'curb_by_type': CURB, 'property_by_type': PROP,
    'axis': [[round(x, 1), round(z, 1)] for x, z in axis], 'waypoints': [list(q) for q in wps],
    'entry': {'x': round(entry[0], 1), 'z': round(entry[1], 1), 'yaw': round(yaw_facing(etx, etz), 4)},
    'exit': {'x': round(salida[0], 1), 'z': round(salida[1], 1)},
    'curb_gaps': junctions, 'humps': [], 'station': {}, 'fuel_lot': {}, 'pasaje': {}, 'underpass': {},
    'buildings': blds, 'lots': [], 'bus_stops': [], 'traffic_signals': [], 'trees': [], 'median_trees': [],
    'gravel_zones': [{'s0': sc['s0'], 's1': sc['s1']} for sc in sections if sc['type'] == 'gravel' and sc['s1'] - sc['s0'] > 40],
    'potholes': potholes, 'fences': [], 'poplars': [], 'orchards': [], 'vine_rows': [], 'fields': [], 'streets': [],
    'bridges': [{'s0': sc['s0'], 's1': sc['s1']} for sc in sections if sc['type'] == 'bridge'],
    'motorway': [], 'trench': {}, 'roundabout': {}, 'rail': {}, 'plaza': {}, 'parks': [], 'churches': [], 'water': [],
    'swamp': {
        'water_y': AGUA_Y,
        'bodies': aguas,
        'marsh': juncos,
        'snags': troncos,
        'hualve': hualve,
        'lianas': lianas,
        'fords': fords,
        'causeway': causeway,
        'pier': muelle,
        'gates': portones,
        'fences': cercos,
        'pasture': pradera,
        'mud_zones': [{'s0': sc['s0'], 's1': sc['s1']} for sc in sections if sc['type'] == 'mud'],
    },
    'street_names': sorted({n for n in anames if n != '?'}),
}
dst = os.path.join(HERE, '..', 'data', 'b2_pantano.json')
json.dump(out, open(dst, 'w', encoding='utf-8'), ensure_ascii=False, separators=(',', ':'))
print('escrito data/b2_pantano.json %d KB | %.0f m | %d waypoints | %d edificios' % (os.path.getsize(dst) // 1024, L, len(wps), len(blds)))
