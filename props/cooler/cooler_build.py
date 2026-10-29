"""Glacière et canette de bière de Need for Pils.

Usage : python3 cooler_build.py <dossier de sortie>   (-> cooler.glb, beer_can.glb)

Réutilise Model / box de props/animals/animals_build.py et le tour (lathe) de
props/thermos_build.py. Facettes plates (low poly). Repère Godot : +Y en haut, objets
posés à y = 0, centrés en x / z.

cooler.glb   glacière rigide bleue à couvercle blanc, poignées sur les côtés.
  Body : caisse ouverte (parois bleues, intérieur blanc, glaçons au fond)
  Lid  : couvercle, pivot sur la charnière arrière (y = BODY_H, z = -D/2)
beer_can.glb canette 33 cl debout.
  Can  : corps (alu, bandeau vert et filet doré)
  Tab  : languette d'ouverture (pivot à son attache, pour la soulever)
  Hole : ouverture (cachée tant que la canette est fermée)
"""
import math, os, sys
import numpy as np
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "animals"))
sys.path.insert(0, os.path.join(HERE, ".."))
from animals_build import Model, box
from thermos_build import lathe

RNG = np.random.default_rng(5)

W, D, BODY_H, LID_H = 0.40, 0.27, 0.24, 0.045   # glacière
T = 0.022                                        # épaisseur des parois
CAN_R, CAN_H = 0.033, 0.122                      # canette


def cooler():
    m = Model("Cooler")
    blue = m.mat("Cooler_Blue", (0.10, 0.32, 0.72), 0.55)
    white = m.mat("Cooler_White", (0.93, 0.94, 0.95), 0.6)
    grey = m.mat("Cooler_Grey", (0.35, 0.37, 0.40), 0.6)
    ice = m.mat("Cooler_Ice", (0.78, 0.90, 0.97), 0.15)
    outer = (box((0, T / 2, 0), (W, T, D)) +
             box((0, BODY_H / 2, D / 2 - T / 2), (W, BODY_H, T)) +
             box((0, BODY_H / 2, -D / 2 + T / 2), (W, BODY_H, T)) +
             box((W / 2 - T / 2, BODY_H / 2, 0), (T, BODY_H, D - 2 * T)) +
             box((-W / 2 + T / 2, BODY_H / 2, 0), (T, BODY_H, D - 2 * T)))
    # intérieur blanc (fines plaques contre les parois) et rebord blanc
    iw, idp, ih = W - 2 * T, D - 2 * T, BODY_H - T
    liner = (box((0, T + 0.001, 0), (iw, 0.002, idp)) +
             box((0, T + ih / 2, idp / 2 - 0.001), (iw, ih, 0.002)) +
             box((0, T + ih / 2, -idp / 2 + 0.001), (iw, ih, 0.002)) +
             box((iw / 2 - 0.001, T + ih / 2, 0), (0.002, ih, idp)) +
             box((-iw / 2 + 0.001, T + ih / 2, 0), (0.002, ih, idp)))
    rim = (box((0, BODY_H - 0.004, D / 2 - T / 2), (W + 0.002, 0.008, T + 0.002)) +
           box((0, BODY_H - 0.004, -D / 2 + T / 2), (W + 0.002, 0.008, T + 0.002)) +
           box((W / 2 - T / 2, BODY_H - 0.004, 0), (T + 0.002, 0.008, D - 2 * T)) +
           box((-W / 2 + T / 2, BODY_H - 0.004, 0), (T + 0.002, 0.008, D - 2 * T)))
    # bande blanche sur la face avant, pieds et poignées
    band = box((0, BODY_H * 0.62, D / 2 + 0.001), (W * 0.82, 0.03, 0.002))
    feet = []
    for sx in (-1, 1):
        for sz in (-1, 1):
            feet += box((sx * (W / 2 - 0.03), -0.004, sz * (D / 2 - 0.03)), (0.04, 0.008, 0.04))
    handles = []
    for sx in (-1, 1):
        x = sx * (W / 2 + 0.012)
        handles += box((x, BODY_H - 0.035, 0), (0.012, 0.014, 0.12))
        handles += box((x - sx * 0.006, BODY_H - 0.035, 0.055), (0.012, 0.02, 0.012))
        handles += box((x - sx * 0.006, BODY_H - 0.035, -0.055), (0.012, 0.02, 0.012))
    plug = box((W / 2 - 0.05, 0.03, D / 2 + 0.004), (0.02, 0.02, 0.008))
    # glaçons au fond, entre les canettes
    cubes = []
    for k in range(26):
        x = RNG.uniform(-iw / 2 + 0.02, iw / 2 - 0.02)
        z = RNG.uniform(-idp / 2 + 0.02, idp / 2 - 0.02)
        s = RNG.uniform(0.018, 0.026)
        c = box((x, T + 0.006 + RNG.uniform(0, 0.012), z), (s, s * 0.8, s))
        cubes += [tuple(tuple(v) for v in t) for t in c]
    m.part("Body", (0, 0, 0), {blue: outer, white: liner + rim + band, grey: feet + handles + plug, ice: cubes})
    # couvercle : dessus bombé blanc, panneau bleu, joint gris dessous
    lid = (box((0, BODY_H + LID_H * 0.45, 0), (W + 0.008, LID_H * 0.9, D + 0.008)) +
           box((0, BODY_H + LID_H * 0.95, 0), (W - 0.03, LID_H * 0.12, D - 0.03)))
    panel = box((0, BODY_H + LID_H + 0.001, 0.01), (W * 0.6, 0.002, D * 0.45))
    seal = box((0, BODY_H + 0.002, 0), (W - 2 * T + 0.004, 0.004, D - 2 * T + 0.004))
    m.part("Lid", (0, BODY_H, -D / 2), {white: lid, blue: panel, grey: seal})
    return m


def beer_can():
    m = Model("BeerCan")
    alu = m.mat("Can_Alu", (0.78, 0.79, 0.81), 0.25)
    green = m.mat("Can_Green", (0.08, 0.42, 0.20), 0.4)
    gold = m.mat("Can_Gold", (0.86, 0.66, 0.22), 0.3)
    dark = m.mat("Can_Hole", (0.03, 0.03, 0.03), 0.8)
    r, h = CAN_R, CAN_H
    bottom = lathe([(0.0, 0.004), (r * 0.7, 0.0), (r, 0.008), (r, 0.03)], n=16)
    band = lathe([(r, 0.03), (r, 0.096)], n=16)
    ring = lathe([(r, 0.096), (r, 0.101)], n=16)
    top = lathe([(r, 0.101), (r, 0.108), (r * 0.82, h - 0.002), (r * 0.82, h), (0.0, h - 0.003)], n=16)
    m.part("Can", (0, 0, 0), {alu: bottom + top, green: band, gold: ring})
    # languette : posée sur le dessus, attache près du centre, anneau vers l'arrière (-Z)
    tab = box((0, h - 0.0015, -0.006), (0.012, 0.0015, 0.02)) + box((0, h - 0.0015, -0.016), (0.008, 0.0016, 0.006))
    m.part("Tab", (0, h - 0.002, 0.002), {alu: tab})
    hole = box((0, h - 0.0028, 0.012), (0.013, 0.0012, 0.01))
    m.part("Hole", (0, h - 0.003, 0.012), {dark: hole})
    return m


ALL = (("cooler", cooler), ("beer_can", beer_can))

if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else "."
    for name, fn in ALL:
        mdl = fn()
        mdl.save(os.path.join(out, name + ".glb"))
        print(name, len(mdl.parts), "pièces", sum(len(t) for p in mdl.parts for t in p[3].values()), "triangles")
