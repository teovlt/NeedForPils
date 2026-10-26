# Synthèse des stations de l'autoradio (musique originale générée par code).
# Sortie : WAV mono 22 050 Hz 16 bits, boucles sans couture.
import numpy as np, wave, sys, os
from scipy.signal import butter, sosfilt

SR = 22050
rng = np.random.default_rng(7)
OUT = sys.argv[1] if len(sys.argv) > 1 else "."

def mtof(m): return 440.0 * 2 ** ((m - 69) / 12)
def tt(n): return np.arange(n) / SR
def nsamp(sec): return max(int(sec * SR), 1)

_sos = {}
def filt(x, kind, fc, order=2):
    key = (kind, tuple(np.atleast_1d(fc)), order)
    if key not in _sos:
        wn = np.array(fc) / (SR / 2)
        _sos[key] = butter(order, np.clip(wn, 1e-4, 0.999), btype=kind, output="sos")
    return sosfilt(_sos[key], x)

def env(n, a=0.005, d=0.1, s=0.6, r=0.1, hold=None):
    """ADSR ; hold = durée tenue (s) avant le relâchement."""
    t = tt(n)
    hold = (n / SR) - r if hold is None else hold
    e = np.where(t < a, t / max(a, 1e-4), s + (1 - s) * np.exp(-(t - a) / max(d, 1e-4)))
    rel = np.clip((t - hold) / max(r, 1e-4), 0, 1)
    return e * (1 - rel)

def saw(f, n, ph=0.0):
    p = np.cumsum(np.full(n, f) if np.isscalar(f) else f) / SR + ph
    return 2 * (p % 1.0) - 1
def sq(f, n, duty=0.5):
    p = (np.cumsum(np.full(n, f) if np.isscalar(f) else f) / SR) % 1.0
    return np.where(p < duty, 1.0, -1.0)
def sine(f, n, ph=0.0):
    return np.sin(2 * np.pi * (np.cumsum(np.full(n, f) if np.isscalar(f) else f) / SR + ph))
def noise(n): return rng.uniform(-1, 1, n)

class Song:
    def __init__(self, seconds):
        self.n = nsamp(seconds)
        self.buf = np.zeros(self.n + nsamp(4.0))
    def add(self, sig, at_sec, gain=1.0):
        i = int(at_sec * SR)
        if i < 0: return
        end = min(i + len(sig), len(self.buf))
        self.buf[i:end] += sig[: end - i] * gain
    def render(self, peak=0.89):
        out = self.buf[: self.n].copy()
        tail = self.buf[self.n:]
        out[: len(tail)] += tail          # la queue revient au début : boucle sans couture
        out = filt(out, "highpass", 60, 2)
        out = filt(out, "lowpass", 9000, 2)   # bande FM
        # égalisation « autoradio » : moins de graves, plus de présence (mélodies audibles)
        out = out - 0.62 * filt(out, "lowpass", 170, 2)
        out = out + 0.55 * filt(out, "bandpass", (1200, 5000), 2)
        out = np.tanh(out / (np.max(np.abs(out)) + 1e-9) * 1.6) # compression douce
        return out / np.max(np.abs(out)) * peak

# ---------------- batterie ----------------
def kick(dur=0.4, punch=1.0):
    n = nsamp(dur); t = tt(n)
    f = 44 + 120 * np.exp(-t * 32)
    s = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 8)
    click = filt(noise(n), "highpass", 2000) * np.exp(-t * 400) * 0.4
    return (s + click) * punch
def snare(dur=0.25, tone=190):
    n = nsamp(dur); t = tt(n)
    nz = filt(noise(n), "bandpass", (1200, 7000)) * np.exp(-t * 17)
    tn = np.sin(2 * np.pi * tone * t) * np.exp(-t * 28) * 0.6
    return nz * 1.1 + tn
def clap(dur=0.3):
    n = nsamp(dur); t = tt(n)
    e = np.zeros(n)
    for k, off in enumerate((0.0, 0.011, 0.022)):
        e += np.where(t >= off, np.exp(-(t - off) * (220 if k < 2 else 22)), 0)
    return filt(noise(n), "bandpass", (900, 3200)) * e
def hat(dur=0.05, open_=False):
    n = nsamp(0.32 if open_ else dur); t = tt(n)
    return filt(noise(n), "highpass", 7000) * np.exp(-t * (11 if open_ else 75)) * 0.5
def crash(dur=1.6):
    n = nsamp(dur); t = tt(n)
    return filt(noise(n), "highpass", 4000) * np.exp(-t * 2.4) * 0.45
def brush(dur=0.35):
    n = nsamp(dur); t = tt(n)
    sw = np.sin(np.pi * np.clip(t / dur, 0, 1)) ** 2
    return filt(noise(n), "bandpass", (2500, 9000)) * sw * 0.3

# ---------------- instruments ----------------
def bass_saw(m, dur, cut=500):
    n = nsamp(dur)
    s = saw(mtof(m), n) + 0.5 * sq(mtof(m) / 2, n)
    return filt(s, "lowpass", cut, 2) * env(n, 0.004, 0.12, 0.5, 0.05) * 0.8
def bass_round(m, dur):
    n = nsamp(dur); t = tt(n); f = mtof(m)
    s = np.sin(2 * np.pi * f * t) + 0.25 * np.sin(4 * np.pi * f * t) + 0.1 * saw(f, n)
    return s * env(n, 0.006, 0.25, 0.55, 0.06) * 0.9
def pluck(m, dur, bright=3000):
    n = nsamp(dur); t = tt(n)
    s = saw(mtof(m), n) * 0.6 + sq(mtof(m) * 1.003, n) * 0.4
    s = filt(s, "lowpass", bright, 2)
    return s * np.exp(-t * 9) * env(n, 0.002, 1, 1, 0.03) * 0.5
def pad(notes, dur, cut=1600, att=0.4):
    n = nsamp(dur); s = np.zeros(n)
    for m in notes:
        for det in (-0.12, 0.0, 0.12):
            s += saw(mtof(m + det), n, ph=rng.random())
    s = filt(s / (3 * len(notes)), "lowpass", cut, 2)
    return s * env(n, att, 0.5, 0.85, 0.4) * 0.9
def stab(notes, dur=0.25, cut=2500):
    n = nsamp(dur); t = tt(n); s = np.zeros(n)
    for m in notes:
        s += saw(mtof(m), n) + saw(mtof(m) * 1.005, n)
    s = filt(s / (2 * len(notes)), "lowpass", cut, 2)
    return s * np.exp(-t * 7) * env(n, 0.003, 1, 1, 0.04)
def rhodes(notes, dur):
    n = nsamp(dur); t = tt(n); s = np.zeros(n)
    for m in notes:
        f = mtof(m)
        idx = 1.8 * np.exp(-t * 4)
        s += np.sin(2 * np.pi * f * t + idx * np.sin(2 * np.pi * f * t)) * np.exp(-t * 1.1)
    trem = 1 + 0.18 * np.sin(2 * np.pi * 4.5 * t)
    return s / len(notes) * trem * env(n, 0.004, 1, 1, 0.25) * 0.8
def vibes(m, dur):
    n = nsamp(dur); t = tt(n); f = mtof(m)
    s = np.sin(2 * np.pi * f * t) + 0.3 * np.sin(2 * np.pi * f * 4.0 * t) * np.exp(-t * 6)
    return s * np.exp(-t * 2.2) * (1 + 0.25 * np.sin(2 * np.pi * 5.5 * t)) * 0.35
def power_chord(root, dur, mute=True):
    n = nsamp(dur); t = tt(n)
    s = np.zeros(n)
    for iv in (0, 7, 12):
        f = mtof(root + iv)
        s += saw(f, n) + saw(f * 1.004, n)
    s = np.tanh(s * 2.2)
    s = filt(s, "lowpass", 2200 if mute else 3600, 2)
    e = np.exp(-t * (14 if mute else 1.6)) * env(n, 0.003, 1, 1, 0.03)
    return s * e * 0.45
def lead(m, dur, vib=True):
    n = nsamp(dur); t = tt(n)
    f = mtof(m) * (1 + (0.006 * np.sin(2 * np.pi * 5.8 * t) * np.clip(t * 3 - 0.3, 0, 1) if vib else 0))
    s = np.tanh((sq(f, n, 0.35) * 0.6 + saw(f, n) * 0.5) * 2.5)
    s = filt(s, "lowpass", 3200, 2)
    return s * env(n, 0.01, 0.2, 0.75, 0.08) * 0.3
def strings(notes, dur, att=0.15, cut=3500):
    n = nsamp(dur); t = tt(n); s = np.zeros(n)
    for m in notes:
        for det in (-0.08, 0.08):
            f = mtof(m + det) * (1 + 0.004 * np.sin(2 * np.pi * 5.2 * t + rng.random() * 6))
            s += saw(f, n)
    s = filt(s / (2 * len(notes)), "lowpass", cut, 2)
    return s * env(n, att, 0.3, 0.8, 0.18) * 0.7
def scratch_guitar(notes, dur=0.09):
    n = nsamp(dur); t = tt(n); s = np.zeros(n)
    for m in notes:
        s += saw(mtof(m), n)
    s = filt(s / len(notes) + noise(n) * 0.3, "bandpass", (700, 3500))
    return s * np.exp(-t * 35) * 0.6

def chord_tones(root, kind):
    iv = {"m": (0, 3, 7), "M": (0, 4, 7), "m7": (0, 3, 7, 10), "M7": (0, 4, 7, 11), "7": (0, 4, 7, 10),
          "m9": (0, 3, 7, 10, 14), "M9": (0, 4, 7, 11, 14), "13": (0, 4, 10, 14, 21), "7b9": (0, 4, 7, 10, 13)}[kind]
    return [root + i for i in iv]

# ================= 1. Pils FM : électro house 124 bpm =================
def station_electro():
    bpm = 124; b = 60 / bpm; bar = 4 * b; bars = 16
    S = Song(bars * bar)
    prog = [(57, "m"), (53, "M"), (48, "M"), (55, "M")]   # Am F C G
    for i in range(bars):
        t0 = i * bar
        root, kind = prog[i % 4]
        tones = chord_tones(root, kind)
        intro, breakdown = i < 4, 12 <= i < 15
        if not breakdown:
            for k in range(4): S.add(kick(), t0 + k * b, 0.95)
        for k in range(8):
            S.add(hat(open_=(k % 2 == 1)), t0 + k * b / 2, 0.35 if k % 2 else 0.25)
        if not intro and not breakdown:
            S.add(clap(), t0 + b, 0.55); S.add(clap(), t0 + 3 * b, 0.55)
        if not breakdown:
            for k in range(4):   # basse sur les contretemps
                S.add(bass_saw(root - 24 + (12 if k == 3 else 0), b * 0.45, 650), t0 + k * b + b / 2, 0.8)
        if not intro:
            arp = [tones[0] + 12, tones[1] + 12, tones[2] + 12, tones[1] + 24]
            for k in range(16):
                cut = 1800 + 1600 * (0.5 + 0.5 * np.sin(2 * np.pi * (i * 16 + k) / 64))
                S.add(pluck(arp[k % 4], b / 4 * 1.6, cut), t0 + k * b / 4, 0.45)
        if not intro and not breakdown:
            S.add(stab([m + 12 for m in tones], 0.22), t0 + 1.5 * b, 0.35)
            S.add(stab([m + 12 for m in tones], 0.22), t0 + 3.5 * b, 0.35)
        if breakdown or intro:
            S.add(pad([m + 12 for m in tones], bar * 1.05), t0, 0.5)
        if i == 15:
            for k in range(8): S.add(snare(0.18), t0 + 2 * b + k * b / 4, 0.25 + k * 0.05)
        if i in (4, 12):
            S.add(crash(), t0, 0.5)
    return S.render()

# ================= 2. Radio Bitume : rock 140 bpm =================
def station_rock():
    bpm = 140; b = 60 / bpm; bar = 4 * b; bars = 18
    S = Song(bars * bar)
    riff_a = [40, 40, 36, 38]      # E5 E5 C5 D5
    riff_b = [45, 45, 36, 38]      # A5 A5 C5 D5
    melody = [(76, 1), (79, 0.5), (81, 0.5), (79, 1), (76, 1), (74, 1), (76, 2), (None, 1),
              (71, 0.5), (74, 0.5), (76, 1), (79, 1), (81, 1.5), (79, 0.5), (76, 2), (None, 2)]
    for i in range(bars):
        t0 = i * bar
        root = (riff_a if (i // 4) % 2 == 0 else riff_b)[i % 4]
        S.add(kick(0.3), t0, 1.0); S.add(kick(0.3), t0 + 2 * b, 1.0); S.add(kick(0.3), t0 + 2.5 * b, 0.8)
        S.add(snare(), t0 + b, 0.9); S.add(snare(), t0 + 3 * b, 0.9)
        for k in range(8): S.add(hat(), t0 + k * b / 2, 0.3)
        if i % 4 == 0: S.add(crash(), t0, 0.55)
        for k in range(8):   # guitare en croches étouffées, accent ouvert sur le 1
            open_ = k == 0 or (k == 6 and i % 2 == 1)
            S.add(power_chord(root, b / 2 * (3 if open_ else 1), mute=not open_), t0 + k * b / 2, 0.7 if open_ else 0.55)
            S.add(bass_saw(root - 12, b * 0.45, 900), t0 + k * b / 2, 0.55)
        if i == 17:
            for k in range(4): S.add(snare(0.15), t0 + 3 * b + k * b / 4, 0.5)
    # solo sur la deuxième moitié
    t = 8 * bar
    for m, d in melody:
        if m: S.add(lead(m, d * b * 0.95), t, 0.8)
        t += d * b
    return S.render()

# ================= 3. Lounge 97.3 : lo-fi jazz 80 bpm =================
def station_lounge():
    bpm = 80; b = 60 / bpm; bar = 4 * b; bars = 12
    S = Song(bars * bar)
    prog = [(50, "m9"), (43, "13"), (48, "M9"), (45, "7b9")]   # Dm9 G13 Cmaj9 A7b9
    walk = {50: [50, 53, 57, 55], 43: [43, 47, 50, 49], 48: [48, 52, 55, 46], 45: [45, 49, 52, 51]}
    sw = b / 2 * 1.32          # croches swinguées
    vib_line = [74, 72, 69, 67, 69, 72, 76, 74, 72, 71, 69, 64]
    for i in range(bars):
        t0 = i * bar
        root, kind = prog[i % 4]
        tones = chord_tones(root, kind)
        S.add(kick(0.35, 0.7), t0, 0.8); S.add(kick(0.35, 0.7), t0 + 1.5 * b + 0.06, 0.6)
        S.add(snare(0.3, 170), t0 + b, 0.35); S.add(snare(0.3, 170), t0 + 3 * b, 0.35)
        for k in range(4):
            S.add(hat(0.04), t0 + k * b, 0.18); S.add(hat(0.04), t0 + k * b + sw, 0.12)
            S.add(brush(), t0 + k * b, 0.5)
        for k, m in enumerate(walk[root]):
            S.add(bass_round(m - 12, b * 0.92), t0 + k * b, 0.75)
        voic = [m + 12 for m in tones[1:]] if len(tones) > 3 else [m + 12 for m in tones]
        S.add(rhodes(voic, bar * 0.9), t0 + 0.02, 0.6)
        S.add(rhodes(voic, b * 0.8), t0 + 2.5 * b + 0.03, 0.35)
        if i >= 4:
            S.add(vibes(vib_line[(i - 4) * 2 % 12], b * 2.5), t0 + b, 0.9)
            S.add(vibes(vib_line[((i - 4) * 2 + 1) % 12], b * 2), t0 + 2.5 * b, 0.8)
    out = S.render(0.82)
    # vinyle : craquements + souffle, et un peu de lo-fi
    crack = np.zeros_like(out)
    pos = rng.integers(0, len(out), int(len(out) / SR * 9))
    crack[pos] = rng.uniform(-0.5, 0.5, len(pos))
    crack = filt(crack, "bandpass", (1500, 6000))
    hiss = filt(noise(len(out)), "bandpass", (3000, 8000)) * 0.012
    out = filt(out, "lowpass", 6500, 2) + crack + hiss
    out = out - 0.4 * filt(out, "lowpass", 160, 2)
    return out / np.max(np.abs(out)) * 0.82

# ================= 4. Disco Pilule : disco-funk 118 bpm =================
def station_disco():
    bpm = 118; b = 60 / bpm; bar = 4 * b; bars = 16
    S = Song(bars * bar)
    prog = [(53, "m7"), (58, "m7"), (51, "M7"), (56, "M7")]   # Fm7 Bbm7 Ebmaj7 Abmaj7
    hook = [(77, 0.5), (75, 0.5), (72, 1), (70, 0.5), (72, 1.5), (None, 4),
            (80, 0.5), (79, 0.5), (77, 1), (75, 1), (72, 1), (None, 4)]
    for i in range(bars):
        t0 = i * bar
        root, kind = prog[i % 4]
        tones = chord_tones(root, kind)
        for k in range(4): S.add(kick(0.3), t0 + k * b, 0.9)
        S.add(clap(), t0 + b, 0.5); S.add(clap(), t0 + 3 * b, 0.5)
        for k in range(4):
            S.add(hat(open_=True), t0 + k * b + b / 2, 0.3)
            S.add(hat(), t0 + k * b, 0.15)
        for k in range(8):   # basse en octaves
            S.add(bass_saw(root - 24 + (12 if k % 2 else 0), b * 0.42, 900), t0 + k * b / 2, 0.8)
        for k in range(16):  # guitare « grattée » en double croches
            if k % 4 in (1, 3) or k % 8 == 6:
                S.add(scratch_guitar([m + 12 for m in tones[:3]]), t0 + k * b / 4, 0.5)
        if i % 2 == 0:
            S.add(strings([m + 12 for m in tones], bar * 2, att=0.6), t0, 0.45)
        else:
            S.add(stab([m + 24 for m in tones[:3]], 0.2, 4000), t0 + 3.5 * b, 0.4)
        if i in (0, 8): S.add(crash(), t0, 0.45)
    t = 4 * bar
    for rep in range(2):
        for m, d in hook:
            if m: S.add(strings([m], d * b * 0.95, att=0.03, cut=5000), t, 0.75)
            t += d * b
    return S.render()

def static_noise(sec=1.2):
    n = nsamp(sec)
    s = filt(noise(n), "lowpass", 6000) * 0.5
    s += filt(noise(n), "bandpass", (300, 1200)) * 0.3 * (0.6 + 0.4 * np.sin(2 * np.pi * 7 * tt(n)))
    pos = rng.integers(0, n, int(sec * 40)); s[pos] += rng.uniform(-0.8, 0.8, len(pos))
    return s / np.max(np.abs(s)) * 0.6

def write(name, x):
    data = (np.clip(x, -1, 1) * 32767).astype("<i2")
    with wave.open(os.path.join(OUT, name), "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR); w.writeframes(data.tobytes())
    print(name, "%.1f s" % (len(x) / SR))

if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    write("pils_fm.wav", station_electro())
    write("radio_bitume.wav", station_rock())
    write("lounge_973.wav", station_lounge())
    write("disco_pilule.wav", station_disco())
    write("static.wav", static_noise())
