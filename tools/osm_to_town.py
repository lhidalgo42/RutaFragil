"""Small-town closed loop (D69): from a raw OSM map (tools/requinoa_map.osm, ODbL) and a list of via points,
builds a closed route through real streets, smooths the corners, inserts a roundabout at a chosen junction,
raises the axis over the real bridge, marks sections by real surface, and extracts the town's features
(railway, station, level crossings, plaza, churches, humps, canals, orchards, villas, buildings).
Godot frame: x east, z = -north, y up. Stage 1 prints the summary and writes tools/_town_debug.json."""
import json, math, os, heapq, collections, random
import xml.etree.ElementTree as ET
HERE = os.path.dirname(os.path.abspath(__file__))
MAP = os.path.join(HERE, 'requinoa_map.osm')
LAT0, LON0 = -34.2848586, -70.8175128            # Requínoa (Nominatim)
def xy(lat, lon): return ((lon - LON0) * 111320 * math.cos(math.radians(LAT0)), (lat - LAT0) * 110574)
def g(p): return (p[0], -p[1])

root = ET.parse(MAP).getroot()
nodes = {n.get('id'): xy(float(n.get('lat')), float(n.get('lon'))) for n in root.iter('node')}
ntags = {n.get('id'): {t.get('k'): t.get('v') for t in n.findall('tag')} for n in root.iter('node') if n.find('tag') is not None}
ways = {w.get('id'): ({t.get('k'): t.get('v') for t in w.findall('tag')}, [r.get('ref') for r in w.findall('nd') if r.get('ref') in nodes]) for w in root.iter('way')}
print('mapa: nodos', len(nodes), 'ways', len(ways))

# ---------------- route: closed loop through via points, penalising reused streets ----------------
DRIVE = {'primary', 'secondary', 'tertiary', 'residential', 'unclassified', 'living_street', 'secondary_link', 'tertiary_link', 'service'}
G = collections.defaultdict(list)
for wid, (t, refs) in ways.items():
    if t.get('highway') not in DRIVE: continue
    pen = {'secondary': 1.0, 'tertiary': 1.05, 'unclassified': 1.2, 'residential': 1.25, 'living_street': 1.5, 'service': 3.5}.get(t['highway'], 1.5)
    for a, b in zip(refs, refs[1:]):
        d = math.dist(nodes[a], nodes[b]); G[a].append((b, d * pen, wid)); G[b].append((a, d * pen, wid))
VIAS = [(70, 0), (-499, 41), (-313, 121), (333, 175), (690, 460), (870, 470), (70, 0)]   # plaza, Los Canelos y Los Guindos (manzana al poniente, cruzando el paso sobre la Ruta 5 ida y vuelta), cruce ferroviario oriente, Marcial Caro (tierra), salida de la villa, plaza
def nearest(x, y): return min(G, key=lambda k: math.dist(nodes[k], (x, y)))
used = collections.Counter(); loop_nodes = []; loop_ways = []
for p1, p2 in zip(VIAS, VIAS[1:]):
    a, b = nearest(*p1), nearest(*p2); dist = {a: 0.0}; prev = {}; pq = [(0.0, a)]
    while pq:
        d, u = heapq.heappop(pq)
        if u == b: break
        if d > dist.get(u, 1e18): continue
        for v, c, wid in G[u]:
            nd = d + c * (1 + 8.0 * used[(min(u, v), max(u, v))])
            if nd < dist.get(v, 1e18): dist[v] = nd; prev[v] = (u, wid); heapq.heappush(pq, (nd, v))
    pn = [b]; u = b; wl = []
    while u != a: p_, wid = prev[u]; pn.append(p_); wl.append(wid); u = p_
    pn, wl = pn[::-1], wl[::-1]
    for u, v in zip(pn, pn[1:]): used[(min(u, v), max(u, v))] += 1
    loop_nodes += pn if not loop_nodes else pn[1:]; loop_ways += wl
raw = [nodes[k] for k in loop_nodes]                     # closed: first == last
UNPAVED = ('unpaved', 'gravel', 'dirt', 'ground', 'compacted', 'fine_gravel')
SOFT = ('residential', 'living_street', 'service', 'track', 'unclassified')
def way_section(t):
    if t.get('bridge'): return 'bridge'
    if t.get('surface') in UNPAVED: return 'gravel'
    # D69: calle vecinal sin dato de superficie = tierra. En Requínoa las residenciales del borde
    # y los pasajes de villa no están pavimentados, y así el recorrido alterna asfalto y tierra.
    if 'surface' not in t and t.get('highway') in SOFT: return 'gravel'
    return 'street'
raw_sec = [way_section(ways[loop_ways[0]][0])] + [way_section(ways[w][0]) for w in loop_ways]
raw_names = ['?'] + [ways[w][0].get('name', '?') for w in loop_ways]
print('lazo:', len(raw), 'vértices,', sum(math.dist(a, b) for a, b in zip(raw, raw[1:])) / 1000, 'km')

# ---------------- simplify + corner arcs (closed polyline) ----------------
def simplify(pts, tol=1.5):
    keep = [False] * len(pts); keep[0] = keep[-1] = True
    def rec(i0, i1):
        if i1 <= i0 + 1: return
        a, b = pts[i0], pts[i1]; ab = (b[0] - a[0], b[1] - a[1]); l2 = ab[0] ** 2 + ab[1] ** 2
        worst, wi = -1.0, -1
        for i in range(i0 + 1, i1):
            p_ = pts[i]
            if l2 < 1e-9: d = math.dist(p_, a)
            else:
                u = max(0.0, min(1.0, ((p_[0] - a[0]) * ab[0] + (p_[1] - a[1]) * ab[1]) / l2)); d = math.dist(p_, (a[0] + ab[0] * u, a[1] + ab[1] * u))
            if d > worst: worst, wi = d, i
        if worst > tol: keep[wi] = True; rec(i0, wi); rec(wi, i1)
    # break the closed loop at the farthest point from the start so both halves simplify independently
    far = max(range(len(pts)), key=lambda i: math.dist(pts[i], pts[0])); keep[far] = True
    rec(0, far); rec(far, len(pts) - 1)
    return [p_ for p_, k in zip(pts, keep) if k]
def fillet_closed(pts, R=16.0, min_turn_deg=18.0):
    """Corner arcs on a closed polyline (last point == first): every vertex is interior."""
    n = len(pts) - 1
    out = []
    for i in range(n):
        a, b, c = pts[i - 1] if i > 0 else pts[n - 1], pts[i], pts[i + 1]
        u = (b[0] - a[0], b[1] - a[1]); v = (c[0] - b[0], c[1] - b[1]); lu, lv = math.hypot(*u), math.hypot(*v)
        if lu < 1e-6 or lv < 1e-6: continue
        u = (u[0] / lu, u[1] / lu); v = (v[0] / lv, v[1] / lv)
        theta = math.acos(max(-1.0, min(1.0, u[0] * v[0] + u[1] * v[1])))
        if math.degrees(theta) < min_turn_deg: out.append(b); continue
        # Radio según el ángulo: las curvas suaves de una carretera de pueblo son amplias y la
        # esquina de calle es cerrada. Con radio único de 16 m el bus se iba de frente a 90 km/h.
        deg = math.degrees(theta)
        r_max = 48.0 if deg < 40.0 else (34.0 if deg < 60.0 else (22.0 if deg < 80.0 else R))
        r = min(r_max, 0.45 * min(lu, lv) / max(1e-6, math.tan(theta / 2.0))); T = r * math.tan(theta / 2.0)
        p1 = (b[0] - u[0] * T, b[1] - u[1] * T); p2 = (b[0] + v[0] * T, b[1] + v[1] * T)
        cross = u[0] * v[1] - u[1] * v[0]; nrm = (-u[1], u[0]) if cross > 0 else (u[1], -u[0])
        o = (p1[0] + nrm[0] * r, p1[1] + nrm[1] * r)
        a1 = math.atan2(p1[1] - o[1], p1[0] - o[0]); a2 = math.atan2(p2[1] - o[1], p2[0] - o[0]); da = (a2 - a1 + math.pi) % (2 * math.pi) - math.pi
        steps = max(2, int(abs(da) * r / 6.0))
        out += [(o[0] + r * math.cos(a1 + da * k / steps), o[1] + r * math.sin(a1 + da * k / steps)) for k in range(steps + 1)]
    out.append(out[0]); return out
def resample_closed(pts, step=10.0):
    out = [pts[0]]; total = sum(math.dist(a, b) for a, b in zip(pts, pts[1:])); target = step; acc = 0.0
    for a, b in zip(pts, pts[1:]):
        seg = math.dist(a, b)
        if seg < 1e-9: continue
        while target <= acc + seg + 1e-9 and target < total - step * 0.6:
            u = (target - acc) / seg; out.append((a[0] + (b[0] - a[0]) * u, a[1] + (b[1] - a[1]) * u)); target += step
        acc += seg
    out.append(pts[0]); return out
clean = simplify(raw, 1.5); fil = fillet_closed(clean); axis_osm = resample_closed(fil, 10.0)
turns = [abs((math.degrees(math.atan2(c[1] - b[1], c[0] - b[0]) - math.atan2(b[1] - a[1], b[0] - a[0])) + 180) % 360 - 180) for a, b, c in zip(axis_osm, axis_osm[1:], axis_osm[2:])]
print(f'eje cerrado: {len(axis_osm)} puntos, {sum(math.dist(a, b) for a, b in zip(axis_osm, axis_osm[1:])):.0f} m, giro máximo {max(turns):.1f}°, vértices simplificados {len(clean)}')
# sections by projection onto the raw chain
raw_segs = [(raw[i], raw[i + 1], raw_sec[i + 1], raw_names[i + 1]) for i in range(len(raw) - 1)]
def nearest_raw(p_):
    best, bsec, bname = 1e18, 'street', '?'
    for a, b, s, nm in raw_segs:
        ab = (b[0] - a[0], b[1] - a[1]); l2 = ab[0] ** 2 + ab[1] ** 2
        u = 0.0 if l2 < 1e-9 else max(0.0, min(1.0, ((p_[0] - a[0]) * ab[0] + (p_[1] - a[1]) * ab[1]) / l2))
        d = math.dist(p_, (a[0] + ab[0] * u, a[1] + ab[1] * u))
        if d < best: best, bsec, bname = d, s, nm
    return bsec, bname
asec, anames = zip(*[nearest_raw(p_) for p_ in axis_osm]); asec, anames = list(asec), list(anames)
sec_len = collections.Counter()
for (a, b), s in zip(zip(axis_osm, axis_osm[1:]), asec[1:]): sec_len[s] += math.dist(a, b)
print('metros por sección:', {k: round(v) for k, v in sec_len.items()})

# ================= stage 2: rotonda, puente, secciones, pueblo y campo =================
random.seed(2026)
TRENCH_DEPTH_M = 5.0                              # la Ruta 5 pasa en trinchera bajo el puente (D69)

# ---- vuelta en punta donde la cadena cruda se devuelve sobre sí misma (callejones sin salida) ----
def teardrop_pts(origin, f, n, scale=1.0):
    return [(origin[0] + (f[0] * ds + n[0] * lt) * scale, origin[1] + (f[1] * ds + n[1] * lt) * scale)
            for ds, lt in [(20, -10.75), (36, -16), (50, -8), (56, 4), (50, 16), (36, 20), (22, 14), (8, 8)]]
def insert_turnarounds(pts):
    out, centres = [pts[0]], []
    for i in range(1, len(pts) - 1):
        a, b, c = pts[i - 1], pts[i], pts[i + 1]
        u = (b[0] - a[0], b[1] - a[1]); v = (c[0] - b[0], c[1] - b[1]); lu, lv = math.hypot(*u), math.hypot(*v)
        if lu < 1e-6 or lv < 1e-6: continue
        if math.degrees(math.acos(max(-1.0, min(1.0, (u[0] * v[0] + u[1] * v[1]) / (lu * lv))))) > 150:
            f = (u[0] / lu, u[1] / lu); out += teardrop_pts(b, f, (-f[1], f[0])); centres.append(b)
        else:
            out.append(b)
    out.append(pts[-1]); return out, centres
clean2, turn_centres = insert_turnarounds(clean)

# ---- rotonda (añadido de diseño, D69: Requínoa no tiene) en la bocacalle más cercana a la plaza ----
def insert_roundabout(pts, R=13.0):
    best = None
    for i in range(1, len(pts) - 1):
        a, b, c = pts[i - 1], pts[i], pts[i + 1]
        u = (b[0] - a[0], b[1] - a[1]); v = (c[0] - b[0], c[1] - b[1]); lu, lv = math.hypot(*u), math.hypot(*v)
        if lu < 45 or lv < 45: continue
        ang = math.degrees(math.acos(max(-1.0, min(1.0, (u[0] * v[0] + u[1] * v[1]) / (lu * lv)))))
        d0 = math.dist(b, (0, 0))
        if 55 < ang < 125 and d0 < 320 and (best is None or d0 < best[0]): best = (d0, i, (u[0] / lu, u[1] / lu), (v[0] / lv, v[1] / lv))
    if best is None: return pts, {}
    _, i, u, v = best; b = pts[i]
    entry = (b[0] - u[0] * R, b[1] - u[1] * R); exit_ = (b[0] + v[0] * R, b[1] + v[1] * R)
    a1 = math.atan2(entry[1] - b[1], entry[0] - b[0]); a2 = math.atan2(exit_[1] - b[1], exit_[0] - b[0])
    da = (a2 - a1) % (2 * math.pi)                                  # antihorario en el plano OSM = por la derecha
    steps = max(5, int(da * R / 4.5))
    ring = [(b[0] + R * math.cos(a1 + da * k / steps), b[1] + R * math.sin(a1 + da * k / steps)) for k in range(steps + 1)]
    return pts[:i] + ring + pts[i + 1:], {'x': round(b[0], 1), 'z': round(-b[1], 1), 'radius': R, 'island_radius': R - 6.5}
def prune_short(pts, min_leg=15.0):
    """Vértices demasiado juntos dejan patas cortas y el redondeo de esquina no cabe: se quitan."""
    out = [pts[0]]
    for p_ in pts[1:-1]:
        if math.dist(p_, out[-1]) >= min_leg: out.append(p_)
    while len(out) > 2 and math.dist(out[-1], pts[-1]) < min_leg: out.pop()
    out.append(pts[-1]); return out
clean3, roundabout = insert_roundabout(prune_short(clean2))
print('rotonda:', roundabout, '| vueltas en punta:', len(turn_centres))

fil = fillet_closed(clean3, R=16.0); axis_osm = resample_closed(fil, 10.0)
asec, anames = zip(*[nearest_raw(p_) for p_ in axis_osm]); asec, anames = list(asec), list(anames)
if roundabout:
    for i, p_ in enumerate(axis_osm):
        if math.dist(p_, (roundabout['x'], -roundabout['z'])) < roundabout['radius'] + 4: asec[i] = 'street'
axis = [g(p_) for p_ in axis_osm]
cum = [0.0]
for a, b in zip(axis, axis[1:]): cum.append(cum[-1] + math.dist(a, b))
L = cum[-1]
turns = [abs((math.degrees(math.atan2(c[1] - b[1], c[0] - b[0]) - math.atan2(b[1] - a[1], b[0] - a[0])) + 180) % 360 - 180)
         for a, b, c in zip(axis, axis[1:], axis[2:])]
print(f'eje final: {len(axis)} puntos, {L:.0f} m, giro máximo {max(turns):.1f}°')

def sample(s):
    n = len(axis) - 1; s = min(max(s, 0.0), L)
    i = next((k for k in range(n) if s <= cum[k + 1] + 1e-9), n - 1)
    (x1, z1), (x2, z2) = axis[i], axis[i + 1]; u = (s - cum[i]) / max(1e-6, cum[i + 1] - cum[i])
    tx, tz = x2 - x1, z2 - z1; nn = math.hypot(tx, tz) or 1.0; tx, tz = tx / nn, tz / nn
    return (x1 + (x2 - x1) * u, z1 + (z2 - z1) * u), (tx, tz), (tz, -tx)
def off(s, lat):
    (px, pz), _, (nx, nz) = sample(s); return (px + nx * lat, pz + nz * lat)
def project(x, z):
    best = (1e18, 0.0, 0.0)
    for i in range(len(axis) - 1):
        (x1, z1), (x2, z2) = axis[i], axis[i + 1]; dx, dz = x2 - x1, z2 - z1; ll = dx * dx + dz * dz
        if ll < 1e-9: continue
        sl = math.sqrt(ll); u = max(0.0, min(1.0, ((x - x1) * dx + (z - z1) * dz) / ll))
        px, pz = x1 + dx * u, z1 + dz * u; d = math.hypot(x - px, z - pz)
        if d < best[0]: best = (d, cum[i] + sl * u, (x - px) * (dz / sl) + (z - pz) * (-dx / sl))
    return best[1], best[2]
def yaw_facing(tx, tz): return math.atan2(-tx, -tz)

# ---- secciones por superficie real, fundiendo las astillas cortas ----
sections = []
for i in range(len(axis) - 1):
    s0, s1, ty = cum[i], cum[i + 1], asec[i + 1]
    if sections and sections[-1]['type'] == ty: sections[-1]['s1'] = round(s1, 1)
    else: sections.append({'s0': round(s0, 1), 's1': round(s1, 1), 'type': ty})
merged = []
for sc in sections:
    if sc['s1'] - sc['s0'] < 25.0 and sc['type'] != 'bridge' and merged:
        merged[-1]['s1'] = sc['s1']                                  # astilla: la absorbe la sección anterior
    elif merged and merged[-1]['type'] == sc['type']: merged[-1]['s1'] = sc['s1']
    else: merged.append(sc)
sections = merged
def sec_at(s):
    for sc in sections:
        if sc['s0'] - 0.01 <= s <= sc['s1'] + 0.01: return sc['type']
    return 'street'
LANE = {'avenue': 6.75, 'street': 3.75, 'gravel': 2.8, 'bridge': 3.4}
CURB = {'avenue': 12.0, 'street': 8.0, 'gravel': 6.5, 'bridge': 6.4}
PROP = {'avenue': 15.0, 'street': 10.0, 'gravel': 9.0, 'bridge': 10.0}
print('secciones:', [(sc['type'], round(sc['s1'] - sc['s0'])) for sc in sections])

# ---- altura del eje: cubierta del puente y rampas ----
bridges = [{'s0': sc['s0'], 's1': sc['s1']} for sc in sections if sc['type'] == 'bridge']
# El paso sobre la Ruta 5 se cruza dos veces (ida y vuelta por las dos calzadas) y hay una
# bocacalle a 13 m del estribo: con cubierta elevada las rampas de las dos pasadas se solapan
# y dejan escalones que vuelcan al bus. Así que la calzada del bus queda plana y es la Ruta 5
# la que pasa en trinchera por debajo, con la cubierta del puente salvando el hueco.
axis_y = [0.0] * len(axis)
deck_idx = [i for i in range(len(axis)) if any(br['s0'] - 0.01 <= cum[i] <= br['s1'] + 0.01 for br in bridges)]
deck_mid_pt = (sum(axis[i][0] for i in deck_idx) / len(deck_idx), sum(axis[i][1] for i in deck_idx) / len(deck_idx)) if deck_idx else (0.0, 0.0)
print('puentes:', [(round(b['s0']), round(b['s1'])) for b in bridges], '| cubierta en', tuple(round(v) for v in deck_mid_pt))

# ---- la Ruta 5 que pasa por debajo del puente ----
motorway, trench = [], {}
best_seg = None
for wid, (t, refs) in ways.items():
    if t.get('highway') != 'motorway' or len(refs) < 2: continue
    pts = [g(nodes[k]) for k in refs]
    if any(math.dist(p_, deck_mid_pt) < 600 for p_ in pts):
        motorway.append([[round(px, 1), round(pz, 1)] for px, pz in pts])
    for a, b in zip(pts, pts[1:]):
        dx, dz = b[0] - a[0], b[1] - a[1]; ll = dx * dx + dz * dz
        if ll < 1e-9: continue
        u = max(0.0, min(1.0, ((deck_mid_pt[0] - a[0]) * dx + (deck_mid_pt[1] - a[1]) * dz) / ll))
        dd = math.hypot(deck_mid_pt[0] - a[0] - dx * u, deck_mid_pt[1] - a[1] - dz * u)
        if best_seg is None or dd < best_seg[0]: best_seg = (dd, a, b)
if best_seg and deck_idx:
    _, a, b = best_seg
    yaw_mw = math.atan2(-(b[1] - a[1]), b[0] - a[0])
    deck_len = max(30.0, max(math.dist(axis[i], axis[j]) for i in deck_idx for j in deck_idx))
    trench = {'x': round(deck_mid_pt[0], 1), 'z': round(deck_mid_pt[1], 1), 'yaw': round(yaw_mw, 4),
              'half_width': round(min(15.0, deck_len * 0.32), 1), 'half_length': 160.0, 'depth': TRENCH_DEPTH_M}
def _rot_x(x, z):      # a través de la Ruta 5 (ancho de la trinchera)
    if not trench: return 1e9
    dx, dz = x - trench['x'], z - trench['z']
    return dx * math.sin(trench['yaw']) + dz * math.cos(trench['yaw'])
def _rot_z(x, z):      # a lo largo de la Ruta 5 (largo de la trinchera)
    if not trench: return 1e9
    dx, dz = x - trench['x'], z - trench['z']
    return dx * math.cos(trench['yaw']) - dz * math.sin(trench['yaw'])
print('ramales de la Ruta 5:', len(motorway), '| trinchera', trench, '| largo de cubierta', round(deck_len if best_seg and deck_idx else 0))

# ---- bocacalles, lomos de toro, bencinera ----
chain_ways_set = set(loop_ways)
junctions = []
for k in set(loop_nodes):
    others = {wid for _, _, wid in G[k] if wid not in chain_ways_set}
    if not others: continue
    x, z = g(nodes[k]); s_j, lat = project(x, z)
    sides = set()
    for v, _, wid in G[k]:
        if wid in others:
            vx, vz = g(nodes[v]); _, vlat = project(vx, vz)
            if abs(vlat) > 6: sides.add(1 if vlat > 0 else -1)
    nm = ways[sorted(others)[0]][0].get('name', '')
    for sd in sides: junctions.append({'s': round(s_j, 1), 'side': sd, 'name': nm})
junctions.sort(key=lambda j: j['s'])
# Las curvas del pueblo son graduales: repartidas en varios vértices, ninguno pasa de 40°, pero
# el bus las toma a 90 km/h y se va de frente. Se mide el cambio de rumbo acumulado en 32 m.
def heading(s):
    (_, (tx_, tz_), _) = sample(max(0.0, min(L, s))); return math.atan2(tz_, tx_)
hits = []
s_c = 18.0
while s_c < L - 18.0:
    dv = abs((math.degrees(heading(s_c + 16.0) - heading(s_c - 16.0)) + 180) % 360 - 180)
    if dv > 38.0: hits.append(s_c)
    s_c += 4.0
corner_s = []                                     # una curva = un punto, el centro de la racha
run = []
for h in hits + [1e9]:
    if run and h - run[-1] > 9.0:
        corner_s.append(sum(run) / len(run)); run = []
    if h < 1e8: run.append(h)
# Dos curvas seguidas (una S, como en el cruce del tren) se funden en una sola: si no, el par de
# frenado de la segunda cae detrás del de la primera y la cadena de waypoints se dobla sobre sí.
merged_c = True
while merged_c and len(corner_s) > 1:
    merged_c = False
    for i in range(len(corner_s) - 1):
        if corner_s[i + 1] - corner_s[i] < 46.0:
            corner_s[i:i + 2] = [(corner_s[i] + corner_s[i + 1]) * 0.5]; merged_c = True; break
humps = []
for k, tg in ntags.items():
    if tg.get('traffic_calming') and k in set(loop_nodes):
        x, z = g(nodes[k]); s_h, _ = project(x, z)
        # Todos redondeados (resalto del Decreto 200): el lomo plano de 15 cm vuelca al bus
        # placeholder a 85 km/h, y en el pueblo hay rectas largas antes de cada uno.
        humps.append({'s': round(s_h, 1), 'side': -1, 'kind': 'round'})
humps.sort(key=lambda h: h['s'])
def near_nodes(pred, maxd):
    res = []
    for nid, tg in ntags.items():
        if not pred(tg) or nid not in nodes: continue
        x, z = g(nodes[nid]); s_i, lat = project(x, z)
        if abs(lat) <= maxd: res.append({'x': round(x, 1), 'z': round(z, 1), 's': round(s_i, 1), 'lat': round(lat, 1), 'side': 1 if lat > 0 else -1, 'tags': tg})
    return res
stops = near_nodes(lambda tg: tg.get('highway') == 'bus_stop', 30)
signals = near_nodes(lambda tg: tg.get('highway') == 'traffic_signals', 30)
trees = near_nodes(lambda tg: tg.get('natural') == 'tree', 40)
fuels = near_nodes(lambda tg: tg.get('amenity') == 'fuel', 60)
st = min(fuels, key=lambda f: abs(f['lat'])) if fuels else None
if st:
    S_STATION, ST_SIDE = st['s'], (-1 if st['lat'] < 0 else 1)
    (_, (stx, stz), _) = sample(S_STATION)
    # El nodo real de la Copec cae a 7 m del eje porque el recorrido pasa por su frente; la escena
    # de la bencinera (patio de 30x60 m) se retira a 30 m como en Rancagua, o su tienda quedaría
    # sobre la calzada y el bus choca.
    sp = off(S_STATION, ST_SIDE * 30.0)
    station = {'x': round(sp[0], 1), 'z': round(sp[1], 1), 'yaw': round(yaw_facing(stx, stz), 4), 's': round(S_STATION, 1),
               'side': ST_SIDE, 'real': True, 'name': st['tags'].get('brand', 'bencinera'), 'real_x': st['x'], 'real_z': st['z']}
else:
    S_STATION, ST_SIDE = 400.0, -1
    sp = off(S_STATION, -30.0); (_, (stx, stz), _) = sample(S_STATION)
    station = {'x': round(sp[0], 1), 'z': round(sp[1], 1), 'yaw': round(yaw_facing(stx, stz), 4), 's': S_STATION, 'side': -1, 'real': False}
print('bocacalles', len(junctions), '| esquinas', len(corner_s), '| lomos', collections.Counter(h['kind'] for h in humps), '| bencinera', station.get('name'), 'en s', round(station['s']))

# ---- ferrocarril, estación y cruces a nivel ----
rail_lines, platforms = [], []
for wid, (t, refs) in ways.items():
    if t.get('railway') in ('rail', 'disused') and len(refs) >= 2:
        pts = [g(nodes[k]) for k in refs]
        if any(math.hypot(px, pz) < 1600 for px, pz in pts): rail_lines.append([[round(px, 1), round(pz, 1)] for px, pz in pts])
    if t.get('railway') == 'platform' or t.get('public_transport') == 'platform':
        pts = [g(nodes[k]) for k in refs]
        if len(pts) >= 2:
            far = max(pts, key=lambda p_: math.dist(p_, pts[0]))
            platforms.append({'x': round(sum(p_[0] for p_ in pts) / len(pts), 1), 'z': round(sum(p_[1] for p_ in pts) / len(pts), 1),
                              'len': round(max(math.dist(pts[0], far), 20.0), 1), 'yaw': round(math.atan2(-(far[1] - pts[0][1]), far[0] - pts[0][0]), 4)})
station_node = next((k for k, t in ntags.items() if t.get('railway') == 'station'), None)
rail_station = {}
if station_node:
    sx, sz = g(nodes[station_node])
    rail_station = {'x': round(sx, 1), 'z': round(sz, 1), 'name': ntags[station_node].get('name', 'Estación'), 'yaw': platforms[0]['yaw'] if platforms else 0.0}
def seg_x(p, p2, q, q2):
    d = (p2[0] - p[0]) * (q2[1] - q[1]) - (p2[1] - p[1]) * (q2[0] - q[0])
    if abs(d) < 1e-9: return None
    t_ = ((q[0] - p[0]) * (q2[1] - q[1]) - (q[1] - p[1]) * (q2[0] - q[0])) / d
    u_ = ((q[0] - p[0]) * (p2[1] - p[1]) - (q[1] - p[1]) * (p2[0] - p[0])) / d
    return (p[0] + t_ * (p2[0] - p[0]), p[1] + t_ * (p2[1] - p[1])) if 0 <= t_ <= 1 and 0 <= u_ <= 1 else None
crossings = []
for i in range(len(axis) - 1):
    for line in rail_lines:
        for q, q2 in zip(line, line[1:]):
            ip = seg_x(axis[i], axis[i + 1], q, q2)
            if not ip: continue
            s_c, _ = project(*ip); (_, (tx, tz), _) = sample(s_c)
            if any(math.dist((c['x'], c['z']), ip) < 12 for c in crossings): continue
            crossings.append({'x': round(ip[0], 1), 'z': round(ip[1], 1), 's': round(s_c, 1), 'yaw': round(yaw_facing(tx, tz), 4),
                              'rail_yaw': round(math.atan2(-(q2[1] - q[1]), q2[0] - q[0]), 4)})
print('vías de tren', len(rail_lines), '| andenes', len(platforms), '| estación', rail_station.get('name'), '| cruces a nivel', [(round(c['s']), round(c['x']), round(c['z'])) for c in crossings])

# ---- plaza, parques, iglesias, acequias, viñas y huertos ----
def poly_of(refs): return [[round(px, 1), round(pz, 1)] for px, pz in (g(nodes[k]) for k in refs)]
def inside(poly, x, z):
    hit = False; n = len(poly)
    for i in range(n):
        x1, z1 = poly[i]; x2, z2 = poly[(i + 1) % n]
        if (z1 > z) != (z2 > z) and x < x1 + (z - z1) / (z2 - z1 + 1e-12) * (x2 - x1): hit = not hit
    return hit
parks = [{'name': t.get('name', ''), 'polygon': poly_of(refs)} for wid, (t, refs) in ways.items()
         if t.get('leisure') in ('park', 'garden') and len(refs) >= 4 and any(math.dist(g(nodes[k]), (0, 0)) < 900 for k in refs)]
plaza = next((p_ for p_ in parks if 'plaza' in p_['name'].lower()), parks[0] if parks else {})
churches = []
for wid, (t, refs) in ways.items():
    if (t.get('amenity') == 'place_of_worship' or t.get('building') == 'church') and len(refs) >= 4:
        pts = [g(nodes[k]) for k in refs]; cx = sum(p_[0] for p_ in pts) / len(pts); cz = sum(p_[1] for p_ in pts) / len(pts)
        if math.hypot(cx, cz) < 900: churches.append({'x': round(cx, 1), 'z': round(cz, 1), 'name': t.get('name', 'iglesia'), 'polygon': poly_of(refs)})
water = []
for wid, (t, refs) in ways.items():
    if t.get('waterway') in ('ditch', 'stream', 'canal') and len(refs) >= 2:
        pts = [g(nodes[k]) for k in refs]
        if any(abs(project(*p_)[1]) < 200 for p_ in pts[::max(1, len(pts) // 4)]): water.append([[round(px, 1), round(pz, 1)] for px, pz in pts])
urban_polys = [poly_of(refs) for wid, (t, refs) in ways.items() if t.get('landuse') in ('residential', 'retail', 'commercial') and len(refs) >= 4]
def in_urban(x, z): return any(inside(p_, x, z) for p_ in urban_polys)
vine_rows, orchard_pts = [], []
fields = []
for wid, (t, refs) in ways.items():
    if t.get('landuse') not in ('orchard', 'vineyard', 'farmland') or len(refs) < 4: continue
    poly = poly_of(refs)
    xs = [p_[0] for p_ in poly]; zs = [p_[1] for p_ in poly]
    if min(abs(project(px, pz)[1]) for px, pz in poly) > 320: continue
    kind = 'vineyard' if t['landuse'] == 'vineyard' or (t['landuse'] == 'farmland' and random.random() < 0.55) else 'orchard'
    fields.append({'kind': kind, 'polygon': poly})
    (x0, x1), (z0, z1) = (min(xs), max(xs)), (min(zs), max(zs))
    if kind == 'vineyard' and len(vine_rows) < 420:
        z = z0 + 3.2
        while z < z1 and len(vine_rows) < 420:
            run = None
            x = x0
            while x < x1 + 2.0:
                ok = inside(poly, x, z) and abs(project(x, z)[1]) > 14.0
                if ok and run is None: run = x
                elif not ok and run is not None:
                    if x - run > 10.0: vine_rows.append([round(run, 1), round(z, 1), round(x, 1)])
                    run = None
                x += 2.5
            if run is not None and x - run > 10.0: vine_rows.append([round(run, 1), round(z, 1), round(x, 1)])
            z += 3.2
    elif len(orchard_pts) < 1100:
        z = z0 + 4.0
        while z < z1 and len(orchard_pts) < 1100:
            x = x0 + 4.0
            while x < x1 and len(orchard_pts) < 1100:
                if inside(poly, x, z) and abs(project(x, z)[1]) > 14.0: orchard_pts.append([round(x, 1), round(z, 1)])
                x += 6.5
            z += 6.5
print('plaza:', plaza.get('name'), '| parques', len(parks), '| iglesias', len(churches), '| acequias', len(water), '| paños', collections.Counter(f['kind'] for f in fields), '| hileras de viña', len(vine_rows), '| árboles de huerto', len(orchard_pts))
print('polígonos urbanos:', len(urban_polys), '| centro urbano?', in_urban(0, 0), '| villa oriente?', in_urban(800, -500), '| campo?', in_urban(690, -430))

# ---- edificios reales del corredor, filtrados por esquina de la caja orientada ----
def obb(poly):
    best = None
    for (x1, y1), (x2, y2) in zip(poly, poly[1:]):
        ang = math.atan2(y2 - y1, x2 - x1); c, s_ = math.cos(-ang), math.sin(-ang)
        rot = [(x * c - y * s_, x * s_ + y * c) for x, y in poly]
        w = max(p_[0] for p_ in rot) - min(p_[0] for p_ in rot); h = max(p_[1] for p_ in rot) - min(p_[1] for p_ in rot)
        if best is None or w * h < best[0]:
            cx = (max(p_[0] for p_ in rot) + min(p_[0] for p_ in rot)) / 2; cy = (max(p_[1] for p_ in rot) + min(p_[1] for p_ in rot)) / 2
            c2, s2 = math.cos(ang), math.sin(ang); best = (w * h, (cx * c2 - cy * s2, cx * s2 + cy * c2), (w, h), ang)
    return best
ADOBE = {'Comercio', 'Pablo Rubio', 'Leonardo Murialdo', 'Rafael Tagle', 'Caupolicán', 'Las Dalias', 'Daniel Vial'}
def style_at(s, x=None, z=None):
    i = min(range(len(axis)), key=lambda k: abs(cum[k] - s)); nm = anames[i]
    px, pz = (x, z) if x is not None else axis[i]
    if not in_urban(px, pz): return 'parcela'
    if sec_at(s) == 'gravel': return 'poblacion'
    return 'adobe' if nm in ADOBE else 'poblacion'
blds, dropped = [], 0
for wid, (t, refs) in ways.items():
    if 'building' not in t or len(refs) < 4: continue
    poly = [nodes[k] for k in refs]; area, centre, (w, dep), ang = obb(poly)
    if area < 12: continue
    x, z = g(centre); s_b, lat = project(x, z)
    if abs(lat) > 70: continue
    cy_, sy_ = math.cos(ang), math.sin(ang)
    corners = [(x + sx * w / 2 * cy_ + sz * dep / 2 * sy_, z - sx * w / 2 * sy_ + sz * dep / 2 * cy_) for sx in (-1, 1) for sz in (-1, 1)]
    if any(abs(project(*c_)[1]) < PROP[sec_at(project(*c_)[0])] + 0.8 for c_ in corners): dropped += 1; continue
    if roundabout and math.dist((x, z), (roundabout['x'], roundabout['z'])) < 30: dropped += 1; continue
    if any(br['s0'] - 30 < s_b < br['s1'] + 30 for br in bridges) and abs(lat) < 26: dropped += 1; continue
    if trench and abs(_rot_x(x, z)) < trench['half_width'] + 4 and abs(_rot_z(x, z)) < trench['half_length']: dropped += 1; continue
    lv = t.get('building:levels'); btype = t['building']
    levels = int(lv) if lv and lv.isdigit() else (2 if btype in ('school', 'public', 'commercial', 'church') else 1 if area < 130 else 2)
    style = 'church' if (t.get('amenity') == 'place_of_worship' or btype == 'church') else style_at(s_b, x, z)
    blds.append({'x': round(x, 1), 'z': round(z, 1), 'w': round(max(w, 3), 1), 'd': round(max(dep, 3), 1), 'yaw': round(ang, 4),
                 'levels': levels, 'type': btype, 'style': style, 's': round(s_b, 1), 'lat': round(lat, 1), 'delivery': False, 'damage': 0, 'collapsed': False})
print('edificios OSM en el corredor:', len(blds), '| descartados', dropped)

# ---- lo que ya está ocupado a cada lado, para no pisarlo con fachadas nuevas ----
covered = {1: [], -1: []}
for b in blds:
    if abs(b['lat']) < 50:
        half = max(b['w'], b['d']) / 2 + 1.5; covered[1 if b['lat'] > 0 else -1].append((b['s'] - half, b['s'] + half))
for j in junctions: covered[j['side']].append((j['s'] - 9, j['s'] + 9))
for c in crossings:
    for sd in (1, -1): covered[sd].append((c['s'] - 16, c['s'] + 16))
for br in bridges:
    for sd in (1, -1): covered[sd].append((br['s0'] - 32, br['s1'] + 32))
covered[ST_SIDE].append((S_STATION - 45, S_STATION + 45))
if roundabout:
    s_r, _ = project(roundabout['x'], roundabout['z'])
    for sd in (1, -1): covered[sd].append((s_r - 38, s_r + 38))
for c_s in corner_s:                  # las esquinas se despejan: el bus placeholder derrapa hasta 16 m al girar
    for sd in (1, -1): covered[sd].append((c_s - 26, c_s + 26))
def overlaps(ivs, a, b): return any(a < i1 and b > i0 for i0, i1 in ivs)
def clear_of_axis(cx_, cz_, w_, d_, yaw_, margin=0.8):
    """El pueblo tiene calles paralelas a 15 m: una fachada colocada por su propia `s` puede caer
    sobre la calzada de otra pasada del recorrido. Se mide contra el eje entero, esquina por esquina."""
    c_, s2 = math.cos(-yaw_), math.sin(-yaw_)
    for sx in (-1, 1):
        for sz in (-1, 1):
            px = cx_ + sx * w_ / 2 * c_ + sz * d_ / 2 * s2
            pz = cz_ - sx * w_ / 2 * s2 + sz * d_ / 2 * c_
            s_p, lat_p = project(px, pz)
            if abs(lat_p) < PROP[sec_at(s_p)] + margin: return False
    return True
def add_bld(s_c, side, style, front, depth, setb, levels, extra=None):
    sec = sec_at(s_c); lat_c = side * (PROP[sec] + setb + depth / 2)
    cx_, cz_ = off(s_c, lat_c); (_, (tx_, tz_), _) = sample(s_c); yaw_ = math.atan2(-tz_, tx_)
    if not clear_of_axis(cx_, cz_, front, depth, yaw_): return None
    e = {'x': round(cx_, 1), 'z': round(cz_, 1), 'w': round(front, 2), 'd': round(depth, 2), 'yaw': round(yaw_, 4), 'levels': levels,
         'type': 'fill', 'style': style, 's': round(s_c, 1), 'lat': round(lat_c, 1), 'delivery': False, 'damage': 0, 'collapsed': False}
    if style != 'adobe':
        fx_, fz_ = off(s_c, side * (PROP[sec] + 0.05))
        e['fence'] = {'x': round(fx_, 1), 'z': round(fz_, 1), 'yaw': round(yaw_, 4), 'len': front if style == 'poblacion' else 24.0,
                      'kind': 'wire' if style == 'parcela' else 'bars'}
    if extra: e.update(extra)
    blds.append(e); covered[side].append((s_c - front / 2 - 1.0, s_c + front / 2 + 1.0)); return e
rnd = random.Random(41)
FRONT = {'adobe': 8.0, 'poblacion': 7.0, 'parcela': 11.0}
DEPTH = {'adobe': 12.0, 'poblacion': 9.0, 'parcela': 10.0}
SETB = {'adobe': 0.0, 'poblacion': 2.0, 'parcela': 16.0}
n_urb = n_rur = 0
for side in (1, -1):
    s_ = 12.0
    while s_ < L - 12.0:
        sec = sec_at(s_)
        if sec == 'bridge': s_ += 12.0; continue
        px_, pz_ = off(s_, 0.0)
        urban = in_urban(px_, pz_)
        style = 'parcela' if not urban else style_at(s_, px_, pz_)
        front = FRONT[style]
        step = front if urban else 120.0
        if not overlaps(covered[side], s_, s_ + front) and s_ + front < L - 12.0:
            if urban:
                # Variedad de frente, fondo y retiro, y un sitio de cada siete vacío: con todas
                # las casas iguales y pegadas la calle se veía como un peine.
                if rnd.random() > 0.14:
                    w_ = front * rnd.uniform(0.72, 1.0)
                    d_ = DEPTH[style] * rnd.uniform(0.8, 1.4)
                    sb_ = SETB[style] + (0.0 if style == 'adobe' else rnd.uniform(0.0, 3.0))
                    lv_ = 2 if (style == 'adobe' and rnd.random() < 0.28) else 1
                    if add_bld(s_ + front / 2, side, style, w_, d_, sb_, lv_): n_urb += 1
            elif rnd.random() < 0.6:
                if add_bld(s_ + front / 2, side, 'parcela', FRONT['parcela'] * rnd.uniform(0.8, 1.3), DEPTH['parcela'] * rnd.uniform(0.8, 1.3), SETB['parcela'] + rnd.uniform(0.0, 8.0), 1): n_rur += 1
        s_ += step * rnd.uniform(0.92, 1.18) if urban else step
# entradas a sitios con casitas: donde una bocacalle sale al campo, un grupo de tres casas al fondo
n_clu = 0
for j in junctions:
    px_, pz_ = off(j['s'], 0.0)
    if in_urban(px_, pz_) or sec_at(j['s']) == 'bridge': continue
    for k, back in enumerate((26.0, 40.0, 54.0)):
        s_c = j['s'] + (k - 1) * 9.0
        cx_, cz_ = off(s_c, j['side'] * (PROP[sec_at(j['s'])] + back))
        (_, (tx_, tz_), _) = sample(s_c)
        if not clear_of_axis(cx_, cz_, 7.0, 8.0, math.atan2(-tz_, tx_)): continue
        blds.append({'x': round(cx_, 1), 'z': round(cz_, 1), 'w': 7.0, 'd': 8.0, 'yaw': round(math.atan2(-tz_, tx_), 4), 'levels': 1,
                     'type': 'fill', 'style': 'poblacion', 's': round(s_c, 1), 'lat': round(j['side'] * (PROP[sec_at(j['s'])] + back), 1),
                     'delivery': False, 'damage': 0, 'collapsed': False})
        n_clu += 1
print(f'fachadas urbanas {n_urb} | parcelas rurales {n_rur} | casitas en entradas {n_clu} | edificios {len(blds)}')

# ---- deterioro moderado (D68 «menos ruina»): grietas, dos casas caídas, unos eriazos ----
cands = [i for i, b in enumerate(blds) if b['style'] in ('adobe', 'poblacion') and abs(b['lat']) < 40]
rnd.shuffle(cands)
for i in cands[:int(len(cands) * 0.2)]: blds[i]['damage'] = 1
for i in [i for i in cands if blds[i]['type'] == 'fill' and blds[i]['style'] == 'adobe'][:2]: blds[i]['collapsed'] = True; blds[i]['damage'] = 1
lots = []
for i in cands[int(len(cands) * 0.2):]:
    if len(lots) >= 4: break
    b = blds[i]
    if b['type'] == 'fill' and not b['collapsed']:
        lots.append({'x': b['x'], 'z': b['z'], 'w': b['w'], 'd': b['d'], 'yaw': b['yaw'], 'kind': 'eriazo', 'trash': 4}); b['collapsed'] = 'lot'
blds = [b for b in blds if b['collapsed'] != 'lot']
if roundabout: lots.append({'x': roundabout['x'], 'z': roundabout['z'], 'w': roundabout['island_radius'] * 2, 'd': roundabout['island_radius'] * 2, 'yaw': 0.0, 'kind': 'isla', 'trash': 0})
# Los sitios despejados en las curvas quedan como eriazos: pasto seco y basura, no un vacío.
done_c = []
for c_s in corner_s:
    if any(abs(c_s - c2) < 60 for c2 in done_c): continue
    done_c.append(c_s)
    px_, pz_ = off(c_s, (PROP[sec_at(c_s)] + 9.0))
    (_, (tx_, tz_), _) = sample(c_s)
    if in_urban(px_, pz_): lots.append({'x': round(px_, 1), 'z': round(pz_, 1), 'w': 17.0, 'd': 14.0, 'yaw': round(math.atan2(-tz_, tx_), 4), 'kind': 'eriazo', 'trash': 3})

# ---- la entrega: casa chica en la calle de tierra de la villa, pasada una curva y con reja ----
villa = [i for i, b in enumerate(blds) if sec_at(b['s']) == 'gravel' and b['style'] in ('poblacion', 'parcela') and abs(b['lat']) < 34 and not b['collapsed']]
gravel_villa = [sc for sc in sections if sc['type'] == 'gravel'][-1]
in_last = [i for i in villa if gravel_villa['s0'] + 40 < blds[i]['s'] < gravel_villa['s1'] - 25]
pick = (in_last or villa)[len(in_last or villa) // 2] if (in_last or villa) else None
if pick is not None:
    blds[pick]['delivery'] = True; blds[pick]['damage'] = 0
    print(f"entrega: casa en s={blds[pick]['s']:.0f} ({blds[pick]['style']}, lat {blds[pick]['lat']:.0f}, tramo de tierra {gravel_villa['s0']:.0f}-{gravel_villa['s1']:.0f})")

# ---- tierra: baches, y el campo vestido con cercos, alamedas y los paños ----
gravel = [sc for sc in sections if sc['type'] == 'gravel']
potholes = []
for sc in gravel:
    s_ = sc['s0'] + 12.0
    while s_ < sc['s1'] - 8.0:
        px_, pz_ = off(s_, rnd.uniform(-3.0, 3.0)); potholes.append({'x': round(px_, 1), 'z': round(pz_, 1), 'r': round(rnd.uniform(0.6, 1.2), 2)}); s_ += rnd.uniform(25, 50)
for sc in gravel:                                         # lomo de toro justo antes de que se acabe el asfalto
    for s_h in (sc['s0'] - 14.0, sc['s1'] + 14.0):
        if 20 < s_h < L - 20 and sec_at(s_h) == 'street' and not any(abs(h['s'] - s_h) < 30 for h in humps):
            humps.append({'s': round(s_h, 1), 'side': -1, 'kind': 'round'})
humps = [h for h in humps if not any(br['s0'] - 26 < h['s'] < br['s1'] + 26 for br in bridges)]   # ninguno en el puente
humps.sort(key=lambda h: h['s'])
fences, poplars = [], []
s_ = 0.0
while s_ < L:
    px_, pz_ = off(s_, 0.0)
    if not in_urban(px_, pz_) and sec_at(s_) != 'bridge':
        s_end = s_
        while s_end < L and not in_urban(*off(s_end, 0.0)) and sec_at(s_end) != 'bridge': s_end += 10.0
        if s_end - s_ > 60.0:
            for sd in (1, -1): fences.append({'s0': round(s_ + 6, 1), 's1': round(s_end - 6, 1), 'side': sd})
            k = 0; sp = s_ + 14.0
            while sp < s_end - 14.0:
                px2, pz2 = off(sp, 13.0 if k % 2 == 0 else -13.0)
                if abs(project(px2, pz2)[1]) > 11.5: poplars.append({'x': round(px2, 1), 'z': round(pz2, 1)})
                sp += 12.0; k += 1
        s_ = s_end
    s_ += 10.0
print('baches', len(potholes), '| lomos', collections.Counter(h['kind'] for h in humps), '| cercos', len(fences), '| álamos', len(poplars))

# ---- circuito cerrado por la pista derecha, con frenadas en las esquinas ----
wps = []
def add(p_):
    if not wps or math.dist(p_, wps[-1]) >= 9.0: wps.append((round(p_[0], 1), round(p_[1], 1)))
def lane(s): return LANE[sec_at(s)]
s_ = 12.0
last_corner = -1e9
while s_ < L - 8.0:
    near = [c for c in corner_s if abs(c - s_) < 22 and c > last_corner + 40.0]
    if near:
        sc_ = near[0]
        last_corner = sc_
        # Dos puntos por curva: el de antes, y el de después bien adelantado. Al llegar al
        # primero el bus ve el segundo a más de 60° y frena, pero aun así se pasa unos 12 m;
        # con el punto de salida a 26 m todavía le queda por delante y endereza sin quedarse
        # clavado (a 9 m le quedaba atrás y giraba en el sitio hasta atascarse).
        add(off(sc_ - 18.0, -lane(sc_ - 18.0))); add(off(sc_ + 26.0, -lane(sc_ + 26.0)))
        s_ = sc_ + 40.0; continue
    # Puntos cada 14 m: con el blanco siempre cerca, en cuanto el bus se abre el ángulo
    # pasa de 60° y frena solo. Con puntos cada 28 m el blanco queda lejos, el ángulo es
    # pequeño y el bus se va de frente en las curvas del pueblo.
    add(off(s_, -lane(s_))); s_ += 12.0 if sec_at(s_) != 'street' else 14.0
entry = off(4.0, -lane(4.0)); (_, (etx, etz), _) = sample(4.0)
chk = wps + [wps[0], wps[1]]
tt = [abs((math.degrees(math.atan2(c[1] - b[1], c[0] - b[0]) - math.atan2(b[1] - a[1], b[0] - a[0])) + 180) % 360 - 180) for a, b, c in zip(chk, chk[1:], chk[2:])]
print(f'waypoints {len(wps)} | giro máximo {max(tt):.0f}° | tramo más corto {min(math.dist(a, b) for a, b in zip(chk, chk[1:])):.1f} m | giros > 60°: {sum(1 for x in tt if x > 60)}')

gaps = [{'side': j['side'], 's0': round(j['s'] - 8, 1), 's1': round(j['s'] + 8, 1), 'name': j['name']} for j in junctions]
gaps.append({'side': ST_SIDE, 's0': round(S_STATION - 40, 1), 's1': round(S_STATION + 40, 1), 'name': 'estacion'})
def snap(items, lat_abs):
    return [{'x': round(off(it['s'], math.copysign(lat_abs, it['lat']))[0], 1), 'z': round(off(it['s'], math.copysign(lat_abs, it['lat']))[1], 1),
             's': it['s'], 'side': it['side']} for it in items]
out = {
    'source': 'OpenStreetMap contributors, ODbL 1.0 (https://www.openstreetmap.org/copyright), extracto 2026-09-14 (Requínoa, API 0.6)',
    'center_latlon': [LAT0, LON0], 'length': round(L, 1), 'closed_loop': True,
    'lane_offset': 6.75, 'carriageway_width': 10.5, 'median_width': 3.0, 'curb_lateral': 12.0, 'sidewalk_lateral': 14.0,
    'sections': sections, 'lane_by_type': LANE, 'curb_by_type': CURB, 'property_by_type': PROP,
    'axis': [[round(x, 1), round(z, 1), round(y, 2)] for (x, z), y in zip(axis, axis_y)], 'waypoints': [list(p_) for p_ in wps],
    'entry': {'x': round(entry[0], 1), 'z': round(entry[1], 1), 'yaw': round(yaw_facing(etx, etz), 4)},
    'exit': {'x': round(entry[0], 1), 'z': round(entry[1], 1)},
    'curb_gaps': gaps, 'humps': humps, 'station': station, 'fuel_lot': {}, 'pasaje': {}, 'underpass': {},
    'buildings': blds, 'lots': lots, 'bus_stops': snap(stops, 14.0), 'traffic_signals': snap(signals, 13.4), 'trees': snap(trees, 14.6), 'median_trees': [],
    # La calamina y la zona de ripio empiezan 14 m dentro del camino de tierra: en la bocacalle
    # el camino nace pegado a la calzada pavimentada de otra pasada del recorrido, y las barras
    # (11 m de ancho) le quedaban en el paso al bus a 77 km/h.
    'gravel_zones': [{'s0': round(sc['s0'] + 14.0, 1), 's1': round(sc['s1'] - 14.0, 1)} for sc in gravel if sc['s1'] - sc['s0'] > 40.0],
    'potholes': potholes, 'fences': fences, 'poplars': poplars,
    'orchards': orchard_pts, 'vine_rows': vine_rows, 'fields': fields,
    'bridges': bridges, 'motorway': motorway, 'trench': trench, 'roundabout': roundabout,
    'rail': {'lines': rail_lines, 'platforms': platforms, 'station': rail_station, 'crossings': crossings},
    'plaza': plaza, 'parks': [p_ for p_ in parks if p_ is not plaza], 'churches': churches, 'water': water,
    'street_names': sorted({n for n in anames if n != '?'}),
}
dst = os.path.join(HERE, '..', 'data', 'b0_requinoa.json')
json.dump(out, open(dst, 'w', encoding='utf-8'), ensure_ascii=False, separators=(',', ':'))
print('escrito data/b0_requinoa.json', os.path.getsize(dst) // 1024, 'KB |', len(blds), 'edificios,', len(wps), 'waypoints,', round(L), 'm')
