"""Briquet jetable low poly (type « Bic ») de Need for Pils.

Usage : python3 lighter_build.py <dossier de sortie>   (-> lighter.glb)

Réutilise les outils de modélisation de props/animals/animals_build.py.
Repère : briquet debout, axe long = +Y, base à y = 0, centré en x/z ; molette et
capot métallique en haut ; le bouton (gâchette) est côté +Z.
Nœuds : Body (corps plastique + capot + molette + bouton), Flame (flamme, cachée par
interaction/lighter.gd tant qu'on n'allume pas).
"""
import math, os, sys
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "animals"))
from animals_build import Model, loft, box

W, D, H = 0.025, 0.0145, 0.064   # largeur, épaisseur, hauteur du corps plastique


def lighter():
    m = Model("Lighter")
    plastic = m.mat("LighterPlastic", (0.80, 0.08, 0.10), 0.35)
    metal = m.mat("LighterMetal", (0.72, 0.73, 0.75), 0.3)
    dark = m.mat("LighterDark", (0.12, 0.12, 0.13), 0.6)
    flame_o = m.mat("FlameOuter", (1.0, 0.55, 0.12), 1.0)
    flame_i = m.mat("FlameInner", (0.35, 0.55, 1.0), 1.0)
    # corps : ovale aplati, légèrement plus large au milieu
    body = loft([(0, 0.0, 0), (0, 0.004, 0), (0, H * 0.5, 0), (0, H - 0.003, 0), (0, H, 0)],
                [(W * 0.9, D * 0.9), (W, D), (W * 1.03, D * 1.03), (W, D), (W * 0.96, D * 0.96)],
                n=12, up=(0, 0, 1))
    base = loft([(0, -0.0005, 0), (0, 0.0015, 0)], [(W * 0.88, D * 0.88)] * 2, n=12, up=(0, 0, 1))
    # capot métallique troué (pare-vent) + molette + bouton
    hood = (box((0, H + 0.006, 0), (W * 0.92, 0.012, D * 0.9)))
    wheel = loft([(-0.006, H + 0.012, -0.002), (0.006, H + 0.012, -0.002)], [(0.0095, 0.0095)] * 2, n=10)
    button = box((0, H + 0.004, 0.0055), (0.011, 0.007, 0.006))
    nozzle = box((0, H + 0.0125, 0.003), (0.004, 0.003, 0.004))
    m.part("Body", (0, 0, 0), {plastic: body, dark: base + button + nozzle, metal: hood + wheel})
    # flamme : goutte orange avec un cœur bleu
    fz = 0.003
    outer = loft([(0, H + 0.014, fz), (0, H + 0.019, fz), (0, H + 0.028, fz), (0, H + 0.040, fz)],
                 [(0.004, 0.004), (0.010, 0.010), (0.008, 0.008), (0.0005, 0.0005)], n=8)
    inner = loft([(0, H + 0.0142, fz), (0, H + 0.017, fz), (0, H + 0.021, fz)],
                 [(0.003, 0.003), (0.005, 0.005), (0.0005, 0.0005)], n=6)
    m.part("Flame", (0, H + 0.014, fz), {flame_o: outer, flame_i: inner})
    return m


ALL = (("lighter", lighter),)

if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else "."
    mdl = lighter()
    mdl.save(os.path.join(out, "lighter.glb"))
    print("lighter", len(mdl.parts), "pièces", sum(len(t) for p in mdl.parts for t in p[3].values()), "triangles")
