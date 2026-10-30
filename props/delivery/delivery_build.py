"""Points de livraison de Need for Pils : boîte aux lettres sur poteau et carton ouvert.

Usage : python3 delivery_build.py <dossier de sortie>   (-> mailbox.glb, carton.glb)

Réutilise Model / box de props/animals/animals_build.py. Facettes plates (low poly).
Repère Godot : +Y en haut, posé à y = 0.

mailbox.glb (boîte de campagne en tôle, toit arrondi, sur un poteau de bois ; la porte
regarde vers +Z) :
  Post : poteau et planchette
  Box  : caisson en tôle (ouvert devant, intérieur visible quand la porte s'ouvre)
  Door : porte, pivot sur l'arête du bas (y = BOX_Y, z = L/2) ; s'ouvre en tournant
         de +90° autour de X (elle bascule vers l'avant)
  Flag : drapeau rouge, pivot sur le côté +X ; baissé (bras vers -Z), levé à +90° autour de X
carton.glb (carton de déménagement ouvert, rabats écartés) :
  Carton : parois, fond, rabats, ruban adhésif
"""
import math, os, sys
import numpy as np
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "animals"))
from animals_build import Model, loft, box as _loft_box


def box(center, size):
    """Pavé aux dimensions demandées. (box() d'animals_build fait une section carrée
    tournée de 45° : ses pavés ne mesuraient que 71 % de la largeur et de la hauteur
    voulues ; le poteau de la boîte aux lettres flottait au-dessus du sol et les
    pièces ne se touchaient plus.)"""
    k = math.sqrt(2.0)
    return _loft_box(center, (size[0] * k, size[1] * k, size[2]))


def beam(a, b, w):
    """Poutre de section carrée w × w entre les points a et b (pièce en biais)."""
    k = math.sqrt(2.0)
    return loft([a, b], [(w * k, w * k)] * 2, n=4, rot=math.pi / 4)

# ---------------------------------------------------------------- outils

def tri(a, b, c):
    return tuple(tuple(float(v) for v in p) for p in (a, b, c))


def quad(a, b, c, d, both=False):
    """Quadrilatère a b c d (sens trigonométrique vu de la face avant)."""
    out = [tri(a, b, c), tri(a, c, d)]
    if both:
        out += [tri(a, c, b), tri(a, d, c)]
    return out


def tunnel_profile(w, h_wall, n_arc=7):
    """Section de la boîte aux lettres (x, y) : fond plat, parois droites, toit en demi-cercle."""
    r = w / 2
    pts = [(-r, 0.0), (r, 0.0), (r, h_wall)]
    for k in range(1, n_arc):
        a = math.pi * k / n_arc
        pts.append((r * math.cos(a), h_wall + r * math.sin(a)))
    pts.append((-r, h_wall))
    return pts


def extrude(profile, z0, z1, y0=0.0, outward=True, inset=0.0):
    """Paroi extrudée le long de Z (contour fermé). inset > 0 : paroi intérieure."""
    out = []
    n = len(profile)
    cx = sum(p[0] for p in profile) / n
    cy = sum(p[1] for p in profile) / n
    pts = []
    for x, y in profile:
        dx, dy = x - cx, y - cy
        ln = math.hypot(dx, dy) or 1.0
        pts.append((x - dx / ln * inset, y - dy / ln * inset + y0))
    for k in range(n):
        (xa, ya), (xb, yb) = pts[k], pts[(k + 1) % n]
        a, b = np.array((xa, ya, z0)), np.array((xb, yb, z0))
        c, d = np.array((xb, yb, z1)), np.array((xa, ya, z1))
        t = [tri(a, b, c), tri(a, c, d)]
        nrm = np.cross(b - a, c - a)
        mid = (a + b + c) / 3
        inside = np.array((cx, cy + y0, mid[2]))
        if (np.dot(nrm, mid - inside) > 0) != outward:
            t = [tri(a, c, b), tri(a, d, c)]
        out += t
    return out


def plate(profile, z, y0=0.0, front=True, scale=1.0):
    """Face plane (éventail) à la cote z ; front = normale vers +Z."""
    n = len(profile)
    c = np.array((sum(p[0] for p in profile) / n * scale, sum(p[1] for p in profile) / n * scale + y0, z))
    out = []
    for k in range(n):
        a = np.array((profile[k][0] * scale, profile[k][1] * scale + y0, z))
        b = np.array((profile[(k + 1) % n][0] * scale, profile[(k + 1) % n][1] * scale + y0, z))
        t = (c, a, b)
        if (np.cross(a - c, b - c)[2] > 0) != front:
            t = (c, b, a)
        out.append(tri(*t))
    return out

# ---------------------------------------------------------------- boîte aux lettres

POST_H = 1.10
POST_BURY = 0.30
BOX_Y = 1.135                  # dessous du caisson
BOX_W, BOX_WALL_H, BOX_L = 0.19, 0.12, 0.46


def mailbox():
    m = Model("Mailbox")
    wood = m.mat("Mailbox_Wood", (0.36, 0.26, 0.16), 0.95)
    metal = m.mat("Mailbox_Metal", (0.36, 0.42, 0.44), 0.55)
    inside = m.mat("Mailbox_Inside", (0.16, 0.17, 0.17), 0.8)
    rust = m.mat("Mailbox_Rust", (0.45, 0.24, 0.12), 0.9)
    red = m.mat("Mailbox_Red", (0.78, 0.10, 0.08), 0.6)
    dark = m.mat("Mailbox_Dark", (0.08, 0.08, 0.08), 0.5)
    # poteau enfoncé de POST_BURY dans le sol : ne flotte pas au bord d'une pente
    post = box((0, (POST_H - POST_BURY) / 2, -0.06), (0.09, POST_H + POST_BURY, 0.09))
    post += box((0, POST_H + 0.0175, 0.0), (0.15, 0.035, 0.36))          # planchette
    # jambe de force : en biais, de l'avant du poteau au-dessous de la planchette
    post += beam((0, POST_H - 0.17, -0.03), (0, POST_H - 0.01, 0.13), 0.04)
    m.part("Post", (0, 0, 0), {wood: post})
    prof = tunnel_profile(BOX_W, BOX_WALL_H)
    z0, z1 = -BOX_L / 2, BOX_L / 2
    shell = extrude(prof, z0, z1, BOX_Y, outward=True)
    shell_in = extrude(prof, z0 + 0.006, z1, BOX_Y, outward=False, inset=0.006)
    back = plate(prof, z0, BOX_Y, front=False)
    back_in = plate(prof, z0 + 0.006, BOX_Y, front=True, scale=0.94)
    # lèvre de l'ouverture (tranche de la tôle à l'avant)
    lip = []
    n = len(prof)
    for k in range(n):
        (xa, ya), (xb, yb) = prof[k], prof[(k + 1) % n]
        a = np.array((xa, ya + BOX_Y, z1)); b = np.array((xb, yb + BOX_Y, z1))
        ca = np.array((xa * 0.94, ya * 0.94 + BOX_Y + 0.003, z1)); cb = np.array((xb * 0.94, yb * 0.94 + BOX_Y + 0.003, z1))
        lip += [tri(a, b, cb), tri(a, cb, ca)]
    rust_patch = box((BOX_W / 2 + 0.001, BOX_Y + 0.03, -0.12), (0.002, 0.04, 0.09))
    rust_patch += box((-BOX_W / 2 - 0.001, BOX_Y + 0.07, 0.10), (0.002, 0.05, 0.06))
    m.part("Box", (0, BOX_Y, 0), {metal: shell + back + lip, inside: shell_in + back_in, rust: rust_patch})
    # porte (pivot sur l'arête du bas, à l'avant)
    door_prof = [(x * 1.02, y * 1.02) for x, y in prof]
    door = plate(door_prof, z1 + 0.012, BOX_Y, front=True) + plate(door_prof, z1 + 0.002, BOX_Y, front=False)
    door += extrude(door_prof, z1 + 0.002, z1 + 0.012, BOX_Y, outward=True)
    handle = box((0, BOX_Y + BOX_WALL_H + 0.05, z1 + 0.02), (0.05, 0.012, 0.016))
    m.part("Door", (0, BOX_Y, z1 + 0.002), {metal: door, dark: handle})
    # drapeau (baissé : bras vers l'arrière)
    fx = BOX_W / 2 + 0.012
    py, pz = BOX_Y + 0.06, 0.02          # pivot (coordonnées absolues, comme le reste)
    flag = box((fx, py, pz - 0.08), (0.008, 0.022, 0.16))
    flag += box((fx, py + 0.035, pz - 0.17), (0.008, 0.09, 0.06))
    pin = box((fx - 0.006, py, pz), (0.006, 0.02, 0.02))
    m.part("Flag", (0, py, pz), {red: flag, dark: pin})
    return m

# ---------------------------------------------------------------- carton

CW, CH, CD = 0.50, 0.34, 0.40


def carton():
    m = Model("Carton")
    card = m.mat("Carton_Card", (0.62, 0.46, 0.29), 0.95)
    card_in = m.mat("Carton_Inside", (0.50, 0.37, 0.23), 0.95)
    tape = m.mat("Carton_Tape", (0.72, 0.58, 0.36), 0.5)
    w, d, h = CW / 2, CD / 2, CH
    # parois (double face : on voit l'intérieur) et fond
    P = lambda x, y, z: np.array((x, y, z))
    walls = []
    walls += quad(P(-w, 0, d), P(w, 0, d), P(w, h, d), P(-w, h, d))       # avant (+Z)
    walls += quad(P(w, 0, -d), P(-w, 0, -d), P(-w, h, -d), P(w, h, -d))   # arrière
    walls += quad(P(w, 0, d), P(w, 0, -d), P(w, h, -d), P(w, h, d))       # droite (+X)
    walls += quad(P(-w, 0, -d), P(-w, 0, d), P(-w, h, d), P(-w, h, -d))   # gauche
    walls += quad(P(-w, 0, -d), P(w, 0, -d), P(w, 0, d), P(-w, 0, d))     # dessous
    e = 0.006
    inner = []
    inner += quad(P(-w + e, e, d - e), P(-w + e, h, d - e), P(w - e, h, d - e), P(w - e, e, d - e))
    inner += quad(P(w - e, e, -d + e), P(w - e, h, -d + e), P(-w + e, h, -d + e), P(-w + e, e, -d + e))
    inner += quad(P(w - e, e, d - e), P(w - e, h, d - e), P(w - e, h, -d + e), P(w - e, e, -d + e))
    inner += quad(P(-w + e, e, -d + e), P(-w + e, h, -d + e), P(-w + e, h, d - e), P(-w + e, e, d - e))
    inner += quad(P(-w + e, e, d - e), P(w - e, e, d - e), P(w - e, e, -d + e), P(-w + e, e, -d + e))
    rim = []
    for (a, b) in (((-w, d), (w, d)), ((w, d), (w, -d)), ((w, -d), (-w, -d)), ((-w, -d), (-w, d))):
        ax, az = a; bx, bz = b
        ia = (ax - math.copysign(e, ax), az - math.copysign(e, az))
        ib = (bx - math.copysign(e, bx), bz - math.copysign(e, bz))
        rim += quad(P(ax, h, az), P(bx, h, bz), P(ib[0], h, ib[1]), P(ia[0], h, ia[1]), both=True)
    # rabats écartés : (arête, longueur, profondeur, inclinaison vers l'extérieur en degrés)
    flaps_out, flaps_in = [], []
    fd = CD / 2 - 0.01
    for edge, tilt in (("front", 38), ("back", 22), ("right", 55), ("left", 30)):
        if edge in ("front", "back"):
            s = 1 if edge == "front" else -1
            a, b = P(-w, h, s * d), P(w, h, s * d)
            out_dir = np.array((0, 0, s))
        else:
            s = 1 if edge == "right" else -1
            a, b = P(s * w, h, -d), P(s * w, h, d)
            out_dir = np.array((s, 0, 0))
        t = math.radians(tilt)
        v = np.array((0, math.cos(t), 0)) + out_dir * math.sin(t)
        c, dd = b + v * fd, a + v * fd
        q = quad(a, b, c, dd)
        # face extérieure = côté out_dir
        nrm = np.cross(np.array(q[0][1]) - np.array(q[0][0]), np.array(q[0][2]) - np.array(q[0][0]))
        if np.dot(nrm, out_dir) < 0:
            q = quad(a, dd, c, b)
        flaps_out += q
        flaps_in += [(t3[0], t3[2], t3[1]) for t3 in q]
    # ruban adhésif sur les côtés (restes du scotch arraché)
    tp = box((0, h - 0.06, d + 0.002), (0.05, 0.12, 0.002)) + box((0, h - 0.06, -d - 0.002), (0.05, 0.12, 0.002))
    tp += box((w * 0.55, 0.002 + 0.0005, d - 0.12), (0.06, 0.001, 0.05))
    m.part("Carton", (0, 0, 0), {card: walls + flaps_out + rim, card_in: inner + flaps_in, tape: tp})
    return m


if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else "."
    for mdl, name in ((mailbox(), "mailbox.glb"), (carton(), "carton.glb")):
        mdl.save(os.path.join(out, name))
        print(name, len(mdl.parts), "pièces", sum(len(t) for p in mdl.parts for t in p[3].values()), "triangles")
