"""Cris des animaux de Need for Pils, synthétisés (pas d'enregistrement).

Usage : python3 animals_synth.py <dossier de sortie>
WAV mono 16 bits 22 050 Hz :
  sheep_1..3       bêlements (vibrato rapide, voyelle « ê »), sheep_3 = agneau, plus aigu
  deer_bark_1..2   aboiement d'alarme de la biche (bref, rauque)
  deer_call        petit appel nasal (biche qui appelle son faon)
  boar_grunt_1..3  grognements du sanglier (impulsions graves)
  boar_squeal      cri aigu du sanglier (choc)
  rabbit_thump     coup de patte au sol (alarme du lapin)
  rabbit_squeal    cri du lapin (choc)
  impact           choc sourd d'un animal contre la voiture
"""
import sys
import numpy as np
from scipy.signal import butter, sosfilt
from scipy.io import wavfile

SR = 22050
rng = np.random.default_rng(7)


def t_of(d):
    return np.arange(int(SR * d)) / SR


def env(n, a, r, hold=None):
    """Enveloppe attaque / maintien / relâche (en secondes)."""
    e = np.ones(n)
    na, nr = int(a * SR), int(r * SR)
    na = max(1, min(na, n)); nr = max(1, min(nr, n - na))
    e[:na] = np.linspace(0, 1, na) ** 1.5
    e[n - nr:] *= np.linspace(1, 0, nr) ** 2
    return e


def bp(x, lo, hi, order=2):
    return sosfilt(butter(order, [lo, hi], btype="band", fs=SR, output="sos"), x)


def lp(x, f, order=2):
    return sosfilt(butter(order, f, btype="low", fs=SR, output="sos"), x)


def hp(x, f, order=2):
    return sosfilt(butter(order, f, btype="high", fs=SR, output="sos"), x)


def glottal(f0, n, jitter=0.0):
    """Source vocale : dents de scie à fréquence variable f0[n] (+ gigue)."""
    f = f0 * (1 + jitter * rng.standard_normal(n).cumsum() / np.sqrt(np.arange(1, n + 1)))
    ph = np.cumsum(f / SR) % 1.0
    return 2 * ph - 1


def formants(src, fmts):
    """Filtre la source par des formants (fréquence, largeur, gain)."""
    out = np.zeros_like(src)
    for f, w, g in fmts:
        out += g * bp(src, max(40, f - w / 2), min(SR / 2 - 100, f + w / 2))
    return out


def norm(x, peak=0.85):
    return x / (np.max(np.abs(x)) + 1e-9) * peak


def bleat(f0=330, d=0.9, trem=7.5, seed=0):
    r = np.random.default_rng(seed)
    t = t_of(d); n = len(t)
    # hauteur : petite montée puis descente ; tremblement caractéristique (« bê-ê-ê »)
    contour = f0 * (1 + 0.06 * np.sin(np.pi * t / d) - 0.08 * t / d)
    vib = 1 + 0.035 * np.sin(2 * np.pi * trem * t + r.uniform(0, 6))
    src = glottal(contour * vib, n, 0.002)
    v = formants(src, [(700, 260, 1.0), (1800, 400, 0.55), (2700, 500, 0.25)])
    am = 0.65 + 0.35 * np.sin(2 * np.pi * trem * t) ** 2      # « bêêê » tremblé
    breath = bp(r.standard_normal(n), 2000, 4000) * 0.02
    return norm(lp(lp(v * am, 2800, 4) + breath, 4500) * env(n, 0.06, 0.25))


def deer_bark(d=0.32, seed=0):
    r = np.random.default_rng(seed)
    t = t_of(d); n = len(t)
    f0 = 520 * np.exp(-t * 3.5) + 230
    src = glottal(f0, n, 0.01)
    rough = 1 + 0.5 * np.sign(np.sin(2 * np.pi * 55 * t))     # voix rauque
    v = formants(src * rough, [(600, 300, 1.0), (1300, 500, 0.6), (2400, 800, 0.3)])
    noise = bp(r.standard_normal(n), 400, 2500) * 0.6
    x = (v + noise) * env(n, 0.012, 0.18)
    return norm(x)


def deer_call(d=0.6):
    t = t_of(d); n = len(t)
    f0 = 700 + 120 * np.sin(np.pi * t / d)
    src = glottal(f0, n, 0.003)
    v = formants(src, [(900, 300, 1.0), (2100, 500, 0.5), (3200, 700, 0.2)])
    nasal = bp(src, 250, 350) * 0.4
    return norm((v + nasal) * env(n, 0.05, 0.2))


def boar_grunt(d=0.5, rate=32, seed=0):
    r = np.random.default_rng(seed)
    t = t_of(d); n = len(t)
    # train d'impulsions grave (glotte qui claque) + souffle filtré
    f = rate * (1 + 0.15 * np.sin(2 * np.pi * 1.5 * t + r.uniform(0, 6)))
    ph = np.cumsum(f / SR) % 1.0
    pulses = np.exp(-ph * 18)
    src = pulses * (0.7 + 0.3 * r.standard_normal(n))
    v = formants(src, [(250, 180, 1.0), (520, 260, 0.7), (1100, 500, 0.25)])
    snort = bp(r.standard_normal(n), 300, 1600) * 0.25 * np.exp(-t * 6)
    return norm((v + snort) * env(n, 0.03, 0.15))


def boar_squeal(d=0.7):
    t = t_of(d); n = len(t)
    f0 = 900 + 500 * np.sin(np.pi * t / d) + 60 * np.sin(2 * np.pi * 11 * t)
    src = glottal(f0, n, 0.01)
    v = formants(src, [(1500, 600, 1.0), (2800, 900, 0.6), (4200, 1000, 0.3)])
    grit = bp(rng.standard_normal(n), 1000, 5000) * 0.35
    return norm((v + grit) * env(n, 0.02, 0.25))


def rabbit_thump():
    d = 0.5; t = t_of(d); n = len(t)
    x = np.zeros(n)
    for t0, a in ((0.0, 1.0), (0.17, 0.7)):        # deux coups de patte
        k = int(t0 * SR); m = n - k
        tt = t[:m]
        x[k:] += a * (np.sin(2 * np.pi * (95 * np.exp(-tt * 12) + 55) * tt) * np.exp(-tt * 28)
                      + 0.3 * lp(rng.standard_normal(m), 600) * np.exp(-tt * 45))
    return norm(x, 0.8)


def rabbit_squeal(d=0.45):
    t = t_of(d); n = len(t)
    f0 = 1900 + 600 * np.sin(np.pi * t / d)
    src = glottal(f0, n, 0.02)
    v = formants(src, [(2400, 800, 1.0), (4200, 1200, 0.5)])
    return norm(v * env(n, 0.01, 0.2), 0.7)


def impact():
    d = 0.6; t = t_of(d); n = len(t)
    thud = np.sin(2 * np.pi * (70 * np.exp(-t * 8) + 45) * t) * np.exp(-t * 9)
    body = lp(rng.standard_normal(n), 900) * np.exp(-t * 14) * 0.8
    rattle = bp(rng.standard_normal(n), 1500, 5000) * np.exp(-t * 20) * 0.25
    return norm(thud + body + rattle, 0.9)


def save(path, x):
    wavfile.write(path, SR, (np.clip(x, -1, 1) * 32000).astype(np.int16))


if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else "."
    sounds = {
        "sheep_1": bleat(320, 0.95, 7.5, 1), "sheep_2": bleat(270, 1.1, 6.5, 2), "sheep_3": bleat(470, 0.7, 9.0, 3),
        "deer_bark_1": deer_bark(0.32, 1), "deer_bark_2": deer_bark(0.26, 2), "deer_call": deer_call(),
        "boar_grunt_1": boar_grunt(0.45, 30, 1), "boar_grunt_2": boar_grunt(0.7, 26, 2), "boar_grunt_3": boar_grunt(0.3, 38, 3),
        "boar_squeal": boar_squeal(), "rabbit_thump": rabbit_thump(), "rabbit_squeal": rabbit_squeal(),
        "impact": impact(),
    }
    for k, v in sounds.items():
        save(f"{out}/{k}.wav", v)
        print(k, f"{len(v) / SR:.2f} s")
