"""OSM (compact JSON in metres, x east / y north) -> res://data/b0_departamental.json for Godot.
Godot frame: x = east, z = -north, y up. Everything the GDScript builders need is precomputed here,
including the demo circuit, so the angle check lives in one place. Run: python3 tools/osm_to_b0.py"""
import json, math, sys, os
HERE = os.path.dirname(os.path.abspath(__file__))
src = json.load(open(os.path.join(HERE, 'osm_departamental_compacto.json'), encoding='utf-8'))
LANE, CURB, SIDEWALK, CARRIAGE, MEDIAN = 6.75, 12.0, 14.0, 10.5, 3.0

def g(x, y): return (x, -y)                      # OSM -> Godot (x, z)
axis = [g(x, y) for x, y in src['axis']]
cum = [0.0]
for (x1, z1), (x2, z2) in zip(axis, axis[1:]): cum.append(cum[-1] + math.hypot(x2 - x1, z2 - z1))
L = cum[-1]
def sample(s):
    # beyond the ends the axis is extrapolated along its end segment (the turnaround loops live there)
    i = 0 if s <= 0 else len(axis) - 2 if s >= L else next(k for k in range(len(axis) - 1) if s <= cum[k + 1])
    (x1, z1), (x2, z2) = axis[i], axis[i + 1]
    t = (s - cum[i]) / max(1e-6, cum[i + 1] - cum[i])
    tx, tz = x2 - x1, z2 - z1; n = math.hypot(tx, tz); tx, tz = tx / n, tz / n
    return (x1 + (x2 - x1) * t, z1 + (z2 - z1) * t), (tx, tz), (tz, -tx)   # left normal = UP x tangent = (tz, -tx)
def off(s, lat):
    (px, pz), _, (nx, nz) = sample(s); return (px + nx * lat, pz + nz * lat)
def project(x, z):
    best = (1e9, 0.0, 0.0)
    for i in range(len(axis) - 1):
        (x1, z1), (x2, z2) = axis[i], axis[i + 1]; dx, dz = x2 - x1, z2 - z1; ll = dx * dx + dz * dz
        t = max(0.0, min(1.0, ((x - x1) * dx + (z - z1) * dz) / ll)); px, pz = x1 + dx * t, z1 + dz * t
        d = math.hypot(x - px, z - pz); nx, nz = dz / math.sqrt(ll), -dx / math.sqrt(ll)
        lat = (x - px) * nx + (z - pz) * nz
        if d < best[0]: best = (d, cum[i] + math.sqrt(ll) * t, lat)
    return best[1], best[2]
def yaw_facing(tx, tz): return math.atan2(-tx, -tz)  # Basis(UP, yaw) maps -Z onto (tx, tz)

# ---- places along the route (s in metres from the west end) ----
S_HUMPS_E = (300.0, 330.0)
ux, _ = src['underpass']['x'], 0
# underpass s: project the real underpass centre (x, y on the axis)
uy = None
for (x, y) in src['axis']:
    if uy is None or abs(x - ux) < abs(uy[0] - ux): uy = (x, y)
S_UNDER, _ = project(*g(ux, uy[1]))
S_HUMPS_W = (S_UNDER + 90.0, S_UNDER + 120.0)     # westbound humps east of the underpass, >= 25 m from it
pasaje = next(s for s in src['side_streets'] if 'pasaje' in s['name'].lower())
PX, PZ = g(pasaje['x'], pasaje['y']); FX, FZ = g(pasaje['far_x'], pasaje['far_y'])
pd = (FX - PX, FZ - PZ); pl = math.hypot(*pd); pd = (pd[0] / pl, pd[1] / pl); pn = (pd[1], -pd[0])  # left normal of pasaje dir
S_PASAJE, LAT_PASAJE = project(PX, PZ)
PASAJE_W = 14.0

# ---- circuit geometry helpers ----
def unit(v):
    n = math.hypot(*v); return (v[0] / n, v[1] / n)
def fillet(corner, u, d, R=16.0, steps=4):
    """Arc of radius R joining the line arriving at `corner` with direction u to the line leaving with direction d."""
    cosang = max(-1.0, min(1.0, u[0] * d[0] + u[1] * d[1])); theta = math.acos(cosang)
    if theta < 1e-3: return [corner]
    T = R * math.tan(theta / 2.0)
    p1 = (corner[0] - u[0] * T, corner[1] - u[1] * T); p2 = (corner[0] + d[0] * T, corner[1] + d[1] * T)
    cross = u[0] * d[1] - u[1] * d[0]           # >0: turning toward +z side in (x,z)... sign only
    nrm = (-u[1], u[0]) if cross > 0 else (u[1], -u[0])
    o = (p1[0] + nrm[0] * R, p1[1] + nrm[1] * R)
    a1 = math.atan2(p1[1] - o[1], p1[0] - o[0]); a2 = math.atan2(p2[1] - o[1], p2[0] - o[0])
    da = (a2 - a1 + math.pi) % (2 * math.pi) - math.pi
    return [(o[0] + R * math.cos(a1 + da * k / steps), o[1] + R * math.sin(a1 + da * k / steps)) for k in range(steps + 1)]
def teardrop(origin, f, n, scale=1.0):
    """U-turn: arrive heading f on the right lane, swing right, arc left, leave heading -f on the other lane. n = left normal of f."""
    pts = []
    for ds, lat in [(20, -10.75), (36, -16), (50, -8), (56, 4), (50, 16), (36, 20), (22, 14), (8, 8)]:
        pts.append((origin[0] + (f[0] * ds + n[0] * lat) * scale, origin[1] + (f[1] * ds + n[1] * lat) * scale))
    return pts
def line_x(p, v, q, w):
    """Intersection of line p+tv with q+sw."""
    den = v[0] * w[1] - v[1] * w[0]
    if abs(den) < 1e-9: return p
    t_ = ((q[0] - p[0]) * w[1] - (q[1] - p[1]) * w[0]) / den
    return (p[0] + v[0] * t_, p[1] + v[1] * t_)

# ---- circuit: eastbound (south carriageway, lat -LANE) with station detour and pasaje detour, east loop, westbound (lat +LANE), west loop ----
wps = []
def add(p): wps.append((round(p[0], 1), round(p[1], 1)))
def add_all(ps): [add(p) for p in ps]
S_STATION = 160.0
s = 40.0
while s < S_STATION - 130: add(off(s, -LANE)); s += 40.0
# station detour: lane -> lateral -30, then 36 m dead straight before the pump islands -> back to the lane (turns <= 16 deg)
for ds, lat in [(-120, -LANE), (-96, -12.5), (-74, -21.0), (-54, -28.0), (-36, -30.0), (-18, -30.0), (0, -30.0), (18, -30.0), (36, -28.5), (56, -22.0), (78, -13.0), (102, -LANE)]:
    add(off(S_STATION + ds, lat))
s = S_STATION + 142
while s < S_PASAJE - 70: add(off(s, -LANE)); s += 40.0
# pasaje detour: fillet from the eastbound lane into the pasaje right lane, down to the lot, teardrop, fillet back to the lane
(_, u_ax, _) = sample(S_PASAJE); u_ax = unit(u_ax)
lane_pt = off(S_PASAJE - 90, -LANE)
right_lane = (PX + pn[0] * (-3.5), PZ + pn[1] * (-3.5))            # pasaje right lane line (across -3.5), direction pd
corner_in = line_x(lane_pt, u_ax, right_lane, pd)
arc_in = fillet(corner_in, u_ax, pd)
add(off(S_PASAJE - 90, -LANE)); add_all(arc_in)
LOT_ALONG = 60.0
def pas(along, across): return (PX + pd[0] * along + pn[0] * across, PZ + pd[1] * along + pn[1] * across)
add(pas(LOT_ALONG - 18, -3.5))
add_all(teardrop(pas(LOT_ALONG, 0.0), pd, pn, scale=0.62))       # U-turn inside the lot: ~35 m deep, +-12 m wide
add(pas(LOT_ALONG - 18, 3.5)); add(pas(22, 3.5))
left_lane = (PX + pn[0] * 3.5, PZ + pn[1] * 3.5); back = (-pd[0], -pd[1])
corner_out = line_x(left_lane, back, off(S_PASAJE + 90, -LANE), u_ax)
add_all(fillet(corner_out, back, u_ax)); add(off(S_PASAJE + 90, -LANE))
s = S_PASAJE + 130
while s < L - 60: add(off(s, -LANE)); s += 40.0
add(off(L - 30, -LANE))
(_, fe, ne) = sample(L); add_all(teardrop(sample(L)[0], unit(fe), ne))
s = L - 40.0
while s > 60: add(off(s, LANE)); s -= 40.0
add(off(30, LANE))
(_, f0, n0) = sample(0.0); add_all(teardrop(sample(0.0)[0], (-f0[0], -f0[1]), (-n0[0], -n0[1])))
def turns(pts):
    out = []
    for a, b, c in zip(pts, pts[1:], pts[2:]):
        h1 = math.atan2(b[1] - a[1], b[0] - a[0]); h2 = math.atan2(c[1] - b[1], c[0] - b[0]); out.append(abs((math.degrees(h2 - h1) + 180) % 360 - 180))
    return out
# drop waypoints closer than the DemoDriver reach radius to their predecessor (fillet ends meeting lane points)
pruned = []
for pt in wps:
    if pruned and math.hypot(pt[0] - pruned[-1][0], pt[1] - pruned[-1][1]) < 7.5:
        print('  descartado waypoint casi duplicado', pt, 'junto a', pruned[-1]); continue
    pruned.append(pt)
wps = pruned
entry = off(8.0, -LANE); (_, (etx, etz), _) = sample(8.0)
chk = [entry] + wps + [wps[0], wps[1]]
tt = turns(chk); worst = max(tt); iw = tt.index(worst)
gapmin = min(math.hypot(b[0]-a[0], b[1]-a[1]) for a, b in zip(chk, chk[1:]))
print(f'eje L={L:.0f} m | waypoints {len(wps)} | giro máximo {worst:.0f}° en el punto {iw} {chk[iw+1]} | tramo más corto {gapmin:.1f} m')
assert worst <= 56, 'giro demasiado cerrado para el DemoDriver'
assert gapmin >= 7.5, 'dos waypoints dentro del radio de alcance (7 m)'

# ---- curb gaps (side, s0, s1): side streets, station, pasaje ----
gaps = []
for ss in src['side_streets']:
    sx, sz = g(ss['x'], ss['y']); s_j, lat = project(sx, sz)
    if 0 < s_j < L: gaps.append({'side': 1 if lat > 0 else -1, 's0': round(s_j - 8, 1), 's1': round(s_j + 8, 1), 'name': ss['name']})
gaps.append({'side': -1, 's0': round(S_STATION - 112, 1), 's1': round(S_STATION + 112, 1), 'name': 'estacion'})
gaps.append({'side': -1, 's0': round(S_PASAJE - 34, 1), 's1': round(S_PASAJE + 34, 1), 'name': 'pasaje'})

# ---- station (south side), delivery house (north side, west part), buildings filter ----
st_pos = off(S_STATION, -30.0); (_, (stx, stz), _) = sample(S_STATION)
station = {'x': round(st_pos[0], 1), 'z': round(st_pos[1], 1), 'yaw': round(yaw_facing(stx, stz), 4), 's': S_STATION}
lot = pas(LOT_ALONG + 16, -24.0); fuel_lot = {'x': round(lot[0], 1), 'z': round(lot[1], 1), 'yaw': round(yaw_facing(pn[0], pn[1]), 4), 'loop_center': dict(zip(('x','z'), (round(v,1) for v in pas(LOT_ALONG + 18, 0.0))))}
blds = []
for b in src['buildings']:
    x, z = g(b['x'], b['y']); s_b, lat = project(x, z)
    if abs(lat) < 15.5: continue                                  # inside the corridor
    if (s_b < 14 or s_b > L - 14) and abs(lat) < 45: continue     # turnaround plazas at both ends
    if lat < 0 and abs(s_b - S_STATION) < 85 and lat > -62: continue   # station lot and its long driveway
    # pasaje corridor
    rx, rz = x - PX, z - PZ; along = rx * pd[0] + rz * pd[1]; across = rx * pn[0] + rz * pn[1]
    if -5 < along < LOT_ALONG + 46 and abs(across) < 9 + PASAJE_W / 2: continue
    if LOT_ALONG - 8 < along < LOT_ALONG + 46 and abs(across) < 26: continue   # the fuel lot (teardrop +-12 m, 35 m deep)
    blds.append({'x': round(x, 1), 'z': round(z, 1), 'w': b['w'], 'd': b['d'], 'yaw': b['yaw'], 'levels': b['levels'], 'type': b['type'], 's': round(s_b, 1), 'lat': round(lat, 1), 'delivery': False})
# ---- fill the frontage where OSM has no building (ronda 4, D67): generated terraced houses with a fence ----
import random
SETBACK, DEPTH, FRONT, LOT_LAT = 2.5, 10.0, 8.0, 15.0
covered = {1: [], -1: []}
for b in blds:
    if abs(b['lat']) < 48:
        half = max(b['w'], b['d']) / 2.0 + 1.5
        covered[1 if b['lat'] > 0 else -1].append((b['s'] - half, b['s'] + half))
for gp in gaps:
    covered[gp['side']].append((gp['s0'] - 4.0, gp['s1'] + 4.0))
for side_ in (1, -1):
    covered[side_].append((S_UNDER - 22.0, S_UNDER + 22.0))
def overlaps(ivs, a, b):
    return any(a < i1 and b > i0 for i0, i1 in ivs)
rnd = random.Random(41); n_fill = 0
for side_ in (1, -1):
    s_ = 16.0
    while s_ + FRONT <= L - 16.0:
        if not overlaps(covered[side_], s_, s_ + FRONT):
            s_c = s_ + FRONT / 2.0
            (_, (tx_, tz_), _) = sample(s_c)
            yaw_ = math.atan2(-tz_, tx_)                       # Basis(UP, yaw) maps +X onto the tangent
            cx_, cz_ = off(s_c, side_ * (LOT_LAT + SETBACK + DEPTH / 2.0))
            fx_, fz_ = off(s_c, side_ * (LOT_LAT + 0.05))
            blds.append({'x': round(cx_, 1), 'z': round(cz_, 1), 'w': round(FRONT * 0.96, 2), 'd': DEPTH, 'yaw': round(yaw_, 4),
                         'levels': 1 if rnd.random() < 0.55 else 2, 'type': 'fill', 's': round(s_c, 1), 'lat': round(side_ * (LOT_LAT + SETBACK + DEPTH / 2.0), 1),
                         'delivery': False, 'fence': {'x': round(fx_, 1), 'z': round(fz_, 1), 'yaw': round(yaw_, 4), 'len': FRONT}})
            n_fill += 1
        s_ += FRONT
print('frentes generados:', n_fill)
cands = [i for i, b in enumerate(blds) if b['type'] in ('house', 'terrace', 'semidetached_house') and b['lat'] > 15.5 and b['lat'] < 40 and 80 < b['s'] < 260]
if not cands: cands = [i for i, b in enumerate(blds) if b['lat'] > 15.5 and b['lat'] < 40 and 60 < b['s'] < 300]
di = min(cands, key=lambda i: abs(blds[i]['s'] - 120)); blds[di]['delivery'] = True
def snap(items, lat_abs):
    out = []
    for it in items:
        x, z = g(it['x'], it['y']); s_i, lat = project(x, z)
        if 5 < s_i < L - 5: p = off(s_i, math.copysign(lat_abs, lat if lat != 0 else 1)); out.append({'x': round(p[0], 1), 'z': round(p[1], 1), 's': round(s_i, 1), 'side': 1 if lat > 0 else -1})
    return out
median_trees = [dict(zip(('x', 'z'), (round(v, 1) for v in off(s, 0.0)))) for s in range(40, int(L) - 40, 30) if abs(s - S_UNDER) > 25]
(_, (utx, utz), _) = sample(S_UNDER); up = off(S_UNDER, 0.0)
out = {
    'source': src['source'], 'center_latlon': src['center_latlon'], 'length': round(L, 1),
    'lane_offset': LANE, 'carriageway_width': CARRIAGE, 'median_width': MEDIAN, 'curb_lateral': CURB, 'sidewalk_lateral': SIDEWALK,
    'axis': [[round(x, 1), round(z, 1)] for x, z in axis],
    'waypoints': [list(p) for p in wps],
    'entry': {'x': round(entry[0], 1), 'z': round(entry[1], 1), 'yaw': round(yaw_facing(etx, etz), 4)},
    'exit': dict(zip(('x', 'z'), (round(v, 1) for v in off(L - 8, LANE)))),
    'curb_gaps': gaps,
    'humps': [{'s': s_h, 'side': -1, 'kind': 'flat'} for s_h in S_HUMPS_E] + [{'s': round(s_h, 1), 'side': 1, 'kind': 'round'} for s_h in S_HUMPS_W],   # flat = resalto plano 15 cm (tutorial, eastbound); round = resalto redondeado 7,5 cm x 3,7 m (Decreto 200)
    'station': station, 'fuel_lot': fuel_lot,
    'pasaje': {'x': round(PX, 1), 'z': round(PZ, 1), 'dir': [round(pd[0], 4), round(pd[1], 4)], 'length': round(LOT_ALONG - 6, 1), 'width': PASAJE_W, 'lot_along': LOT_ALONG, 'lot_depth': 44.0, 'lot_half_width': 26.0, 'name': pasaje['name']},
    'underpass': {'s': round(S_UNDER, 1), 'x': round(up[0], 1), 'z': round(up[1], 1), 'yaw': round(yaw_facing(utx, utz), 4), 'maxheight': src['underpass']['maxheight'], 'deck_length_along': 30.0, 'deck_width_across': 44.0, 'crossing_name': 'Gran Avenida José Miguel Carrera'},
    'buildings': blds, 'bus_stops': snap(src['bus_stops'], SIDEWALK), 'traffic_signals': snap(src['traffic_signals'], 13.4), 'trees': snap(src['trees'], SIDEWALK + 0.6), 'median_trees': median_trees,
    'street_names': sorted({s['name'] for s in src['side_streets'] if s['name']}),
}
dst = os.path.join(HERE, '..', 'data', 'b0_departamental.json')
json.dump(out, open(dst, 'w', encoding='utf-8'), ensure_ascii=False, separators=(',', ':'))
print(f"estación s={S_STATION} | paso bajo nivel s={S_UNDER:.0f} (x={up[0]:.0f}) | pasaje s={S_PASAJE:.0f} | entrega: edificio {di} ({blds[di]['type']}, s={blds[di]['s']}) | edificios {len(blds)} | huecos de bordillo {len(gaps)} | paraderos {len(out['bus_stops'])} | semáforos {len(out['traffic_signals'])} | árboles {len(out['trees'])}+{len(median_trees)}")
print('escrito', os.path.relpath(dst, HERE), os.path.getsize(dst) // 1024, 'KB')
