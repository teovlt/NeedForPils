"""Pistolet de Need for Pils (rangé dans la voiture, pour tirer sur les concurrents et la police).

Usage : python3 gun_build.py <dossier de sortie>   (-> pistol.glb)

Réutilise Model / box / loft de props/animals/animals_build.py. Facettes plates (low poly).
Repère Godot : canon vers -Z, +Y en haut ; origine au centre du poing sur la crosse
(là où la main le tient : interaction/weapons/gun.gd le place dans la main avec ce repère).

Nœuds :
  Body    : carcasse, crosse inclinée, pontet, chargeur, canon, guidon/hausse
  Slide   : culasse (recule à chaque tir)
  Trigger : détente, pivot en haut (tourne autour de X)
"""
import math, os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "animals"))
from animals_build import Model, box, loft

RAKE = math.radians(16)          # inclinaison de la crosse (bas vers l'arrière)
MUZZLE_Z = -0.165                # bout du canon


def rot_x(tris, ang, pivot):
    c, s = math.cos(ang), math.sin(ang)
    out = []
    for t in tris:
        nt = []
        for (x, y, z) in t:
            y0, z0 = y - pivot[1], z - pivot[2]
            nt.append((x, pivot[1] + y0 * c - z0 * s, pivot[2] + y0 * s + z0 * c))
        out.append(tuple(nt))
    return out


def pistol():
    m = Model("Pistol")
    steel = m.mat("Gun_Steel", (0.10, 0.10, 0.11), 0.45)
    poly = m.mat("Gun_Polymer", (0.16, 0.15, 0.14), 0.85)
    grip_tex = m.mat("Gun_Grip", (0.11, 0.10, 0.09), 0.95)
    worn = m.mat("Gun_Worn", (0.38, 0.38, 0.40), 0.35)
    # carcasse sous la culasse
    frame = box((0, 0.040, -0.072), (0.026, 0.020, 0.150))
    rail = box((0, 0.029, -0.120), (0.022, 0.006, 0.060))
    # crosse inclinée (bas vers l'arrière), plaquettes quadrillées et talon du chargeur
    grip = rot_x(box((0, -0.012, 0.010), (0.030, 0.105, 0.046)), -RAKE, (0, 0.03, 0.0))
    panels = rot_x(box((0.0158, -0.016, 0.010), (0.002, 0.080, 0.036)) + box((-0.0158, -0.016, 0.010), (0.002, 0.080, 0.036)), -RAKE, (0, 0.03, 0.0))
    magbase = rot_x(box((0, -0.068, 0.012), (0.032, 0.010, 0.050)), -RAKE, (0, 0.03, 0.0))
    backstrap = rot_x(box((0, 0.034, 0.030), (0.028, 0.014, 0.020)), -RAKE, (0, 0.03, 0.0))
    # pontet
    guard = box((0, 0.010, -0.050), (0.012, 0.005, 0.046))
    guard += box((0, 0.020, -0.073), (0.012, 0.024, 0.005))
    # canon qui dépasse de la culasse, guidon et hausse
    barrel = loft([(0, 0.062, -0.150), (0, 0.062, MUZZLE_Z)], [(0.013, 0.013), (0.013, 0.013)], n=8)
    bore = loft([(0, 0.062, MUZZLE_Z + 0.0005), (0, 0.062, MUZZLE_Z - 0.0002)], [(0.007, 0.007), (0.007, 0.007)], n=8)
    m.part("Body", (0, 0, 0), {poly: frame + rail + grip + backstrap + guard, grip_tex: panels,
                               steel: magbase + barrel, worn: bore})
    # culasse (recule le long de +Z)
    slide = box((0, 0.064, -0.058), (0.029, 0.030, 0.186))
    serr = []
    for k in range(5):
        z = 0.012 - k * 0.007
        for sx in (-1, 1):
            serr += box((sx * 0.0148, 0.066, z), (0.0015, 0.020, 0.0025))
    sights = box((0, 0.0815, -0.145), (0.004, 0.006, 0.006)) + box((0, 0.0815, 0.025), (0.016, 0.006, 0.008))
    port = box((0.0146, 0.068, -0.040), (0.0015, 0.012, 0.030))
    m.part("Slide", (0, 0.064, 0), {steel: slide + sights, worn: serr + port})
    # détente (pivot en haut)
    trig = rot_x(box((0, 0.020, -0.046), (0.006, 0.020, 0.006)), math.radians(12), (0, 0.030, -0.046))
    m.part("Trigger", (0, 0.030, -0.046), {steel: trig})
    return m


if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else "."
    mdl = pistol()
    mdl.save(os.path.join(out, "pistol.glb"))
    print("pistol", len(mdl.parts), "pièces", sum(len(t) for p in mdl.parts for t in p[3].values()), "triangles")
