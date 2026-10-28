"""Thermos low poly de Need for Pils, en deux pièces : corps et bouchon-tasse.

Usage : python3 thermos_build.py <dossier de sortie>   (-> thermos.glb, thermos_cup.glb)

Réutilise le Model de props/animals/animals_build.py ; les pièces rondes sont des
révolutions (tour) d'un profil (rayon, hauteur), facettes plates (style low poly).

thermos.glb : thermos debout, +Y en haut, fond à y = 0, poignée côté +X.
  Body : fond inox, corps vert, épaule inox, goulot noir fileté (ouvert, intérieur sombre)
  Cup  : le bouchon (une tasse retournée vissée sur le goulot), pivot au centre de son
         bord (y = CUP_RIM) ; caché par interaction/thermos.gd quand on le dévisse.
thermos_cup.glb : la même tasse à l'endroit (fond à y = 0, ouverture en haut), l'objet
  qu'on tient en main une fois dévissée (interaction/thermos_cup.gd y ajoute le café).
"""
import math, os, sys
import numpy as np
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "animals"))
from animals_build import Model, box

N = 14                 # facettes autour de l'axe
CUP_H = 0.078          # hauteur de la tasse
CUP_RIM = 0.208        # hauteur du bord de la tasse quand elle est vissée (retournée)
NECK_TOP = 0.256       # haut du goulot (ouverture), rayon intérieur 0,019


def lathe(profile, n=N):
    """Surface de révolution autour de Y. profile = [(r, y), ...] parcouru de façon que
    l'extérieur de la surface soit à droite du sens de parcours (r vers la droite, y en haut)."""
    tris = []
    for (r1, y1), (r2, y2) in zip(profile[:-1], profile[1:]):
        dr, dy = r2 - r1, y2 - y1
        for k in range(n):
            a0, a1 = 2 * math.pi * k / n, 2 * math.pi * (k + 1) / n
            p = lambda r, y, a: np.array((r * math.cos(a), y, r * math.sin(a)))
            q = [p(r1, y1, a0), p(r1, y1, a1), p(r2, y2, a1), p(r2, y2, a0)]
            am = (a0 + a1) / 2
            want = np.array((dy * math.cos(am), -dr, dy * math.sin(am)))   # (dy, -dr) en (r, y)
            for t in ((q[0], q[1], q[2]), (q[0], q[2], q[3])):
                nrm = np.cross(t[1] - t[0], t[2] - t[0])
                if np.linalg.norm(nrm) < 1e-12:
                    continue   # triangle dégénéré sur l'axe
                if np.dot(nrm, want) < 0:
                    t = (t[0], t[2], t[1])
                tris.append(tuple(tuple(float(x) for x in v) for v in t))
    return tris


def flip_cup(tris):
    """Tasse retournée et vissée sur le thermos : rotation de 180° autour de X."""
    top = CUP_RIM + CUP_H
    return [tuple((v[0], top - v[1], -v[2]) for v in t) for t in tris]


def cup_geo(m):
    green, steel = m.mats_by["green"], m.mats_by["steel"]
    return {
        green: lathe([(0.0, 0.0), (0.037, 0.0), (0.0405, 0.062)]),
        steel: lathe([(0.0405, 0.062), (0.0415, CUP_H), (0.0385, CUP_H), (0.034, 0.004), (0.0, 0.004)]),
    }


def materials(m):
    m.mats_by = {
        "steel": m.mat("Steel", (0.70, 0.72, 0.74), 0.3),
        "green": m.mat("Thermos_Green", (0.12, 0.36, 0.20), 0.5),
        "black": m.mat("Black_Plastic", (0.06, 0.06, 0.065), 0.7),
        "inside": m.mat("Thermos_Inside", (0.03, 0.025, 0.02), 0.6),
    }
    return m.mats_by


def thermos():
    m = Model("Thermos")
    mb = materials(m)
    steel = lathe([(0.0, 0.0), (0.036, 0.0), (0.039, 0.004), (0.039, 0.020)]) + \
        lathe([(0.039, 0.205), (0.039, 0.213), (0.030, 0.226), (0.026, 0.232)])
    green = lathe([(0.0393, 0.020), (0.0393, 0.205)])
    neck = lathe([(0.0255, 0.232), (0.0255, 0.240), (0.027, 0.242), (0.0255, 0.244),
                  (0.0255, 0.248), (0.027, 0.250), (0.0255, 0.252), (0.0255, NECK_TOP), (0.019, NECK_TOP)])
    inside = lathe([(0.019, NECK_TOP), (0.019, 0.238), (0.0, 0.238)])
    # poignée : barre verticale reliée au corps par deux pattes
    handle = box((0.057, 0.13, 0), (0.012, 0.125, 0.016)) + box((0.047, 0.185, 0), (0.022, 0.014, 0.016)) + \
        box((0.047, 0.075, 0), (0.022, 0.014, 0.016))
    m.part("Body", (0, 0, 0), {mb["steel"]: steel, mb["green"]: green, mb["black"]: neck + handle, mb["inside"]: inside})
    m.part("Cup", (0, CUP_RIM, 0), {k: flip_cup(v) for k, v in cup_geo(m).items()})
    return m


def thermos_cup():
    m = Model("ThermosCup")
    materials(m)
    m.part("Cup", (0, 0, 0), cup_geo(m))
    return m


ALL = (("thermos", thermos), ("thermos_cup", thermos_cup))

if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else "."
    for name, fn in ALL:
        mdl = fn()
        mdl.save(os.path.join(out, name + ".glb"))
        print(name, len(mdl.parts), "pièces", sum(len(t) for p in mdl.parts for t in p[3].values()), "triangles")
