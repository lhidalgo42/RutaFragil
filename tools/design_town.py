#!/usr/bin/env python3
"""Pueblo DISEÑADO «Quenlobo» (D80, rehecho en D81): genera data/b0_pueblo.json con el mismo
esquema que los extractos de OSM (tools/osm_to_town.py), así los constructores de Godot no
cambian. Requínoa se queda como está en data/b0_requinoa.json.

Lo que el dueño marcó sobre la foto el 17 sep 2026 (D81):
  ROJO    → bosque denso de pinos gigantes alrededor del pueblo (clave `forests`, OsmForest)
  MORADO  → los árboles del pueblo son PALMERAS (`street_trees: "palm"` y `kind` en `trees`)
  CELESTE → la ESTACIÓN va ahí, al centro-sur; las dos vías rectas se cruzan en ella y donde
            una vía cruza una calle manda el tren (paso a nivel; ninguna casa ni calle en el corredor)
  VERDE   → la ciudad, generada IRREGULAR: no cuadrados perfectos
  huerto  → FUNDO vitivinícola con casa patronal y bodega: la misión de los viñedos

El plano, en metros, x al este y z al sur (Godot: -z es el norte):
  - ANILLO irregular (10 vértices con radio al azar, esquinas de R = 30) de avenida de doble
    calzada con bandejón: el recorrido del bus.
  - AVENIDA E–O (z = 0) y CALLE N–S (x = 0) rectas, salen por los cuatro bordes hasta 1500 m.
  - RED interior: una cuadrícula base cuyos cruces se mueven al azar hasta 18 m y de la que se
    quita un cuarto de los tramos (sin dejar cruces colgando). Las calles serpentean.
  - Manzanas irregulares; casas a lo largo de cada tramo, mirando a su calle, sin pisarse.
  - Plaza, iglesia y escuela al oeste del centro; parque al este; recinto de la ESTACIÓN al
    centro-sur (celeste), con las vías N–S por x = 80 y E–O por z = 50 cruzándose en él.
  - Bencinera al este del anillo. Paraderos, lomos, álamos en las salidas.

Uso:  python3 tools/design_town.py       → escribe data/b0_pueblo.json
"""
import json
import math
import os
import random
import re

HERE = os.path.dirname(os.path.abspath(__file__))
rnd = random.Random(81)

# ----------------------------------------------------------------------------- plano
RING_RX, RING_RZ = 310.0, 232.0
RING_VERTS = 10
CORNER_R = 30.0
BASE_X = [-210.0, -105.0, 0.0, 105.0, 210.0]     # calles N–S (índices 0..4)
BASE_Z = [-150.0, -75.0, 0.0, 75.0, 150.0]       # calles E–O (índices 0..4)
JITTER = 18.0
DROP_SHARE = 0.25
INNER_X, INNER_Z = 268.0, 190.0
EXIT_REACH = 1500.0
RAIL_X, RAIL_Z = 80.0, 50.0
RAIL_REACH = 2600.0
RAIL_CLEAR = 14.0
STREET_W = 8.0
MAIN_W = 10.0
SETBACK = 13.5
LOT = 15.0

LANE = {"avenue": 6.75, "street": 3.75, "gravel": 2.8, "bridge": 3.4}
CURB = {"avenue": 12.0, "street": 8.0, "gravel": 6.5, "bridge": 6.4}
PROP = {"avenue": 15.0, "street": 10.0, "gravel": 9.0, "bridge": 10.0}

NAMES = ["Avenida Quenlobo", "Calle Trepaluz", "Pasaje Vurca", "Calle Los Álamos", "Calle Ñirre",
         "Avenida del Anillo", "Calle La Estación", "Calle Peumo", "Calle Boldo", "Calle Litre"]


# ----------------------------------------------------------------------------- geometría
def fillet_closed(pts, r):
    n = len(pts) - 1
    out = []
    for i in range(n):
        a, b, c = pts[i - 1] if i > 0 else pts[n - 1], pts[i], pts[i + 1]
        u = (b[0] - a[0], b[1] - a[1]); v = (c[0] - b[0], c[1] - b[1])
        lu, lv = math.hypot(*u), math.hypot(*v)
        u = (u[0] / lu, u[1] / lu); v = (v[0] / lv, v[1] / lv)
        theta = math.acos(max(-1.0, min(1.0, u[0] * v[0] + u[1] * v[1])))
        if math.degrees(theta) < 8.0:
            out.append(b); continue
        rr = min(r * 1.6, r if math.degrees(theta) > 60 else r * 1.5, 0.45 * min(lu, lv) / max(1e-6, math.tan(theta / 2.0)))
        t = rr * math.tan(theta / 2.0)
        p1 = (b[0] - u[0] * t, b[1] - u[1] * t); p2 = (b[0] + v[0] * t, b[1] + v[1] * t)
        cross = u[0] * v[1] - u[1] * v[0]
        nrm = (-u[1], u[0]) if cross > 0 else (u[1], -u[0])
        o = (p1[0] + nrm[0] * rr, p1[1] + nrm[1] * rr)
        a1 = math.atan2(p1[1] - o[1], p1[0] - o[0]); a2 = math.atan2(p2[1] - o[1], p2[0] - o[0])
        da = (a2 - a1 + math.pi) % (2 * math.pi) - math.pi
        steps = max(3, int(abs(da) * rr / 5.0))
        out += [(o[0] + rr * math.cos(a1 + da * k / steps), o[1] + rr * math.sin(a1 + da * k / steps)) for k in range(steps + 1)]
    out.append(out[0])
    return out


def resample_closed(pts, step):
    out = [pts[0]]
    total = sum(math.dist(a, b) for a, b in zip(pts, pts[1:]))
    target, acc = step, 0.0
    for a, b in zip(pts, pts[1:]):
        seg = math.dist(a, b)
        if seg < 1e-9:
            continue
        while target <= acc + seg + 1e-9 and target < total - step * 0.6:
            u = (target - acc) / seg
            out.append((a[0] + (b[0] - a[0]) * u, a[1] + (b[1] - a[1]) * u)); target += step
        acc += seg
    out.append(pts[0])
    return out


# Anillo irregular: diez vértices sobre una elipse con el radio movido al azar, horario desde
# arriba. Un anillo rectangular se leía como caja; este es un pueblo que creció.
ring_raw = []
for k in range(RING_VERTS):
    ang = -math.pi + (2.0 * math.pi) * k / RING_VERTS + rnd.uniform(-0.12, 0.12)
    f = rnd.uniform(0.9, 1.08)
    ring_raw.append((RING_RX * f * math.cos(ang), RING_RZ * f * math.sin(ang)))
# sentido horario visto desde arriba (x este, z sur): ángulo creciente ya lo es
ring_raw.append(ring_raw[0])
axis = resample_closed(fillet_closed(ring_raw, CORNER_R), 10.0)
cum = [0.0]
for a, b in zip(axis, axis[1:]):
    cum.append(cum[-1] + math.dist(a, b))
L = cum[-1]


def sample(s):
    n = len(axis) - 1; s = min(max(s, 0.0), L)
    i = next((k for k in range(n) if s <= cum[k + 1] + 1e-9), n - 1)
    (x1, z1), (x2, z2) = axis[i], axis[i + 1]
    u = (s - cum[i]) / max(1e-6, cum[i + 1] - cum[i])
    tx, tz = x2 - x1, z2 - z1; nn = math.hypot(tx, tz) or 1.0; tx, tz = tx / nn, tz / nn
    return (x1 + (x2 - x1) * u, z1 + (z2 - z1) * u), (tx, tz), (tz, -tx)


def off(s, lat):
    (px, pz), _, (nx, nz) = sample(s)
    return (px + nx * lat, pz + nz * lat)


def project(x, z):
    best = (1e18, 0.0, 0.0)
    for i in range(len(axis) - 1):
        (x1, z1), (x2, z2) = axis[i], axis[i + 1]; dx, dz = x2 - x1, z2 - z1; ll = dx * dx + dz * dz
        if ll < 1e-9:
            continue
        sl = math.sqrt(ll); u = max(0.0, min(1.0, ((x - x1) * dx + (z - z1) * dz) / ll))
        px, pz = x1 + dx * u, z1 + dz * u; d = math.hypot(x - px, z - pz)
        if d < best[0]:
            perp = (x - px) * (dz / sl) + (z - pz) * (-dx / sl)
            best = (d, cum[i] + sl * u, math.copysign(d, perp if perp != 0.0 else 1.0))
    return best[1], best[2]


def yaw_facing(tx, tz):
    return math.atan2(-tx, -tz)


def heading(s):
    _, (tx, tz), _ = sample(s)
    return math.atan2(tz, tx)


def inside_ring(x, z, margin=0.0):
    """Dentro del anillo: el costado firmado hacia el centro es negativo (anillo horario)."""
    _, lat = project(x, z)
    cx = sum(p[0] for p in axis) / len(axis); cz = sum(p[1] for p in axis) / len(axis)
    # el signo de "adentro" se calibra con el centro
    _, lat_c = project(cx, cz)
    inner_sign = -1.0 if lat_c < 0 else 1.0
    return lat * inner_sign > margin


# ----------------------------------------------------------------------------- esquinas y waypoints
hits = []
s_c = 18.0
while s_c < L - 18.0:
    dv = abs((math.degrees(heading(s_c + 16.0) - heading(s_c - 16.0)) + 180) % 360 - 180)
    if dv > 30.0:
        hits.append(s_c)
    s_c += 4.0
corner_s, run = [], []
for h in hits + [1e9]:
    if run and h - run[-1] > 9.0:
        corner_s.append(sum(run) / len(run)); run = []
    if h < 1e8:
        run.append(h)
merged = True
while merged and len(corner_s) > 1:
    merged = False
    for i in range(len(corner_s) - 1):
        if corner_s[i + 1] - corner_s[i] < 46.0:
            corner_s[i:i + 2] = [(corner_s[i] + corner_s[i + 1]) * 0.5]; merged = True; break

wps = []


def add_wp(p):
    if not wps or math.dist(p, wps[-1]) >= 9.0:
        wps.append((round(p[0], 1), round(p[1], 1)))


lane = LANE["avenue"]
s_ = 12.0
last_corner = -1e9
while s_ < L - 8.0:
    near = [c for c in corner_s if abs(c - s_) < 22 and c > last_corner + 40.0]
    if near:
        sc_ = near[0]; last_corner = sc_
        add_wp(off(sc_ - 18.0, -lane)); add_wp(off(sc_ + 26.0, -lane))
        s_ = sc_ + 40.0; continue
    add_wp(off(s_, -lane)); s_ += 12.0
entry = off(4.0, -lane); (_, (etx, etz), _) = sample(4.0)

# ----------------------------------------------------------------------------- red de calles
# Cruces de la cuadrícula base, movidos al azar; los de las dos calles principales solo se
# mueven a lo largo de su propia calle, así la avenida y la calle N–S siguen rectas.
node = {}
for i, bx in enumerate(BASE_X):
    for j, bz in enumerate(BASE_Z):
        jx = 0.0 if bx == 0.0 else rnd.uniform(-JITTER, JITTER)
        jz = 0.0 if bz == 0.0 else rnd.uniform(-JITTER, JITTER)
        node[(i, j)] = (bx + jx, bz + jz)
# tramos: entre cruces vecinos, más un tramo de salida al anillo por cada punta de línea
def ring_point_toward(x, z):
    """El punto del EJE del anillo más cercano a (x, z): ahí termina cada calle que sale de la
    cuadrícula. El anillo es irregular, así que un largo fijo dejaba calles muertas 30 m antes
    de la avenida o asomando por fuera. OsmTown las recorta después al cordón."""
    s_r, _ = project(x, z)
    (ax, az), _, _ = sample(s_r)
    return (ax, az)


segments = []   # (p, q, main, key)
for i in range(len(BASE_X)):
    x_top = node[(i, 0)][0]; x_bot = node[(i, len(BASE_Z) - 1)][0]
    segments.append((ring_point_toward(x_top, -INNER_Z - 60.0), node[(i, 0)], BASE_X[i] == 0.0, ("x", i, -1)))
    for j in range(len(BASE_Z) - 1):
        segments.append((node[(i, j)], node[(i, j + 1)], BASE_X[i] == 0.0, ("x", i, j)))
    segments.append((node[(i, len(BASE_Z) - 1)], ring_point_toward(x_bot, INNER_Z + 60.0), BASE_X[i] == 0.0, ("x", i, 99)))
for j in range(len(BASE_Z)):
    z_l = node[(0, j)][1]; z_r = node[(len(BASE_X) - 1, j)][1]
    segments.append((ring_point_toward(-INNER_X - 60.0, z_l), node[(0, j)], BASE_Z[j] == 0.0, ("z", j, -1)))
    for i in range(len(BASE_X) - 1):
        segments.append((node[(i, j)], node[(i + 1, j)], BASE_Z[j] == 0.0, ("z", j, i)))
    segments.append((node[(len(BASE_X) - 1, j)], ring_point_toward(INNER_X + 60.0, z_r), BASE_Z[j] == 0.0, ("z", j, 99)))


def degree(pt, segs):
    return sum(1 for (p, q, _, _) in segs if math.dist(p, pt) < 0.5 or math.dist(q, pt) < 0.5)


# se quita un cuarto de los tramos interiores no principales, sin dejar cruces con un solo brazo
candidates = [s for s in segments if not s[2] and s[3][2] not in (-1, 99)]
rnd.shuffle(candidates)
to_drop = set()
for seg in candidates:
    if len(to_drop) >= int(len(candidates) * DROP_SHARE):
        break
    remaining = [s for s in segments if s[3] not in to_drop and s[3] != seg[3]]
    if degree(seg[0], remaining) >= 2 and degree(seg[1], remaining) >= 2:
        to_drop.add(seg[3])
segments = [s for s in segments if s[3] not in to_drop]


def near_rail_line(p, q):
    """El tramo corre pegado y paralelo a una vía: el tren se queda con ese corredor."""
    for (rx, rz, vertical) in ((RAIL_X, None, True), (None, RAIL_Z, False)):
        if vertical and abs(p[0] - rx) < RAIL_CLEAR and abs(q[0] - rx) < RAIL_CLEAR:
            return True
        if not vertical and abs(p[1] - rz) < RAIL_CLEAR and abs(q[1] - rz) < RAIL_CLEAR:
            return True
    return False


segments = [s for s in segments if not near_rail_line(s[0], s[1])]

# calles: cadenas de tramos consecutivos de la misma línea
streets = []
names_used = []


def emit_chain(chain, main, name):
    pts = [chain[0][0]] + [q for (_, q, _, _) in chain]
    streets.append({"pts": [[round(x, 1), round(z, 1)] for x, z in pts], "w": MAIN_W if main else STREET_W, "surface": "street"})
    names_used.append(name)


for axis_key, count in (("x", len(BASE_X)), ("z", len(BASE_Z))):
    for idx in range(count):
        line = sorted([s for s in segments if s[3][0] == axis_key and s[3][1] == idx], key=lambda s: (s[3][2] if s[3][2] != 99 else 98))
        chain = []
        for seg in line:
            if chain and math.dist(chain[-1][1], seg[0]) > 0.5:
                emit_chain(chain, chain[0][2], NAMES[(idx * 3 + (0 if axis_key == "x" else 1)) % len(NAMES)]); chain = []
            chain.append(seg)
        if chain:
            emit_chain(chain, chain[0][2], NAMES[(idx * 3 + (0 if axis_key == "x" else 1)) % len(NAMES)])

# las cuatro salidas, rectas hasta EXIT_REACH; nacen en el EJE del anillo, como los tramos
# interiores, y OsmTown las recorta al cordón (D84): nacidas 13 m afuera quedaban separadas de
# la avenida por la vereda y el cordón, «las 4 salidas no parecen conectadas», dijo el dueño
exit_starts = []
for (px, pz, dx, dz) in ((RING_RX, 0.0, 1.0, 0.0), (-RING_RX, 0.0, -1.0, 0.0), (0.0, -RING_RZ, 0.0, -1.0), (0.0, RING_RZ, 0.0, 1.0)):
    s0, _ = project(px, pz)
    (ax, az), _, _ = sample(s0)
    far = (dx * EXIT_REACH if dx else 0.0, dz * EXIT_REACH if dz else 0.0)
    streets.append({"pts": [[round(ax, 1), round(az, 1)], [round(far[0], 1), round(far[1], 1)]], "w": 9.0, "surface": "street"})
    names_used.append("Avenida Quenlobo" if dx else "Calle Trepaluz")
    exit_starts.append((s0, far))

# camino de tierra del fundo: desde la salida este hacia el norte, hasta la casa patronal
FUNDO_X = 520.0
streets.append({"pts": [[FUNDO_X, -9.0], [FUNDO_X, -150.0], [FUNDO_X + 6.0, -196.0]], "w": 6.0, "surface": "gravel"})
names_used.append("Camino del Fundo")


# ----------------------------------------------------------------------------- lotes especiales
def cell_poly(i0, i1, j0, j1, shrink):
    corners = [node[(i0, j0)], node[(i1, j0)], node[(i1, j1)], node[(i0, j1)]]
    cx = sum(c[0] for c in corners) / 4.0; cz = sum(c[1] for c in corners) / 4.0
    out = []
    for (x, z) in corners:
        dx, dz = x - cx, z - cz; d = math.hypot(dx, dz) or 1.0
        out.append([round(x - dx / d * shrink * 1.35, 1), round(z - dz / d * shrink * 1.35, 1)])
    out.append(out[0])
    return out, (cx, cz)


def inside(poly, x, z):
    n = len(poly) - 1; c = False
    for i in range(n):
        (x1, z1), (x2, z2) = poly[i], poly[i + 1]
        if (z1 > z) != (z2 > z) and x < (x2 - x1) * (z - z1) / ((z2 - z1) or 1e-9) + x1:
            c = not c
    return c


plaza_poly, plaza_c = cell_poly(1, 2, 1, 2, 9.0)      # al oeste de la calle N–S, al norte de la avenida
church_poly, church_c = cell_poly(0, 1, 1, 2, 10.0)
school_poly, school_c = cell_poly(0, 1, 2, 3, 10.0)
park_poly, park_c = cell_poly(3, 4, 3, 4, 9.0)
station_poly, station_c = cell_poly(2, 4, 2, 3, 6.0)   # el rectángulo CELESTE del dueño
plaza = {"name": "Plaza Quenlobo", "polygon": plaza_poly}
parks = [{"name": "Parque Vurca", "polygon": park_poly}]
churches = [{"x": round(church_c[0], 1), "z": round(church_c[1], 1), "name": "Iglesia de Quenlobo",
             "polygon": [[church_c[0] - 9.0, church_c[1] - 16.0], [church_c[0] + 9.0, church_c[1] - 16.0], [church_c[0] + 9.0, church_c[1] + 16.0], [church_c[0] - 9.0, church_c[1] + 16.0], [church_c[0] - 9.0, church_c[1] - 16.0]]}]
exclusions = [plaza_poly, church_poly, school_poly, park_poly, station_poly]

# ----------------------------------------------------------------------------- casas
buildings = []
placed = []


def add_building(cx, cz, w, d, yaw, style, levels, kind="house", delivery=False):
    s_b, lat_b = project(cx, cz)
    b = {"x": round(cx, 1), "z": round(cz, 1), "w": round(w, 1), "d": round(d, 1), "yaw": round(yaw, 4),
         "levels": levels, "type": kind, "style": style, "s": round(s_b, 1), "lat": round(lat_b, 1),
         "delivery": delivery, "damage": 0, "collapsed": False}
    buildings.append(b); placed.append((cx, cz, max(w, d)))
    return b


def free_spot(cx, cz, w, d):
    for (px, pz, size) in placed:
        if math.hypot(cx - px, cz - pz) < (size + max(w, d)) * 0.5 + 2.5:
            return False
    for poly in exclusions:
        if inside(poly, cx, cz):
            return False
    if abs(cx - RAIL_X) < RAIL_CLEAR or abs(cz - RAIL_Z) < RAIL_CLEAR:
        return False
    if not inside_ring(cx, cz, 4.0):
        return False   # las casas del pueblo van DENTRO del anillo; afuera es campo y bosque
    # las esquinas no invaden el corredor del anillo
    for sx in (-1, 1):
        for sz in (-1, 1):
            _, lat_c = project(cx + sx * w * 0.5, cz + sz * d * 0.5)
            if abs(lat_c) < PROP["avenue"] + 0.5:
                return False
    return True


add_building(church_c[0], church_c[1], 18.0, 32.0, 0.0, "adobe", 2, "church")
add_building(school_c[0], school_c[1], 46.0, 20.0, 0.0, "default", 2, "school")

# el edificio de la estación, al oeste de la vía N–S y al norte de la E–O, dentro del recinto
ST_BX, ST_BZ = RAIL_X - 34.0, RAIL_Z - 4.0
add_building(ST_BX, ST_BZ, 30.0, 12.0, -math.pi * 0.5, "adobe", 1, "station")

for (p, q, main, key) in segments:
    seg_len = math.dist(p, q)
    if seg_len < 30.0:
        continue
    tx, tz = (q[0] - p[0]) / seg_len, (q[1] - p[1]) / seg_len
    nx, nz = tz, -tx
    for side in (-1.0, 1.0):
        d_along = 14.0
        k = 0
        while d_along + 6.0 < seg_len - 14.0:
            cx = p[0] + tx * d_along + nx * side * SETBACK
            cz = p[1] + tz * d_along + nz * side * SETBACK
            w = 10.0 + (k % 3) * 1.5 + rnd.uniform(-0.8, 0.8)
            depth = 11.0 + rnd.uniform(-1.0, 1.5)
            style = "adobe" if math.hypot(cx, cz) < 130.0 else ("parcela" if math.hypot(cx, cz) > 215.0 else "poblacion")
            levels = 2 if (style == "adobe" and k % 3 == 1) else 1
            yaw = yaw_facing(-nx * side, -nz * side) + rnd.uniform(-0.05, 0.05)   # mira a la calle
            if free_spot(cx, cz, w, depth):
                add_building(cx, cz, w, depth, yaw, style, levels)
            d_along += LOT + rnd.uniform(-1.5, 2.5); k += 1

# ----------------------------------------------------------------------------- fundo vitivinícola (la misión)
# La viña es un pentágono torcido, no un rectángulo (D82): las hileras se recortan al polígono
# y cada doce hay una calle de cabecera para el tractor. El PATIO (z de -235 a -175) queda
# libre de parras: ahí van la casa patronal, la bodega, los frutales y el final del camino.
vine_poly = [[440.0, -440.0], [722.0, -462.0], [748.0, -256.0], [612.0, -232.0], [440.0, -262.0], [440.0, -440.0]]


def row_span(z):
    xs = []
    for (x1, z1), (x2, z2) in zip(vine_poly, vine_poly[1:]):
        if (z1 > z) != (z2 > z):
            xs.append(x1 + (x2 - x1) * (z - z1) / (z2 - z1))
    return (min(xs) + 6.0, max(xs) - 6.0) if len(xs) >= 2 else None


vine_rows = []
for k, z in enumerate(range(-456, -236, 3)):
    if k % 12 == 11:
        continue
    span = row_span(float(z))
    if span and span[1] - span[0] > 20.0:
        vine_rows.append([round(span[0], 1), float(z), round(span[1], 1)])
fields = [{"kind": "vineyard", "polygon": vine_poly}]
casa = add_building(FUNDO_X - 26.0, -200.0, 22.0, 12.0, yaw_facing(1.0, 0.0), "adobe", 2, "house", delivery=True)
add_building(FUNDO_X + 36.0, -208.0, 30.0, 14.0, yaw_facing(-1.0, 0.0), "parcela", 1, "house")   # la bodega
orchards = [[FUNDO_X - 40.0 + 7.0 * i, -160.0 - 7.0 * j] for i in range(4) for j in range(3)]      # frutales del patio

# ----------------------------------------------------------------------------- palmeras del pueblo
trees = []
for (p, q, main, key) in segments:
    seg_len = math.dist(p, q)
    if seg_len < 24.0:
        continue
    tx, tz = (q[0] - p[0]) / seg_len, (q[1] - p[1]) / seg_len
    nx, nz = tz, -tx
    d_along = 10.0
    while d_along < seg_len - 10.0:
        for side in (-1.0, 1.0):
            x = p[0] + tx * d_along + nx * side * 6.3
            z = p[1] + tz * d_along + nz * side * 6.3
            if abs(x - RAIL_X) > 7.0 and abs(z - RAIL_Z) > 7.0 and not inside(station_poly, x, z):
                trees.append({"x": round(x, 1), "z": round(z, 1), "s": 0.0, "side": int(side), "kind": "palm"})
        d_along += 12.0

# ----------------------------------------------------------------------------- bosque (lo rojo)
# Los cuatro bosques se tocan y dejan un claro rectangular justo alrededor del anillo (D82):
# antes había 120 m de pasto pelado entre la avenida y los pinos. El del nororiente es una L
# que rodea el fundo por el norte y el este; OsmForest deshace los bordes con ruido.
FX, FZ = 380.0, 300.0
forests = [
    {"name": "Bosque del Poniente", "polygon": [[-1500.0, -1300.0], [-FX, -1300.0], [-FX, 1300.0], [-1500.0, 1300.0], [-1500.0, -1300.0]]},
    {"name": "Bosque del Norte", "polygon": [[-FX, -1300.0], [FX, -1300.0], [FX, -FZ], [-FX, -FZ], [-FX, -1300.0]]},
    {"name": "Bosque del Nororiente", "polygon": [[FX, -1300.0], [1500.0, -1300.0], [1500.0, -120.0], [790.0, -120.0], [790.0, -500.0], [FX, -500.0], [FX, -1300.0]]},
    {"name": "Bosque del Oriente", "polygon": [[FX, -120.0], [1500.0, -120.0], [1500.0, 1300.0], [FX, 1300.0], [FX, -120.0]]},
    {"name": "Bosque del Sur", "polygon": [[-FX, FZ], [FX, FZ], [FX, 1300.0], [-FX, 1300.0], [-FX, FZ]]},
]

# ----------------------------------------------------------------------------- tren
rail_lines = [[[RAIL_X, -RAIL_REACH], [RAIL_X, RAIL_REACH]], [[-RAIL_REACH, RAIL_Z], [RAIL_REACH, RAIL_Z]]]
rail_station = {"x": RAIL_X, "z": RAIL_Z, "name": "Estación Quenlobo", "yaw": round(yaw_facing(0.0, 1.0), 4)}
platforms = [{"x": RAIL_X - 5.0, "z": RAIL_Z - 45.0, "len": 70.0, "yaw": round(yaw_facing(0.0, 1.0), 4)},
             {"x": RAIL_X + 5.0, "z": RAIL_Z - 45.0, "len": 70.0, "yaw": round(yaw_facing(0.0, 1.0), 4)}]
crossings = []
for (cx, cz, rail_dir) in ((RAIL_X, -RING_RZ, (0.0, 1.0)), (RAIL_X, RING_RZ, (0.0, 1.0)), (-RING_RX, RAIL_Z, (1.0, 0.0)), (RING_RX, RAIL_Z, (1.0, 0.0))):
    s_x, _ = project(cx, cz)
    (ax, az), (tx, tz), _ = sample(s_x)
    crossings.append({"x": round(ax, 1), "z": round(az, 1), "s": round(s_x, 1), "yaw": round(yaw_facing(tx, tz), 4),
                      "rail_yaw": round(yaw_facing(*rail_dir), 4)})

# ----------------------------------------------------------------------------- bencinera, paraderos, lomos
s_st, _ = project(RING_RX, -110.0)
(stx_p, stz_p), (stx, stz), _ = sample(s_st)
station = {"x": round(stx_p, 1), "z": round(stz_p, 1), "yaw": round(yaw_facing(stx, stz), 4), "s": round(s_st, 1), "side": 1,
           "real": False, "name": "Quenlobo"}
stops, humps = [], []
for (px, pz) in ((70.0, -RING_RZ), (RING_RX, 70.0), (-70.0, RING_RZ), (-RING_RX, -70.0)):
    s_p, _ = project(px, pz)
    stops.append({"s": round(s_p, 1), "side": -1, "lat": -1.0})
for (px, pz) in ((-150.0, -RING_RZ), (RING_RX, 150.0), (150.0, RING_RZ), (-RING_RX, -150.0)):
    s_h, _ = project(px, pz)
    humps.append({"s": round(s_h, 1), "side": -1, "kind": "round"})
humps.sort(key=lambda h: h["s"])


def snap(items, lat_abs):
    return [{"x": round(off(it["s"], math.copysign(lat_abs, it["lat"]))[0], 1),
             "z": round(off(it["s"], math.copysign(lat_abs, it["lat"]))[1], 1), "s": it["s"], "side": it["side"]} for it in items]


poplars = []
for x in range(int(RING_RX) + 40, int(RING_RX) + 420, 9):
    poplars += [{"x": float(x), "z": -18.0}, {"x": float(x), "z": 18.0}, {"x": -float(x), "z": -18.0}, {"x": -float(x), "z": 18.0}]

# ----------------------------------------------------------------------------- huecos de cordón
gaps = []
for (p, q, main, key) in segments:
    if key[2] not in (-1, 99):
        continue
    end = p if key[2] == -1 else q
    other = q if key[2] == -1 else p
    s_g, _ = project(*end)
    _, lat_in = project(*other)
    gaps.append({"side": -1 if lat_in < 0 else 1, "s0": round(s_g - 9.0, 1), "s1": round(s_g + 9.0, 1), "name": "calle"})
gaps.append({"side": 1, "s0": round(s_st - 40.0, 1), "s1": round(s_st + 40.0, 1), "name": "bencinera"})
# hueco de cordón y vereda para cada salida, del lado de afuera (D84)
for (s_e, far) in exit_starts:
    _, lat_far = project(*far)
    gaps.append({"side": -1 if lat_far < 0 else 1, "s0": round(s_e - 9.0, 1), "s1": round(s_e + 9.0, 1), "name": "salida"})

# ----------------------------------------------------------------------------- comprobaciones
chk = wps + [wps[0], wps[1]]
turns = [abs((math.degrees(math.atan2(c[1] - b[1], c[0] - b[0]) - math.atan2(b[1] - a[1], b[0] - a[0])) + 180) % 360 - 180)
         for a, b, c in zip(chk, chk[1:], chk[2:])]
intrusions = 0
for b in buildings:
    half_w, half_d = b["w"] * 0.5, b["d"] * 0.5
    for sx in (-1, 1):
        for sz in (-1, 1):
            cx = b["x"] + math.cos(b["yaw"]) * sx * half_w + math.sin(b["yaw"]) * sz * half_d
            cz = b["z"] - math.sin(b["yaw"]) * sx * half_w + math.cos(b["yaw"]) * sz * half_d
            _, lat_c = project(cx, cz)
            if abs(lat_c) < PROP["avenue"] - 0.5:
                intrusions += 1
print(f"anillo {L:.0f} m, {len(axis)} puntos, {len(corner_s)} curvas | waypoints {len(wps)}, giro máx {max(turns):.0f}°, "
      f"tramo mín {min(math.dist(a, b) for a, b in zip(chk, chk[1:])):.1f} m | {len(buildings)} edificios, {intrusions} invaden | "
      f"{len(streets)} calles ({len(to_drop)} tramos quitados), {len(gaps)} bocacalles, {len(trees)} palmeras, {len(forests)} bosques")

out = {
    "source": "Diseño propio (D80/D81): pueblo Quenlobo, sin datos de OpenStreetMap",
    "center_latlon": [-34.28, -70.82], "length": round(L, 1), "closed_loop": True,
    "lane_offset": 6.75, "carriageway_width": 10.5, "median_width": 3.0, "curb_lateral": 12.0, "sidewalk_lateral": 14.0,
    "sections": [{"s0": 0.0, "s1": round(L, 1), "type": "avenue"}], "lane_by_type": LANE, "curb_by_type": CURB, "property_by_type": PROP,
    "axis": [[round(x, 1), round(z, 1), 0.0] for (x, z) in axis], "waypoints": [list(p) for p in wps],
    "entry": {"x": round(entry[0], 1), "z": round(entry[1], 1), "yaw": round(yaw_facing(etx, etz), 4)},
    "exit": {"x": round(entry[0], 1), "z": round(entry[1], 1)},
    "curb_gaps": gaps, "humps": humps, "station": station, "fuel_lot": {}, "pasaje": {}, "underpass": {},
    "buildings": buildings, "lots": [], "bus_stops": snap(stops, 14.0), "traffic_signals": [], "trees": trees, "median_trees": [],
    "street_trees": "palm",
    "gravel_zones": [], "potholes": [], "fences": [], "poplars": poplars,
    "orchards": orchards, "vine_rows": vine_rows, "fields": fields, "forests": forests,
    "bridges": [], "motorway": [], "trench": {}, "roundabout": {},
    "rail": {"lines": rail_lines, "platforms": platforms, "station": rail_station, "crossings": crossings},
    "streets": streets, "plaza": plaza, "parks": parks, "churches": churches, "water": [],
    "street_names": sorted(set(names_used)),
}
dst = os.path.join(HERE, "..", "data", "b0_pueblo.json")
json.dump(out, open(dst, "w", encoding="utf-8"), ensure_ascii=False, separators=(",", ":"))
print("escrito data/b0_pueblo.json", os.path.getsize(dst) // 1024, "KB")

# La escena lleva la ENTRADA y el LARGO a mano (marcadores Entry/Exit y length_m de
# scenes/b0_pueblo.tscn): se sincronizan aquí, porque en D81 quedaron los de D80 y el camión
# nacía en un potrero a 200 m de la avenida (D82).
scene = os.path.join(HERE, "..", "scenes", "b0_pueblo.tscn")
txt = open(scene, encoding="utf-8").read()
txt = re.sub(r"length_m = [-\d.]+", f"length_m = {round(L, 1)}", txt)
marker = f'position = Vector3({out["entry"]["x"]}, 1.2, {out["entry"]["z"]})'
txt = re.sub(r'(\[node name="Entry"[^\n]*\n)position = Vector3\([^)]*\)\nrotation = Vector3\([^)]*\)',
             lambda m: m.group(1) + marker + f'\nrotation = Vector3(0, {out["entry"]["yaw"]}, 0)', txt)
txt = re.sub(r'(\[node name="Exit"[^\n]*\n)position = Vector3\([^)]*\)', lambda m: m.group(1) + marker, txt)
open(scene, "w", encoding="utf-8", newline="\n").write(txt)
print("escena sincronizada: entrada", out["entry"], "largo", round(L, 1))
