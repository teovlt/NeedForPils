"""Sac à dos de Need for Pils (posé sur la banquette arrière, à côté de la glacière).

Usage : python3 backpack_build.py <dossier de sortie>   (-> backpack.glb)

Réutilise Model / box de props/animals/animals_build.py. Facettes plates (low poly).
Repère Godot : +Y en haut, sac debout posé à y = 0, dos (bretelles) vers -Z, poche
avant vers +Z.

Nœuds :
  Body : sac ouvert par le haut (tissu bordeaux, intérieur sombre, fond, poche avant,
         bretelles, poignée, fermetures éclair)
  Flap : rabat du dessus, pivot sur la couture arrière (y = H, z = -D/2)
"""
import math, os, sys
import numpy as np
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "animals"))
from animals_build import Model, box

W, D, H = 0.31, 0.17, 0.40      # largeur (X), épaisseur (Z), hauteur (Y)
N = 12                          # facettes du contour arrondi
WALL = 0.012


def ring(y, w, d, n=N):
    """Contour arrondi (super-ellipse) du sac à la hauteur y."""
    pts = []
    for k in range(n):
        a = 2 * math.pi * (k + 0.5) / n
        c, s = math.cos(a), math.sin(a)
        x = math.copysign(abs(c) ** 0.6, c) * w / 2
        z = math.copysign(abs(s) ** 0.6, s) * d / 2
        pts.append(np.array((x, y, z)))
    return pts


def band(r0, r1, outward=True):
    """Bande entre deux contours (normales vers l'extérieur ou l'intérieur)."""
    tris = []
    n = len(r0)
    for k in range(n):
        a, b = r0[k], r0[(k + 1) % n]
        c, d = r1[(k + 1) % n], r1[k]
        for t in ((a, b, c), (a, c, d)):
            ctr = (r0[0] + r0[n // 2]) / 2
            ctr[1] = t[0][1]
            nrm = np.cross(t[1] - t[0], t[2] - t[0])
            mid = (t[0] + t[1] + t[2]) / 3
            if (np.dot(nrm, mid - ctr) < 0) == outward:
                t = (t[0], t[2], t[1])
            tris.append(tuple(tuple(float(v) for v in p) for p in t))
    return tris


def annulus(r_out, r_in):
    """Couronne horizontale (bord de l'ouverture), face vers le haut."""
    tris = []
    n = len(r_out)
    for k in range(n):
        a, b = r_out[k], r_out[(k + 1) % n]
        c, d = r_in[(k + 1) % n], r_in[k]
        for t in ((a, b, c), (a, c, d)):
            nrm = np.cross(t[1] - t[0], t[2] - t[0])
            if nrm[1] < 0:
                t = (t[0], t[2], t[1])
            tris.append(tuple(tuple(float(v) for v in p) for p in t))
    return tris


def cap(r, up=True):
    c = sum(r) / len(r)
    tris = []
    for k in range(len(r)):
        t = (c, r[k], r[(k + 1) % len(r)])
        nrm = np.cross(t[1] - t[0], t[2] - t[0])
        if (nrm[1] > 0) != up:
            t = (t[0], t[2], t[1])
        tris.append(tuple(tuple(float(v) for v in p) for p in t))
    return tris


def backpack():
    m = Model("Backpack")
    cloth = m.mat("Bag_Cloth", (0.42, 0.08, 0.10), 0.95)
    dark = m.mat("Bag_Dark", (0.10, 0.10, 0.11), 0.95)
    inside = m.mat("Bag_Inside", (0.16, 0.15, 0.17), 0.95)
    zip_ = m.mat("Bag_Zip", (0.55, 0.56, 0.58), 0.4)
    # corps : un peu plus large en bas, épaules arrondies en haut
    levels = [(0.0, 0.92, 0.85), (0.03, 1.0, 1.0), (0.25, 1.0, 1.0), (H - 0.05, 0.97, 0.96), (H, 0.93, 0.9)]
    rings = [ring(y, W * sw, D * sd) for y, sw, sd in levels]
    outer = []
    for a, b in zip(rings[:-1], rings[1:]):
        outer += band(a, b, True)
    bottom = cap(rings[0], up=False)
    inner_top = ring(H, W * 0.93 - 2 * WALL, D * 0.9 - 2 * WALL)
    inner_bot = ring(0.02, W * 0.92 - 2 * WALL, D * 0.85 - 2 * WALL)
    inner = band(inner_bot, inner_top, False) + cap(inner_bot, up=True)
    rim = annulus(rings[-1], inner_top)
    # poche avant (bloc arrondi sur la face +Z) et sa fermeture
    pocket = []
    pr = [ring(y, W * 0.7, 0.06) for y in (0.04, 0.2)]
    shift = np.array((0, 0, D / 2 + 0.012))
    pr = [[p + shift for p in r] for r in pr]
    pocket += band(pr[0], pr[1], True) + cap(pr[1], up=True) + cap(pr[0], up=False)
    zips = box((0, 0.2 + 0.001, D / 2 + 0.03), (W * 0.62, 0.003, 0.004))
    zips += box((0, H - 0.002, D * 0.45 - 0.002), (W * 0.8, 0.004, 0.004))
    # bretelles (dos) et poignée du dessus
    straps = []
    for sx in (-1, 1):
        straps += box((sx * 0.07, 0.22, -D / 2 - 0.012), (0.05, 0.34, 0.012))
        straps += box((sx * 0.07, 0.05, -D / 2 - 0.02), (0.05, 0.03, 0.02))
    handle = box((0, H + 0.012, -D * 0.25), (0.08, 0.012, 0.018))
    m.part("Body", (0, 0, 0), {cloth: outer + bottom + rim + pocket, inside: inner, dark: straps + handle, zip_: zips})
    # rabat : couvercle arrondi un peu plus grand que l'ouverture
    fr0 = ring(H, W * 0.97, D * 0.95)
    fr1 = ring(H + 0.025, W * 0.9, D * 0.85)
    flap = band(fr0, fr1, True) + cap(fr1, up=True) + cap(fr0, up=False)
    tab = box((0, H + 0.01, D * 0.47), (0.04, 0.03, 0.006))
    m.part("Flap", (0, H, -D / 2), {cloth: flap, dark: tab})
    return m


if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else "."
    mdl = backpack()
    mdl.save(os.path.join(out, "backpack.glb"))
    print("backpack", len(mdl.parts), "pièces", sum(len(t) for p in mdl.parts for t in p[3].values()), "triangles")
