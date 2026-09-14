"""Rancagua chained route (D68): merges raw OSM maps (tools/*.osm, ODbL), finds the real road chain
Av. San Martín -> Av. España -> Av. Germán Ibarra -> Av. Pdte. Domingo Santa María (unpaved),
smooths the corners, assigns a section per stretch (avenue / street / gravel), places real and
generated buildings with light deterioration, and precomputes the demo circuit.
Godot frame: x east, z = -north. Run: python3 tools/osm_to_rancagua.py"""
import json, math, os, heapq, random, collections
import xml.etree.ElementTree as ET
HERE = os.path.dirname(os.path.abspath(__file__))
LAT0, LON0 = -34.1702862, -70.740757          # Plaza de los Héroes
def xy(lat, lon): return ((lon - LON0) * 111320 * math.cos(math.radians(LAT0)), (lat - LAT0) * 110574)
def g(p): return (p[0], -p[1])                # OSM (x east, y north) -> Godot (x, z)

# ---------------- merge maps ----------------
nodes, ways = {}, {}
for fn in ('damero_map.osm', 'norte_map.osm'):
    root = ET.parse(os.path.join(HERE, fn)).getroot()
    for n in root.iter('node'): nodes[n.get('id')] = xy(float(n.get('lat')), float(n.get('lon')))
    for w in root.iter('way'):
        tags = {t.get('k'): t.get('v') for t in w.findall('tag')}; refs = [r.get('ref') for r in w.findall('nd')]
        ways[w.get('id')] = (tags, refs)
print('mapas unidos: nodos', len(nodes), 'ways', len(ways))

# ---------------- road chain (shortest path, big roads preferred) ----------------
DRIVE = {'primary', 'secondary', 'tertiary', 'residential', 'unclassified', 'living_street', 'primary_link', 'secondary_link', 'tertiary_link'}
G = collections.defaultdict(list)
for wid, (t, refs) in ways.items():
    if t.get('highway') not in DRIVE: continue
    refs = [r for r in refs if r in nodes]
    pen = 1.0 if t.get('highway') in ('primary', 'secondary', 'tertiary') else 1.5
    for a, b in zip(refs, refs[1:]):
        d = math.dist(nodes[a], nodes[b]); G[a].append((b, d * pen, wid)); G[b].append((a, d * pen, wid))
def nearest_node(x, y): return min(G, key=lambda k: math.dist(nodes[k], (x, y)))
# start: Av. San Martín inside the grid (south of the Alameda); end: the far end of the unpaved Av. Domingo Santa María
sm_nodes = [r for wid, (t_, refs) in ways.items() if 'san mart' in t_.get('name', '').lower() and t_.get('highway') in DRIVE for r in refs if r in G]
src = min(sm_nodes, key=lambda k: math.dist(nodes[k], (-520, -320)))
via = nearest_node(-349, 1744)      # cruce República de Chile / inicio del ripio
dst = nearest_node(-498, 1404)      # extremo sur-oeste del tramo sin pavimentar
print('inicio', tuple(round(v) for v in nodes[src]), 'vía', tuple(round(v) for v in nodes[via]), 'fin', tuple(round(v) for v in nodes[dst]))
def dijkstra(a, b):
    dist = {a: 0.0}; prev = {}; pq = [(0.0, a)]
    while pq:
        d, u = heapq.heappop(pq)
        if u == b: break
        if d > dist.get(u, 1e18): continue
        for v, c, wid in G[u]:
            nd = d + c
            if nd < dist.get(v, 1e18): dist[v] = nd; prev[v] = (u, wid); heapq.heappush(pq, (nd, v))
    path_nodes = [b]; path_ways = []; u = b
    while u != a:
        pn, wid = prev[u]; path_nodes.append(pn); path_ways.append(wid); u = pn
    return path_nodes[::-1], path_ways[::-1]
n1, w1 = dijkstra(src, via); n2, w2 = dijkstra(via, dst)
chain_nodes = n1 + n2[1:]; chain_ways = w1 + w2
raw = [nodes[k] for k in chain_nodes]
seq = []
for wid in chain_ways:
    t = ways[wid][0]; key = (t.get('name', '?'), t.get('highway'), t.get('surface', '?'))
    if not seq or seq[-1] != key: seq.append(key)
print('cadena real:'); [print('   ', k) for k in seq]

# per raw vertex: section from the way that leads to it
def section_of(tags):
    if tags.get('surface') in ('unpaved', 'gravel', 'dirt', 'ground', 'compacted', 'fine_gravel'): return 'gravel'
    if tags.get('highway') in ('primary', 'secondary'): return 'avenue'
    return 'street'
vertex_section = [section_of(ways[chain_ways[0]][0])] + [section_of(ways[wid][0]) for wid in chain_ways]

# ---------------- resample + smooth corners ----------------
def resample(pts, secs, step=10.0):
    """Points every `step` metres along the polyline; each point takes the section of the segment it lies on."""
    out, osec = [pts[0]], [secs[0]]
    total = sum(math.dist(a, b) for a, b in zip(pts, pts[1:]))
    target = step
    acc = 0.0
    for (a, b), s in zip(zip(pts, pts[1:]), secs[1:]):
        seg = math.dist(a, b)
        if seg < 1e-9: continue
        while target <= acc + seg + 1e-9 and target < total - step * 0.5:
            u = (target - acc) / seg
            out.append((a[0] + (b[0] - a[0]) * u, a[1] + (b[1] - a[1]) * u)); osec.append(s)
            target += step
        acc += seg
    out.append(pts[-1]); osec.append(secs[-1])
    return out, osec
def fillet_polyline(pts, secs, R=18.0, min_turn_deg=18.0):
    """Replace every sharp vertex by a circular arc tangent to both segments (radius limited by segment lengths)."""
    out, osec = [pts[0]], [secs[0]]
    for i in range(1, len(pts) - 1):
        a, b, c = pts[i - 1], pts[i], pts[i + 1]
        u = (b[0] - a[0], b[1] - a[1]); v = (c[0] - b[0], c[1] - b[1])
        lu, lv = math.hypot(*u), math.hypot(*v)
        if lu < 1e-6 or lv < 1e-6: continue
        u = (u[0] / lu, u[1] / lu); v = (v[0] / lv, v[1] / lv)
        cosang = max(-1.0, min(1.0, u[0] * v[0] + u[1] * v[1])); theta = math.acos(cosang)
        if math.degrees(theta) < min_turn_deg:
            out.append(b); osec.append(secs[i]); continue
        r = min(R, 0.45 * min(lu, lv) / max(1e-6, math.tan(theta / 2.0)))
        T = r * math.tan(theta / 2.0)
        p1 = (b[0] - u[0] * T, b[1] - u[1] * T); p2 = (b[0] + v[0] * T, b[1] + v[1] * T)
        cross = u[0] * v[1] - u[1] * v[0]
        nrm = (-u[1], u[0]) if cross > 0 else (u[1], -u[0])
        o = (p1[0] + nrm[0] * r, p1[1] + nrm[1] * r)
        a1 = math.atan2(p1[1] - o[1], p1[0] - o[0]); a2 = math.atan2(p2[1] - o[1], p2[0] - o[0])
        da = (a2 - a1 + math.pi) % (2 * math.pi) - math.pi
        steps = max(2, int(abs(da) * r / 8.0))
        for k in range(steps + 1):
            out.append((o[0] + r * math.cos(a1 + da * k / steps), o[1] + r * math.sin(a1 + da * k / steps))); osec.append(secs[i])
    out.append(pts[-1]); osec.append(secs[-1])
    return out, osec
def simplify(pts, secs, tol=1.5):
    """Douglas-Peucker on the raw chain so the corner arcs get long straight legs; a section change is always kept."""
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
    anchors = [i for i, k in enumerate(keep) if k]
    for i0, i1 in zip(anchors, anchors[1:]): rec(i0, i1)
    return [p_ for p_, k in zip(pts, keep) if k], [s_ for s_, k in zip(secs, keep) if k]
clean, csec = simplify(raw, vertex_section, 1.5)
print('vértices tras simplificar:', len(clean), 'de', len(raw))
fil, fsec = fillet_polyline(clean, csec)
axis, _ = resample(fil, fsec, 10.0)
# sections come from the RAW chain (each raw segment carries its way's section): project every axis point onto it
raw_segs = [(raw[i], raw[i + 1], vertex_section[i + 1]) for i in range(len(raw) - 1)]
def section_at_point(p_):
    best, bsec = 1e18, 'avenue'
    for a, b, s in raw_segs:
        ab = (b[0] - a[0], b[1] - a[1]); l2 = ab[0] ** 2 + ab[1] ** 2
        u = 0.0 if l2 < 1e-9 else max(0.0, min(1.0, ((p_[0] - a[0]) * ab[0] + (p_[1] - a[1]) * ab[1]) / l2))
        d = math.dist(p_, (a[0] + ab[0] * u, a[1] + ab[1] * u))
        if d < best: best, bsec = d, s
    return bsec
asec = [section_at_point(p_) for p_ in axis]
axis_g = [g(p) for p in axis]
cum = [0.0]
for a, b in zip(axis_g, axis_g[1:]): cum.append(cum[-1] + math.dist(a, b))
L = cum[-1]
turns = [abs((math.degrees(math.atan2(c[1] - b[1], c[0] - b[0]) - math.atan2(b[1] - a[1], b[0] - a[0])) + 180) % 360 - 180) for a, b, c in zip(axis_g, axis_g[1:], axis_g[2:])]
print(f'eje: {len(axis_g)} puntos, {L:.0f} m, giro máximo entre tramos de 10 m: {max(turns):.1f}°')
sec_len = collections.Counter()
for (a, b), s in zip(zip(axis_g, axis_g[1:]), asec[1:]): sec_len[s] += math.dist(a, b)
print('metros por sección:', {k: round(v) for k, v in sec_len.items()})

# ================= stage 2: everything else =================
axis = axis_g
def sample(s):
    n = len(axis) - 1
    i = 0 if s <= 0 else n - 1 if s >= L else next(k for k in range(n) if s <= cum[k + 1])
    (x1, z1), (x2, z2) = axis[i], axis[i + 1]
    u = (s - cum[i]) / max(1e-6, cum[i + 1] - cum[i]); tx, tz = x2 - x1, z2 - z1; nn = math.hypot(tx, tz); tx, tz = tx / nn, tz / nn
    return (x1 + (x2 - x1) * u, z1 + (z2 - z1) * u), (tx, tz), (tz, -tx)
def off(s, lat):
    (px, pz), _, (nx, nz) = sample(s); return (px + nx * lat, pz + nz * lat)
def project(x, z):
    best = (1e18, 0.0, 0.0)
    for i in range(len(axis) - 1):
        (x1, z1), (x2, z2) = axis[i], axis[i + 1]; dx, dz = x2 - x1, z2 - z1; ll = dx * dx + dz * dz
        u = max(0.0, min(1.0, ((x - x1) * dx + (z - z1) * dz) / ll)); px, pz = x1 + dx * u, z1 + dz * u
        d = math.hypot(x - px, z - pz)
        if d < best[0]: best = (d, cum[i] + math.sqrt(ll) * u, (x - px) * (dz / math.sqrt(ll)) + (z - pz) * (-dx / math.sqrt(ll)))
    return best[1], best[2]
def yaw_facing(tx, tz): return math.atan2(-tx, -tz)
# section intervals along s
sections = []
for i in range(len(axis) - 1):
    s0, s1, ty = cum[i], cum[i + 1], asec[i + 1]
    if sections and sections[-1]['type'] == ty: sections[-1]['s1'] = round(s1, 1)
    else: sections.append({'s0': round(s0, 1), 's1': round(s1, 1), 'type': ty})
def sec_at(s):
    for sc in sections:
        if sc['s0'] - 0.01 <= s <= sc['s1'] + 0.01: return sc['type']
    return sections[-1]['type']
LANE = {'avenue': 6.75, 'street': 3.75, 'gravel': 2.8}
CURB = {'avenue': 12.0, 'street': 8.0, 'gravel': 6.5}
PROP = {'avenue': 15.0, 'street': 10.0, 'gravel': 9.0}      # property line (fences / facades start)
print('secciones:', [(sc['type'], round(sc['s1'] - sc['s0'])) for sc in sections])

# ---- real junctions: chain nodes that connect to other driveable ways ----
chain_set = set(chain_nodes)
junctions = []
for k in chain_nodes[1:-1]:
    others = {wid for _, _, wid in G[k] if wid not in set(chain_ways)}
    if not others: continue
    x, z = g(nodes[k]); s_j, lat = project(x, z)
    # which side does the side street leave to? take the neighbour node of the other way
    sides = set()
    for v, _, wid in G[k]:
        if wid in others:
            vx, vz = g(nodes[v]); _, vlat = project(vx, vz)
            if abs(vlat) > 6: sides.add(1 if vlat > 0 else -1)
    for sd in sides:
        junctions.append({'s': round(s_j, 1), 'side': sd, 'name': ways[list(others)[0]][0].get('name', '')})
junctions.sort(key=lambda j: j['s'])
print('bocacalles reales:', len(junctions))

# ---- real POIs near the axis ----
def node_tags():
    out = {}
    for fn in ('damero_map.osm', 'norte_map.osm'):
        root = ET.parse(os.path.join(HERE, fn)).getroot()
        for n in root.iter('node'):
            tg = {t_.get('k'): t_.get('v') for t_ in n.findall('tag')}
            if tg: out[n.get('id')] = tg
    return out
ntags = node_tags()
def near_nodes(pred, maxd):
    res = []
    for nid, tg in ntags.items():
        if not pred(tg) or nid not in nodes: continue
        x, z = g(nodes[nid]); s_i, lat = project(x, z)
        if abs(lat) <= maxd and 5 < s_i < L - 5: res.append({'x': round(x, 1), 'z': round(z, 1), 's': round(s_i, 1), 'lat': round(lat, 1), 'side': 1 if lat > 0 else -1, 'tags': tg})
    return res
stops = near_nodes(lambda tg: tg.get('highway') == 'bus_stop', 30)
signals = near_nodes(lambda tg: tg.get('highway') == 'traffic_signals', 30)
trees = near_nodes(lambda tg: tg.get('natural') == 'tree', 40)
fuel_nodes = near_nodes(lambda tg: tg.get('amenity') == 'fuel', 90)
fuel_ways = []
for wid, (tg, refs) in ways.items():
    if tg.get('amenity') == 'fuel' and refs and refs[0] in nodes:
        pts = [g(nodes[r]) for r in refs if r in nodes]; cx, cz = sum(p_[0] for p_ in pts) / len(pts), sum(p_[1] for p_ in pts) / len(pts)
        s_i, lat = project(cx, cz)
        if abs(lat) < 90 and 60 < s_i < L - 60: fuel_ways.append({'x': cx, 'z': cz, 's': s_i, 'lat': lat, 'name': tg.get('brand') or tg.get('name') or 'bencinera'})
fuels = fuel_nodes + fuel_ways
print('paraderos', len(stops), 'semáforos', len(signals), 'árboles', len(trees), 'bencineras cerca:', [(round(f['s']), round(f['lat']), f.get('name') or f.get('tags', {}).get('brand')) for f in fuels])

# ---- station: real fuel station on the avenue if any (south side preferred), else placed on the avenue at s=520 south side ----
st = None
for f in sorted(fuels, key=lambda f: abs(f['lat'])):
    if sec_at(f['s']) == 'avenue' and 150 < f['s'] < 1500: st = f; break
if st: S_STATION, ST_SIDE, st_real = st['s'], (1 if st['lat'] > 0 else -1), True
else: S_STATION, ST_SIDE, st_real = 520.0, -1, False
st_pos = off(S_STATION, ST_SIDE * 30.0); (_, (stx, stz), _) = sample(S_STATION)
station = {'x': round(st_pos[0], 1), 'z': round(st_pos[1], 1), 'yaw': round(yaw_facing(stx, stz), 4), 's': round(S_STATION, 1), 'side': ST_SIDE, 'real': st_real}
print('estación en s=%.0f lado %d real=%s' % (S_STATION, ST_SIDE, st_real))
# the station detour needs the bus on that side's carriageway: with right-hand traffic the outbound (right) lane is side -1.
# If the station is on the north side (+1) the outbound bus would cross the median -> we move it to the south side lot at the same s.
if ST_SIDE == 1:
    ST_SIDE = -1; st_pos = off(S_STATION, -30.0); station.update({'x': round(st_pos[0], 1), 'z': round(st_pos[1], 1), 'side': -1, 'note': 'bencinera real al norte; el lote se refleja al sur para el sentido de ida'})

# ---- humps: two flat ones on the avenue, outbound side, before the station or after (>= 25 m from junctions) ----
def far_from_junctions(s, m=25):
    return all(abs(j['s'] - s) > m for j in junctions)
humps = []
s_try = 300.0
while len(humps) < 2 and s_try < 1400:
    if sec_at(s_try) == 'avenue' and far_from_junctions(s_try) and abs(s_try - S_STATION) > 140: humps.append({'s': round(s_try, 1), 'side': -1, 'kind': 'flat'})
    s_try += 30.0
print('lomos:', humps)

# ---- buildings from OSM (both maps), OBB, style by section ----
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
rnd = random.Random(2010)
blds = []
for wid, (tg, refs) in ways.items():
    if 'building' not in tg: continue
    poly = [nodes[r] for r in refs if r in nodes]
    if len(poly) < 4: continue
    area, center, (w, d), ang = obb(poly)
    if area < 12: continue
    x, z = g(center); s_b, lat = project(x, z)
    if abs(lat) < PROP[sec_at(s_b)] + 0.5 or abs(lat) > 75 or s_b < 5 or s_b > L - 5: continue
    # the oriented box must stay outside the corridor: check its four corners, not just the centre
    cy, sy = math.cos(ang), math.sin(ang)
    corners = [(x + sx * w / 2 * cy + sz * d / 2 * sy, z - sx * w / 2 * sy + sz * d / 2 * cy) for sx in (-1, 1) for sz in (-1, 1)]
    if any(abs(project(*c_)[1]) < PROP[sec_at(project(*c_)[0])] + 0.8 for c_ in corners): dropped_intruding = globals().get('dropped_intruding', 0) + 1; globals()['dropped_intruding'] = dropped_intruding; continue
    lv = tg.get('building:levels'); btype = tg['building']
    sec = sec_at(s_b)
    if lv and lv.isdigit(): levels = int(lv)
    elif btype in ('house', 'terrace', 'semidetached_house', 'residential'): levels = 1 if area < 110 else 2
    elif btype in ('apartments',): levels = 4
    elif area > 800: levels = 3
    else: levels = 1 if sec != 'avenue' or area < 160 else 2
    style = 'adobe' if sec == 'avenue' else 'poblacion' if sec == 'street' else 'parcela'
    if btype in ('school', 'public', 'commercial', 'church') and levels < 2: levels = 2
    blds.append({'x': round(x, 1), 'z': round(z, 1), 'w': round(max(w, 3), 1), 'd': round(max(d, 3), 1), 'yaw': round(ang, 4), 'levels': levels, 'type': btype, 'style': style, 's': round(s_b, 1), 'lat': round(lat, 1), 'delivery': False, 'damage': 0, 'collapsed': False})
print('edificios OSM en el corredor:', len(blds), '| descartados por invadir la calzada:', globals().get('dropped_intruding', 0))

# ---- turnarounds + station + eriazos at corners: exclusion zones (buildings removed there) ----
corners = [i for i, tturn in enumerate(turns) if tturn > 25]
corner_s = []
for i in corners:
    s_c = cum[i + 1]
    if not corner_s or s_c - corner_s[-1] > 30: corner_s.append(s_c)
print('esquinas (s):', [round(s_) for s_ in corner_s])
def excluded(b):
    s_b, lat = b['s'], b['lat']
    if (s_b < 60 or s_b > L - 60) and abs(lat) < 40: return True                 # turnaround plazas
    if abs(s_b - S_STATION) < 85 and lat < 0 and lat > -62: return True             # station lot + driveway
    return False
lots = []
kept = []
for b in blds:
    if excluded(b): continue
    kept.append(b)
blds = kept
# corner lots -> eriazos (inner corners get cleared: the arcs need room)
for s_c in corner_s:
    for side in (1, -1):
        lat_c = side * (PROP[sec_at(s_c)] + 11.0)
        cx, cz = off(s_c, lat_c); (_, (tx_, tz_), _) = sample(s_c)
        removed = [b for b in blds if abs(b['s'] - s_c) < 50 and (b['lat'] > 0) == (side > 0) and abs(b['lat']) < 40]
        blds = [b for b in blds if b not in removed]
        lots.append({'x': round(cx, 1), 'z': round(cz, 1), 'w': 22.0, 'd': 90.0, 'yaw': round(math.atan2(-tz_, tx_), 4), 'kind': 'eriazo', 'trash': 8})

# ---- fill frontage by style ----
covered = {1: [], -1: []}
for b in blds:
    if abs(b['lat']) < 48: half = max(b['w'], b['d']) / 2 + 1.5; covered[1 if b['lat'] > 0 else -1].append((b['s'] - half, b['s'] + half))
for j in junctions: covered[j['side']].append((j['s'] - 9, j['s'] + 9))
for lt in lots:
    s_l, lat_l = project(lt['x'], lt['z']); covered[1 if lat_l > 0 else -1].append((s_l - lt['d'] / 2 - 2, s_l + lt['d'] / 2 + 2))
covered[-1].append((S_STATION - 90, S_STATION + 90))
for side in (1, -1): covered[side] += [(-10, 60), (L - 60, L + 10)]
def overlaps(ivs, a, b): return any(a < i1 and b > i0 for i0, i1 in ivs)
FRONT = {'avenue': 8.0, 'street': 8.0, 'gravel': 40.0}
DEPTH = {'avenue': 12.0, 'street': 9.0, 'gravel': 10.0}
SETBACK = {'avenue': 0.0, 'street': 2.0, 'gravel': 14.0}
n_fill = 0; last_parcela_side = 1
for side in (1, -1):
    s_ = 14.0
    while s_ < L - 14.0:
        sec = sec_at(s_); front = FRONT[sec]
        if s_ + front > L - 14.0: break
        if not overlaps(covered[side], s_, s_ + front):
            if sec == 'gravel' and rnd.random() < 0.45: s_ += front; continue        # parcelas: sparse
            s_c = s_ + front / 2; (_, (tx_, tz_), _) = sample(s_c); yaw_ = math.atan2(-tz_, tx_)
            depth = DEPTH[sec]; setback = SETBACK[sec]; lat_c = side * (PROP[sec] + setback + depth / 2)
            cx_, cz_ = off(s_c, lat_c)
            style = 'adobe' if sec == 'avenue' else 'poblacion' if sec == 'street' else 'parcela'
            levels = 1 if (style != 'adobe' or rnd.random() < 0.7) else 2
            w_ = front * 0.98 if style != 'parcela' else 11.0
            entry = {'x': round(cx_, 1), 'z': round(cz_, 1), 'w': round(w_, 2), 'd': depth, 'yaw': round(yaw_, 4), 'levels': levels, 'type': 'fill', 'style': style, 's': round(s_c, 1), 'lat': round(lat_c, 1), 'delivery': False, 'damage': 0, 'collapsed': False}
            if style != 'adobe':
                fx_, fz_ = off(s_c, side * (PROP[sec] + 0.05)); entry['fence'] = {'x': round(fx_, 1), 'z': round(fz_, 1), 'yaw': round(yaw_, 4), 'len': front if style == 'poblacion' else 26.0, 'kind': 'wire' if style == 'parcela' else 'bars'}
            blds.append(entry); n_fill += 1
        s_ += front
print('frentes generados:', n_fill, '| edificios total:', len(blds))

# ---- light deterioration (owner: "menos ruina"): 22% cracked/stained, 2 collapsed, a few extra eriazos ----
cands = [i for i, b in enumerate(blds) if b['style'] in ('adobe', 'poblacion') and abs(b['lat']) < 40]
rnd.shuffle(cands)
for i in cands[:int(len(cands) * 0.22)]: blds[i]['damage'] = 1
coll = [i for i in cands if blds[i]['type'] == 'fill' and blds[i]['style'] == 'adobe' and 200 < blds[i]['s'] < 1400][:2]
for i in coll: blds[i]['collapsed'] = True; blds[i]['damage'] = 1
for i in cands[int(len(cands) * 0.22):int(len(cands) * 0.22) + 4]:
    b = blds[i]
    if b['type'] == 'fill' and b['style'] != 'parcela':
        lots.append({'x': b['x'], 'z': b['z'], 'w': b['w'], 'd': b['d'], 'yaw': b['yaw'], 'kind': 'eriazo', 'trash': 4}); b['collapsed'] = 'lot'
blds = [b for b in blds if b['collapsed'] != 'lot']
print('dañados:', sum(1 for b in blds if b['damage']), 'derrumbados:', sum(1 for b in blds if b['collapsed'] is True), 'eriazos:', len(lots))
# delivery: last parcela on the gravel stretch
parcelas = [i for i, b in enumerate(blds) if b['style'] == 'parcela']
if parcelas:
    di = max(parcelas, key=lambda i: blds[i]['s']); blds[di]['delivery'] = True
    print('entrega: parcela en s=%.0f lado %s' % (blds[di]['s'], '+' if blds[di]['lat'] > 0 else '-'))

# ---- gravel details ----
gravel = [sc for sc in sections if sc['type'] == 'gravel']
potholes = []
for sc in gravel:
    s_ = sc['s0'] + 18
    while s_ < sc['s1'] - 10:
        lat_ = rnd.uniform(-3.5, 3.5); px_, pz_ = off(s_, lat_)
        potholes.append({'x': round(px_, 1), 'z': round(pz_, 1), 'r': round(rnd.uniform(0.6, 1.3), 2)}); s_ += rnd.uniform(28, 55)
fences = [{'s0': sc['s0'] + 4, 's1': sc['s1'] - 4, 'side': sd} for sc in gravel for sd in (1, -1)]
poplars = []
for sc in gravel:
    s_ = sc['s0'] + 10
    while s_ < sc['s1'] - 6:
        px_, pz_ = off(s_, 1 * (PROP['gravel'] + 1.5)); poplars.append({'x': round(px_, 1), 'z': round(pz_, 1)}); s_ += 9.0
orchards = []
for sc in gravel:
    for side in (1, -1):
        s_ = sc['s0'] + 6
        while s_ < sc['s1'] - 6:
            for lat_ in range(int(PROP['gravel'] + 6), 70, 5):
                px_, pz_ = off(s_, side * lat_)
                if not any(abs(project(b['x'], b['z'])[0] - s_) < max(b['w'], b['d']) / 2 + 4 and abs(abs(b['lat']) - lat_) < max(b['w'], b['d']) / 2 + 4 for b in blds if b['style'] == 'parcela'):
                    orchards.append([round(px_, 1), round(pz_, 1)])
            s_ += 4.5
print('baches', len(potholes), 'cercos', len(fences), 'álamos', len(poplars), 'frutales', len(orchards))

# ---- circuit: outbound on the right lane of each section, teardrop at the end, back on the left lane, teardrop at the start ----
def lane(s): return LANE[sec_at(s)]
wps = []
def add(p_): wps.append((round(p_[0], 1), round(p_[1], 1)))
def add_all(ps): [add(p_) for p_ in ps]
def unit(v): n_ = math.hypot(*v); return (v[0] / n_, v[1] / n_)
def teardrop(origin, f, n, scale=1.0):
    return [(origin[0] + (f[0] * ds + n[0] * lt) * scale, origin[1] + (f[1] * ds + n[1] * lt) * scale) for ds, lt in [(20, -10.75), (36, -16), (50, -8), (56, 4), (50, 16), (36, 20), (22, 14), (8, 8)]]
s_ = 40.0
while s_ < S_STATION - 130: add(off(s_, -lane(s_))); s_ += 30.0
for ds, lt in [(-120, -LANE['avenue']), (-96, -12.5), (-74, -21.0), (-54, -28.0), (-36, -30.0), (-18, -30.0), (0, -30.0), (18, -30.0), (36, -28.5), (56, -22.0), (78, -13.0), (102, -LANE['avenue'])]:
    add(off(S_STATION + ds, lt))
def corner_near(s_, m=16.0): return any(abs(s_ - sc_) < m for sc_ in corner_s)
def leg(s_from, s_to, lane_sign):
    """Lane points from s_from to s_to; around each corner: one point 14 m before and one 8 m after so the driver brakes into the turn."""
    step_dir = 1.0 if s_to > s_from else -1.0
    s_ = s_from
    while (s_ < s_to) if step_dir > 0 else (s_ > s_to):
        if corner_near(s_):
            sc_ = min(corner_s, key=lambda c_: abs(c_ - s_))
            add(off(sc_ - step_dir * 14.0, lane_sign * lane(sc_ - step_dir * 14.0))); add(off(sc_ + step_dir * 8.0, lane_sign * lane(sc_ + step_dir * 8.0)))
            s_ = sc_ + step_dir * 30.0; continue
        add(off(s_, lane_sign * lane(s_)))
        s_ += step_dir * (25.0 if sec_at(s_) != 'avenue' else 30.0)
leg(S_STATION + 132, L - 40, -1.0)
add(off(L - 20, -lane(L - 20)))
(_, fe, ne) = sample(L); add_all(teardrop(sample(L)[0], unit(fe), ne, 0.85))
leg(L - 30.0, 50.0, 1.0)
add(off(24, lane(24)))
(_, f0, n0) = sample(0.0); add_all(teardrop(sample(0.0)[0], (-f0[0], -f0[1]), (-n0[0], -n0[1]), 0.85))
pruned = []
for pt in wps:
    if pruned and math.dist(pt, pruned[-1]) < 7.5: continue
    pruned.append(pt)
wps = pruned
entry = off(8.0, -lane(8.0)); (_, (etx, etz), _) = sample(8.0)
chk = [entry] + wps + [wps[0], wps[1]]
tt = [abs((math.degrees(math.atan2(c[1] - b[1], c[0] - b[0]) - math.atan2(b[1] - a[1], b[0] - a[0])) + 180) % 360 - 180) for a, b, c in zip(chk, chk[1:], chk[2:])]
print(f'waypoints {len(wps)} | giro máximo {max(tt):.0f}° | tramo más corto {min(math.dist(a, b) for a, b in zip(chk, chk[1:])):.1f} m')
brake_pts = {tuple((round(v, 1) for v in off(sc_ - d_ * 14.0, sg * lane(sc_ - d_ * 14.0)))) for sc_ in corner_s for d_ in (1.0, -1.0) for sg in (-1.0, 1.0)} | {tuple((round(v, 1) for v in off(sc_ + d_ * 8.0, sg * lane(sc_ + d_ * 8.0)))) for sc_ in corner_s for d_ in (1.0, -1.0) for sg in (-1.0, 1.0)}
sharp = [(round(t_), chk[i + 1]) for i, t_ in enumerate(tt) if t_ > 56]
print('giros > 56° (todos deben ser puntos de frenado):', sharp)
assert all(pt in brake_pts for _, pt in sharp) and max(tt) <= 100, 'giro cerrado fuera de un punto de frenado'
assert min(math.dist(a, b) for a, b in zip(chk, chk[1:])) >= 7.5

gaps = [{'side': j['side'], 's0': round(j['s'] - 8, 1), 's1': round(j['s'] + 8, 1), 'name': j['name']} for j in junctions]
gaps.append({'side': -1, 's0': round(S_STATION - 112, 1), 's1': round(S_STATION + 112, 1), 'name': 'estacion'})
def snap(items, lat_abs):
    return [dict(zip(('x', 'z'), (round(v, 1) for v in off(it['s'], math.copysign(lat_abs, it['lat'])))), s=it['s'], side=it['side']) for it in items]
median_trees = [dict(zip(('x', 'z'), (round(v, 1) for v in off(s_, 0.0)))) for s_ in range(40, int(L) - 40, 30) if sec_at(s_) == 'avenue']
out = {
    'source': 'OpenStreetMap contributors, ODbL 1.0 (https://www.openstreetmap.org/copyright), extracto 2026-09-14 (Rancagua: damero y sector norte)',
    'center_latlon': [LAT0, LON0], 'length': round(L, 1),
    'lane_offset': LANE['avenue'], 'carriageway_width': 10.5, 'median_width': 3.0, 'curb_lateral': 12.0, 'sidewalk_lateral': 14.0,
    'sections': sections, 'lane_by_type': LANE, 'curb_by_type': CURB, 'property_by_type': PROP,
    'axis': [[round(x, 1), round(z, 1)] for x, z in axis], 'waypoints': [list(p_) for p_ in wps],
    'entry': {'x': round(entry[0], 1), 'z': round(entry[1], 1), 'yaw': round(yaw_facing(etx, etz), 4)},
    'exit': dict(zip(('x', 'z'), (round(v, 1) for v in off(L - 8, lane(L - 8))))),
    'curb_gaps': gaps, 'humps': humps, 'station': station, 'fuel_lot': {}, 'pasaje': {}, 'underpass': {},
    'buildings': blds, 'lots': lots, 'bus_stops': snap(stops, 14.0), 'traffic_signals': snap(signals, 13.4), 'trees': snap(trees, 14.6), 'median_trees': median_trees,
    'gravel_zones': [{'s0': sc['s0'], 's1': sc['s1']} for sc in gravel], 'potholes': potholes, 'fences': fences, 'poplars': poplars, 'orchards': orchards,
    'street_names': [k[0] for k in seq],
}
dst_path = os.path.join(HERE, '..', 'data', 'b0_rancagua.json')
json.dump(out, open(dst_path, 'w', encoding='utf-8'), ensure_ascii=False, separators=(',', ':'))
print('escrito data/b0_rancagua.json', os.path.getsize(dst_path) // 1024, 'KB')
