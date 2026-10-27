"""Modèles low poly des animaux de Need for Pils (lapin, sanglier, biche, mouton).

Usage : python3 animals_build.py <dossier de sortie>   (-> rabbit.glb, boar.glb, deer.glb, sheep.glb)

Chaque animal regarde vers +Z (repère Godot : +Y en haut), les pieds à y = 0.
Pièces séparées pour l'animation par code (world/animals/animal.gd) :
  Body, Head (pivot au cou), Leg_FL / Leg_FR / Leg_BL / Leg_BR (pivot à la hanche / l'épaule),
  Tail (pivot à la base), et sous Head : Ear_L / Ear_R (pivot à la base).
Facettes plates (une normale par face), une couleur unie par matériau.
"""
import json, math, struct, sys
import numpy as np

# ---------------------------------------------------------------- formes de base

def frustum(c, bot, top, h, y0=0.0, n=4, rot=0.0):
    """Tronc de pyramide / prisme : section du bas `bot`=(sx, sz), du haut `top`, hauteur h.
    n=4 : rectangle ; n>4 : polygone (ellipse). Centre en x,z = c, base à y0."""
    cx, cz = c
    ring = []
    for k in range(n):
        a = rot + (math.pi / 4 if n == 4 else 0.0) + 2 * math.pi * k / n
        ring.append((math.cos(a), math.sin(a)))
    s = math.sqrt(2) if n == 4 else 1.0
    b = [(cx + x * bot[0] / 2 * s, y0, cz + z * bot[1] / 2 * s) for x, z in ring]
    t = [(cx + x * top[0] / 2 * s, y0 + h, cz + z * top[1] / 2 * s) for x, z in ring]
    tris = []
    for k in range(n):
        k2 = (k + 1) % n
        tris += [(b[k], t[k2], b[k2]), (b[k], t[k], t[k2])]
    for k in range(1, n - 1):
        tris.append((b[0], b[k + 1], b[k]))
        tris.append((t[0], t[k], t[k + 1]))
    return tris


def frustum_z(c, z0, length, back, front, n=6):
    """Prisme couché le long de +Z : section arrière `back`=(largeur, hauteur) à z0,
    section avant `front` à z0+length, centrée sur c=(x, y)."""
    cx, cy = c
    ring = []
    for k in range(n):
        a = (math.pi / 4 if n == 4 else math.pi / 2) + 2 * math.pi * k / n
        ring.append((math.cos(a), math.sin(a)))
    sq = math.sqrt(2) if n == 4 else 1.0
    b = [(cx + x * back[0] / 2 * sq, cy + y * back[1] / 2 * sq, z0) for x, y in ring]
    f = [(cx + x * front[0] / 2 * sq, cy + y * front[1] / 2 * sq, z0 + length) for x, y in ring]
    tris = []
    for k in range(n):
        k2 = (k + 1) % n
        tris += [(b[k], b[k2], f[k2]), (b[k], f[k2], f[k])]
    for k in range(1, n - 1):
        tris.append((b[0], b[k], b[k + 1]))
        tris.append((f[0], f[k + 1], f[k]))
    return tris


def box(center, size):
    x, y, z = center
    return frustum((x, z), (size[0], size[2]), (size[0], size[2]), size[1], y - size[1] / 2)


def blob(center, size, lat=4, lon=6, squash_top=1.0):
    """Ellipsoïde low poly (lat bandes, lon méridiens)."""
    cx, cy, cz = center
    rx, ry, rz = size[0] / 2, size[1] / 2, size[2] / 2
    pts = []
    for i in range(lat + 1):
        th = math.pi * i / lat
        row = []
        for j in range(lon):
            ph = 2 * math.pi * j / lon + (math.pi / lon if i % 2 else 0)
            y = math.cos(th) * ry * (squash_top if i < lat / 2 else 1.0)
            r = math.sin(th)
            row.append((cx + r * math.cos(ph) * rx, cy + y, cz + r * math.sin(ph) * rz))
        pts.append(row)
    tris = []
    for i in range(lat):
        for j in range(lon):
            j2 = (j + 1) % lon
            a, b2, c2, d = pts[i][j], pts[i][j2], pts[i + 1][j], pts[i + 1][j2]
            if i > 0:
                tris.append((a, b2, c2))
            if i < lat - 1:
                tris.append((b2, d, c2))
    return tris


def xform(tris, rx=0.0, ry=0.0, rz=0.0, move=(0, 0, 0), pivot=(0, 0, 0)):
    """Rotation (degrés, X puis Y puis Z) autour de `pivot`, puis translation."""
    def R(ax, a):
        a = math.radians(a); c, s = math.cos(a), math.sin(a)
        if ax == 0: return np.array([[1, 0, 0], [0, c, -s], [0, s, c]])
        if ax == 1: return np.array([[c, 0, s], [0, 1, 0], [-s, 0, c]])
        return np.array([[c, -s, 0], [s, c, 0], [0, 0, 1]])
    M = R(2, rz) @ R(1, ry) @ R(0, rx)
    p = np.array(pivot, float); m = np.array(move, float)
    return [tuple(tuple((M @ (np.array(v) - p)) + p + m) for v in t) for t in tris]


def shift(tris, d):
    return [tuple((v[0] - d[0], v[1] - d[1], v[2] - d[2]) for v in t) for t in tris]

# ---------------------------------------------------------------- écriture glb

class Model:
    def __init__(self, name):
        self.name = name
        self.parts = []      # (nom, parent, pivot (repère monde de l'animal), {matériau: tris})
        self.mats = {}

    def mat(self, name, rgb, rough=0.9):
        self.mats[name] = (rgb, rough)
        return name

    def part(self, name, pivot, geo, parent=None):
        """geo = {matériau: triangles en coordonnées de l'animal} ; stockés relatifs au pivot."""
        self.parts.append((name, parent, pivot, {m: shift(t, pivot) for m, t in geo.items()}))

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
                if not tris: continue
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
                an = len(accs) - 1
                prims.append({"attributes": {"POSITION": ap, "NORMAL": an}, "material": mat_names.index(m)})
            meshes.append({"name": name, "primitives": prims})
            nodes.append({"name": name, "mesh": len(meshes) - 1})
        # hiérarchie : translation = pivot - pivot du parent
        piv = {p[0]: p[2] for p in self.parts}
        children = {}
        roots = []
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
            "asset": {"version": "2.0", "generator": "Need for Pils animals_build.py"},
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

# ---------------------------------------------------------------- animaux

def legs(m, mat, hip_y, xs, zs, w, foot=None, hoof=None, names=("FL", "FR", "BL", "BR"), taper=0.75):
    """4 pattes droites sous les hanches, pivot en haut."""
    pos = [(xs, zs[0]), (-xs, zs[0]), (xs, zs[1]), (-xs, zs[1])]
    for (x, z), n in zip(pos, names):
        geo = {mat: frustum((x, z), (w * taper, w * taper), (w, w * 1.1), hip_y, 0.0)}
        if hoof:
            geo[hoof] = frustum((x, z), (w * 0.85, w * 0.95), (w * 0.8, w * 0.85), hip_y * 0.12, 0.0)
            geo[mat] = frustum((x, z), (w * taper, w * taper), (w, w * 1.1), hip_y * 0.88, hip_y * 0.12)
        m.part("Leg_" + n, (x, hip_y, z), geo)


def eyes(x, y, z, r=0.018):
    return box((x, y, z), (r, r, r)) + box((-x, y, z), (r, r, r))


def sheep():
    m = Model("Sheep")
    wool = m.mat("Wool", (0.86, 0.83, 0.74)); face = m.mat("SheepFace", (0.12, 0.11, 0.1))
    eye = m.mat("Eye", (0.02, 0.02, 0.02), 0.3)
    m.part("Body", (0, 0.62, 0), {wool: blob((0, 0.64, 0), (0.62, 0.52, 1.0), 4, 7) +
                                   blob((0, 0.78, -0.12), (0.5, 0.26, 0.6), 3, 6) +
                                   blob((0, 0.77, 0.28), (0.46, 0.24, 0.42), 3, 6)})
    neck = (0, 0.72, 0.42)
    tilt = dict(rx=28, pivot=neck)      # museau vers le bas
    head = {face: xform(frustum_z((0, 0.72), 0.4, 0.34, (0.22, 0.25), (0.13, 0.15)), **tilt),
            wool: xform(blob((0, 0.84, 0.5), (0.26, 0.14, 0.2), 2, 6), **tilt),
            eye: xform(eyes(0.098, 0.77, 0.57), **tilt)}
    m.part("Head", neck, head)
    for s_, n in ((1, "L"), (-1, "R")):
        piv = (0.11 * s_, 0.79, 0.5)
        ear = frustum_z((0.11 * s_ + 0.06 * s_, 0.79), 0.48, 0.05, (0.1, 0.03), (0.1, 0.03), 4)
        m.part("Ear_" + n, xform([(piv,) * 3], **tilt)[0][0],
               {face: xform(xform(ear, rz=-15 * s_, pivot=piv), **tilt)}, parent="Head")
    legs(m, face, 0.42, 0.17, (0.3, -0.32), 0.075)
    m.part("Tail", (0, 0.66, -0.5), {wool: blob((0, 0.6, -0.55), (0.12, 0.16, 0.1), 2, 5)})
    return m


def deer():
    m = Model("Deer")
    fur = m.mat("DeerFur", (0.52, 0.34, 0.19)); belly = m.mat("DeerBelly", (0.85, 0.78, 0.66))
    dark = m.mat("DeerDark", (0.14, 0.1, 0.08)); eye = m.mat("Eye", (0.02, 0.02, 0.02), 0.3)
    m.part("Body", (0, 0.95, 0), {fur: blob((0, 1.0, 0), (0.38, 0.42, 1.08), 4, 7),
                                  belly: blob((0, 0.86, 0.02), (0.28, 0.14, 0.8), 2, 6)})
    neck_base = (0, 1.08, 0.38)
    neck = xform(frustum((0, 0.38), (0.2, 0.24), (0.12, 0.14), 0.5, 1.02, n=6), rx=30, pivot=(0, 1.02, 0.38))
    m.part("Neck", neck_base, {fur: neck})
    hp = (0, 1.47, 0.6)
    tilt = dict(rx=22, pivot=hp)
    head = {fur: xform(frustum_z((0, 1.49), 0.54, 0.34, (0.15, 0.19), (0.07, 0.09)), **tilt),
            dark: xform(box((0, 1.485, 0.885), (0.06, 0.06, 0.03)), **tilt),
            eye: xform(eyes(0.066, 1.53, 0.66, 0.02), **tilt)}
    m.part("Head", hp, head, parent="Neck")
    for s_, n in ((1, "L"), (-1, "R")):
        piv = (0.06 * s_, 1.57, 0.58)
        ear = xform(frustum((0.06 * s_, 0.58), (0.045, 0.02), (0.08, 0.025), 0.16, 1.57, n=6), rz=-40 * s_, pivot=piv)
        m.part("Ear_" + n, piv, {fur: ear}, parent="Head")
    legs(m, fur, 0.86, 0.12, (0.38, -0.36), 0.065, hoof=dark, taper=0.6)
    m.part("Tail", (0, 1.08, -0.52), {belly: xform(frustum((0, -0.52), (0.08, 0.05), (0.04, 0.03), 0.14, 1.08),
                                                    rx=-150, pivot=(0, 1.08, -0.52))})
    return m


def boar():
    m = Model("Boar")
    fur = m.mat("BoarFur", (0.22, 0.17, 0.13)); bristle = m.mat("BoarBristle", (0.12, 0.09, 0.07))
    snout = m.mat("BoarSnout", (0.42, 0.3, 0.27)); tusk = m.mat("Tusk", (0.92, 0.88, 0.78), 0.5)
    eye = m.mat("Eye", (0.02, 0.02, 0.02), 0.3)
    m.part("Body", (0, 0.55, 0), {fur: blob((0, 0.58, -0.05), (0.5, 0.52, 1.0), 4, 7) +
                                   blob((0, 0.64, 0.22), (0.56, 0.6, 0.6), 4, 7),
                                   bristle: frustum_z((0, 0.86), -0.32, 0.72, (0.05, 0.08), (0.08, 0.16), 4)})
    hp = (0, 0.6, 0.44)
    tilt = dict(rx=14, pivot=hp)
    head = {fur: xform(frustum_z((0, 0.6), 0.4, 0.46, (0.36, 0.4), (0.15, 0.15)), **tilt),
            snout: xform(frustum_z((0, 0.6), 0.85, 0.04, (0.15, 0.13), (0.14, 0.12)), **tilt),
            tusk: xform(xform(box((0.075, 0.57, 0.8), (0.022, 0.09, 0.022)), rz=-25, pivot=(0.075, 0.54, 0.8)) +
                        xform(box((-0.075, 0.57, 0.8), (0.022, 0.09, 0.022)), rz=25, pivot=(-0.075, 0.54, 0.8)), **tilt),
            eye: xform(eyes(0.105, 0.67, 0.6), **tilt)}
    m.part("Head", hp, head)
    for s_, n in ((1, "L"), (-1, "R")):
        piv = (0.1 * s_, 0.76, 0.5)
        m.part("Ear_" + n, piv, {fur: xform(frustum((0.1 * s_, 0.5), (0.07, 0.04), (0.02, 0.02), 0.12, 0.76),
                                            rz=-25 * s_, rx=-10, pivot=piv)}, parent="Head")
    legs(m, fur, 0.36, 0.15, (0.3, -0.3), 0.085, hoof=bristle)
    m.part("Tail", (0, 0.62, -0.52), {bristle: xform(frustum((0, -0.52), (0.03, 0.03), (0.015, 0.015), 0.2, 0.62),
                                                      rx=-160, pivot=(0, 0.62, -0.52))})
    return m


def rabbit():
    m = Model("Rabbit")
    fur = m.mat("RabbitFur", (0.5, 0.42, 0.33)); white = m.mat("RabbitWhite", (0.92, 0.9, 0.86))
    pink = m.mat("RabbitEar", (0.75, 0.55, 0.52)); eye = m.mat("Eye", (0.02, 0.02, 0.02), 0.3)
    m.part("Body", (0, 0.16, 0), {fur: blob((0, 0.17, -0.02), (0.2, 0.22, 0.34), 3, 6) +
                                   blob((0, 0.14, -0.1), (0.24, 0.2, 0.2), 3, 6)})
    hp = (0, 0.24, 0.13)
    m.part("Head", hp, {fur: blob((0, 0.27, 0.19), (0.13, 0.12, 0.15), 3, 6),
                        white: box((0, 0.245, 0.265), (0.03, 0.025, 0.02)),
                        eye: eyes(0.05, 0.29, 0.23, 0.014)})
    for s, n in ((1, "L"), (-1, "R")):
        piv = (0.025 * s, 0.32, 0.16)
        m.part("Ear_" + n, piv, {fur: xform(frustum((0.025 * s, 0.16), (0.025, 0.012), (0.045, 0.014), 0.15, 0.32, n=5),
                                            rz=-12 * s, rx=-18, pivot=piv),
                                 pink: xform(box((0.025 * s, 0.4, 0.168), (0.02, 0.1, 0.006)),
                                             rz=-12 * s, rx=-18, pivot=piv)}, parent="Head")
    # pattes avant fines, pattes arrière longues et pliées (pied à plat)
    for s, n in ((1, "L"), (-1, "R")):
        m.part("Leg_F" + n, (0.05 * s, 0.1, 0.1), {fur: frustum((0.05 * s, 0.11), (0.03, 0.04), (0.035, 0.035), 0.1, 0.0)})
        m.part("Leg_B" + n, (0.08 * s, 0.12, -0.1), {fur: blob((0.08 * s, 0.1, -0.1), (0.07, 0.12, 0.12), 2, 5) +
                                                     box((0.08 * s, 0.015, -0.06), (0.05, 0.03, 0.14))})
    m.part("Tail", (0, 0.17, -0.19), {white: blob((0, 0.18, -0.2), (0.07, 0.07, 0.06), 2, 5)})
    return m


if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else "."
    for fn, f in (("sheep", sheep), ("deer", deer), ("boar", boar), ("rabbit", rabbit)):
        mdl = f()
        mdl.save(f"{out}/{fn}.glb")
        n = sum(len(t) for p in mdl.parts for t in p[3].values())
        print(fn, len(mdl.parts), "pièces", n, "triangles")
