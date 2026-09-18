#!/usr/bin/env python3
"""Pueblo DISEÑADO (D80): genera data/b0_pueblo.json con el mismo esquema que los extractos
de OSM (tools/osm_to_town.py), así los constructores de Godot no cambian.

El dueño lo dijo así el 17 sep 2026: «no tiene que ser Requínoa; puedes quitar casas y
cosas para que se vea bien el camino completo, que el tren salga recto desde un punto, igual
que la calle; si necesitas curvas o rotondas no hay problema». Requínoa se queda como está
(data/b0_requinoa.json); este es otro mapa.

El plano, en metros, x al este y z al sur (Godot: -z es el norte):

  - ANILLO (el recorrido del bus): avenida de doble calzada con bandejón, rectángulo de
    600 × 440 m con esquinas redondeadas (R = 32 m). El bus da la vuelta por dentro.
  - AVENIDA E–O (z = 0) y CALLE N–S (x = 0): rectas, cruzan el pueblo entero y SALEN por los
    cuatro bordes hasta 1500 m; BiomeHints las prolonga 700 m más hasta la silueta del bioma.
  - CUADRÍCULA: calles cada 100 m (N–S) y 80 m (E–O) dentro del anillo; casas a ambos lados
    de cada calle, con retiro, mirando a su calle.
  - PLAZA en la manzana NE del cruce central; IGLESIA enfrente, al otro lado de la calle N–S;
    PARQUE y ESCUELA en dos manzanas más.
  - TREN: dos vías RECTAS de borde a borde, N–S por x = 230 y E–O por z = 120, que se cruzan
    en la estación. Cruces a nivel donde pisan el anillo.
  - BENCINERA en el lado este del anillo. PARADEROS, LOMOS DE TORO, ÁLAMOS a la salida,
    HUERTOS y VIÑAS fuera del anillo.

Uso:  python3 tools/design_town.py       → escribe data/b0_pueblo.json
"""
import json
import math
import os

HERE = os.path.dirname(os.path.abspath(__file__))

# ----------------------------------------------------------------------------- plano
RX, RZ = 300.0, 220.0            # medio ancho y medio alto del anillo
CORNER_R = 32.0                  # radio de las esquinas del anillo
GRID_X = [-200.0, -100.0, 0.0, 100.0, 200.0]     # calles N–S
GRID_Z = [-160.0, -80.0, 0.0, 80.0, 160.0]       # calles E–O
INNER_X, INNER_Z = 272.0, 192.0  # hasta dónde llegan las manzanas (dentro del anillo)
EXIT_REACH = 1500.0              # las salidas llegan hasta acá; BiomeHints suma 700 m
RAIL_X, RAIL_Z = 230.0, 120.0    # las dos vías rectas
RAIL_REACH = 2600.0
STREET_W = 8.0
MAIN_W = 10.0

LANE = {"avenue": 6.75, "street": 3.75, "gravel": 2.8, "bridge": 3.4}
CURB = {"avenue": 12.0, "street": 8.0, "gravel": 6.5, "bridge": 6.4}
PROP = {"avenue": 15.0, "street": 10.0, "gravel": 9.0, "bridge": 10.0}

NAMES = ["Avenida Quenlobo", "Calle Trepaluz", "Pasaje Vurca", "Calle Los Álamos", "Calle Ñirre",
         "Avenida del Anillo", "Calle La Estación", "Calle Peumo", "Calle Boldo", "Calle Litre"]


# ----------------------------------------------------------------------------- geometría
def fillet_closed(pts, r):
    """Esquinas redondeadas en una polilínea cerrada (último punto == primero)."""
    n = len(pts) - 1
    out = []
    for i in range(n):
        a, b, c = pts[i - 1] if i > 0 else pts[n - 1], pts[i], pts[i + 1]
        u = (b[0] - a[0], b[1] - a[1]); v = (c[0] - b[0], c[1] - b[1])
        lu, lv = math.hypot(*u), math.hypot(*v)
        u = (u[0] / lu, u[1] / lu); v = (v[0] / lv, v[1] / lv)
        theta = math.acos(max(-1.0, min(1.0, u[0] * v[0] + u[1] * v[1])))
        if math.degrees(theta) < 10.0:
            out.append(b); continue
        t = r * math.tan(theta / 2.0)
        p1 = (b[0] - u[0] * t, b[1] - u[1] * t); p2 = (b[0] + v[0] * t, b[1] + v[1] * t)
        cross = u[0] * v[1] - u[1] * v[0]
        nrm = (-u[1], u[0]) if cross > 0 else (u[1], -u[0])
        o = (p1[0] + nrm[0] * r, p1[1] + nrm[1] * r)
        a1 = math.atan2(p1[1] - o[1], p1[0] - o[0]); a2 = math.atan2(p2[1] - o[1], p2[0] - o[0])
        da = (a2 - a1 + math.pi) % (2 * math.pi) - math.pi
        steps = max(3, int(abs(da) * r / 5.0))
        out += [(o[0] + r * math.cos(a1 + da * k / steps), o[1] + r * math.sin(a1 + da * k / steps)) for k in range(steps + 1)]
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


ring_raw = [(-RX, -RZ), (RX, -RZ), (RX, RZ), (-RX, RZ), (-RX, -RZ)]   # horario visto desde arriba
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
    return (x1 + (x2 - x1) * u, z1 + (z2 - z1) * u), (tx, tz), (tz, -tx)   # izquierda = (tz, -tx)


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


# ----------------------------------------------------------------------------- esquinas y waypoints
hits = []
s_c = 18.0
while s_c < L - 18.0:
    dv = abs((math.degrees(heading(s_c + 16.0) - heading(s_c - 16.0)) + 180) % 360 - 180)
    if dv > 38.0:
        hits.append(s_c)
    s_c += 4.0
corner_s, run = [], []
for h in hits + [1e9]:
    if run and h - run[-1] > 9.0:
        corner_s.append(sum(run) / len(run)); run = []
    if h < 1e8:
        run.append(h)

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

# ----------------------------------------------------------------------------- calles
streets = []
names_used = []


def street(pts, w, name):
    streets.append({"pts": [[round(x, 1), round(z, 1)] for x, z in pts], "w": w, "surface": "street"})
    names_used.append(name)


for i, gx in enumerate(GRID_X):
    w = MAIN_W if gx == 0.0 else STREET_W
    street([(gx, -INNER_Z - 20.0), (gx, INNER_Z + 20.0)], w, NAMES[(i * 3) % len(NAMES)])
for j, gz in enumerate(GRID_Z):
    w = MAIN_W if gz == 0.0 else STREET_W
    street([(-INNER_X - 20.0, gz), (INNER_X + 20.0, gz)], w, NAMES[(j * 3 + 1) % len(NAMES)])
# Las cuatro salidas: nacen justo fuera del anillo (OsmTown las recorta al cordón) y llegan
# hasta EXIT_REACH. Son las calles que BiomeHints toma por cuadrante.
street([(RX + 12.0, 0.0), (EXIT_REACH, 0.0)], 9.0, "Avenida Quenlobo")
street([(-RX - 12.0, 0.0), (-EXIT_REACH, 0.0)], 9.0, "Avenida Quenlobo")
street([(0.0, -RZ - 12.0), (0.0, -EXIT_REACH)], 9.0, "Calle Trepaluz")
street([(0.0, RZ + 12.0), (0.0, EXIT_REACH)], 9.0, "Calle Trepaluz")

# ----------------------------------------------------------------------------- manzanas
xs = [-INNER_X] + GRID_X + [INNER_X]
zs = [-INNER_Z] + GRID_Z + [INNER_Z]
blocks = []
for i in range(len(xs) - 1):
    for j in range(len(zs) - 1):
        x0, x1, z0, z1 = xs[i], xs[i + 1], zs[j], zs[j + 1]
        if x1 - x0 < 40.0 or z1 - z0 < 40.0:
            continue
        blocks.append((x0, x1, z0, z1))


def block_is(x0, x1, z0, z1, bx0, bz0):
    return abs(x0 - bx0) < 1e-6 and abs(z0 - bz0) < 1e-6


PLAZA_B = (0.0, -80.0)      # manzana NE del cruce central
CHURCH_B = (-100.0, -80.0)  # enfrente de la plaza, cruzando la calle N–S
PARK_B = (100.0, 80.0)
SCHOOL_B = (-200.0, 0.0)

buildings, parks, churches = [], [], []
plaza = None
delivery_done = False


def style_for(x, z):
    return "adobe" if math.hypot(x, z) < 130.0 else "poblacion"


def add_house(cx, cz, w, d, yaw, style, levels, kind="house"):
    global delivery_done
    s_b, lat_b = project(cx, cz)
    b = {"x": round(cx, 1), "z": round(cz, 1), "w": round(w, 1), "d": round(d, 1), "yaw": round(yaw, 4),
         "levels": levels, "type": kind, "style": style, "s": round(s_b, 1), "lat": round(lat_b, 1),
         "delivery": False, "damage": 0, "collapsed": False}
    buildings.append(b)
    return b


SETBACK = 8.0      # del eje de la calle al frente de la casa (calle/2 + vereda + antejardín)
LOT = 15.0
for (x0, x1, z0, z1) in blocks:
    if block_is(x0, x1, z0, z1, *PLAZA_B):
        m = 8.0
        plaza = {"name": "Plaza Quenlobo", "polygon": [[x0 + m, z0 + m], [x1 - m, z0 + m], [x1 - m, z1 - m], [x0 + m, z1 - m], [x0 + m, z0 + m]]}
        continue
    if block_is(x0, x1, z0, z1, *PARK_B):
        m = 8.0
        parks.append({"name": "Parque Vurca", "polygon": [[x0 + m, z0 + m], [x1 - m, z0 + m], [x1 - m, z1 - m], [x0 + m, z1 - m], [x0 + m, z0 + m]]})
        continue
    if block_is(x0, x1, z0, z1, *CHURCH_B):
        cx, cz = (x0 + x1) * 0.5 + 10.0, (z0 + z1) * 0.5
        churches.append({"x": round(cx, 1), "z": round(cz, 1), "name": "Iglesia de Quenlobo",
                         "polygon": [[cx - 9.0, cz - 16.0], [cx + 9.0, cz - 16.0], [cx + 9.0, cz + 16.0], [cx - 9.0, cz + 16.0], [cx - 9.0, cz - 16.0]]})
        add_house(cx, cz, 18.0, 32.0, 0.0, "adobe", 2, "church")
        continue
    if block_is(x0, x1, z0, z1, *SCHOOL_B):
        add_house((x0 + x1) * 0.5, (z0 + z1) * 0.5, 48.0, 22.0, 0.0, "default", 2, "school")
        continue
    # casas mirando a las calles E–O (bordes norte y sur de la manzana)
    style = style_for((x0 + x1) * 0.5, (z0 + z1) * 0.5)
    for edge_z, face in ((z0, -1.0), (z1, 1.0)):
        cz = edge_z - face * (SETBACK + 5.5)   # hacia adentro de la manzana
        if RAIL_Z - 15.0 < cz < RAIL_Z + 15.0:
            continue                            # la vía E–O pasa por aquí
        x = x0 + 12.0
        k = 0
        while x + 6.0 <= x1 - 12.0:
            w = 10.0 + (k % 3) * 1.5
            levels = 2 if (style == "adobe" and k % 3 == 1) else 1
            # yaw: la fachada mira a la calle. yaw 0 mira a -z (norte); pi mira a +z (sur).
            yaw = 0.0 if face < 0 else math.pi
            b = add_house(x, cz, w, 11.0, yaw, style, levels)
            if not delivery_done and x0 == 100.0 and z0 == -160.0 and k == 2:
                b["delivery"] = True; delivery_done = True
            x += LOT; k += 1
    # y a las calles N–S (bordes este y oeste), dejando libres las esquinas
    for edge_x, face in ((x0, -1.0), (x1, 1.0)):
        cx = edge_x - face * (SETBACK + 5.5)
        if RAIL_X - 15.0 < cx < RAIL_X + 15.0:
            continue
        z = z0 + 26.0
        k = 0
        while z + 6.0 <= z1 - 26.0:
            if not (RAIL_Z - 15.0 < z < RAIL_Z + 15.0):
                yaw = math.pi * 0.5 if face < 0 else -math.pi * 0.5
                add_house(cx, z, 10.0 + (k % 2) * 2.0, 11.0, yaw, style, 1)
            z += LOT; k += 1

# ----------------------------------------------------------------------------- árboles de vereda
# OsmFurniture solo planta árboles a lo largo del eje del bus (el anillo); las calles de la
# cuadrícula quedaban peladas. `trees` acepta x,z directos, así que se plantan aquí: uno cada
# 12 m a cada lado de cada calle interior, a 6,3 m del eje de la calle (entre el cordón y el
# frente de las casas), sin pisar las bocacalles.
trees = []
for gx in GRID_X:
    z = -INNER_Z + 6.0
    while z < INNER_Z - 6.0:
        if all(abs(z - gz) > 9.0 for gz in GRID_Z):
            for side in (-1.0, 1.0):
                trees.append({"x": round(gx + side * 6.3, 1), "z": round(z, 1), "s": 0.0, "side": int(side)})
        z += 12.0
for gz in GRID_Z:
    x = -INNER_X + 6.0
    while x < INNER_X - 6.0:
        if all(abs(x - gx) > 9.0 for gx in GRID_X):
            for side in (-1.0, 1.0):
                cz = gz + side * 6.3
                if not (RAIL_Z - 6.0 < cz < RAIL_Z + 6.0):
                    trees.append({"x": round(x, 1), "z": round(cz, 1), "s": 0.0, "side": int(side)})
        x += 12.0

# ----------------------------------------------------------------------------- tren
rail_lines = [[[RAIL_X, -RAIL_REACH], [RAIL_X, RAIL_REACH]], [[-RAIL_REACH, RAIL_Z], [RAIL_REACH, RAIL_Z]]]
rail_station = {"x": RAIL_X, "z": RAIL_Z, "name": "Estación Quenlobo", "yaw": round(yaw_facing(0.0, 1.0), 4)}
platforms = [{"x": RAIL_X - 5.0, "z": RAIL_Z - 40.0, "len": 60.0, "yaw": round(yaw_facing(0.0, 1.0), 4)},
             {"x": RAIL_X + 5.0, "z": RAIL_Z - 40.0, "len": 60.0, "yaw": round(yaw_facing(0.0, 1.0), 4)}]
crossings = []
for (cx, cz, rail_dir) in ((RAIL_X, -RZ, (0.0, 1.0)), (RAIL_X, RZ, (0.0, 1.0)), (-RX, RAIL_Z, (1.0, 0.0)), (RX, RAIL_Z, (1.0, 0.0))):
    s_x, _ = project(cx, cz)
    _, (tx, tz), _ = sample(s_x)
    crossings.append({"x": round(cx, 1), "z": round(cz, 1), "s": round(s_x, 1), "yaw": round(yaw_facing(tx, tz), 4),
                      "rail_yaw": round(yaw_facing(*rail_dir), 4)})

# ----------------------------------------------------------------------------- bencinera, paraderos, lomos
s_st, _ = project(RX, -100.0)
(_, (stx, stz), _) = sample(s_st)
station = {"x": round(RX, 1), "z": -100.0, "yaw": round(yaw_facing(stx, stz), 4), "s": round(s_st, 1), "side": 1,
           "real": False, "name": "Quenlobo"}
stops, humps = [], []
for (px, pz) in ((0.0 + 60.0, -RZ), (RX, 60.0), (-60.0, RZ), (-RX, -60.0)):
    s_p, _ = project(px, pz)
    stops.append({"s": round(s_p, 1), "side": -1, "lat": -1.0})
for (px, pz) in ((-150.0, -RZ), (RX, 150.0), (150.0, RZ), (-RX, -150.0)):
    s_h, _ = project(px, pz)
    humps.append({"s": round(s_h, 1), "side": -1, "kind": "round"})
humps.sort(key=lambda h: h["s"])


def snap(items, lat_abs):
    return [{"x": round(off(it["s"], math.copysign(lat_abs, it["lat"]))[0], 1),
             "z": round(off(it["s"], math.copysign(lat_abs, it["lat"]))[1], 1), "s": it["s"], "side": it["side"]} for it in items]


# ----------------------------------------------------------------------------- campo
poplars = []
for x in range(int(RX) + 40, int(RX) + 340, 9):
    poplars += [{"x": float(x), "z": -18.0}, {"x": float(x), "z": 18.0}, {"x": -float(x), "z": -18.0}, {"x": -float(x), "z": 18.0}]
orchard_poly = [[420.0, -420.0], [720.0, -420.0], [720.0, -170.0], [420.0, -170.0], [420.0, -420.0]]
orchards = [[float(x), float(z)] for x in range(430, 715, 7) for z in range(-410, -175, 7)]
vine_poly = [[-720.0, 170.0], [-420.0, 170.0], [-420.0, 420.0], [-720.0, 420.0], [-720.0, 170.0]]
vine_rows = [[-712.0, float(z), -428.0] for z in range(178, 414, 3)]
fields = [{"kind": "orchard", "polygon": orchard_poly}, {"kind": "vineyard", "polygon": vine_poly}]

# ----------------------------------------------------------------------------- huecos de cordón
gaps = []
for gx in GRID_X:
    for pz, side_pt in ((-RZ, -RZ + 20.0), (RZ, RZ - 20.0)):
        s_g, _ = project(gx, pz)
        _, lat_in = project(gx, side_pt)
        gaps.append({"side": -1 if lat_in < 0 else 1, "s0": round(s_g - 9.0, 1), "s1": round(s_g + 9.0, 1), "name": "calle"})
for gz in GRID_Z:
    for px, side_pt in ((-RX, -RX + 20.0), (RX, RX - 20.0)):
        s_g, _ = project(px, gz)
        _, lat_in = project(side_pt, gz)
        gaps.append({"side": -1 if lat_in < 0 else 1, "s0": round(s_g - 9.0, 1), "s1": round(s_g + 9.0, 1), "name": "calle"})
gaps.append({"side": 1, "s0": round(s_st - 40.0, 1), "s1": round(s_st + 40.0, 1), "name": "bencinera"})

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
print(f"anillo {L:.0f} m, {len(axis)} puntos, {len(corner_s)} esquinas | waypoints {len(wps)}, giro máx {max(turns):.0f}°, "
      f"tramo mín {min(math.dist(a, b) for a, b in zip(chk, chk[1:])):.1f} m | {len(buildings)} edificios, {intrusions} invaden el corredor | "
      f"{len(streets)} calles, {len(gaps)} bocacalles")

out = {
    "source": "Diseño propio (D80): pueblo Quenlobo, sin datos de OpenStreetMap",
    "center_latlon": [-34.28, -70.82], "length": round(L, 1), "closed_loop": True,
    "lane_offset": 6.75, "carriageway_width": 10.5, "median_width": 3.0, "curb_lateral": 12.0, "sidewalk_lateral": 14.0,
    "sections": [{"s0": 0.0, "s1": round(L, 1), "type": "avenue"}], "lane_by_type": LANE, "curb_by_type": CURB, "property_by_type": PROP,
    "axis": [[round(x, 1), round(z, 1), 0.0] for (x, z) in axis], "waypoints": [list(p) for p in wps],
    "entry": {"x": round(entry[0], 1), "z": round(entry[1], 1), "yaw": round(yaw_facing(etx, etz), 4)},
    "exit": {"x": round(entry[0], 1), "z": round(entry[1], 1)},
    "curb_gaps": gaps, "humps": humps, "station": station, "fuel_lot": {}, "pasaje": {}, "underpass": {},
    "buildings": buildings, "lots": [], "bus_stops": snap(stops, 14.0), "traffic_signals": [], "trees": trees, "median_trees": [],
    "gravel_zones": [], "potholes": [], "fences": [], "poplars": poplars,
    "orchards": orchards, "vine_rows": vine_rows, "fields": fields,
    "bridges": [], "motorway": [], "trench": {}, "roundabout": {},
    "rail": {"lines": rail_lines, "platforms": platforms, "station": rail_station, "crossings": crossings},
    "streets": streets, "plaza": plaza, "parks": parks, "churches": churches, "water": [],
    "street_names": sorted(set(names_used)),
}
dst = os.path.join(HERE, "..", "data", "b0_pueblo.json")
json.dump(out, open(dst, "w", encoding="utf-8"), ensure_ascii=False, separators=(",", ":"))
print("escrito data/b0_pueblo.json", os.path.getsize(dst) // 1024, "KB")
