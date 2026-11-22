#!/usr/bin/env python3
"""Генерирует фоновую музыку assets/sounds/music.ogg (бесшовный луп ~48 с).
Музыка синтезируется этим скриптом, поэтому свободна от чужих прав — CC0.
Нужны numpy и ffmpeg:  python3 tools/make_music.py
"""
import subprocess, sys, os
import numpy as np

SR = 32000
BPM = 80
BEAT = 60.0 / BPM
BARS = 16                      # 16 тактов по 4 доли = 48 с
LEN = BARS * 4 * BEAT
TAIL = 4.0                     # хвост реверба, будет «склеен» с началом лупа

def midi(n):
    return 440.0 * 2 ** ((n - 69) / 12.0)

def env(n, a, r, sr=SR):
    e = np.ones(n)
    na, nr = int(a * sr), int(r * sr)
    if na: e[:na] = np.linspace(0, 1, na) ** 2
    if nr: e[-nr:] *= np.linspace(1, 0, nr) ** 2
    return e

def pad(freq, dur):
    n = int(dur * SR)
    t = np.arange(n) / SR
    s = np.zeros(n)
    for k, amp in ((1, 1.0), (2, 0.35), (3, 0.15), (4, 0.06)):
        for det in (-0.12, 0.0, 0.12):          # лёгкий хорус
            s += amp * np.sin(2 * np.pi * (freq * k + det * k) * t) / 3
    return s * env(n, 1.2, 1.6)

def pluck(freq, dur=1.6):
    n = int(dur * SR)
    t = np.arange(n) / SR
    s = (np.sin(2 * np.pi * freq * t) + 0.4 * np.sin(2 * np.pi * 2 * freq * t) * np.exp(-t * 6)
         + 0.15 * np.sin(2 * np.pi * 3 * freq * t) * np.exp(-t * 9))
    return s * np.exp(-t * 3.2) * env(n, 0.005, 0.05)

# Am – F – C – G (каждый аккорд — 2 такта)
CHORDS = [(57, [57, 60, 64]), (53, [53, 57, 60]), (48, [48, 52, 55]), (55, [55, 59, 62])]
ARP = [0, 1, 2, 1, 2, 1, 0, 1]   # порядок нот арпеджио по 8-м

total = int((LEN + TAIL) * SR)
mix = np.zeros(total)

def add(sig, t0, gain):
    i = int(t0 * SR)
    j = min(total, i + len(sig))
    mix[i:j] += sig[: j - i] * gain

bar_len = 4 * BEAT
for bar in range(BARS):
    root, notes = CHORDS[(bar // 2) % 4]
    t0 = bar * bar_len
    if bar % 2 == 0:
        for nt in notes:
            add(pad(midi(nt), bar_len * 2 + 1.0), t0, 0.16)
        add(pad(midi(root - 12), bar_len * 2 + 1.0), t0, 0.22)
    for step in range(8):
        nt = notes[ARP[step] % 3] + 12
        if (bar // 2) % 2 == 1 and step % 4 == 3:
            nt += 12
        if step % 2 == 0 or bar % 4 == 3:
            add(pluck(midi(nt)), t0 + step * BEAT / 2, 0.10)

# эхо
delay = int(BEAT * 0.75 * SR)
for k, g in ((1, 0.35), (2, 0.2), (3, 0.1)):
    mix[delay * k:] += mix[: total - delay * k] * g

# бесшовный луп: хвост накладываем на начало
loop_n = int(LEN * SR)
out = mix[:loop_n].copy()
tail = mix[loop_n:]
out[: len(tail)] += tail
out /= max(1e-9, np.abs(out).max()) / 0.7
pcm = (out * 32767).astype("<i2")

here = os.path.dirname(os.path.abspath(__file__))
dst = os.path.join(here, "..", "assets", "sounds", "music.ogg")
p = subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-f", "s16le", "-ar", str(SR), "-ac", "1",
                    "-i", "-", "-c:a", "libvorbis", "-q:a", "3", dst], input=pcm.tobytes())
sys.exit(p.returncode)
