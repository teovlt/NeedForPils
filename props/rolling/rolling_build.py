"""Matériel pour rouler de Need for Pils : grinder, tête de weed, pincée d'herbe moulue,
carnet de feuilles, boîte de filtres, feuille seule, filtre seul.

Usage : python3 rolling_build.py <dossier de sortie>
   -> grinder.glb, bud.glb, pinch.glb, papers.glb, filter_box.glb, sheet.glb, filter.glb

Réutilise Model / loft / box de props/animals/animals_build.py et le tour (lathe) de
props/thermos_build.py. Facettes plates (low poly). Repère Godot : +Y en haut, objets
posés à y = 0, centrés en x / z.

Nœuds (animés par les scripts de interaction/) :
  grinder.glb    Base (corps et chambre ouverte), Lid (couvercle, pivot au centre du
                 bord de la chambre, y = BASE_H)
  papers.glb     Body (couverture du dessous), Stack (pile de feuilles, pivot au fond :
                 on l'écrase en Y quand il en reste moins), Flap (rabat, pivot à la
                 charnière arrière)
  filter_box.glb Body (boîte ouverte), Lid (couvercle, pivot à la charnière arrière)
  filter.glb     filtre debout (axe Y, base à y = 0)
"""
import math, os, sys
import numpy as np
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "animals"))
sys.path.insert(0, os.path.join(HERE, ".."))
from animals_build import Model, loft, box
from thermos_build import lathe

RNG = np.random.default_rng(11)

GR_R = 0.03         # rayon du grinder
BASE_H = 0.028      # hauteur du corps (bord de la chambre)
LID_H = 0.018
CH_R = 0.025        # rayon de la chambre
CH_FLOOR = 0.006

SHEET = (0.07, 0.036)
FILTER_R = 0.0035
FILTER_L = 0.015


def rot_y(tris, a):
    c, s = math.cos(a), math.sin(a)
    return [tuple((v[0] * c + v[2] * s, v[1], -v[0] * s + v[2] * c) for v in t) for t in tris]


def ridges(r, y0, y1, n=16):
    """Moletage : barrettes verticales autour du cylindre."""
    out = []
    for k in range(n):
        out += rot_y(box((r, (y0 + y1) / 2, 0), (0.003, y1 - y0, 0.0035)), 2 * math.pi * k / n)
    return out


def grinder():
    m = Model("Grinder")
    body = m.mat("Grinder_Body", (0.16, 0.17, 0.19), 0.35)
    lid = m.mat("Grinder_Lid", (0.42, 0.16, 0.55), 0.3)
    steel = m.mat("Grinder_Teeth", (0.7, 0.71, 0.73), 0.3)
    leaf = m.mat("Grinder_Logo", (0.35, 0.75, 0.25), 0.5)
    base = lathe([(0.0, 0.0), (GR_R - 0.001, 0.0), (GR_R, 0.002), (GR_R, BASE_H), (CH_R, BASE_H),
                  (CH_R, CH_FLOOR), (0.0, CH_FLOOR)], n=20)
    teeth = []
    for k in range(10):
        teeth += rot_y(box((0.016, CH_FLOOR + 0.004, 0), (0.003, 0.008, 0.003)), 2 * math.pi * k / 10)
    m.part("Base", (0, 0, 0), {body: base + ridges(GR_R, 0.004, BASE_H - 0.003), steel: teeth})
    y0, y1 = BASE_H, BASE_H + LID_H
    cap = lathe([(0.0, y0), (GR_R + 0.0005, y0), (GR_R + 0.001, y0 + 0.002), (GR_R + 0.001, y1 - 0.002),
                 (GR_R - 0.001, y1), (0.0, y1)], n=20)
    pins = []
    for k in range(8):
        pins += rot_y(box((0.021, y0 - 0.004, 0), (0.003, 0.008, 0.003)), 2 * math.pi * (k + 0.5) / 8)
    # logo : feuille stylisée (trois pétales) sur le dessus
    logo = []
    for k in range(5):
        logo += rot_y(box((0.0, y1 + 0.0004, 0.006), (0.004, 0.0008, 0.012)), 2 * math.pi * k / 5 - math.pi * 0.4)
    m.part("Lid", (0, BASE_H, 0), {lid: cap + ridges(GR_R + 0.001, y0 + 0.003, y1 - 0.003), steel: pins, leaf: logo})
    return m


def bud():
    m = Model("Bud")
    green = m.mat("Bud_Green", (0.30, 0.48, 0.18), 0.85)
    light = m.mat("Bud_Leaf", (0.52, 0.66, 0.30), 0.8)
    hair = m.mat("Bud_Hair", (0.86, 0.46, 0.14), 0.8)
    core = loft([(0, 0.0, 0), (0, 0.005, 0), (0, 0.011, 0), (0, 0.017, 0), (0, 0.022, 0)],
                [(0.008, 0.008), (0.016, 0.015), (0.015, 0.014), (0.010, 0.010), (0.003, 0.003)],
                n=7, up=(0, 0, 1), noise=0.28)
    leaves, hairs = [], []
    for k in range(4):
        a = 2 * math.pi * k / 4 + 0.4
        leaves += rot_y(box((0.007, 0.008 + 0.003 * k, 0), (0.007, 0.0012, 0.003)), a)
    for k in range(9):
        a = RNG.uniform(0, 2 * math.pi)
        y = RNG.uniform(0.004, 0.019)
        r = 0.0075 - abs(y - 0.011) * 0.25
        hairs += rot_y(box((r, y, 0), (0.0035, 0.0008, 0.0008)), a)
    m.part("Bud", (0, 0, 0), {green: core, light: leaves, hair: hairs})
    return m


def pinch():
    m = Model("Pinch")
    herb = m.mat("Herb_Ground", (0.36, 0.42, 0.19), 0.9)
    dark = m.mat("Herb_Dark", (0.24, 0.30, 0.13), 0.9)
    heap = lathe([(0.0, 0.0), (0.009, 0.0), (0.0065, 0.0028), (0.003, 0.0052), (0.0, 0.006)], n=9)
    bits = []
    for k in range(7):
        a = RNG.uniform(0, 2 * math.pi)
        bits += rot_y(box((RNG.uniform(0.002, 0.007), 0.0028 + RNG.uniform(0, 0.002), 0), (0.002, 0.0015, 0.0015)), a)
    m.part("Pinch", (0, 0, 0), {herb: heap, dark: bits})
    return m


def sheet():
    m = Model("Sheet")
    paper = m.mat("Paper", (0.97, 0.96, 0.92), 0.9)
    gum = m.mat("Paper_Gum", (0.90, 0.86, 0.66), 0.7)
    w, d = SHEET
    m.part("Sheet", (0, 0, 0), {paper: box((0, 0.0002, -0.0015), (w, 0.0004, d - 0.003)),
                                gum: box((0, 0.0002, d / 2 - 0.0015), (w, 0.00045, 0.003))})
    return m


def filt():
    m = Model("Filter")
    card = m.mat("Filter_Card", (0.94, 0.91, 0.82), 0.85)
    edge = m.mat("Filter_Edge", (0.80, 0.74, 0.60), 0.85)
    body = lathe([(FILTER_R, 0.0005), (FILTER_R, FILTER_L - 0.0005)], n=8)
    ends = lathe([(0.0, 0.0), (FILTER_R, 0.0), (FILTER_R, 0.0005)], n=8) + \
        lathe([(FILTER_R, FILTER_L - 0.0005), (FILTER_R, FILTER_L), (0.0, FILTER_L)], n=8)
    m.part("Filter", (0, 0, 0), {card: body, edge: ends})
    return m


def papers():
    m = Model("Papers")
    cover = m.mat("Papers_Cover", (0.52, 0.34, 0.18), 0.8)
    inner = m.mat("Papers_Inner", (0.88, 0.82, 0.70), 0.8)
    paper = m.mat("Paper", (0.97, 0.96, 0.92), 0.9)
    w, d = SHEET[0] + 0.004, SHEET[1] + 0.002
    t = 0.0008
    body = box((0, t / 2, 0), (w, t, d))                         # dessous
    fold = box((0, 0.003, -d / 2 + t / 2), (w, 0.006, t))       # dos (pli)
    pocket = box((0, t + 0.0005, d / 2 - 0.006), (w, 0.0006, 0.012))   # languette avant
    m.part("Body", (0, 0, 0), {cover: body + fold, inner: pocket})
    m.part("Stack", (0, t, 0), {paper: box((0, t + 0.00225, 0.0005), (SHEET[0], 0.0045, SHEET[1]))})
    m.part("Flap", (0, 0.006, -d / 2), {cover: box((0, 0.006 + t / 2, -d / 2 + d / 2), (w, t, d))})
    return m


def filter_box():
    m = Model("FilterBox")
    card = m.mat("FilterBox_Card", (0.10, 0.10, 0.11), 0.8)
    white = m.mat("FilterBox_White", (0.92, 0.92, 0.9), 0.8)
    W, H, D = 0.05, 0.018, 0.03
    t = 0.001
    walls = box((0, t / 2, 0), (W, t, D)) + box((0, H / 2, D / 2 - t / 2), (W, H, t)) + \
        box((0, H / 2, -D / 2 + t / 2), (W, H, t)) + box((W / 2 - t / 2, H / 2, 0), (t, H, D - 2 * t)) + \
        box((-W / 2 + t / 2, H / 2, 0), (t, H, D - 2 * t))
    band = box((0, H * 0.45, D / 2 + 0.0002), (W + 0.0004, 0.006, 0.0004))
    m.part("Body", (0, 0, 0), {card: walls, white: band})
    lid = box((0, H + t / 2, -D / 2 + D / 2), (W + 0.001, t, D + 0.001))
    lip = box((0, H - 0.003, D / 2 + 0.0006), (W + 0.001, 0.006, t))
    m.part("Lid", (0, H, -D / 2), {card: lid + lip})
    return m


ALL = (("grinder", grinder), ("bud", bud), ("pinch", pinch), ("sheet", sheet), ("filter", filt),
       ("papers", papers), ("filter_box", filter_box))

if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else "."
    for name, fn in ALL:
        mdl = fn()
        mdl.save(os.path.join(out, name + ".glb"))
        print(name, len(mdl.parts), "pièces", sum(len(t) for p in mdl.parts for t in p[3].values()), "triangles")
