"""Modèles low poly des animaux de Need for Pils (lapin, sanglier, biche, mouton).

Usage : python3 animals_build.py <dossier de sortie>   (-> rabbit.glb, boar.glb, deer.glb, sheep.glb)

Modélisation « organique » : chaque partie est un tronc lissé (loft) le long d'un
chemin (colonne vertébrale, patte, cou...) avec des sections elliptiques de taille
variable, comme le modificateur Skin de Blender : épaules, cuisses, jarrets, museau,
oreilles en feuille. Facettes plates (style low poly), quelques couleurs par animal
(ventre clair, sabots, museau...) attribuées selon l'orientation des faces.

Chaque animal regarde vers +Z (repère Godot : +Y en haut), les pieds à y = 0.
Pièces séparées pour l'animation par code (world/animals/animal.gd) :
  Body, Neck (biche), Head (pivot au cou), Leg_FL / Leg_FR / Leg_BL / Leg_BR (pivot à
  l'épaule / la hanche), Tail (pivot à la base), et sous Head : Ear_L / Ear_R.
"""
import json, math, struct, sys
import numpy as np

RNG = np.random.default_rng(7)

# ---------------------------------------------------------------- loft

def _frames(P, up):
    T = np.zeros_like(P)
    for i in range(len(P)):
        a, b = P[max(i - 1, 0)], P[min(i + 1, len(P) - 1)]
        t = b - a
        T[i] = t / (np.linalg.norm(t) or 1.0)
    U, S = [], []
    for t in T:
        u = np.array(up, float) - np.dot(up, t) * t
        if np.linalg.norm(u) < 1e-4:
            u = np.array([0, 0, 1.0]) - t[2] * t
        u /= np.linalg.norm(u)
        U.append(u)
        S.append(np.cross(u, t))
    return T, np.array(U), np.array(S)


def loft(pts, secs, n=8, up=(0, 1, 0), noise=0.0, rot=None, cap0=True, cap1=True, flat_bottom=0.0):
    """Tronc lissé le long de `pts` ; secs[i] = (largeur, hauteur) de la section i.
    noise : bosses aléatoires (laine) ; flat_bottom : aplatit le dessous (0-1)."""
    P = np.array(pts, float)
    T, U, S = _frames(P, up)
    a0 = math.pi / n if rot is None else rot
    rings = []
    for i, p in enumerate(P):
        w, h = secs[i][0] / 2, secs[i][1] / 2
        ring = []
        for k in range(n):
            a = a0 + 2 * math.pi * k / n
            c, s = math.cos(a), math.sin(a)
            if flat_bottom and s < 0:
                s *= 1.0 - flat_bottom
            r = 1.0 + (RNG.uniform(-noise, noise) if noise and 0 < i < len(P) - 1 else 0.0)
            ring.append(p + S[i] * c * w * r - U[i] * 0.0 + U[i] * s * h * r)
        rings.append(ring)
    tris = []
    for i in range(len(rings) - 1):
        c = (P[i] + P[i + 1]) / 2
        for k in range(n):
            k2 = (k + 1) % n
            a, b, cc, d = rings[i][k], rings[i][k2], rings[i + 1][k], rings[i + 1][k2]
            tris += [_out((a, b, d), c), _out((a, d, cc), c)]
    if cap0:
        c = P[0]
        for k in range(n):
            tris.append(_out((c, rings[0][(k + 1) % n], rings[0][k]), P[0] + T[0] * 0.5 * np.linalg.norm(P[1] - P[0]), inward=True))
    if cap1:
        c = P[-1]
        for k in range(n):
            tris.append(_out((c, rings[-1][k], rings[-1][(k + 1) % n]), P[-1] - T[-1] * 0.5 * np.linalg.norm(P[-1] - P[-2]), inward=True))
    return [tuple(tuple(float(x) for x in v) for v in t) for t in tris]


def _out(tri, inside, inward=False):
    a, b, c = (np.array(v, float) for v in tri)
    nrm = np.cross(b - a, c - a)
    cen = (a + b + c) / 3
    if np.dot(nrm, cen - inside) < 0:
        return (a, c, b)
    return (a, b, c)


def leaf(base, tip, width, thick, bend=(0, 0, 0), n=5):
    """Oreille en feuille : fine, large au milieu, pointue."""
    base, tip, bend = (np.array(v, float) for v in (base, tip, bend))
    pts = [base + (tip - base) * t + bend * math.sin(math.pi * t) for t in (0.0, 0.3, 0.65, 1.0)]
    secs = [(width * 0.45, thick), (width, thick), (width * 0.75, thick * 0.9), (width * 0.08, thick * 0.5)]
    d = tip - base
    side = np.cross(d, [0, 0, 1.0]) if abs(d[2]) < 0.9 * np.linalg.norm(d) else np.cross(d, [1.0, 0, 0])
    up = np.cross(side, d)
    return loft(pts, secs, n=n, up=tuple(up / np.linalg.norm(up)))


def box(center, size):
    x, y, z = center
    sx, sy, sz = (s / 2 for s in size)
    return loft([(x, y, z - sz), (x, y, z + sz)], [(size[0], size[1])] * 2, n=4, rot=math.pi / 4)


def split(tris, pred):
    """Sépare les triangles selon pred(normale, centre) -> (vrais, faux)."""
    yes, no = [], []
    for t in tris:
        a, b, c = (np.array(v) for v in t)
        nrm = np.cross(b - a, c - a)
        ln = np.linalg.norm(nrm)
        nrm = nrm / ln if ln else nrm
        (yes if pred(nrm, (a + b + c) / 3) else no).append(t)
    return yes, no


def mirror_x(tris):
    return [tuple((-v[0], v[1], v[2]) for v in (t[0], t[2], t[1])) for t in tris]

# ---------------------------------------------------------------- écriture glb

def shift(tris, d):
    return [tuple((v[0] - d[0], v[1] - d[1], v[2] - d[2]) for v in t) for t in tris]


class Model:
    def __init__(self, name):
        self.name = name
        self.parts = []
        self.mats = {}

    def mat(self, name, rgb, rough=0.9):
        self.mats[name] = (rgb, rough)
        return name

    def part(self, name, pivot, geo, parent=None):
        self.parts.append((name, parent, pivot, {m: shift(t, pivot) for m, t in geo.items() if t}))

    def save(self, path):
        mat_names = list(self.mats)
        bin_ = bytearray()
        views, accs, meshes, nodes = [], [], [], []

        def add_view(data, target):
            while len(bin_) % 4: bin_.append(0)
            off = len(bin_); bin_.extend(data)
            views.append({"buffer": 0, "byteOffset": off, "byteLength": len(data), "target": target})
            return len(views) - 1

        for name, parent, pivot, geo in self.parts:
            prims = []
            for m, tris in geo.items():
                P = np.array(tris, np.float32).reshape(-1, 3, 3)
                N = np.cross(P[:, 1] - P[:, 0], P[:, 2] - P[:, 0])
                ln = np.linalg.norm(N, axis=1, keepdims=True); ln[ln == 0] = 1
                N = np.repeat((N / ln)[:, None, :], 3, axis=1).astype(np.float32)
                pos = P.reshape(-1, 3); nor = N.reshape(-1, 3)
                vp = add_view(pos.tobytes(), 34962)
                accs.append({"bufferView": vp, "componentType": 5126, "count": len(pos), "type": "VEC3",
                             "min": pos.min(0).tolist(), "max": pos.max(0).tolist()})
                ap = len(accs) - 1
                vn = add_view(nor.tobytes(), 34962)
                accs.append({"bufferView": vn, "componentType": 5126, "count": len(nor), "type": "VEC3"})
                prims.append({"attributes": {"POSITION": ap, "NORMAL": len(accs) - 1}, "material": mat_names.index(m)})
            meshes.append({"name": name, "primitives": prims})
            nodes.append({"name": name, "mesh": len(meshes) - 1})
        piv = {p[0]: p[2] for p in self.parts}
        children, roots = {}, []
        for i, (name, parent, pivot, _) in enumerate(self.parts):
            base = piv[parent] if parent else (0, 0, 0)
            nodes[i]["translation"] = [pivot[k] - base[k] for k in range(3)]
            if parent:
                children.setdefault(parent, []).append(i)
            else:
                roots.append(i)
        for i, (name, *_r) in enumerate(self.parts):
            if name in children:
                nodes[i]["children"] = children[name]
        nodes.append({"name": self.name, "children": roots})
        gltf = {
            "asset": {"version": "2.0", "generator": "Need for Pils animals_build.py (loft)"},
            "scene": 0, "scenes": [{"nodes": [len(nodes) - 1]}], "nodes": nodes, "meshes": meshes,
            "materials": [{"name": m, "pbrMetallicRoughness": {"baseColorFactor": list(self.mats[m][0]) + [1.0],
                           "metallicFactor": 0.0, "roughnessFactor": self.mats[m][1]}} for m in mat_names],
            "accessors": accs, "bufferViews": views, "buffers": [{"byteLength": len(bin_)}],
        }
        js = json.dumps(gltf, separators=(",", ":")).encode()
        while len(js) % 4: js += b" "
        while len(bin_) % 4: bin_.append(0)
        out = struct.pack("<III", 0x46546C67, 2, 12 + 8 + len(js) + 8 + len(bin_))
        out += struct.pack("<II", len(js), 0x4E4F534A) + js
        out += struct.pack("<II", len(bin_), 0x004E4942) + bytes(bin_)
        open(path, "wb").write(out)

    def world_tris(self):
        """(triangles en coordonnées de l'animal, couleur) pour l'aperçu."""
        piv = {p[0]: p[2] for p in self.parts}
        out = []
        for name, parent, pivot, geo in self.parts:
            for m, tris in geo.items():
                for t in tris:
                    out.append(([tuple(v[k] + pivot[k] for k in range(3)) for v in t], self.mats[m][0]))
        return out


def eyes(x, y, z, r=0.02):
    return box((x, y, z), (r * 0.6, r, r)) + box((-x, y, z), (r * 0.6, r, r))

# ---------------------------------------------------------------- biche

def deer():
    m = Model("Deer")
    fur = m.mat("DeerFur", (0.55, 0.35, 0.19))
    belly = m.mat("DeerBelly", (0.88, 0.80, 0.66))
    dark = m.mat("DeerDark", (0.13, 0.09, 0.07))
    eye = m.mat("Eye", (0.02, 0.02, 0.02), 0.3)
    inner = m.mat("DeerEarIn", (0.75, 0.55, 0.45))
    body = loft([(0, 1.00, -0.60), (0, 1.01, -0.52), (0, 1.00, -0.34), (0, 0.97, -0.08),
                 (0, 0.98, 0.18), (0, 1.02, 0.40), (0, 1.07, 0.55), (0, 1.12, 0.63)],
                [(0.16, 0.20), (0.30, 0.36), (0.35, 0.42), (0.37, 0.44), (0.35, 0.46), (0.31, 0.46),
                 (0.22, 0.34), (0.10, 0.18)], n=10, flat_bottom=0.15)
    under, top = split(body, lambda nr, c: nr[1] < -0.55 or (nr[2] < -0.55 and c[1] > 0.88))
    m.part("Body", (0, 0.95, 0), {fur: top, belly: under})
    neck = loft([(0, 1.02, 0.40), (0, 1.16, 0.50), (0, 1.32, 0.57), (0, 1.47, 0.62)],
                [(0.20, 0.32), (0.16, 0.24), (0.13, 0.18), (0.12, 0.15)], n=8)
    nb, nt = split(neck, lambda nr, c: nr[2] > 0.55 and c[1] < 1.35)
    m.part("Neck", (0, 1.08, 0.45), {fur: nt, belly: nb})
    head = loft([(0, 1.52, 0.57), (0, 1.54, 0.64), (0, 1.52, 0.72), (0, 1.48, 0.80), (0, 1.44, 0.87), (0, 1.425, 0.905)],
                [(0.11, 0.12), (0.155, 0.16), (0.14, 0.14), (0.10, 0.10), (0.07, 0.075), (0.045, 0.05)], n=8)
    nose, hd = split(head, lambda nr, c: c[2] > 0.875)
    chin, hd = split(hd, lambda nr, c: nr[1] < -0.6 and c[2] > 0.7)
    m.part("Head", (0, 1.47, 0.62), {fur: hd, dark: nose, belly: chin, eye: eyes(0.072, 1.545, 0.70)}, parent="Neck")
    for s, n in ((1, "L"), (-1, "R")):
        piv = (0.055 * s, 1.58, 0.62)
        ear = leaf(piv, (0.17 * s, 1.72, 0.57), 0.085, 0.018, bend=(0, 0, 0.015))
        ein, eout = split(ear, lambda nr, c: nr[2] > 0.3)
        m.part("Ear_" + n, piv, {fur: eout, inner: ein}, parent="Head")
    for s, n in ((1, "L"), (-1, "R")):
        x = 0.11 * s
        z = 0.40
        leg = loft([(x, 0.98, z - 0.02), (x, 0.80, z), (x, 0.62, z + 0.01), (x, 0.44, z + 0.03), (x, 0.40, z + 0.03),
                    (x, 0.14, z + 0.0), (x, 0.06, z + 0.01), (x, 0.0, z + 0.025)],
                   [(0.11, 0.17), (0.09, 0.12), (0.065, 0.075), (0.055, 0.06), (0.06, 0.065), (0.04, 0.045),
                    (0.05, 0.06), (0.055, 0.075)], n=7)
        hoof, lg = split(leg, lambda nr, c: c[1] < 0.065)
        m.part("Leg_F" + n, (x, 0.95, z), {fur: lg, dark: hoof})
        z = -0.38
        leg = loft([(x, 1.02, z + 0.02), (x, 0.84, z - 0.02), (x, 0.66, z - 0.06), (x, 0.50, z - 0.10), (x, 0.44, z - 0.11),
                    (x, 0.16, z - 0.05), (x, 0.06, z - 0.035), (x, 0.0, z - 0.02)],
                   [(0.13, 0.30), (0.12, 0.22), (0.085, 0.12), (0.06, 0.07), (0.055, 0.075), (0.04, 0.045),
                    (0.05, 0.06), (0.055, 0.075)], n=7)
        hoof, lg = split(leg, lambda nr, c: c[1] < 0.065)
        m.part("Leg_B" + n, (x, 0.98, z), {fur: lg, dark: hoof})
    tail = loft([(0, 1.07, -0.58), (0, 1.02, -0.64), (0, 0.94, -0.66)], [(0.07, 0.04), (0.06, 0.035), (0.02, 0.02)], n=6)
    m.part("Tail", (0, 1.07, -0.58), {dark: tail})
    return m

# ---------------------------------------------------------------- sanglier

def boar():
    m = Model("Boar")
    fur = m.mat("BoarFur", (0.34, 0.26, 0.19))
    bristle = m.mat("BoarBristle", (0.17, 0.13, 0.10))
    snout = m.mat("BoarSnout", (0.45, 0.33, 0.3))
    tusk = m.mat("Tusk", (0.93, 0.89, 0.78), 0.5)
    eye = m.mat("Eye", (0.02, 0.02, 0.02), 0.3)
    body = loft([(0, 0.58, -0.64), (0, 0.57, -0.56), (0, 0.56, -0.36), (0, 0.57, -0.08), (0, 0.60, 0.18),
                 (0, 0.62, 0.36), (0, 0.61, 0.50), (0, 0.60, 0.58)],
                [(0.20, 0.24), (0.38, 0.44), (0.45, 0.52), (0.50, 0.58), (0.52, 0.64), (0.50, 0.66), (0.42, 0.56), (0.30, 0.40)],
                n=10, noise=0.03)
    dark_back, rest = split(body, lambda nr, c: nr[1] > 0.75)
    crest = loft([(0, 0.82, -0.30), (0, 0.90, 0.0), (0, 0.95, 0.28), (0, 0.93, 0.46)],
                 [(0.03, 0.06), (0.05, 0.10), (0.06, 0.12), (0.03, 0.06)], n=4)
    m.part("Body", (0, 0.55, 0), {fur: rest, bristle: dark_back + crest})
    head = loft([(0, 0.66, 0.50), (0, 0.64, 0.62), (0, 0.58, 0.76), (0, 0.53, 0.88), (0, 0.515, 0.95), (0, 0.51, 0.975)],
                [(0.34, 0.40), (0.30, 0.34), (0.20, 0.22), (0.13, 0.14), (0.115, 0.115), (0.11, 0.10)], n=8)
    disc, hd = split(head, lambda nr, c: c[2] > 0.955)
    m.part("Head", (0, 0.6, 0.52), {fur: hd, snout: disc, eye: eyes(0.105, 0.69, 0.64),
                                    tusk: loft([(0.06, 0.49, 0.86), (0.085, 0.53, 0.885), (0.09, 0.58, 0.87)],
                                               [(0.025, 0.025), (0.02, 0.02), (0.006, 0.006)], n=5) +
                                    mirror_x(loft([(0.06, 0.49, 0.86), (0.085, 0.53, 0.885), (0.09, 0.58, 0.87)],
                                                  [(0.025, 0.025), (0.02, 0.02), (0.006, 0.006)], n=5))})
    for s, n in ((1, "L"), (-1, "R")):
        piv = (0.10 * s, 0.78, 0.56)
        m.part("Ear_" + n, piv, {bristle: leaf(piv, (0.15 * s, 0.90, 0.52), 0.08, 0.02, bend=(0, 0, 0.02))}, parent="Head")
    for s, n in ((1, "L"), (-1, "R")):
        x = 0.14 * s
        z = 0.32
        leg = loft([(x, 0.52, z), (x, 0.36, z + 0.01), (x, 0.22, z + 0.02), (x, 0.08, z + 0.01), (x, 0.0, z + 0.02)],
                   [(0.13, 0.18), (0.09, 0.10), (0.065, 0.07), (0.055, 0.06), (0.06, 0.07)], n=7)
        hoof, lg = split(leg, lambda nr, c: c[1] < 0.07)
        m.part("Leg_F" + n, (x, 0.48, z), {fur: lg, bristle: hoof})
        z = -0.40
        leg = loft([(x, 0.58, z + 0.02), (x, 0.40, z - 0.03), (x, 0.24, z - 0.06), (x, 0.08, z - 0.03), (x, 0.0, z - 0.02)],
                   [(0.15, 0.28), (0.11, 0.14), (0.065, 0.075), (0.055, 0.06), (0.06, 0.07)], n=7)
        hoof, lg = split(leg, lambda nr, c: c[1] < 0.07)
        m.part("Leg_B" + n, (x, 0.52, z), {fur: lg, bristle: hoof})
    tail = loft([(0, 0.66, -0.62), (0, 0.58, -0.66), (0, 0.46, -0.67), (0, 0.42, -0.67)],
                [(0.03, 0.03), (0.02, 0.02), (0.015, 0.015), (0.04, 0.05)], n=5)
    m.part("Tail", (0, 0.66, -0.62), {bristle: tail})
    return m

# ---------------------------------------------------------------- mouton

def sheep():
    m = Model("Sheep")
    wool = m.mat("Wool", (0.88, 0.85, 0.77))
    wool_d = m.mat("WoolShade", (0.78, 0.74, 0.66))
    face = m.mat("SheepFace", (0.13, 0.12, 0.11))
    eye = m.mat("Eye", (0.02, 0.02, 0.02), 0.3)
    pts = [(0, 0.66, -0.64), (0, 0.66, -0.56), (0, 0.65, -0.42), (0, 0.65, -0.24), (0, 0.66, -0.04),
           (0, 0.67, 0.16), (0, 0.68, 0.34), (0, 0.70, 0.48), (0, 0.72, 0.58)]
    secs = [(0.22, 0.24), (0.48, 0.48), (0.62, 0.58), (0.68, 0.62), (0.70, 0.62), (0.68, 0.62),
            (0.62, 0.60), (0.50, 0.50), (0.28, 0.32)]
    body = loft(pts, secs, n=12, noise=0.09)
    shade, lit = split(body, lambda nr, c: nr[1] < -0.35)
    m.part("Body", (0, 0.62, 0), {wool: lit, wool_d: shade})
    head = loft([(0, 0.80, 0.50), (0, 0.79, 0.60), (0, 0.74, 0.70), (0, 0.69, 0.78), (0, 0.665, 0.82)],
                [(0.17, 0.19), (0.19, 0.21), (0.15, 0.16), (0.11, 0.115), (0.08, 0.08)], n=8)
    cap = loft([(0, 0.88, 0.52), (0, 0.90, 0.57), (0, 0.88, 0.63)], [(0.14, 0.06), (0.22, 0.10), (0.14, 0.06)], n=8, noise=0.12)
    m.part("Head", (0, 0.76, 0.50), {face: head, wool: cap, eye: eyes(0.088, 0.80, 0.63, 0.022)})
    for s, n in ((1, "L"), (-1, "R")):
        piv = (0.08 * s, 0.81, 0.58)
        m.part("Ear_" + n, piv, {face: leaf(piv, (0.22 * s, 0.78, 0.55), 0.07, 0.018, bend=(0, -0.01, 0))}, parent="Head")
    for s, n in ((1, "L"), (-1, "R")):
        x = 0.17 * s
        for z, nm in ((0.32, "F"), (-0.34, "B")):
            leg = loft([(x, 0.50, z), (x, 0.30, z), (x, 0.22, z + 0.005), (x, 0.06, z), (x, 0.0, z + 0.01)],
                       [(0.08, 0.09), (0.05, 0.055), (0.055, 0.06), (0.04, 0.045), (0.05, 0.06)], n=6)
            m.part("Leg_" + nm + n, (x, 0.45, z), {face: leg})
    tail = loft([(0, 0.68, -0.62), (0, 0.62, -0.68), (0, 0.54, -0.69)], [(0.10, 0.08), (0.11, 0.10), (0.06, 0.06)], n=7, noise=0.1)
    m.part("Tail", (0, 0.68, -0.62), {wool: tail})
    return m

# ---------------------------------------------------------------- lapin

def rabbit():
    m = Model("Rabbit")
    fur = m.mat("RabbitFur", (0.52, 0.43, 0.33))
    white = m.mat("RabbitWhite", (0.92, 0.9, 0.86))
    pink = m.mat("RabbitEar", (0.80, 0.58, 0.55))
    eye = m.mat("Eye", (0.02, 0.02, 0.02), 0.3)
    body = loft([(0, 0.15, -0.17), (0, 0.16, -0.14), (0, 0.17, -0.07), (0, 0.18, 0.02), (0, 0.20, 0.09),
                 (0, 0.215, 0.13), (0, 0.22, 0.15)],
                [(0.10, 0.10), (0.20, 0.20), (0.23, 0.23), (0.20, 0.21), (0.15, 0.17), (0.11, 0.13), (0.07, 0.08)], n=9)
    under, top = split(body, lambda nr, c: nr[1] < -0.45)
    m.part("Body", (0, 0.16, 0), {fur: top, white: under})
    head = loft([(0, 0.255, 0.12), (0, 0.275, 0.16), (0, 0.28, 0.20), (0, 0.27, 0.235), (0, 0.255, 0.258)],
                [(0.09, 0.09), (0.12, 0.12), (0.115, 0.11), (0.085, 0.08), (0.04, 0.04)], n=8)
    nose, hd = split(head, lambda nr, c: c[2] > 0.25)
    m.part("Head", (0, 0.24, 0.13), {fur: hd, pink: nose, eye: eyes(0.05, 0.29, 0.205, 0.016)})
    for s, n in ((1, "L"), (-1, "R")):
        piv = (0.022 * s, 0.32, 0.15)
        ear = leaf(piv, (0.045 * s, 0.47, 0.105), 0.05, 0.012, bend=(0.005 * s, 0, -0.01))
        ein, eout = split(ear, lambda nr, c: nr[2] > 0.25)
        m.part("Ear_" + n, piv, {fur: eout, pink: ein}, parent="Head")
    for s, n in ((1, "L"), (-1, "R")):
        x = 0.045 * s
        m.part("Leg_F" + n, (x, 0.12, 0.10), {fur: loft([(x, 0.13, 0.10), (x, 0.06, 0.115), (x, 0.0, 0.125)],
                                                         [(0.032, 0.035), (0.026, 0.028), (0.03, 0.026)], n=6)})
        x = 0.075 * s
        haunch = loft([(x, 0.17, -0.07), (x, 0.13, -0.09), (x, 0.08, -0.10), (x, 0.04, -0.09)],
                      [(0.055, 0.12), (0.07, 0.13), (0.065, 0.10), (0.045, 0.05)], n=7, up=(0, 0, 1))
        foot = loft([(x, 0.014, -0.13), (x, 0.014, -0.06), (x, 0.014, 0.0)], [(0.045, 0.028), (0.04, 0.026), (0.03, 0.02)], n=6)
        m.part("Leg_B" + n, (x, 0.13, -0.09), {fur: haunch + foot})
    m.part("Tail", (0, 0.17, -0.18), {white: loft([(0, 0.18, -0.17), (0, 0.19, -0.2), (0, 0.185, -0.225)],
                                                   [(0.05, 0.05), (0.07, 0.07), (0.03, 0.03)], n=7)})
    return m


ALL = (("sheep", sheep), ("deer", deer), ("boar", boar), ("rabbit", rabbit))

if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else "."
    for fn, f in ALL:
        mdl = f()
        mdl.save(f"{out}/{fn}.glb")
        n = sum(len(t) for p in mdl.parts for t in p[3].values())
        print(fn, len(mdl.parts), "pièces", n, "triangles")
