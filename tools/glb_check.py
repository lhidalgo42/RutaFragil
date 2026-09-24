"""Checklist mecánico del maestro §10.1 sobre un .glb (M-ART DA6). Python puro.

    python tools/glb_check.py <archivo.glb> --kind package|prop|bus [--pivot base|center] [--json]

Responde sí/no a los puntos 1, 2, 4 y 5 del checklist con el número que falla;
los puntos 3 (colisión autorada), 6 (coherencia con el board) y 7 (CREDITS) los
valida el humano. Sale con 0 si todo pasa y 1 si algo falla.

Presupuestos (§10.1 punto 2): props ≤2000 tris, paquetes ≤800, bus ≤25000.
Escala esperada: paquete 0,4 m (D81), bus ≈ 2,5 × 7,8 de suelo (D99) más morro.
"""
import argparse
import json
import math
import struct
import sys

BUDGETS = {"package": 800, "prop": 2000, "bus": 25000}
# (min, max) del lado mayor en metros; None = sin límite.
SIZES = {"package": (0.35, 0.45), "prop": (0.05, 6.0), "bus": (7.0, 10.0)}
TEXTURE_MAX = 1024
PIVOT_TOL = 0.02  # el pivote "en la base" tolera 2 cm por errores de export

COMP = {5120: ("b", 1), 5121: ("B", 1), 5122: ("h", 2), 5123: ("H", 2),
        5125: ("I", 4), 5126: ("f", 4)}
NCOMP = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4}


def load_glb(path):
    b = open(path, "rb").read()
    magic, _ver, _len = struct.unpack_from("<III", b, 0)
    if magic != 0x46546C67:
        raise SystemExit("no es un GLB: " + path)
    off = 12
    gltf, bins = None, []
    while off < len(b):
        clen, ctype = struct.unpack_from("<II", b, off)
        chunk = b[off + 8: off + 8 + clen]
        if ctype == 0x4E4F534A:
            gltf = json.loads(chunk)
        elif ctype == 0x004E4942:
            bins.append(chunk)
        off += 8 + clen
    return gltf, bins


def read_accessor(g, bins, idx):
    acc = g["accessors"][idx]
    bv = g["bufferViews"][acc["bufferView"]]
    buf = bins[bv["buffer"]]
    fmt, size = COMP[acc["componentType"]]
    n = NCOMP[acc["type"]]
    stride = bv.get("byteStride", size * n)
    base = bv.get("byteOffset", 0) + acc.get("byteOffset", 0)
    out = []
    for i in range(acc["count"]):
        o = base + i * stride
        vals = struct.unpack_from("<" + fmt * n, buf, o)
        out.append(vals if n > 1 else vals[0])
    return out


def png_size(data):
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        return None
    w, h = struct.unpack_from(">II", data, 16)
    return w, h


def jpeg_size(data):
    i = 2
    while i < len(data):
        if data[i] != 0xFF:
            return None
        marker = data[i + 1]
        if marker in (0xC0, 0xC1, 0xC2):
            h, w = struct.unpack_from(">HH", data, i + 5)
            return w, h
        seg = struct.unpack_from(">H", data, i + 2)[0]
        i += 2 + seg
    return None


def image_size(g, bins, img):
    if "bufferView" not in img:
        return None
    bv = g["bufferViews"][img["bufferView"]]
    data = bins[bv["buffer"]][bv.get("byteOffset", 0): bv.get("byteOffset", 0) + bv["byteLength"]]
    return png_size(data) or jpeg_size(data)


def sub(a, b):
    return (a[0] - b[0], a[1] - b[1], a[2] - b[2])


def cross(a, b):
    return (a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0])


def dot(a, b):
    return a[0] * b[0] + a[1] * b[1] + a[2] * b[2]


def node_matrix(n):
    """Matriz 4x4 fila-mayor del nodo: 'matrix' o T*R*S, según glTF §3.5.2."""
    if "matrix" in n:
        m = n["matrix"]  # columna-mayor en glTF
        return [[m[c * 4 + r] for c in range(4)] for r in range(4)]
    t = n.get("translation", [0, 0, 0])
    q = n.get("rotation", [0, 0, 0, 1])
    sc = n.get("scale", [1, 1, 1])
    x, y, z, w = q
    r = [[1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
         [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
         [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)]]
    return [[r[i][j] * sc[j] for j in range(3)] + [t[i]] for i in range(3)] + [[0, 0, 0, 1]]


def mat_mul(a, b):
    return [[sum(a[i][k] * b[k][j] for k in range(4)) for j in range(4)] for i in range(4)]


def apply(m, p):
    return tuple(m[i][0] * p[0] + m[i][1] * p[1] + m[i][2] * p[2] + m[i][3] for i in range(3))


def mesh_instances(g):
    """(mesh_index, world_matrix) por cada nodo con malla, recorriendo la escena por defecto."""
    ident = [[1 if i == j else 0 for j in range(4)] for i in range(4)]
    scene = g["scenes"][g.get("scene", 0)] if g.get("scenes") else {"nodes": list(range(len(g.get("nodes", []))))}
    out = []
    stack = [(n, ident) for n in scene.get("nodes", [])]
    while stack:
        ni, parent = stack.pop()
        n = g["nodes"][ni]
        world = mat_mul(parent, node_matrix(n))
        if "mesh" in n:
            out.append((n["mesh"], world))
        stack.extend((c, world) for c in n.get("children", []))
    if not out:  # sin escena: mallas tal cual
        out = [(i, ident) for i in range(len(g.get("meshes", [])))]
    return out


def check(path, kind, pivot="base"):
    """pivot: 'base' (y mínimo en 0: el modelo se apoya, y la escena lo coloca sobre el
    colisionador, como el paquete D81 en package.tscn a Y=−0,2) o 'center' (centro del
    bbox en el origen, para un visual que se instancia sin desplazar)."""
    g, bins = load_glb(path)
    findings = []
    ok = lambda name, passed, detail: findings.append({"check": name, "pass": bool(passed), "detail": detail})

    tris = 0
    mn = [math.inf] * 3
    mx = [-math.inf] * 3
    loose_faces = 0
    inverted = 0
    total_faces_checked = 0
    signed_volume = 0.0
    normal_vs_winding = 0
    for mesh_idx, world in mesh_instances(g):
        mesh = g["meshes"][mesh_idx]
        for prim in mesh["primitives"]:
            pos = [apply(world, p) for p in read_accessor(g, bins, prim["attributes"]["POSITION"])]
            for p in pos:
                for k in range(3):
                    mn[k] = min(mn[k], p[k])
                    mx[k] = max(mx[k], p[k])
            idx = read_accessor(g, bins, prim["indices"]) if "indices" in prim else list(range(len(pos)))
            # Los exportadores duplican vértices por normal/UV (shade flat = 3 copias por
            # cara), así que las aristas se comparan por POSICIÓN soldada, no por índice.
            canon = {}
            weld = []
            for p in pos:
                key = (round(p[0], 5), round(p[1], 5), round(p[2], 5))
                weld.append(canon.setdefault(key, len(canon)))
            faces = [tuple(idx[i:i + 3]) for i in range(0, len(idx) - 2, 3)]
            wfaces = [(weld[f[0]], weld[f[1]], weld[f[2]]) for f in faces]
            tris += len(faces)

            # caras sueltas: una cara sin ninguna arista compartida con otra
            edge_count = {}
            for f in wfaces:
                for e in ((f[0], f[1]), (f[1], f[2]), (f[2], f[0])):
                    k = tuple(sorted(e))
                    edge_count[k] = edge_count.get(k, 0) + 1
            for f in wfaces:
                shared = sum(1 for e in ((f[0], f[1]), (f[1], f[2]), (f[2], f[0]))
                             if edge_count[tuple(sorted(e))] > 1)
                if shared == 0:
                    loose_faces += 1

            # normales invertidas, tres señales independientes de la normal almacenada
            # (Blender voltea normal y orden de vértices juntos, así que compararlas
            # entre sí no detecta nada):
            #  a) una arista dirigida recorrida dos veces en el mismo sentido = dos
            #     caras vecinas con orientación opuesta (una está al revés);
            #  b) volumen con signo negativo = la malla entera mira hacia dentro.
            directed = {}
            for f in wfaces:
                for e in ((f[0], f[1]), (f[1], f[2]), (f[2], f[0])):
                    directed[e] = directed.get(e, 0) + 1
            inconsistent_edges = sum(1 for e, n in directed.items() if n > 1)
            inverted += inconsistent_edges
            total_faces_checked += len(faces)
            #  c) la normal almacenada apunta contra el orden de vértices: un generador
            #     que hornea normales aparte del winding; Godot culea la cara al revés.
            nrm = read_accessor(g, bins, prim["attributes"]["NORMAL"]) if "NORMAL" in prim["attributes"] else None
            vol = 0.0
            for f in faces:
                a, b, c = pos[f[0]], pos[f[1]], pos[f[2]]
                vol += dot(a, cross(b, c))
                if nrm is not None:
                    geo = cross(sub(b, a), sub(c, a))
                    stored = tuple(nrm[f[0]][k] + nrm[f[1]][k] + nrm[f[2]][k] for k in range(3))
                    lg = math.sqrt(dot(geo, geo)); ls = math.sqrt(dot(stored, stored))
                    # caras degeneradas (área ~0) no cuentan: su winding es ruido numérico
                    if lg > 1e-12 and ls > 1e-9 and dot(geo, stored) / (lg * ls) < -0.2:
                        normal_vs_winding += 1
            signed_volume += vol / 6.0

    size = [mx[k] - mn[k] for k in range(3)]
    longest = max(size)
    lo, hi = SIZES[kind]
    ok("1.escala", lo <= longest <= hi,
       "lado mayor %.3f m (esperado %.2f–%.2f); bbox %.3f × %.3f × %.3f" % (longest, lo, hi, *size))
    if pivot == "center":
        ctr = [(mn[k] + mx[k]) / 2 for k in range(3)]
        ok("1.pivote_en_centro", max(abs(c) for c in ctr) <= PIVOT_TOL,
           "centro del bbox (%.3f, %.3f, %.3f) m (origen ± %.2f)" % (*ctr, PIVOT_TOL))
    else:
        ok("1.pivote_en_base", abs(mn[1]) <= PIVOT_TOL,
           "y mínimo %.3f m (base en 0 ± %.2f)" % (mn[1], PIVOT_TOL))
    # Ejes: glTF es +Y arriba. Un modelo exportado Z-up (Y y Z cruzados) o tumbado deja
    # su dimensión mayor en Y. Una caja, un prop o el bus nunca son más altos que largos
    # Y anchos a la vez, así que el alto no puede superar a los otros dos. El bus además
    # tiene que ser más largo en Z que ancho en X (−Z adelante).
    axes_ok = size[1] <= max(size[0], size[2]) + 1e-6
    if kind == "bus":
        axes_ok = axes_ok and size[2] >= size[0]
    ok("1.ejes", axes_ok,
       "alto y %.3f, ancho x %.3f, largo z %.3f (glTF +Y arriba: el alto no supera a ambos lados; "
       "el bus es más largo en z)" % (size[1], size[0], size[2]))
    ok("2.triangulos", tris <= BUDGETS[kind], "%d tris (presupuesto %d)" % (tris, BUDGETS[kind]))
    ok("2.caras_sueltas", loose_faces == 0, "%d caras sin arista compartida" % loose_faces)
    ok("2.normales_invertidas", inverted == 0 and signed_volume >= 0 and normal_vs_winding == 0,
       "%d aristas inconsistentes, %d normales contra el winding, volumen con signo %.4f m³ (%d caras)"
       % (inverted, normal_vs_winding, signed_volume, total_faces_checked))
    # §10.1 punto 4: «una sola textura por asset (atlas o paleta)». Se cuentan
    # las imágenes, no los materiales: un material PBR con color, ORM y normal
    # lleva tres texturas y no cumple. Cero es válido (paleta plana).
    nmat = len(g.get("materials", []))
    nimg = len(g.get("images", []))
    ok("4.una_textura", nmat <= 1 and nimg <= 1,
       "%d materiales, %d imágenes (el punto 4 pide 1 material y ≤1 textura)" % (nmat, nimg))
    big = []
    for i, img in enumerate(g.get("images", [])):
        s = image_size(g, bins, img)
        if s and max(s) > TEXTURE_MAX:
            big.append("img%d %dx%d" % (i, *s))
    ok("5.textura_max_%d" % TEXTURE_MAX, not big, ", ".join(big) if big else "%d imágenes, todas ≤%d" % (len(g.get("images", [])), TEXTURE_MAX))
    return findings


def main():
    # la consola de Windows arranca en cp1252 y no imprime "×" ni "−"
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    ap = argparse.ArgumentParser()
    ap.add_argument("glb")
    ap.add_argument("--kind", choices=sorted(BUDGETS), required=True)
    ap.add_argument("--pivot", choices=("base", "center"), default="base",
                    help="base: y mínimo en 0, el modelo se apoya (el paquete usa este); center: "
                         "centro del bbox en el origen, para un visual instanciado sin desplazar")
    ap.add_argument("--json", action="store_true")
    a = ap.parse_args()
    findings = check(a.glb, a.kind, a.pivot)
    failed = [f for f in findings if not f["pass"]]
    if a.json:
        print(json.dumps({"file": a.glb, "kind": a.kind, "findings": findings,
                          "pass": not failed}, indent=1, ensure_ascii=False))
    else:
        for f in findings:
            print("%s  %-24s %s" % ("OK " if f["pass"] else "FAIL", f["check"], f["detail"]))
        print("=> %s (%d/%d)" % ("PASA" if not failed else "FALLA", len(findings) - len(failed), len(findings)))
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
