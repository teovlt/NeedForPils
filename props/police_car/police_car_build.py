"""Voiture de police low poly de Need for Pils (remplace la Doge, trop lourde).

Usage : python3 police_car_build.py <dossier de sortie>   (-> police_car.glb)

Réutilise les outils de modélisation de props/animals/animals_build.py (troncs lissés,
facettes plates). Berline blanche à bande bleue (style police française), vitres
sombres, pare-chocs et bas de caisse noirs, phares et feux, rétroviseurs.
La rampe de gyrophares et les inscriptions « POLICE » sont ajoutées par
world/chase/pursuer.gd (lumières animées).

Repère Godot : +Z = avant, +Y = haut, roues posées à y = 0. Nœuds : Body (caisse),
Wheel_FL / Wheel_FR / Wheel_BL / Wheel_BR (pivot au centre de la roue, pour les faire
tourner autour de X).
"""
import math, os, sys
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "animals"))
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from animals_build import Model, loft, box, split

WHEEL_R = 0.34
WHEEL_W = 0.24
AXLE_Z = (1.36, -1.38)
TRACK_X = 0.79


def police_car():
    m = Model("PoliceCar")
    white = m.mat("Paint", (0.93, 0.94, 0.95), 0.45)
    blue = m.mat("PoliceBlue", (0.08, 0.22, 0.62), 0.5)
    black = m.mat("Trim", (0.06, 0.06, 0.07), 0.8)
    glass = m.mat("Glass", (0.08, 0.11, 0.15), 0.15)
    head = m.mat("Headlight", (0.97, 0.96, 0.88), 0.2)
    tail = m.mat("Taillight", (0.75, 0.05, 0.05), 0.3)
    orange = m.mat("Indicator", (0.95, 0.5, 0.05), 0.3)
    tire = m.mat("Tire", (0.05, 0.05, 0.05), 0.95)
    rim = m.mat("Rim", (0.62, 0.64, 0.66), 0.4)

    # caisse basse : octogone allongé (arêtes chanfreinées)
    low = loft([(0, 0.60, -2.27), (0, 0.62, -2.18), (0, 0.63, -1.9), (0, 0.63, 1.75), (0, 0.61, 2.12), (0, 0.58, 2.27)],
               [(1.64, 0.56), (1.76, 0.70), (1.80, 0.76), (1.80, 0.76), (1.76, 0.68), (1.62, 0.50)],
               n=8, rot=math.pi / 8)
    # capot et coffre légèrement bombés au-dessus de la caisse
    band, rest = split(low, lambda nr, c: abs(nr[0]) > 0.6 and 0.6 < c[1] < 0.8)
    skirt, rest = split(rest, lambda nr, c: c[1] < 0.40)
    # habitacle : vitres sur les côtés, l'avant et l'arrière, toit blanc
    cab = loft([(0, 0.98, -1.45), (0, 1.20, -1.05), (0, 1.27, -0.55), (0, 1.27, 0.35), (0, 1.20, 0.72), (0, 0.98, 1.12)],
               [(1.60, 0.06), (1.46, 0.42), (1.40, 0.50), (1.40, 0.50), (1.46, 0.40), (1.60, 0.06)],
               n=8, rot=math.pi / 8)
    roof, win = split(cab, lambda nr, c: nr[1] > 0.8)
    # montants : une bande de peinture au milieu des vitres latérales
    pillars = box((0.705, 1.22, -0.15), (0.02, 0.34, 0.09)) + box((-0.705, 1.22, -0.15), (0.02, 0.34, 0.09))
    # pare-chocs, calandre, plaques, rétros, phares, feux
    bump = (box((0, 0.42, 2.28), (1.70, 0.16, 0.12)) + box((0, 0.42, -2.29), (1.70, 0.16, 0.12)) +
            box((0, 0.62, 2.285), (0.70, 0.12, 0.04)))
    plates = box((0, 0.42, 2.345), (0.46, 0.10, 0.01)) + box((0, 0.58, -2.30), (0.46, 0.10, 0.01))
    mirrors = (box((0.86, 1.07, 0.62), (0.16, 0.09, 0.12)) + box((-0.86, 1.07, 0.62), (0.16, 0.09, 0.12)))
    lights = {head: box((0.6, 0.66, 2.255), (0.34, 0.12, 0.05)) + box((-0.6, 0.66, 2.255), (0.34, 0.12, 0.05)),
              tail: box((0.62, 0.72, -2.255), (0.32, 0.12, 0.05)) + box((-0.62, 0.72, -2.255), (0.32, 0.12, 0.05)),
              orange: box((0.86, 0.66, 2.1), (0.04, 0.06, 0.14)) + box((-0.86, 0.66, 2.1), (0.04, 0.06, 0.14))}
    geo = {white: rest + roof + pillars + mirrors, blue: band, black: skirt + bump, glass: win,
           head: lights[head], tail: lights[tail], orange: lights[orange]}
    geo[white] += plates
    m.part("Body", (0, 0, 0), geo)
    # roues (pneu à 12 pans + jante + moyeu), pivot au centre
    for z, zn in ((AXLE_Z[0], "F"), (AXLE_Z[1], "B")):
        for s, sn in ((1, "L"), (-1, "R")):
            c = (TRACK_X * s, WHEEL_R, z)
            ty = loft([(c[0] - WHEEL_W / 2, c[1], c[2]), (c[0] + WHEEL_W / 2, c[1], c[2])],
                      [(WHEEL_R * 2, WHEEL_R * 2)] * 2, n=12, up=(0, 1, 0))
            x_out = c[0] + s * (WHEEL_W / 2 + 0.005)
            rm = loft([(x_out - s * 0.01, c[1], c[2]), (x_out, c[1], c[2])], [(WHEEL_R * 1.25, WHEEL_R * 1.25)] * 2,
                      n=8, up=(0, 1, 0))
            hub = loft([(x_out, c[1], c[2]), (x_out + s * 0.02, c[1], c[2])], [(0.1, 0.1)] * 2, n=6, up=(0, 1, 0))
            m.part("Wheel_" + zn + sn, c, {tire: ty, rim: rm + hub})
    return m


ALL = (("police_car", police_car),)

if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else "."
    mdl = police_car()
    mdl.save(os.path.join(out, "police_car.glb"))
    print("police_car", len(mdl.parts), "pièces", sum(len(t) for p in mdl.parts for t in p[3].values()), "triangles")
