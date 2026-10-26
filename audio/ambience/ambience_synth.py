# Bruits d'ambiance de la carte (synthétisés, originaux) : nappes stéréo en boucle
# par milieu + cris d'oiseaux isolés (placés en 3D dans le jeu) + souffle du vent.
# Sortie : WAV 22 050 Hz 16 bits.
import numpy as np, wave, sys, os
from scipy.signal import butter, sosfilt

SR = 22050
rng = np.random.default_rng(11)
OUT = sys.argv[1] if len(sys.argv) > 1 else "."

def tt(n): return np.arange(n) / SR
def ns(sec): return max(int(sec * SR), 1)
_sos = {}
def filt(x, kind, fc, order=2):
    key = (kind, tuple(np.atleast_1d(fc)), order)
    if key not in _sos:
        _sos[key] = butter(order, np.clip(np.array(fc) / (SR / 2), 1e-4, 0.999), btype=kind, output="sos")
    return sosfilt(_sos[key], x)
def noise(n): return rng.uniform(-1, 1, n)
def pink(n):
    w = np.fft.rfft(rng.standard_normal(n)); f = np.fft.rfftfreq(n, 1 / SR); f[0] = 1
    return np.fft.irfft(w / np.sqrt(f), n)
def osc(freq):  # fréquence variable -> sinus
    return np.sin(2 * np.pi * np.cumsum(freq) / SR)
def smooth_rand(n, rate_hz, lo=0.0, hi=1.0):
    k = max(int(n / SR * rate_hz) + 2, 3)
    pts = rng.uniform(lo, hi, k)
    return np.interp(np.linspace(0, k - 1, n), np.arange(k), pts)

class Bed:
    """Nappe en boucle : les événements qui dépassent la fin reviennent au début, et le
    fond continu est fondu enchaîné sur la couture."""
    def __init__(self, sec):
        self.n = ns(sec); self.x = 2 * SR
        self.buf = np.zeros((2, self.n + self.x + ns(6)))
    def add(self, sig, at, gain=1.0, pan=0.0):
        i = int(at * SR) % self.n
        end = min(i + len(sig), self.buf.shape[1])
        l, r = np.cos((pan + 1) * np.pi / 4), np.sin((pan + 1) * np.pi / 4)
        self.buf[0, i:end] += sig[: end - i] * gain * l * 1.41
        self.buf[1, i:end] += sig[: end - i] * gain * r * 1.41
    def add_bg(self, left, right, gain=1.0):  # fond continu, longueur n + x
        self.buf[0, : self.n + self.x] += left * gain
        self.buf[1, : self.n + self.x] += right * gain
    def render(self, peak=0.7):
        n, x = self.n, self.x
        out = self.buf[:, :n].copy()
        tail = self.buf[:, n:]
        fade = np.linspace(0, 1, x)
        # fond : fondu entre la fin (n..n+x) et le début
        out[:, :x] = out[:, :x] * fade + tail[:, :x] * (1 - fade)
        # événements au-delà de n+x : simplement repliés au début
        rest = tail[:, x:]
        out[:, : rest.shape[1]] += rest
        return out / (np.max(np.abs(out)) + 1e-9) * peak

# ------------------ voix d'oiseaux et autres ------------------
def chirp(f0, f1, dur, shape="exp", amp_curve=None):
    n = ns(dur); t = tt(n) / dur
    f = f0 * (f1 / f0) ** t if shape == "exp" else f0 + (f1 - f0) * t
    e = np.sin(np.pi * np.clip(t, 0, 1)) ** 1.5
    return osc(f) * e
def great_tit(rep=3):        # mésange charbonnière : « ti-tu ti-tu ti-tu »
    parts = []
    for _ in range(rep):
        parts += [chirp(6800, 6000, 0.09), np.zeros(ns(0.03)), chirp(4300, 4100, 0.11), np.zeros(ns(0.08))]
    return np.concatenate(parts) * 0.5
def blackbird():             # merle : phrase flûtée, notes variées avec vibrato
    parts = []
    for _ in range(rng.integers(4, 8)):
        f = rng.uniform(1600, 3200); d = rng.uniform(0.08, 0.28)
        n = ns(d); t = tt(n)
        fr = f * (1 + 0.04 * np.sin(2 * np.pi * rng.uniform(18, 30) * t)) * (1 + rng.uniform(-0.15, 0.15) * t / d)
        e = np.sin(np.pi * t / d) ** 1.2
        parts += [osc(fr) * e + 0.15 * osc(fr * 2) * e, np.zeros(ns(rng.uniform(0.02, 0.09)))]
    return np.concatenate(parts) * 0.5
def chaffinch():             # pinson : trille qui accélère et descend, fioriture finale
    parts = []; f = 5200
    for k in range(10):
        d = 0.07 - k * 0.004
        parts += [chirp(f, f * 0.8, d), np.zeros(ns(0.02))]
        f *= 0.95
    parts += [chirp(3000, 5500, 0.12), chirp(5000, 2500, 0.18)]
    return np.concatenate(parts) * 0.45
def cuckoo():                # coucou : « cou-cou »
    def hoot(f, d):
        n = ns(d); t = tt(n)
        return osc(np.full(n, f) * (1 - 0.06 * t / d)) * np.sin(np.pi * t / d) ** 0.8
    return np.concatenate([hoot(720, 0.22), np.zeros(ns(0.12)), hoot(590, 0.32)]) * 0.55
def owl():                   # chouette hulotte : « hou … hou-hou-hou »
    def hoot(d, f=420):
        n = ns(d); t = tt(n)
        s = osc(np.full(n, f) * (1 + 0.03 * np.sin(2 * np.pi * 6 * t))) + filt(noise(n), "bandpass", (300, 700)) * 0.25
        return s * np.sin(np.pi * t / d) ** 1.4
    return np.concatenate([hoot(0.55), np.zeros(ns(0.9)), hoot(0.2, 400), np.zeros(ns(0.05)), hoot(0.2, 390),
                           np.zeros(ns(0.05)), hoot(0.6, 380)]) * 0.55
def buzzard():               # buse : « piiiii-ah » descendant
    n = ns(1.1); t = tt(n) / 1.1
    f = 2900 - 1300 * t ** 1.5
    s = osc(f) + 0.3 * osc(f * 2.02) + filt(noise(n), "bandpass", (1500, 4000)) * 0.3
    return s * np.sin(np.pi * t) ** 0.6 * 0.4
def cowbell(f=620):          # cloche de vache (partiels inharmoniques)
    n = ns(1.6); t = tt(n); s = np.zeros(n)
    for ratio, dec, a in ((1, 3.0, 1), (2.76, 5, 0.5), (5.40, 8, 0.3), (8.93, 12, 0.15)):
        s += a * np.sin(2 * np.pi * f * ratio * t) * np.exp(-t * dec)
    return s * 0.25
def lark_warble(dur):        # alouette : gazouillis continu très aigu
    n = ns(dur); t = tt(n)
    f = 3500 + 1800 * smooth_rand(n, 14, -1, 1) + 600 * np.sin(2 * np.pi * 23 * t)
    gate = (smooth_rand(n, 9) > 0.35).astype(float) * (smooth_rand(n, 0.15) > 0.55)   # chante par épisodes
    gate = filt(gate, "lowpass", 60)
    return osc(f) * gate * 0.25
def crickets(n, rate=None):  # grillon : trains d'impulsions à ~4,5 kHz
    t = tt(n)
    carrier = np.sin(2 * np.pi * rng.uniform(4200, 5200) * t)
    pulse_rate = rng.uniform(28, 40)
    chirp_period = rng.uniform(0.35, 0.7) if rate is None else rate
    pulses = (np.sin(2 * np.pi * pulse_rate * t) > 0.2).astype(float)
    in_chirp = ((t % chirp_period) < chirp_period * 0.35).astype(float)
    return carrier * filt(pulses * in_chirp, "lowpass", 400) * 0.25
def grasshoppers(n):         # sauterelles : grésillement aigu par bouffées
    buzz = filt(noise(n), "bandpass", (6000, 9500))
    env = filt((smooth_rand(n, 3) > 0.45).astype(float), "lowpass", 8) * (0.6 + 0.4 * np.sin(2 * np.pi * 45 * tt(n)))
    return buzz * env * 0.35
def wind(n, strength=1.0, cut=500):
    p = pink(n); p /= np.max(np.abs(p))
    gust = 0.35 + 0.65 * smooth_rand(n, 0.25) ** 2
    return filt(p, "lowpass", cut) * gust * strength
def leaves(n):
    rustle = filt(noise(n), "bandpass", (1800, 6500))
    return rustle * (0.15 + 0.85 * smooth_rand(n, 0.4) ** 3) * 0.12

def bed_forest(sec=48):
    B = Bed(sec); m = B.n + B.x
    B.add_bg(wind(m, 0.5, 400) + leaves(m), wind(m, 0.5, 400) + leaves(m))
    t = 0.0
    while t < sec:
        f = [great_tit, blackbird, chaffinch][rng.integers(0, 3)]
        B.add(f() if f is not great_tit else great_tit(rng.integers(2, 5)), t, rng.uniform(0.15, 0.4), rng.uniform(-0.9, 0.9))
        t += rng.uniform(2.5, 7.0)          # silences entre deux chants
    B.add(cuckoo(), rng.uniform(0, sec), 0.12, rng.uniform(-0.8, 0.8))
    return B.render()
def bed_meadow(sec=48):
    B = Bed(sec); m = B.n + B.x
    B.add_bg(wind(m, 0.6, 600) + grasshoppers(m) * 0.3, wind(m, 0.6, 600) + grasshoppers(m) * 0.3)
    B.add_bg(lark_warble(m / SR) * 0.35, lark_warble(m / SR) * 0.35)
    t = 0.0
    while t < sec:
        B.add(great_tit(2) if rng.random() < 0.5 else chaffinch(), t, rng.uniform(0.08, 0.2), rng.uniform(-1, 1))
        t += rng.uniform(7.0, 15.0)
    return B.render()
def bed_mountain(sec=48):
    B = Bed(sec); m = B.n + B.x
    B.add_bg(wind(m, 1.0, 350) + wind(m, 0.4, 1200) * 0.4, wind(m, 1.0, 350) + wind(m, 0.4, 1200) * 0.4)
    t = 0.0
    while t < sec:   # troupeau au loin : cloches irrégulières
        base = rng.choice([540, 620, 700, 820])
        for k in range(rng.integers(1, 4)):
            B.add(filt(cowbell(base), "lowpass", 2500), t + k * rng.uniform(0.25, 0.6), rng.uniform(0.05, 0.12), rng.uniform(-0.7, 0.7))
        t += rng.uniform(4.0, 11.0)
    B.add(buzzard(), sec * 0.55, 0.11, -0.5)
    return B.render()
def bed_night(sec=48):
    B = Bed(sec); m = B.n + B.x
    l = wind(m, 0.25, 300); r = wind(m, 0.25, 300)
    for k in range(7):
        c = crickets(m); pan = rng.uniform(-1, 1)
        l += c * (1 - pan) * 0.5 * rng.uniform(0.4, 1); r += c * (1 + pan) * 0.5 * rng.uniform(0.4, 1)
    B.add_bg(l, r)
    B.add(owl(), sec * 0.4, 0.22, -0.6)
    return B.render(0.6)
def wind_rush(sec=8):        # souffle de l'air par la fenêtre ouverte
    B = Bed(sec); m = B.n + B.x
    def side():
        p = pink(m); p /= np.max(np.abs(p))
        turb = 0.6 + 0.4 * smooth_rand(m, 3) ** 2
        return (filt(p, "bandpass", (150, 2500)) + 0.3 * filt(noise(m), "bandpass", (1500, 6000))) * turb
    B.add_bg(side(), side())
    return B.render(0.75)

def write(name, x, stereo):
    data = (np.clip(x, -1, 1) * 32767).astype("<i2")
    if stereo: data = data.T.reshape(-1)
    with wave.open(os.path.join(OUT, name), "wb") as w:
        w.setnchannels(2 if stereo else 1); w.setsampwidth(2); w.setframerate(SR); w.writeframes(data.tobytes())
    print(name, "%.1f s" % ((x.shape[-1]) / SR))

def mono(sig, peak=0.8):
    sig = np.concatenate([np.zeros(ns(0.02)), sig, np.zeros(ns(0.1))])
    return sig / np.max(np.abs(sig)) * peak

if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    write("forest.wav", bed_forest(), True)
    write("meadow.wav", bed_meadow(), True)
    write("mountain.wav", bed_mountain(), True)
    write("night.wav", bed_night(), True)
    write("wind_rush.wav", wind_rush(), True)
    write("call_great_tit.wav", mono(great_tit(3)), False)
    write("call_blackbird.wav", mono(blackbird()), False)
    write("call_chaffinch.wav", mono(chaffinch()), False)
    write("call_cuckoo.wav", mono(cuckoo()), False)
    write("call_owl.wav", mono(owl()), False)
    write("call_buzzard.wav", mono(buzzard()), False)
    write("call_cowbell.wav", mono(filt(np.concatenate([cowbell(620), cowbell(640)[: ns(0.9)]]), "lowpass", 3000)), False)
